//
//  SchedulerController.swift
//  updatecountdown
//
//  Opens the Scheduler window, and shows the "update now?" popup at the
//  start of each allowed hour while an update is available.
//

import AppKit
import SwiftUI
import Combine

final class SchedulerController: NSObject, NSWindowDelegate {

    private let monitor: UpdateMonitor

    /// Called when the Scheduler window opens or closes, for the Dock icon.
    var onWindowsChanged: (() -> Void)?

    private var schedulerWindow: NSWindow?
    private var schedulerDraft: SchedulerDraft?
    // One per screen while the popup shows.
    private var promptPanels: [NSPanel] = []
    private var hourTimer: Timer?
    private var busyRetryTimer: Timer?
    // Start of the hour the popup last showed in, so it shows once per hour.
    private var lastPromptedHour: Date?
    private var cancellables = Set<AnyCancellable>()

    var isSchedulerWindowOpen: Bool { schedulerWindow != nil }

    init(monitor: UpdateMonitor) {
        self.monitor = monitor
        super.init()
    }

    func start() {
        // @Published fires before the value changes, so hop to the next pass.
        Publishers.Merge6(
            monitor.$popupEnabled.map { _ in () },
            monitor.$popupThresholdDays.map { _ in () },
            monitor.$targetDate.map { _ in () },
            monitor.$userSchedule.map { _ in () },
            monitor.$suggestedSchedule.map { _ in () },
            monitor.$status.map { _ in () }
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in self?.evaluate() }
        .store(in: &cancellables)

        // Timers don't fire during sleep, so check again on wake.
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.evaluate() }
            .store(in: &cancellables)

