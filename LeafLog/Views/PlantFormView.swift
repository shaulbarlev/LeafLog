import SwiftUI
import UIKit

struct PlantFormView: View {
    @Environment(\.openURL) private var openURL
    enum Mode {
        case create
        case edit(Plant)

        var title: String {
            switch self {
            case .create:
                return "Add Plant"
            case .edit:
                return "Edit Plant"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PlantStore

    private let mode: Mode

    @State private var draftID: UUID
    @State private var name: String
    @State private var species: String
    @State private var room: String
    @State private var notes: String
    @State private var wateringIntervalDays: Int
    @State private var lastWateredAt: Date
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date

    init(mode: Mode) {
        self.mode = mode

        switch mode {
        case .create:
            _draftID = State(initialValue: UUID())
            _name = State(initialValue: "")
            _species = State(initialValue: "")
            _room = State(initialValue: "")
            _notes = State(initialValue: "")
            _wateringIntervalDays = State(initialValue: 7)
            _lastWateredAt = State(initialValue: .now)
            _reminderEnabled = State(initialValue: false)
            _reminderTime = State(initialValue: Self.dateFor(hour: 9, minute: 0))
        case let .edit(plant):
            _draftID = State(initialValue: plant.id)
            _name = State(initialValue: plant.name)
            _species = State(initialValue: plant.species)
            _room = State(initialValue: plant.room)
            _notes = State(initialValue: plant.notes)
            _wateringIntervalDays = State(initialValue: plant.wateringIntervalDays)
            _lastWateredAt = State(initialValue: plant.lastWateredAt)
            _reminderEnabled = State(initialValue: plant.reminderEnabled)
            _reminderTime = State(initialValue: Self.dateFor(hour: plant.reminderHour, minute: plant.reminderMinute))
        }
    }

    var body: some View {
        Form {
            Section {
                labeledField(
                    title: "Name",
                    text: $name,
                    prompt: "Monstera"
                )
                labeledField(
                    title: "Species",
                    text: $species,
                    prompt: "Deliciosa"
                )
                labeledField(
                    title: "Room",
                    text: $room,
                    prompt: "Living Room"
                )
            } header: {
                Text("Plant Details")
            } footer: {
                Text("Only the plant name is required. Species, room, and notes help you search and recognize plants faster later.")
            }

            Section {
                DatePicker("Last Watered", selection: $lastWateredAt, displayedComponents: .date)

                Stepper(value: $wateringIntervalDays, in: 1 ... 30) {
                    Label("Every \(wateringIntervalDays) day\(wateringIntervalDays == 1 ? "" : "s")", systemImage: "drop")
                }
            } header: {
                Text("Watering Schedule")
            } footer: {
                Text("LeafLog uses the last watered date and interval to calculate the next watering day.")
            }

            Section {
                Toggle("Send watering reminder", isOn: $reminderEnabled)
                if reminderEnabled {
                    DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    NotificationStatusCard(
                        authorizationState: store.notificationState,
                        reminderEnabled: reminderEnabled,
                        reminderTimeText: composedPlant.formattedReminderTime,
                        onOpenSettings: openAppSettings
                    )
                }
            } header: {
                Text("Reminder")
            } footer: {
                Text("Enable a reminder if you want a local notification on the next watering day.")
            }

            Section("Notes") {
                TextField("", text: $notes, prompt: Text("Add care notes, quirks, or problem spots"), axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
            }

            Section {
                LabeledContent("Next Watering") {
                    Text(composedPlant.nextWateringDate.formatted(date: .abbreviated, time: .omitted))
                        .fontWeight(.semibold)
                }

                LabeledContent("Status") {
                    Text(composedPlant.wateringStatusText)
                        .foregroundStyle(composedPlant.isOverdue ? .red : .secondary)
                }
            }
        }
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.refreshNotificationStatus()
        }
        .onChange(of: reminderEnabled) { _, isEnabled in
            guard isEnabled else { return }
            Task {
                await NotificationManager.shared.requestAuthorizationIfNeeded()
                await store.refreshNotificationStatus()
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    savePlant()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var composedPlant: Plant {
        let reminderComponents = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)

        return Plant(
            id: draftID,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            species: species.trimmingCharacters(in: .whitespacesAndNewlines),
            room: room.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            wateringIntervalDays: wateringIntervalDays,
            lastWateredAt: lastWateredAt,
            reminderEnabled: reminderEnabled,
            reminderHour: reminderComponents.hour ?? 9,
            reminderMinute: reminderComponents.minute ?? 0,
            wateringEvents: modePlant?.wateringEvents ?? []
        )
    }

    private func savePlant() {
        let plant = composedPlant
        switch mode {
        case .create:
            store.addPlant(plant)
        case .edit:
            store.updatePlant(plant)
        }
        dismiss()
    }

    private static func dateFor(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? .now
    }

    private var modePlant: Plant? {
        switch mode {
        case .create:
            return nil
        case let .edit(plant):
            return plant
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    @ViewBuilder
    private func labeledField(title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("", text: text, prompt: Text(prompt))
                .textInputAutocapitalization(.words)
        }
        .padding(.vertical, 2)
    }
}
