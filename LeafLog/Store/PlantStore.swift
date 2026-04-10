import Foundation

@MainActor
final class PlantStore: ObservableObject {
    enum UndoAction: Identifiable {
        case watering(
            id: UUID = UUID(),
            plantID: UUID,
            plantName: String,
            previousDate: Date,
            addedEventID: UUID
        )
        case deletion(
            id: UUID = UUID(),
            plant: Plant,
            originalIndex: Int
        )

        var id: UUID {
            switch self {
            case let .watering(id, _, _, _, _):
                return id
            case let .deletion(id, _, _):
                return id
            }
        }

        var title: String {
            switch self {
            case .watering:
                return "Marked watered"
            case .deletion:
                return "Plant deleted"
            }
        }

        var plantName: String {
            switch self {
            case let .watering(_, _, plantName, _, _):
                return plantName
            case let .deletion(_, plant, _):
                return plant.name
            }
        }
    }

    @Published private(set) var plants: [Plant] = []
    @Published var pendingUndo: UndoAction?
    @Published private(set) var notificationState: NotificationManager.AuthorizationState = .notDetermined

    private let saveURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        saveURL = documentsURL.appendingPathComponent("plants.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        loadPlants()
        Task {
            await refreshNotificationStatus()
        }
    }

    var sortedPlants: [Plant] {
        sort(plants, by: .dueSoon)
    }

    var todayPlants: [Plant] {
        sortedPlants.filter { $0.isOverdue || $0.isDueToday }
    }

    func plant(withID id: UUID) -> Plant? {
        plants.first { $0.id == id }
    }

    func sort(_ plants: [Plant], by mode: PlantSortMode) -> [Plant] {
        plants.sorted { lhs, rhs in
            switch mode {
            case .dueSoon:
                if lhs.isOverdue != rhs.isOverdue {
                    return lhs.isOverdue && !rhs.isOverdue
                }
                if lhs.nextWateringDate != rhs.nextWateringDate {
                    return lhs.nextWateringDate < rhs.nextWateringDate
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .name:
                let nameOrder = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                if nameOrder != .orderedSame {
                    return nameOrder == .orderedAscending
                }
                return lhs.nextWateringDate < rhs.nextWateringDate
            case .room:
                let leftRoom = lhs.room.isEmpty ? "Unassigned" : lhs.room
                let rightRoom = rhs.room.isEmpty ? "Unassigned" : rhs.room
                let roomOrder = leftRoom.localizedCaseInsensitiveCompare(rightRoom)
                if roomOrder != .orderedSame {
                    return roomOrder == .orderedAscending
                }
                let nameOrder = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                if nameOrder != .orderedSame {
                    return nameOrder == .orderedAscending
                }
                return lhs.nextWateringDate < rhs.nextWateringDate
            }
        }
    }

    func addPlant(_ plant: Plant) {
        plants.append(preparePlantForPersistence(plant, defaultEventSource: .manualForm))
        persistAndRefresh()
    }

    func updatePlant(_ plant: Plant) {
        guard let index = plants.firstIndex(where: { $0.id == plant.id }) else { return }
        plants[index] = preparePlantForPersistence(plant, defaultEventSource: .manualForm)
        persistAndRefresh()
    }

    func deletePlant(_ plant: Plant) {
        guard let index = plants.firstIndex(where: { $0.id == plant.id }) else { return }
        pendingUndo = .deletion(plant: plant, originalIndex: index)
        plants.remove(at: index)
        persistAndRefresh()
    }

    func deletePlants(at offsets: IndexSet) {
        let idsToDelete = offsets.map { sortedPlants[$0].id }
        for id in idsToDelete {
            guard let plant = plant(withID: id) else { continue }
            deletePlant(plant)
        }
    }

    func markWatered(
        _ plant: Plant,
        on date: Date = .now,
        source: WateringEvent.Source = .manualList
    ) {
        guard let index = plants.firstIndex(where: { $0.id == plant.id }) else { return }

        let eventID = UUID()
        pendingUndo = .watering(
            plantID: plant.id,
            plantName: plant.name,
            previousDate: plant.lastWateredAt,
            addedEventID: eventID
        )
        plants[index] = plant.withWateringEvent(date: date, source: source, eventID: eventID)
        persistAndRefresh()
    }

    func undoPendingAction() {
        guard let pendingUndo else { return }

        switch pendingUndo {
        case let .watering(_, plantID, _, previousDate, addedEventID):
            guard let index = plants.firstIndex(where: { $0.id == plantID }) else {
                self.pendingUndo = nil
                return
            }
            plants[index].lastWateredAt = previousDate
            plants[index].wateringEvents.removeAll { $0.id == addedEventID }
            plants[index].wateringEvents.insert(
                WateringEvent(date: previousDate, source: .undoRestore),
                at: 0
            )
            plants[index].wateringEvents.sort { $0.date > $1.date }
        case let .deletion(_, plant, originalIndex):
            let restoredPlant = preparePlantForPersistence(plant, defaultEventSource: .migrationSeed)
            let insertionIndex = min(originalIndex, plants.count)
            plants.insert(restoredPlant, at: insertionIndex)
        }

        self.pendingUndo = nil
        persistAndRefresh()
    }

    func clearPendingUndo() {
        pendingUndo = nil
    }

    func plants(on day: Date) -> [Plant] {
        let calendar = Calendar.current
        return sortedPlants.filter { calendar.isDate($0.nextWateringDate, inSameDayAs: day) }
    }

    func duePlantCount(on day: Date) -> Int {
        plants(on: day).count
    }

    func refreshNotifications() async {
        await NotificationManager.shared.scheduleNotifications(for: plants)
        await refreshNotificationStatus()
    }

    func refreshNotificationStatus() async {
        notificationState = await NotificationManager.shared.authorizationState()
    }

    private func persistAndRefresh() {
        savePlants()
        Task {
            await NotificationManager.shared.scheduleNotifications(for: plants)
            await refreshNotificationStatus()
        }
    }

    private func loadPlants() {
        guard let data = try? Data(contentsOf: saveURL) else {
            plants = Plant.samplePlants.map { preparePlantForPersistence($0, defaultEventSource: .migrationSeed) }
            savePlants()
            return
        }

        do {
            let decodedPlants = try decoder.decode([Plant].self, from: data)
            plants = decodedPlants.map { preparePlantForPersistence($0, defaultEventSource: .migrationSeed) }
            savePlants()
        } catch {
            plants = Plant.samplePlants.map { preparePlantForPersistence($0, defaultEventSource: .migrationSeed) }
            savePlants()
        }
    }

    private func savePlants() {
        do {
            let data = try encoder.encode(plants)
            try data.write(to: saveURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save plants: \(error)")
        }
    }

    private func preparePlantForPersistence(
        _ plant: Plant,
        defaultEventSource: WateringEvent.Source
    ) -> Plant {
        if plant.wateringEvents.isEmpty {
            return plant.withWateringEvent(date: plant.lastWateredAt, source: defaultEventSource)
        }
        return plant
    }
}

enum PlantSortMode: String, CaseIterable, Identifiable {
    case dueSoon
    case name
    case room

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dueSoon:
            return "Due Soon"
        case .name:
            return "Name"
        case .room:
            return "Room"
        }
    }
}
