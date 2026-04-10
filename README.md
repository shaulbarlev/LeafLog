# LeafLog

LeafLog is a SwiftUI iOS app for keeping track of houseplants, their watering cadence, reminder notifications, and recent watering history.

The app is designed around quick daily check-ins. It highlights what needs attention today, lets you mark plants as watered in a tap, and gives you enough detail to answer basic questions like:

- What needs watering right now?
- When did I last water this plant?
- Is this plant overdue or just coming up next?
- Are reminders actually enabled for this plant?

## What The App Does

LeafLog currently supports:

- A `Today` section for overdue and due-today plants
- Search, filter, and sort for larger plant collections
- Add, edit, and delete plant records
- Undo for accidental watering and delete actions
- A plant detail screen with schedule, notes, reminder status, and watering history
- Watering history persisted per plant
- Local reminder notifications for upcoming watering days
- A calendar view for browsing plants due on specific dates
- Local JSON persistence in the app's documents directory

## Main Screens

- `Plants`
  Shows today's plants first, then the rest of the collection with search/filter/sort controls.

- `Plant Detail`
  Shows one plant's full context: notes, interval, last watered date, next watering date, reminder state, and recent watering history.

- `Calendar`
  Shows due plants on a monthly calendar and supports marking plants as watered from a selected date.

## Project Structure

The project is intentionally small and lives in a single iOS target.

- `LeafLog/LeafLogApp.swift`
  App entry point and root dependency wiring.

- `LeafLog/Models`
  Plant domain models, including persisted watering history.

- `LeafLog/Store`
  Observable app state, persistence, undo behavior, sorting helpers, and notification status.

- `LeafLog/Services`
  Notification scheduling and authorization status helpers.

- `LeafLog/Views`
  SwiftUI screens such as the plant list, detail view, form, root tabs, and calendar.

- `LeafLog.xcodeproj`
  Xcode project file for the iOS app target.

## Requirements

- macOS with Xcode installed
- iOS 17.0+ deployment target
- A simulator or physical iPhone for running the app

If command-line builds do not work, make sure the terminal is pointing at full Xcode rather than Command Line Tools:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Running The App

### In Xcode

1. Open `LeafLog.xcodeproj` in Xcode.
2. Select the `LeafLog` scheme.
3. Choose an iPhone simulator or a connected iPhone.
4. If needed, set your signing team and bundle identifier.
5. Build and run.

### From The Terminal

List schemes:

```bash
xcodebuild -list -project LeafLog.xcodeproj
```

Build for the iOS simulator:

```bash
xcodebuild -project LeafLog.xcodeproj -scheme LeafLog -configuration Debug -sdk iphonesimulator build
```

## Notifications

LeafLog uses local notifications for watering reminders.

- The app requests notification permission when reminder functionality is enabled.
- If permission is denied, the UI surfaces that state and can route the user to iPhone Settings.
- Each reminder-enabled plant schedules one upcoming local notification for its next watering day.

## Persistence

Plant data is stored locally as JSON in the app's documents directory.

Persisted data includes:

- Plant identity and metadata
- Watering interval
- Last watered date
- Reminder configuration
- Watering history events

There is currently no cloud sync or backup/export flow.

## Current Product Notes

LeafLog is intentionally local-first and lightweight. It is best suited for personal plant tracking with a moderate collection size.

Things the app now handles well:

- Quick daily watering workflow
- Recovering from common mistakes
- Understanding a plant's recent watering context
- Seeing reminder status without digging

Things still likely worth building later:

- Backup/export/import
- More advanced care logs beyond watering
- Richer settings/preferences
- Cloud sync or multi-device state

## Development Notes

- The UI is built with SwiftUI.
- Persistence is plain JSON rather than Core Data or SwiftData.
- The store is `@MainActor` and acts as the app's central source of truth.
- Reminder scheduling lives in a small `NotificationManager` actor.

## Build Verification

The project has been verified with:

```bash
xcodebuild -project LeafLog.xcodeproj -scheme LeafLog -configuration Debug -sdk iphonesimulator build
```
