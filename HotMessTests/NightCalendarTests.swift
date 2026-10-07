//
//  NightCalendarTests.swift
//  HotMessTests
//

import Foundation
import Testing

@testable import HotMess

@Suite("Night calendar")
struct NightCalendarTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        calendar.firstWeekday = 1
        return calendar
    }

    private func date(_ day: Int, _ hour: Int = 21) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private func event(_ name: String, at start: Date) -> Event {
        Event(id: UUID(), name: name, startDate: start)
    }

    @Test("Lays out four Sunday-first weeks around today")
    func layout() {
        // Wednesday, October 7, 2026.
        let nights = NightCalendar(events: [], today: date(7, 12), calendar: calendar)

        #expect(nights.weeks.count == 4)
        #expect(nights.weeks.allSatisfy { $0.count == 7 })
        #expect(nights.nights.first?.date == calendar.startOfDay(for: date(4)))
        #expect(nights.nights.filter(\.isPast).count == 3)
        #expect(nights.nights.filter(\.isToday).map(\.date) == [calendar.startOfDay(for: date(7))])
    }

    @Test("Counts small-hours events towards the night before")
    func smallHours() {
        let events = [
            event("Friday headliner", at: date(9, 22)),
            event("Friday after hours", at: date(10, 2)),
            event("Saturday tea dance", at: date(10, 16))
        ]
        let nights = NightCalendar(events: events, today: date(7, 12), calendar: calendar)
        let byDay = Dictionary(uniqueKeysWithValues: nights.nights.map { ($0.date, $0.count) })

        #expect(byDay[calendar.startOfDay(for: date(9))] == 2)
        #expect(byDay[calendar.startOfDay(for: date(10))] == 1)
    }

    @Test("Shades nights relative to the busiest one")
    func busyness() {
        #expect(NightCalendar.level(count: 0, busiest: 6) == 0)
        #expect(NightCalendar.level(count: 1, busiest: 6) == 1)
        #expect(NightCalendar.level(count: 3, busiest: 6) == 2)
        #expect(NightCalendar.level(count: 6, busiest: 6) == 3)
    }
}