        // A monitor plugged in or removed while it shows: rebuild on the current screens.
        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, !self.promptPanels.isEmpty else { return }
                self.dismissPrompt()
                self.showPrompt(playSound: false)
            }
            .store(in: &cancellables)
    }

    // MARK: - Timing

    // Managed deadlines only, within the threshold. Stops at the deadline, like notifications.
    private var isInPopupWindow: Bool {
        guard monitor.status == .scheduled, let target = monitor.targetDate else { return false }
        return target.timeIntervalSinceNow <= TimeInterval(monitor.popupThresholdDays) * 24 * 60 * 60
    }

    private func evaluate() {
        defer { scheduleNextHour() }
        busyRetryTimer?.invalidate()
        busyRetryTimer = nil

        let now = Date()
        // An unanswered popup stays as is, no second one.
        guard monitor.popupEnabled,
              promptPanels.isEmpty,
              let hourStart = Calendar.current.dateInterval(of: .hour, for: now)?.start,
              isInPopupWindow,
              hourStart != lastPromptedHour,
              monitor.isSchedulerHourOn(at: now)
        else { return }

        // Wait out calls and Keynote/PowerPoint slideshows, retry each minute.
        if BusyDetector.isBusy {
            scheduleBusyRetry()
            return
        }

        lastPromptedHour = hourStart
        showPrompt()
    }

    private func scheduleBusyRetry() {
        let retry = Date().addingTimeInterval(60)
        // Past the hour, the hour timer takes over.
        guard let hourEnd = Calendar.current.dateInterval(of: .hour, for: Date())?.end,
              retry < hourEnd else { return }
        let timer = Timer(fire: retry, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.evaluate() }
        }
        RunLoop.main.add(timer, forMode: .common)
        busyRetryTimer = timer
    }

    private func scheduleNextHour() {
        hourTimer?.invalidate()
        guard let next = Calendar.current.dateInterval(of: .hour, for: Date())?.end else { return }
        // A second past the hour, so the schedule check lands inside the new hour.
        let timer = Timer(fire: next.addingTimeInterval(1), interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.evaluate() }
        }
        RunLoop.main.add(timer, forMode: .common)
        hourTimer = timer
    }

    // MARK: - Scheduler window

    func showSchedulerWindow() {
        if schedulerWindow == nil {
            let draft = SchedulerDraft(hours: monitor.effectiveSchedule)
            schedulerDraft = draft
            let window = NSWindow(contentViewController: NSHostingController(rootView: SchedulerGridView(
                monitor: monitor,
                draft: draft,
                // Closing saves, see windowWillClose.
                onDone: { [weak self] in self?.schedulerWindow?.close() }
            )))
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.title = ""
            window.isReleasedWhenClosed = false
            window.delegate = self
            // Dead center of the screen each time it opens. It's released on close.
            if let screen = NSScreen.main ?? NSScreen.screens.first, let content = window.contentView {
                window.setContentSize(content.fittingSize)
                let size = window.frame.size
                window.setFrameOrigin(NSPoint(x: screen.frame.midX - size.width / 2,
                                              y: screen.frame.midY - size.height / 2))
            }
            schedulerWindow = window
            onWindowsChanged?()
        }

        // Same as Settings, NSApp.activate() alone can be refused.
        NSApp.activate(ignoringOtherApps: true)
        if let window = schedulerWindow {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === schedulerWindow else { return }
        // Closing the window saves. Empty or matching the suggestion means
        // following the suggested hours again.
        if let hours = schedulerDraft?.hours {
            let isEmpty = hours.allSatisfy { $0 == 0 }
            let schedule = isEmpty || hours == monitor.suggestedSchedule ? nil : hours
            if monitor.userSchedule != schedule { monitor.userSchedule = schedule }
        }
        // Deferred like Settings, so the Dock icon doesn't outlive the window for a frame.
        Task { @MainActor [weak self] in
            self?.schedulerWindow?.delegate = nil
            self?.schedulerWindow?.contentViewController = nil
            self?.schedulerWindow = nil
            self?.schedulerDraft = nil
            self?.onWindowsChanged?()
        }
    }

    // MARK: - Popup

    /// Also used by the Option menu to test it, whatever the schedule says.
    func showPrompt(playSound: Bool = true) {
        guard promptPanels.isEmpty else {
            promptPanels.forEach { $0.orderFrontRegardless() }
            return
        }

        promptPanels = NSScreen.screens.map(makePromptPanel(on:))
        for panel in promptPanels {
            panel.orderFrontRegardless()
        }
        // Keyboard goes to the main screen's copy, so Return and Escape work there.
        let main = NSScreen.main
        (promptPanels.first { $0.screen == main } ?? promptPanels.first)?.makeKey()

        if playSound { monitor.playAlertSound() }
    }

    private func makePromptPanel(on screen: NSScreen) -> NSPanel {
        let view = SchedulerPromptView(
            monitor: monitor,
            onReschedule: { [weak self] in
                self?.later()
                self?.showSchedulerWindow()
            },
            onUpdateNow: { [weak self] in self?.updateNow() }
        )

        // Non-activating so it floats over any app, even full screen, without
        // switching the frontmost app.
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        let host = NSHostingController(rootView: view)
        // The title bar is hidden, so don't leave room for it.
        host.safeAreaRegions = []
        panel.contentViewController = host
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true

        // Dead center of that screen. center() sits higher and only uses one screen.
        // The panel isn't sized to its content yet at this point, so do it now.
        panel.setContentSize(host.view.fittingSize)
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: screen.frame.midX - size.width / 2,
                                     y: screen.frame.midY - size.height / 2))
        return panel
    }

    private func dismissPrompt() {
        let panels = promptPanels
        promptPanels = []
        panels.forEach { $0.orderOut(nil) }
        // Released on the next pass, the click is still inside a SwiftUI button action.
        Task { @MainActor in
            panels.forEach { $0.contentViewController = nil }
        }
    }

    // Counts as this hour's popup, so the next one waits for the next allowed hour.
    private func later() {
        lastPromptedHour = Calendar.current.dateInterval(of: .hour, for: Date())?.start
        dismissPrompt()
    }

    // Comes back at the next allowed hour if macOS still hasn't updated.
    private func updateNow() {
        NSWorkspace.shared.open(UpdateMonitor.softwareUpdateURL)
        later()
    }
}
