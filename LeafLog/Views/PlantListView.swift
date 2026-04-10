import SwiftUI

struct PlantListView: View {
    @EnvironmentObject private var store: PlantStore
    @State private var showingAddPlant = false
    @State private var editingPlant: Plant?

    var body: some View {
        List {
            Section("Your Plants") {
                if store.sortedPlants.isEmpty {
                    ContentUnavailableView(
                        "No Plants Yet",
                        systemImage: "leaf.circle",
                        description: Text("Add your first plant to start tracking watering schedules and reminders.")
                    )
                } else {
                    ForEach(store.sortedPlants) { plant in
                        PlantRow(plant: plant) {
                            store.markWatered(plant)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingPlant = plant
                        }
                    }
                    .onDelete(perform: store.deletePlants)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("LeafLog")
        .toolbar {
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
    }
}

private struct PlantRow: View {
    let plant: Plant
    let onWatered: () -> Void

    var body: some View {
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

                if plant.isOverdue {
                    StatusBadge(title: "Overdue", color: .red)
                } else {
                    StatusBadge(title: "Up Next", color: .green)
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

            HStack {
                Label("Every \(plant.wateringIntervalDays) day\(plant.wateringIntervalDays == 1 ? "" : "s")", systemImage: "drop")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if plant.reminderEnabled {
                    Label(
                        "\(formattedTime(hour: plant.reminderHour, minute: plant.reminderMinute)) reminder",
                        systemImage: "bell.badge"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Button("Mark Watered", action: onWatered)
                .buttonStyle(.borderedProminent)
                .tint(.green)
        }
        .padding(.vertical, 6)
    }

    private func formattedTime(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
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
    }
}
