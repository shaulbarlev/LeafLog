import SwiftUI

struct PlantListView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all
        case attention
        case reminders

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                return "All Plants"
            case .attention:
                return "Needs Attention"
            case .reminders:
                return "Reminders On"
            }
        }
    }

    private struct PlantRoute: Identifiable, Hashable {
        let id: UUID
    }

    private struct PlantSection: Identifiable {
        let id = UUID()
        let title: String
        let plants: [Plant]
    }

    @EnvironmentObject private var store: PlantStore

    @AppStorage("plant_sort_mode") private var selectedSortRawValue = PlantSortMode.dueSoon.rawValue

    @State private var showingAddPlant = false
    @State private var editingPlant: Plant?
    @State private var selectedPlantRoute: PlantRoute?
    @State private var searchText = ""
    @State private var selectedFilter: Filter = .all

    var body: some View {
        List {
            if store.plants.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Plants Yet",
                        systemImage: "leaf.circle",
                        description: Text("Add your first plant to start tracking watering schedules, reminders, and quick daily tasks.")
                    )
                }
            } else {
                if todayPlants.isEmpty == false {
                    Section {
                        ForEach(todayPlants) { plant in
                            plantRow(for: plant, emphasized: true)
                        }
                    } header: {
                        Text("Today")
                    } footer: {
                        Text("Overdue and due-today plants stay here so your next actions are obvious.")
                    }
                } else if selectedFilter == .all && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        ContentUnavailableView(
                            "You're All Caught Up",
                            systemImage: "checkmark.circle",
                            description: Text("Nothing needs watering today.")
                        )
                    } header: {
                        Text("Today")
                    }
                }

                Section {
                    PlantOverviewSection(plants: visiblePlants)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

                ForEach(resultSections) { section in
                    Section(section.title) {
                        ForEach(section.plants) { plant in
                            plantRow(for: plant, emphasized: false)
                        }
                    }
                }

                if shouldShowNoResults {
                    Section("Results") {
                        ContentUnavailableView(
                            "No Matching Plants",
                            systemImage: "line.3.horizontal.decrease.circle",
                            description: Text("Try clearing your search or choosing a different filter.")
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("LeafLog")
        .searchable(text: $searchText, prompt: "Search by name, species, room, or notes")
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: visiblePlants)
        .animation(.easeInOut(duration: 0.2), value: selectedFilter)
        .animation(.easeInOut(duration: 0.2), value: searchText)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Section("Filter") {
                        Picker("Filter", selection: $selectedFilter) {
                            ForEach(Filter.allCases) { filter in
                                Text(filter.title).tag(filter)
                            }
                        }
                    }

                    Section("Sort") {
                        Picker("Sort", selection: $selectedSortRawValue) {
                            ForEach(PlantSortMode.allCases) { mode in
                                Text(mode.title).tag(mode.rawValue)
                            }
                        }
                    }
                } label: {
                    Label("Organize", systemImage: "line.3.horizontal.decrease.circle")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddPlant = true
                } label: {
                    Label("Add Plant", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPlant) {
            NavigationStack {
                PlantFormView(mode: .create)
            }
            .environmentObject(store)
        }
        .sheet(item: $editingPlant) { plant in
            NavigationStack {
                PlantFormView(mode: .edit(plant))
            }
            .environmentObject(store)
        }
        .navigationDestination(item: $selectedPlantRoute) { route in
            PlantDetailView(plantID: route.id)
                .environmentObject(store)
        }
    }

    private var selectedSort: PlantSortMode {
        PlantSortMode(rawValue: selectedSortRawValue) ?? .dueSoon
    }

    private var visiblePlants: [Plant] {
        let normalizedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let sorted = store.sort(store.plants, by: selectedSort)

        return sorted.filter { plant in
            let matchesFilter: Bool
            switch selectedFilter {
            case .all:
                matchesFilter = true
            case .attention:
                matchesFilter = plant.isOverdue || plant.isDueToday
            case .reminders:
                matchesFilter = plant.reminderEnabled
            }

            guard matchesFilter else { return false }
            guard normalizedQuery.isEmpty == false else { return true }

            let haystacks = [plant.name, plant.species, plant.room, plant.notes]
            return haystacks.contains { $0.localizedCaseInsensitiveContains(normalizedQuery) }
        }
    }

    private var todayPlants: [Plant] {
        visiblePlants.filter { $0.isOverdue || $0.isDueToday }
    }

    private var laterPlants: [Plant] {
        visiblePlants.filter { todayPlants.contains($0) == false }
    }

    private var resultSections: [PlantSection] {
        guard laterPlants.isEmpty == false else { return [] }

        if selectedSort == .room {
            let grouped = Dictionary(grouping: laterPlants) { plant in
                plant.room.isEmpty ? "Unassigned" : plant.room
            }
            return grouped.keys.sorted().map { key in
                PlantSection(title: key, plants: grouped[key] ?? [])
            }
        }

        let title: String
        switch selectedSort {
        case .dueSoon:
            title = "Upcoming"
        case .name:
            title = "All Plants"
        case .room:
            title = "By Room"
        }
        return [PlantSection(title: title, plants: laterPlants)]
    }

    private var shouldShowNoResults: Bool {
        store.plants.isEmpty == false && visiblePlants.isEmpty
    }

    @ViewBuilder
    private func plantRow(for plant: Plant, emphasized: Bool) -> some View {
        PlantRow(
            plant: plant,
            emphasized: emphasized,
            onOpen: {
                selectedPlantRoute = PlantRoute(id: plant.id)
            },
            onWatered: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    store.markWatered(plant, source: .manualList)
                }
            },
            onEdit: {
                editingPlant = plant
            },
            onDelete: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    store.deletePlant(plant)
                }
            }
        )
        .id(plant.id)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    store.markWatered(plant, source: .manualList)
                }
            } label: {
                Label("Watered", systemImage: "drop.fill")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    store.deletePlant(plant)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                editingPlant = plant
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
}

