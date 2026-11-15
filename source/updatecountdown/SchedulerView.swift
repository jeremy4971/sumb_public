//
//  SchedulerView.swift
//  updatecountdown
//
//  The weekly grid where users paint the hours they can be asked to update,
//  and the popup that asks them.
//

import SwiftUI
import AppKit
import Combine

// Edited by the grid. The window saves it on close, Settings after each change.
final class SchedulerDraft: ObservableObject {
    @Published var hours: [Int]

    init(hours: [Int]) {
        self.hours = hours
    }
}

struct SchedulerGridView: View {
    // Not observed: the help text comes in through onReceive.
    let monitor: UpdateMonitor
    let draft: SchedulerDraft
    let onDone: () -> Void

    @State private var helpText: String

    init(monitor: UpdateMonitor, draft: SchedulerDraft, onDone: @escaping () -> Void) {
        self.monitor = monitor
        self.draft = draft
        self.onDone = onDone
        // Set here too so the window is measured with the text when it opens.
        _helpText = State(initialValue: monitor.popupSchedulerHelp)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !helpText.isEmpty {
                Text(helpText)
                    .foregroundStyle(.secondary)
                    .frame(width: SchedulerGrid.width, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            SchedulerGrid(draft: draft, onDone: onDone)
        }
        .padding(20)
        .fixedSize()
        // Escape closes the window, same as the red button.
        .background {
            Button("", action: onDone)
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .onReceive(monitor.$popupSchedulerHelp) { helpText = $0 }
    }
}

struct SchedulerGrid: View {
    @ObservedObject var draft: SchedulerDraft
    var isEditable = true
    var onColor: Color = .blue
    var onOpenUserSchedule: (() -> Void)? = nil
    var onDone: (() -> Void)? = nil
    var onCommit: () -> Void = {}

    @State private var paintValue: Bool?
    @Environment(\.colorScheme) private var colorScheme

    private var offColor: Color {
        colorScheme == .dark ? Color(white: 0.75) : .white
    }

    private static let emptyHours = Array(repeating: 0, count: 7)

    private static let cellSize: CGFloat = 20
    private static let spacing: CGFloat = 2
    private static let headerHeight: CGFloat = 14
    private static let bandGap: CGFloat = 4
    private static let dayLabelWidth: CGFloat = 40
    private static let columnGap: CGFloat = 8
    private static let buttonIconHeight: CGFloat = 16
    static let width = dayLabelWidth + columnGap + 24 * cellSize + 23 * spacing

    // For day names and AM/PM. The app is English only, so the current
    // locale would give English words.
    private static var systemCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = UpdateMonitor.preferredLocale
        return calendar
    }

    private static var dayNames: [String] {
        let symbols = systemCalendar.shortStandaloneWeekdaySymbols
        return Array(symbols[1...] + symbols[..<1])
    }

    // Follows the 24-hour time setting in System Settings.
    // preferredLocale only has the language, so it would miss it.
    private static var uses12HourClock: Bool {
        DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .autoupdatingCurrent)?.contains("a") == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            grid
            buttons
        }
        .frame(width: Self.width)
    }

    private var buttons: some View {
        HStack {
            Spacer()
            Button {
                draft.hours = Self.emptyHours
                onCommit()
            } label: {
                Label {
                    Text(BuiltInStrings.current.reset)
                } icon: {
                    Image(systemName: "trash.fill")
                        .frame(height: Self.buttonIconHeight)
                }
                .labelStyle(.titleAndIcon)
            }
            .disabled(!isEditable || draft.hours == Self.emptyHours)
            if let onOpenUserSchedule {
                // Stays enabled when a profile locks the grid, the user's schedule isn't managed.
                Button(action: onOpenUserSchedule) {
                    Label {
                        Text("User Schedule")
                    } icon: {
                        Image(systemName: "person.fill")
                            .frame(height: Self.buttonIconHeight)
                    }
                    .labelStyle(.titleAndIcon)
                }
            }
            if let onDone {
                Button("OK", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.hours.allSatisfy { $0 == 0 })
            }
        }
    }

    private var grid: some View {
        let is12h = Self.uses12HourClock
        let headerTotal = Self.headerHeight + (is12h ? Self.headerHeight + Self.bandGap + Self.spacing : 0)
        return HStack(alignment: .top, spacing: Self.columnGap) {
            VStack(alignment: .trailing, spacing: Self.spacing) {
                Color.clear.frame(height: headerTotal)
                ForEach(Array(Self.dayNames.enumerated()), id: \.offset) { _, name in
                    Text(name)
                        .frame(width: Self.dayLabelWidth, height: Self.cellSize, alignment: .trailing)
                }
            }

            VStack(alignment: .leading, spacing: Self.spacing) {
                if is12h {
                    let calendar = Self.systemCalendar
                    HStack(spacing: Self.spacing) {
                        periodBand(calendar.amSymbol)
                        periodBand(calendar.pmSymbol)
                    }
                    .padding(.bottom, Self.bandGap)
                }
                HStack(spacing: Self.spacing) {
                    ForEach(0..<24, id: \.self) { hour in
                        hourLabel(hour, is12h: is12h)
                    }
                }
                .overlay(alignment: .trailing) {
                    hourLabel(24, is12h: is12h)
                        .offset(x: Self.cellSize + Self.spacing)
                }
                .offset(x: -(Self.cellSize + Self.spacing) / 2)
                cells
            }
        }
    }

    private func hourLabel(_ hour: Int, is12h: Bool) -> some View {
        let shown = is12h ? (hour % 12 == 0 ? 12 : hour % 12) : hour
        return Text("\(shown)")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: Self.cellSize, height: Self.headerHeight)
    }

    private func periodBand(_ text: String) -> some View {
        HStack(spacing: 6) {
            Rectangle().fill(.tertiary).frame(height: 1)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize()
            Rectangle().fill(.tertiary).frame(height: 1)
        }
        .padding(.horizontal, 3)
        .frame(width: 12 * Self.cellSize + 11 * Self.spacing, height: Self.headerHeight)
    }

    private var cells: some View {
        VStack(spacing: Self.spacing) {
            ForEach(0..<7, id: \.self) { day in
                HStack(spacing: Self.spacing) {
                    ForEach(0..<24, id: \.self) { hour in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isOn(day: day, hour: hour) ? onColor : offColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(Color(nsColor: .separatorColor))
                            )
                            .frame(width: Self.cellSize, height: Self.cellSize)
                    }
                }
            }
        }
        // The first box decides: starting on an empty box paints, on a filled one erases.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard isEditable, let (day, hour) = Self.cell(at: value.location) else { return }
                    let paint = paintValue ?? !isOn(day: day, hour: hour)
                    paintValue = paint
                    set(day: day, hour: hour, on: paint)
                }
                .onEnded { _ in
                    guard isEditable else { return }
                    paintValue = nil
                    onCommit()
                }
        )
    }

    private static func cell(at point: CGPoint) -> (day: Int, hour: Int)? {
        guard point.x >= 0, point.y >= 0 else { return nil }
        let step = cellSize + spacing
        let hour = Int(point.x / step)
        let day = Int(point.y / step)
        guard (0..<24).contains(hour), (0..<7).contains(day) else { return nil }
        return (day, hour)
    }

    private func isOn(day: Int, hour: Int) -> Bool {
        draft.hours[day] & (1 << hour) != 0
    }

    private func set(day: Int, hour: Int, on: Bool) {
        guard isOn(day: day, hour: hour) != on else { return }
        draft.hours[day] ^= 1 << hour
    }
}

struct SchedulerPromptView: View {
    @ObservedObject var monitor: UpdateMonitor
    let onReschedule: () -> Void
    let onUpdateNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 6) {
                    Text(monitor.expandingVariables(in: monitor.popupTitle))
                        .font(.headline)
                    Text(monitor.expandingVariables(in: monitor.popupBody))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Spacer()
                Button(monitor.popupRescheduleButton, action: onReschedule)
                    .keyboardShortcut(.cancelAction)
                Button(monitor.popupUpdateButton, action: onUpdateNow)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 470)
    }
}
