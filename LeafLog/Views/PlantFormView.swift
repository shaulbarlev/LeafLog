import SwiftUI

struct PlantFormView: View {
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
            Section("Plant Details") {
                TextField("Name", text: $name)
                TextField("Species", text: $species)
                TextField("Room", text: $room)
            }

            Section("Watering Schedule") {
                DatePicker("Last Watered", selection: $lastWateredAt, displayedComponents: .date)

                Stepper(value: $wateringIntervalDays, in: 1 ... 30) {
                    Label("Every \(wateringIntervalDays) day\(wateringIntervalDays == 1 ? "" : "s")", systemImage: "drop")
                }
            }

            Section("Reminder") {
                Toggle("Send watering reminder", isOn: $reminderEnabled)
                if reminderEnabled {
                    DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                }
            }

            Section("Notes") {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
            }

            Section {
                LabeledContent("Next Watering") {
                    Text(composedPlant.nextWateringDate.formatted(date: .abbreviated, time: .omitted))
                        .fontWeight(.semibold)
                }
            }
        }
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
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
            reminderMinute: reminderComponents.minute ?? 0
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
}
