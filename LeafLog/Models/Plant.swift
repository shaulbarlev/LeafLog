import Foundation

struct Plant: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var species: String
    var room: String
    var notes: String
    var wateringIntervalDays: Int
    var lastWateredAt: Date
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int

    init(
        id: UUID = UUID(),
        name: String,
        species: String = "",
        room: String = "",
        notes: String = "",
        wateringIntervalDays: Int = 7,
        lastWateredAt: Date = .now,
        reminderEnabled: Bool = false,
        reminderHour: Int = 9,
        reminderMinute: Int = 0
    ) {
        self.id = id
        self.name = name
        self.species = species
        self.room = room
        self.notes = notes
        self.wateringIntervalDays = wateringIntervalDays
        self.lastWateredAt = lastWateredAt
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
    }

    var nextWateringDate: Date {
        Calendar.current.date(byAdding: .day, value: wateringIntervalDays, to: lastWateredAt) ?? lastWateredAt
    }

    var reminderDate: Date {
        let nextDate = nextWateringDate
        var components = Calendar.current.dateComponents([.year, .month, .day], from: nextDate)
        components.hour = reminderHour
        components.minute = reminderMinute
        return Calendar.current.date(from: components) ?? nextDate
    }

    var isOverdue: Bool {
        nextWateringDate < Calendar.current.startOfDay(for: .now)
    }
}

extension Plant {
    static let samplePlants: [Plant] = [
        Plant(name: "Monstera", species: "Deliciosa", room: "Living Room", wateringIntervalDays: 7, lastWateredAt: .now.addingTimeInterval(-3 * 24 * 60 * 60), reminderEnabled: true, reminderHour: 8, reminderMinute: 30),
        Plant(name: "Snake Plant", species: "Sansevieria", room: "Bedroom", wateringIntervalDays: 14, lastWateredAt: .now.addingTimeInterval(-9 * 24 * 60 * 60)),
        Plant(name: "Pothos", species: "Golden Pothos", room: "Office", wateringIntervalDays: 5, lastWateredAt: .now.addingTimeInterval(-5 * 24 * 60 * 60), reminderEnabled: true)
    ]
}
