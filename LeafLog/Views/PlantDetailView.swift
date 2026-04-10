import SwiftUI
import UIKit

struct PlantDetailView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var store: PlantStore

    let plantID: UUID

    @State private var editingPlant: Plant?

    var body: some View {
        Group {
            if let plant {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    labeledSummaryValue(title: "Plant", value: plant.name, prominent: true)

                                    if plant.species.isEmpty == false {
                                        labeledSummaryValue(title: "Species", value: plant.species)
                                    }

                                    if plant.room.isEmpty == false {
                                        labeledSummaryValue(title: "Room", value: plant.room, systemImage: "house")
                                    }
                                }

                                Spacer()

                                statusBadge(for: plant)
                            }

                            Text(plant.wateringStatusText)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(plant.isOverdue ? .red : plant.isDueToday ? .orange : .secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    Section("Actions") {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                store.markWatered(plant, source: .manualDetail)
                            }
                        } label: {
                            Label("Mark Watered", systemImage: "drop.fill")
                        }
                        .tint(.green)

                        Button {
                            editingPlant = plant
                        } label: {
                            Label("Edit Plant", systemImage: "pencil")
                        }

                        Button {
                            toggleReminder(for: plant)
                        } label: {
                            Label(plant.reminderEnabled ? "Turn Reminder Off" : "Turn Reminder On", systemImage: "bell")
                        }

                        Button(role: .destructive) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                store.deletePlant(plant)
                            }
                        } label: {
                            Label("Delete Plant", systemImage: "trash")
                        }
                    }

                    Section("Watering") {
                        detailRow(title: "Last watered", value: plant.lastWateredAt.formatted(date: .abbreviated, time: .omitted))
                        detailRow(title: "Next watering", value: plant.nextWateringDate.formatted(date: .abbreviated, time: .omitted))
                        detailRow(title: "Interval", value: "Every \(plant.wateringIntervalDays) day\(plant.wateringIntervalDays == 1 ? "" : "s")")
                    }

                    Section("Reminder") {
                        NotificationStatusCard(
                            authorizationState: store.notificationState,
                            reminderEnabled: plant.reminderEnabled,
                            reminderTimeText: plant.formattedReminderTime,
                            onOpenSettings: openAppSettings
                        )
                    }

                    Section("Notes") {
                        if plant.notes.isEmpty {
                            Text("No notes yet. Add details like watering quirks, sunlight needs, or problem spots.")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(plant.notes)
                        }
                    }

                    Section("Recent Watering History") {
                        if plant.recentWateringEvents.isEmpty {
                            Text("No watering history yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(plant.recentWateringEvents.prefix(10))) { event in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline.weight(.semibold))
                                    Text(event.source.label)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle(plant.name)
                .navigationBarTitleDisplayMode(.inline)
                .sheet(item: $editingPlant) { plant in
                    NavigationStack {
                        PlantFormView(mode: .edit(plant))
                    }
                    .environmentObject(store)
                }
            } else {
                ContentUnavailableView(
                    "Plant Not Available",
                    systemImage: "leaf.circle",
                    description: Text("This plant may have been deleted.")
                )
            }
        }
        .task {
            await store.refreshNotificationStatus()
        }
    }

    private var plant: Plant? {
        store.plant(withID: plantID)
    }

    @ViewBuilder
    private func statusBadge(for plant: Plant) -> some View {
        if plant.isOverdue {
            StatusPill(title: "Overdue", tint: .red)
        } else if plant.isDueToday {
            StatusPill(title: "Due Today", tint: .orange)
        } else {
            StatusPill(title: "Upcoming", tint: .green)
        }
    }

    @ViewBuilder
    private func detailRow(title: String, value: String) -> some View {
        LabeledContent(title) {
            Text(value)
        }
    }

    private func toggleReminder(for plant: Plant) {
        Task {
            if plant.reminderEnabled == false {
                await NotificationManager.shared.requestAuthorizationIfNeeded()
            }

            await store.refreshNotificationStatus()

            guard let refreshedPlant = store.plant(withID: plant.id) else { return }
            var updatedPlant = refreshedPlant
            updatedPlant.reminderEnabled.toggle()
            store.updatePlant(updatedPlant)
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    @ViewBuilder
    private func labeledSummaryValue(
        title: String,
        value: String,
        prominent: Bool = false,
        systemImage: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let systemImage {
                Label(value, systemImage: systemImage)
                    .font(prominent ? .title2.weight(.bold) : .headline)
                    .foregroundStyle(prominent ? .primary : .secondary)
            } else {
                Text(value)
                    .font(prominent ? .title2.weight(.bold) : .headline)
                    .foregroundStyle(prominent ? .primary : .secondary)
            }
        }
    }
}

struct NotificationStatusCard: View {
    let authorizationState: NotificationManager.AuthorizationState
    let reminderEnabled: Bool
    let reminderTimeText: String
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(authorizationState.title)
                .font(.subheadline.weight(.semibold))

            Text(detailText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if authorizationState == .denied {
                Button("Open Settings", action: onOpenSettings)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    private var detailText: String {
        switch authorizationState {
        case .allowed:
            if reminderEnabled {
                return "This plant is set to remind you at \(reminderTimeText) on its next watering day."
            }
            return "Notifications are allowed, but this plant's reminder is currently off."
        case .notDetermined, .denied:
            return authorizationState.detail
        }
    }
}

private struct StatusPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.16), in: Capsule())
            .foregroundStyle(tint)
    }
}