private struct PlantRow: View {
    let plant: Plant
    let emphasized: Bool
    let onOpen: () -> Void
    let onWatered: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plant.name)
                                .font(.headline)

                            if !plant.species.isEmpty {
                                Text(plant.species)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if !plant.room.isEmpty {
                                Label(plant.room, systemImage: "house")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            statusBadge
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Last watered")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(plant.lastWateredAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Water again")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(plant.nextWateringDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline.weight(.semibold))
                        }
                    }

                    Label(plant.wateringStatusText, systemImage: plant.isOverdue ? "exclamationmark.triangle.fill" : "calendar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(plant.isOverdue ? .red : plant.isDueToday ? .orange : .secondary)

                    HStack {
                        Label("Every \(plant.wateringIntervalDays) day\(plant.wateringIntervalDays == 1 ? "" : "s")", systemImage: "drop")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if plant.reminderEnabled {
                            Label("\(plant.formattedReminderTime) reminder", systemImage: "bell.badge")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if plant.notes.isEmpty == false {
                        Text(plant.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            HStack {
                Button("Mark Watered", action: onWatered)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .symbolEffect(.bounce, value: plant.lastWateredAt)

                Button("Edit", action: onEdit)
                    .buttonStyle(.bordered)

                Button("Delete", role: .destructive, action: onDelete)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, emphasized ? 4 : 0)
        .contentTransition(.interpolate)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: plant.lastWateredAt)
        .animation(.easeInOut(duration: 0.2), value: plant.isOverdue)
        .animation(.easeInOut(duration: 0.2), value: plant.isDueToday)
    }

    private var statusBadge: some View {
        Group {
            if plant.isOverdue {
                StatusBadge(title: "Overdue", color: .red)
            } else if plant.isDueToday {
                StatusBadge(title: "Today", color: .orange)
            } else {
                StatusBadge(title: "Up Next", color: .green)
            }
        }
    }
}

private struct PlantOverviewSection: View {
    let plants: [Plant]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                OverviewCard(
                    title: "Overdue",
                    value: plants.filter(\.isOverdue).count,
                    icon: "exclamationmark.triangle.fill",
                    tint: .red
                )
                OverviewCard(
                    title: "Due Today",
                    value: plants.filter(\.isDueToday).count,
                    icon: "calendar",
                    tint: .orange
                )
                OverviewCard(
                    title: "Reminders",
                    value: plants.filter(\.reminderEnabled).count,
                    icon: "bell.badge.fill",
                    tint: .blue
                )
            }
            .padding(.horizontal)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct OverviewCard: View {
    let title: String
    let value: Int
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text("\(value)")
                .font(.title2.weight(.bold))
                .contentTransition(.numericText())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 116, alignment: .leading)
        .padding()
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.spring(response: 0.3, dampingFraction: 0.84), value: value)
    }
}

private struct StatusBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
            .contentTransition(.interpolate)
    }
}
