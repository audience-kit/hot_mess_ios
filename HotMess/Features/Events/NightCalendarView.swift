//
//  NightCalendarView.swift
//  HotMess
//

import SwiftUI

/// A month-style grid of the next four weeks, each night shaded by how many
/// events it has. Tapping a night selects it; tapping it again clears it.
struct NightCalendarView: View {
    let calendar: NightCalendar
    @Binding var selection: Date?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(monthTitle)
                .font(.hotMess(.headline, semibold: true))

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.hotMess(.caption2, semibold: true))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }

                ForEach(calendar.nights) { night in
                    NightCell(night: night, isSelected: selection == night.date) {
                        selection = selection == night.date ? nil : night.date
                    }
                }
            }

            BusynessLegend()
        }
        .padding(.vertical, 6)
    }

    /// "October" or "October – November" when the four weeks span two months.
    private var monthTitle: String {
        let months = calendar.nights.filter { !$0.isPast }.map { $0.date.formatted(.dateTime.month(.wide)) }
        guard let first = months.first, let last = months.last else { return "" }
        return first == last ? first : "\(first) – \(last)"
    }

    /// Very short weekday names, starting on the user's first weekday.
    private var weekdaySymbols: [String] {
        let current = Calendar.current
        let symbols = current.veryShortStandaloneWeekdaySymbols
        let offset = current.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }
}

private struct NightCell: View {
    let night: Night
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(night.date.formatted(.dateTime.day()))
                    .font(.hotMess(.subheadline, semibold: night.isToday))

                Text(night.count > 0 ? "\(night.count)" : " ")
                    .font(.hotMess(.caption2))
                    .opacity(0.8)
            }
            .foregroundStyle(night.busyness >= 2 ? Color.white : Color.primary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(BusynessShade.color(for: night.busyness))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 2.5 : 1.5)
            )
            .opacity(night.isPast ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(night.isPast)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var borderColor: Color {
        if isSelected { return .primary }
        if night.isToday { return Color.hotMessAccent }
        return .clear
    }

    private var accessibilityLabel: String {
        let day = night.date.formatted(date: .complete, time: .omitted)
        let count = night.count == 0
            ? String(localized: "no events")
            : String(localized: "\(night.count) events")
        return "\(day), \(count)"
    }
}

/// The accent shades used for 0 through `NightCalendar.maxLevel`.
enum BusynessShade {
    static func color(for level: Int) -> Color {
        switch level {
        case ..<1: Color.secondary.opacity(0.08)
        case 1: Color.hotMessAccent.opacity(0.25)
        case 2: Color.hotMessAccent.opacity(0.6)
        default: Color.hotMessAccent
        }
    }
}

private struct BusynessLegend: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("Quiet")
            ForEach(0...NightCalendar.maxLevel, id: \.self) { level in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(BusynessShade.color(for: level))
                    .frame(width: 14, height: 14)
            }
            Text("Busy")
        }
        .font(.hotMess(.caption2))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityHidden(true)
    }
}
