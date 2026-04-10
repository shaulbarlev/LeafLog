# LeafLog

A simple SwiftUI iOS app for tracking the plants you own, the last time each plant was watered, the next watering date, and reminder notifications.

## Features

- Add, edit, and delete plants you own
- Track the last watered date and watering interval for each plant
- View upcoming watering dates in a calendar tab
- Mark plants as watered from the list or calendar
- Enable local notifications for watering reminders
- Persist plant data locally in JSON

## Project Structure

- `LeafLog.xcodeproj`: Xcode project
- `LeafLog/Models`: Plant model
- `LeafLog/Store`: Persistence and app state
- `LeafLog/Services`: Notification scheduling
- `LeafLog/Views`: SwiftUI screens

## Run

1. Open `LeafLog.xcodeproj` in Xcode.
2. Set your team and bundle identifier if needed.
3. Build and run on an iPhone simulator or device.
4. Allow notifications when prompted to receive watering reminders.
