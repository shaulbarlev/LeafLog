import Foundation

@MainActor
final class PlantStore: ObservableObject {
    @Published private(set) var plants: [Plant] = []

    private let saveURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        saveURL = documentsURL.appendingPathComponent("plants.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        loadPlants()
    }

    var sortedPlants: [Plant] {
        plants.sorted { lhs, rhs in
            if lhs.nextWateringDate == rhs.nextWateringDate {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.nextWateringDate < rhs.nextWateringDate
        }
    }

    func addPlant(_ plant: Plant) {
        plants.append(plant)
        persistAndRefresh()
    }

    func updatePlant(_ plant: Plant) {
        guard let index = plants.firstIndex(where: { $0.id == plant.id }) else { return }
        plants[index] = plant
        persistAndRefresh()
    }

    func deletePlants(at offsets: IndexSet) {
        let idsToDelete = offsets.map { sortedPlants[$0].id }
        plants.removeAll { idsToDelete.contains($0.id) }
        persistAndRefresh()
    }

    func markWatered(_ plant: Plant, on date: Date = .now) {
        var updatedPlant = plant
        updatedPlant.lastWateredAt = date
        updatePlant(updatedPlant)
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
    }

    private func persistAndRefresh() {
        savePlants()
        Task {
            await NotificationManager.shared.scheduleNotifications(for: plants)
        }
    }

    private func loadPlants() {
        guard let data = try? Data(contentsOf: saveURL) else {
            plants = Plant.samplePlants
            savePlants()
            return
        }

        do {
            plants = try decoder.decode([Plant].self, from: data)
        } catch {
            plants = Plant.samplePlants
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
}
