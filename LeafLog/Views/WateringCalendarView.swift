import SwiftUI

struct WateringCalendarView: View {
    private struct PlantRoute: Identifiable, Hashable {
        let id: UUID
    }

    @EnvironmentObject private var store: PlantStore
    @State private var monthAnchor = Calendar.current.startOfDay(for: .now)
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var selectedPlantRoute: PlantRoute?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                monthHeader

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(Array(daysForMonth().enumerated()), id: \.offset) { _, day in
                        if let day {
                            CalendarDayCell(
                                date: day,
                                isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDate),
                                isToday: Calendar.current.isDateInToday(day),
                                dueCount: store.duePlantCount(on: day)
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                    selectedDate = day
                                }
                            }
                        } else {
                            Color.clear
                                .frame(height: 54)
                        }
                    }
                }

                selectedDaySection
            }
            .padding()
        }
        .navigationTitle("Watering Calendar")
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: selectedDate)
        .animation(.easeInOut(duration: 0.22), value: monthAnchor)
        .navigationDestination(item: $selectedPlantRoute) { route in
            PlantDetailView(plantID: route.id)
                .environmentObject(store)
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    shiftMonth(by: -1)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
            }

            Spacer()

            Text(monthAnchor.formatted(.dateTime.month(.wide).year()))
                .font(.title3.weight(.semibold))
                .contentTransition(.interpolate)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    shiftMonth(by: 1)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
            }
        }
        .buttonStyle(.plain)
    }

    private var selectedDaySection: some View {
        let plants = store.plants(on: selectedDate)

        return VStack(alignment: .leading, spacing: 10) {
            Text(selectedDate.formatted(date: .complete, time: .omitted))
                .font(.headline)
                .contentTransition(.interpolate)

            if plants.isEmpty {
                ContentUnavailableView(
                    "Nothing Scheduled",
                    systemImage: "checkmark.circle",
                    description: Text("No plants need watering on this date.")
                )
            } else {
                ForEach(plants) { plant in
                    HStack {
                        Button {
                            selectedPlantRoute = PlantRoute(id: plant.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plant.name)
                                    .font(.headline)

                                if !plant.room.isEmpty {
                                    Text(plant.room)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button("Watered") {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                store.markWatered(plant, on: selectedDate, source: .manualCalendar)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: plants)
    }

    private var weekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let firstWeekday = calendar.firstWeekday - 1
        return Array(symbols[firstWeekday...]) + Array(symbols[..<firstWeekday])
    }

    private func daysForMonth() -> [Date?] {
        let calendar = Calendar.current
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: monthAnchor),
            let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
            let lastWeekReference = calendar.date(byAdding: .day, value: -1, to: monthInterval.end),
            let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: lastWeekReference)
        else {
            return []
        }

        var dates: [Date?] = []
        var cursor = firstWeek.start

        while cursor < lastWeek.end {
            if calendar.isDate(cursor, equalTo: monthAnchor, toGranularity: .month) {
                dates.append(cursor)
            } else {
                dates.append(nil)
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = nextDay
        }

        return dates
    }

    private func shiftMonth(by value: Int) {
        guard let nextMonth = Calendar.current.date(byAdding: .month, value: value, to: monthAnchor) else { return }
        monthAnchor = nextMonth
        if !Calendar.current.isDate(selectedDate, equalTo: nextMonth, toGranularity: .month) {
            selectedDate = Calendar.current.startOfDay(for: nextMonth)
        }
    }
}

private struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let dueCount: Int

    var body: some View {
        VStack(spacing: 6) {
            Text(date.formatted(.dateTime.day()))
                .font(.subheadline.weight(.semibold))
                .contentTransition(.numericText())

            if dueCount > 0 {
                Text("\(dueCount)")
                    .font(.caption2.weight(.bold))
                    .frame(width: 18, height: 18)
                    .background(Color.green, in: Circle())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 18, height: 18)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .padding(.vertical, 6)
        .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.green.opacity(0.65), lineWidth: 1.5)
            }
        }
        .scaleEffect(isSelected ? 1.03 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isSelected)
        .animation(.easeInOut(duration: 0.18), value: dueCount)
    }

    private var backgroundStyle: Color {
        if isSelected {
            return Color.green.opacity(0.22)
        }
        return Color(.secondarySystemGroupedBackground)
    }
}
