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

// The Scheduler window: help text above the grid.
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
            // Clearing empties the grid. Closing it empty follows the suggested schedule.
            SchedulerGrid(draft: draft, onDone: onDone)
        }
        .padding(20)
        .fixedSize()
        .onReceive(monitor.$popupSchedulerHelp) { helpText = $0 }
    }
}

// Days, hours, boxes and the clear button. Shared by the window and Settings.
struct SchedulerGrid: View {
    @ObservedObject var draft: SchedulerDraft
    var isEditable = true
    // Selected boxes. Settings uses green for the suggested hours.
    var onColor: Color = .blue
    // Shows a button that opens the user's own Scheduler window.
    var onOpenUserSchedule: (() -> Void)? = nil
    // Shows an OK button, the window passes it to close itself.
    var onDone: (() -> Void)? = nil
    // Called after each drag and after a clear.
    var onCommit: () -> Void = {}

    @State private var paintValue: Bool?
    @Environment(\.colorScheme) private var colorScheme

    // Light grey in dark mode, plain white is too bright there.
    private var offColor: Color {
        colorScheme == .dark ? Color(white: 0.75) : .white
    }

    // What the clear button puts back.
    private static let emptyHours = Array(repeating: 0, count: 7)

    private static let cellSize: CGFloat = 20
    private static let spacing: CGFloat = 2
    private static let headerHeight: CGFloat = 14
    private static let dayLabelWidth: CGFloat = 40
    private static let columnGap: CGFloat = 8
    // Fixed frame, the eraser glyph is taller than a regular button.
    private static let buttonIconSize = CGSize(width: 24, height: 16)
    static let width = dayLabelWidth + columnGap + 24 * cellSize + 23 * spacing

    // Short weekday names in the system language, Monday first.
    private static var dayNames: [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = UpdateMonitor.preferredLocale
        let symbols = calendar.shortStandaloneWeekdaySymbols
        return Array(symbols[1...] + symbols[..<1])
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
                Image(systemName: "eraser.line.dashed.fill")
                    .frame(width: Self.buttonIconSize.width, height: Self.buttonIconSize.height)
            }
            .accessibilityLabel("Clear")
            .disabled(!isEditable || draft.hours == Self.emptyHours)
            if let onOpenUserSchedule {
                // Stays enabled when a profile locks the grid, the user's schedule isn't managed.
                Button(action: onOpenUserSchedule) {
                    Image(systemName: "person.fill")
                        .frame(width: Self.buttonIconSize.width, height: Self.buttonIconSize.height)
                }
                .accessibilityLabel("My schedule")
            }
            if let onDone {
                // Blue even when SwiftUI doesn't pick up the default look on its own.
                Button("OK", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.hours.allSatisfy { $0 == 0 })
            }
        }
    }

    private var grid: some View {
        HStack(alignment: .top, spacing: Self.columnGap) {
            VStack(alignment: .leading, spacing: Self.spacing) {
                Color.clear.frame(height: Self.headerHeight)
                ForEach(Array(Self.dayNames.enumerated()), id: \.offset) { _, name in
                    Text(name)
                        .frame(width: Self.dayLabelWidth, height: Self.cellSize, alignment: .leading)
                }
            }

            VStack(alignment: .leading, spacing: Self.spacing) {
                HStack(spacing: Self.spacing) {
                    ForEach(0..<24, id: \.self) { hour in
                        hourLabel(hour)
                    }
                }
                // Closes the last box. An overlay, so the grid width doesn't change.
                .overlay(alignment: .trailing) {
                    hourLabel(24)
                        .offset(x: Self.cellSize + Self.spacing)
                }
                // Half a box to the left, so each hour sits on the line where it starts.
                .offset(x: -(Self.cellSize + Self.spacing) / 2)
                cells
            }
        }
    }

    private func hourLabel(_ hour: Int) -> some View {
        Text("\(hour)")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: Self.cellSize, height: Self.headerHeight)
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
        .frame(width: 420)
    }
}
