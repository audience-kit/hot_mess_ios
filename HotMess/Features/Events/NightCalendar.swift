//
//  NightCalendar.swift
//  HotMess
//

import Foundation

/// One night on the events calendar, with how many events it has.
struct Night: Hashable, Sendable, Identifiable {
    let date: Date
    let events: [Event]
    let isToday: Bool
    let isPast: Bool
    /// 0 for a quiet night, up to `NightCalendar.maxLevel` for the busiest.
    let busyness: Int

    var id: Date { date }
    var count: Int { events.count }
}

/// The next four weeks of nights, laid out a week to a row like a month view.
///
/// The grid starts on the first day of the week containing today, so the
/// first row can hold a few nights that have already passed; those are shown
/// dimmed. Events starting before 5 AM count towards the night before, since
/// a 1 AM set is part of Friday night, not Saturday.
struct NightCalendar: Hashable, Sendable {
    static let weekCount = 4
    static let maxLevel = 3
    static let nightRollover = 5

    let weeks: [[Night]]

    init(events: [Event], today: Date = .now, calendar: Calendar = .current) {
        let todayStart = calendar.startOfDay(for: today)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: todayStart)?.start ?? todayStart

        var byNight: [Date: [Event]] = [:]
        for event in events {
            byNight[Self.night(of: event.startDate, calendar: calendar), default: []].append(event)
        }

        let days = (0..<(Self.weekCount * 7)).compactMap {
            calendar.date(byAdding: .day, value: $0, to: weekStart)
        }
        let busiest = days.filter { $0 >= todayStart }.map { byNight[$0]?.count ?? 0 }.max() ?? 0

        let nights = days.map { day in
            let nightEvents = (byNight[day] ?? []).sorted { $0.startDate < $1.startDate }
            return Night(
                date: day,
                events: nightEvents,
                isToday: day == todayStart,
                isPast: day < todayStart,
                busyness: Self.level(count: nightEvents.count, busiest: busiest)
            )
        }

        weeks = stride(from: 0, to: nights.count, by: 7).map { Array(nights[$0..<min($0 + 7, nights.count)]) }
    }

    var nights: [Night] { weeks.flatMap { $0 } }

    /// The night an event belongs to: its start date, or the day before when
    /// it starts in the small hours.
    static func night(of date: Date, calendar: Calendar = .current) -> Date {
        let shifted = calendar.date(byAdding: .hour, value: -nightRollover, to: date) ?? date
        return calendar.startOfDay(for: shifted)
    }

    /// Scales a night's event count against the busiest night in view, so a
    /// small town and a big city both use the full range of shades.
    static func level(count: Int, busiest: Int) -> Int {
        guard count > 0, busiest > 0 else { return 0 }
        return max(1, Int((Double(count) / Double(busiest) * Double(maxLevel)).rounded(.up)))
    }
}
