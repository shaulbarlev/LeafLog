import Foundation
import UserNotifications

actor NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let identifierPrefix = "plant-reminder-"

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        default:
            break
        }
    }

    func scheduleNotifications(for plants: [Plant]) async {
        let identifiers = plants.map { identifier(for: $0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        for plant in plants where plant.reminderEnabled {
            let content = UNMutableNotificationContent()
            content.title = "Water \(plant.name)"
            content.body = plant.room.isEmpty
                ? "Your \(plant.name) is due for watering today."
                : "Your \(plant.name) in the \(plant.room) is due for watering today."
            content.sound = .default

            let triggerDate = nextTriggerDate(for: plant)
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: identifier(for: plant), content: content, trigger: trigger)

            try? await center.add(request)
        }
    }

    private func nextTriggerDate(for plant: Plant) -> Date {
        let reminderDate = plant.reminderDate
        if reminderDate > .now {
            return reminderDate
        }

        var adjustedComponents = DateComponents()
        adjustedComponents.minute = 1
        return Calendar.current.date(byAdding: adjustedComponents, to: .now) ?? .now.addingTimeInterval(60)
    }

    private func identifier(for plant: Plant) -> String {
        identifierPrefix + plant.id.uuidString
    }
}
