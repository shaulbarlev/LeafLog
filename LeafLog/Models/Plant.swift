import Foundation

struct WateringEvent: Identifiable, Codable, Hashable {
    enum Source: String, Codable, Hashable {
        case manualList
        case manualCalendar
        case manualDetail
        case manualForm
        case undoRestore
        case migrationSeed

        var label: String {
            switch self {
            case .manualList:
                return "Marked from list"
            case .manualCalendar:
                return "Marked from calendar"
            case .manualDetail:
                return "Marked from detail"
            case .manualForm:
                return "Saved from form"
            case .undoRestore:
                return "Restored by undo"
            case .migrationSeed:
                return "Imported existing watering date"
            }
        }
    }

    var id: UUID
    var date: Date
    var source: Source

    init(id: UUID = UUID(), date: Date, source: Source) {
        self.id = id
        self.date = date
        self.source = source
    }
}

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
    var wateringEvents: [WateringEvent]

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
        reminderMinute: Int = 0,
        wateringEvents: [WateringEvent] = []
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
        self.wateringEvents = wateringEvents
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case species
        case room
        case notes
        case wateringIntervalDays
        case lastWateredAt
        case reminderEnabled
        case reminderHour
        case reminderMinute
        case wateringEvents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        species = try container.decodeIfPresent(String.self, forKey: .species) ?? ""
        room = try container.decodeIfPresent(String.self, forKey: .room) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        wateringIntervalDays = try container.decodeIfPresent(Int.self, forKey: .wateringIntervalDays) ?? 7
        lastWateredAt = try container.decodeIfPresent(Date.self, forKey: .lastWateredAt) ?? .now
        reminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? false
        reminderHour = try container.decodeIfPresent(Int.self, forKey: .reminderHour) ?? 9
        reminderMinute = try container.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? 0
        wateringEvents = try container.decodeIfPresent([WateringEvent].self, forKey: .wateringEvents) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(species, forKey: .species)
        try container.encode(room, forKey: .room)
        try container.encode(notes, forKey: .notes)
        try container.encode(wateringIntervalDays, forKey: .wateringIntervalDays)
        try container.encode(lastWateredAt, forKey: .lastWateredAt)
        try container.encode(reminderEnabled, forKey: .reminderEnabled)
        try container.encode(reminderHour, forKey: .reminderHour)
        try container.encode(reminderMinute, forKey: .reminderMinute)
        try container.encode(wateringEvents, forKey: .wateringEvents)
    }

    var nextWateringDate: Date {
        Calendar.current.date(byAdding: .day, value: wateringIntervalDays, to: lastWateredAt) ?? lastWateredAt
    }

    var daysUntilDue: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let dueDate = calendar.startOfDay(for: nextWateringDate)
        return calendar.dateComponents([.day], from: today, to: dueDate).day ?? 0
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

    var isDueToday: Bool {
        Calendar.current.isDate(nextWateringDate, inSameDayAs: .now)
    }

    var wateringStatusText: String {
        switch daysUntilDue {
        case ..<0:
            let overdueDays = abs(daysUntilDue)
            return "Overdue by \(overdueDays) day\(overdueDays == 1 ? "" : "s")"
        case 0:
            return "Due today"
        case 1:
            return "Due tomorrow"
        default:
            return "Due in \(daysUntilDue) days"
        }
    }

    var recentWateringEvents: [WateringEvent] {
        wateringEvents.sorted { $0.date > $1.date }
    }

    var reminderStatusText: String {
        guard reminderEnabled else { return "Reminder off" }
        return "Reminder at \(formattedReminderTime)"
    }

    var formattedReminderTime: String {
        var components = DateComponents()
        components.hour = reminderHour
        components.minute = reminderMinute
        let date = Calendar.current.date(from: components) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    func withWateringEvent(date: Date, source: WateringEvent.Source, eventID: UUID = UUID()) -> Plant {
        var updated = self
        updated.lastWateredAt = date
        updated.wateringEvents.append(
            WateringEvent(id: eventID, date: date, source: source)
        )
        updated.wateringEvents.sort { $0.date > $1.date }
        return updated
    }

    func ensuringHistorySeeded() -> Plant {
        guard wateringEvents.isEmpty else { return self }
        return withWateringEvent(date: lastWateredAt, source: .migrationSeed)
    }
}

extension Plant {
    static let samplePlants: [Plant] = [
        Plant(
            name: "Monstera",
            species: "Deliciosa",
            room: "Living Room",
            wateringIntervalDays: 7,
            lastWateredAt: .now.addingTimeInterval(-3 * 24 * 60 * 60),
            reminderEnabled: true,
            reminderHour: 8,
            reminderMinute: 30,
            wateringEvents: [WateringEvent(date: .now.addingTimeInterval(-3 * 24 * 60 * 60), source: .migrationSeed)]
        ),
        Plant(
            name: "Snake Plant",
            species: "Sansevieria",
            room: "Bedroom",
            wateringIntervalDays: 14,
            lastWateredAt: .now.addingTimeInterval(-9 * 24 * 60 * 60),
            wateringEvents: [WateringEvent(date: .now.addingTimeInterval(-9 * 24 * 60 * 60), source: .migrationSeed)]
        ),
        Plant(
            name: "Pothos",
            species: "Golden Pothos",
            room: "Office",
            wateringIntervalDays: 5,
            lastWateredAt: .now.addingTimeInterval(-5 * 24 * 60 * 60),
            reminderEnabled: true,
            wateringEvents: [WateringEvent(date: .now.addingTimeInterval(-5 * 24 * 60 * 60), source: .migrationSeed)]
        )
    ]
}
