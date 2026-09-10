//
//  AppDelegate.swift
//  updatecountdown
//
//  Runs the NSStatusItem (icon + countdown title). Both menus are plain
//  NSMenus — the dropdown is a custom NSMenuItem view hosting SwiftUI — so
//  they attach flush under the status item with no gap or animation.
//

import Cocoa
import SwiftUI
import Combine
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSMenuItemValidation {

    let monitor = UpdateMonitor()

    private var statusItem: NSStatusItem?
    private var optionsWindow: NSWindow?
    private var reminderTimer: Timer?
    private var wasWithinReminderWindow = false
    private var didSendExpiredNotification = false
    private var pendingOptionsWindowTimer: Timer?
    private var suppressReopenUntil: Date = .distantPast
    private var cancellables = Set<AnyCancellable>()

    private nonisolated static let softwareUpdateURL = URL(string: "x-apple.systempreferences:com.apple.Software-Update-Settings.extension")!

    private static let notificationReopenGrace: TimeInterval = 0.5

    // Relaunching SUMB.app while it's already running is what makes "Launch
    // SUMB.app to re-open settings" work when the status item is hidden.
    //
    // It's deferred because clicking a notification's body also foregrounds the
    // app and lands here as a reopen, which would pop Settings up next to the
    // Software Update pane. The didReceive callback cancels this timer;
    // suppressReopenUntil covers the case where it arrives first instead.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard Date() >= suppressReopenUntil else { return true }

        pendingOptionsWindowTimer?.invalidate()
        pendingOptionsWindowTimer = Timer.scheduledTimer(
            withTimeInterval: Self.notificationReopenGrace, repeats: false
        ) { _ in
            Task { @MainActor [weak self] in self?.showOptionsWindow() }
        }
        return true
    }

    private func suppressOptionsWindowForNotification() {
        pendingOptionsWindowTimer?.invalidate()
        pendingOptionsWindowTimer = nil
        suppressReopenUntil = Date().addingTimeInterval(Self.notificationReopenGrace)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            // Same font as the system clock: fixed-width digits, so the icon
            // doesn't shift around as the digits change.
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        monitor.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // objectWillChange fires *before* the value updates, so defer.
                DispatchQueue.main.async { self?.refreshStatusItem() }
            }
            .store(in: &cancellables)

        refreshStatusItem()

        // @Published emits on subscribe, so this also applies at launch and a
        // forced value takes effect right away.
        monitor.$hideNotch
            .receive(on: RunLoop.main)
            .sink { hidden in NotchDisplay.setHidden(hidden) }
            .store(in: &cancellables)

        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // Registered once at launch, and again only if the button label is
        // edited — never on the notification-post cadence.
        monitor.$localizedUpdateNowButton
            .receive(on: RunLoop.main)
            .sink { title in
                let action = UNNotificationAction(
                    identifier: UpdateMonitor.updateActionIdentifier,
                    title: title,
                    options: []
                )
                let category = UNNotificationCategory(
                    identifier: UpdateMonitor.reminderCategoryIdentifier,
                    actions: [action],
                    intentIdentifiers: [],
                    options: []
                )
                UNUserNotificationCenter.current().setNotificationCategories([category])
            }
            .store(in: &cancellables)

        // Turning on Demo mode shouldn't fire a reminder straight away just
        // because the demo date already sits inside the threshold window.
        monitor.$demoMode
            .filter { $0 }
            .sink { [weak self] _ in self?.wasWithinReminderWindow = true }
            .store(in: &cancellables)

        // `status` needs removeDuplicates: recomputeDisplay() reassigns it on
        // every display tick even while still .scheduled, which would restart
        // the repeating timer before it ever fires twice.
        Publishers.Merge5(
            monitor.$targetDate.map { _ in () },
            monitor.$reminderThresholdDays.map { _ in () },
            monitor.$reminderIntervalMinutes.map { _ in () },
            monitor.$notificationsEnabled.map { _ in () },
            monitor.$status.removeDuplicates().map { _ in () }
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in self?.updateReminderScheduling() }
        .store(in: &cancellables)

        // Once per crossing. removeDuplicates for the same reason as above, and
        // the flag resets when status leaves .expired so a later crossing can
        // fire again.
        monitor.$status
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self else { return }
                guard status == .expired else {
                    self.didSendExpiredNotification = false
                    return
                }
                guard !self.didSendExpiredNotification, self.monitor.notificationsEnabled else { return }
                self.didSendExpiredNotification = true
                self.monitor.postExpiredNotification()
            }
            .store(in: &cancellables)
    }

    // MARK: - Status item rendering

    private func refreshStatusItem() {
        guard let button = statusItem?.button else { return }

        let baseConfig = NSImage.SymbolConfiguration(textStyle: .body, scale: .large)

        let symbolName: String
        var showsRedBadge = false
        switch monitor.status {
        case .scheduled:
            symbolName = "gear.badge"
            button.title = monitor.countdownText.map { " \($0)" } ?? ""
            showsRedBadge = true
        case .expired:
            // Deadline passed but macOS hasn't updated yet.
            symbolName = "gear.badge"
            button.title = " \(monitor.localizedUpdatingMenuBar)"
            showsRedBadge = true
        case .none where monitor.recommendedOSVersion != nil:
            // No MDM deadline, but a newer macOS version is available.
            symbolName = "gear.badge"
            button.title = ""
            showsRedBadge = true
        case .none:
            symbolName = "gear.badge.checkmark"
            button.title = ""
        }

        let image: NSImage?
        if showsRedBadge {
            // Two colorable layers: gear and badge dot. isTemplate has to be
            // false or the palette colors are thrown away.
            let paletteConfig = baseConfig.applying(
                NSImage.SymbolConfiguration(paletteColors: [.systemRed, .labelColor])
            )
            image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
                .withSymbolConfiguration(paletteConfig)
            image?.isTemplate = false
        } else {
            // Template image: monochrome, matches the menu bar.
            image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
                .withSymbolConfiguration(baseConfig)
            image?.isTemplate = true
        }
        button.image = image

        let isUpToDate = monitor.status == .none && monitor.recommendedOSVersion == nil
        statusItem?.isVisible = !(monitor.hideIconWhenUpToDate && isUpToDate)
    }

    // MARK: - Status item click handling

    @objc private func handleStatusItemClick(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            showMainMenu()
        }
    }

    // MARK: - Main dropdown

    private func showMainMenu() {
        let menu = NSMenu()
        let item = NSMenuItem()

        let hostingView = NSHostingView(rootView: MenuContentView(monitor: monitor, onUpdateNow: { [weak menu] in
            menu?.cancelTracking()
        }))
        hostingView.frame = NSRect(origin: .zero, size: hostingView.fittingSize)
        item.view = hostingView
        menu.addItem(item)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    // MARK: - Context menu

    // The two plists the countdown comes from, revealed in Finder with Option
    // held. The path rides along in representedObject so one action covers both.
    private static let revealablePlists: [(title: String, path: String)] = [
        ("SoftwareUpdateDDMStatePersistence", UpdateMonitor.plistPath),
        ("com.apple.SoftwareUpdate", UpdateMonitor.softwareUpdatePlistPath),
    ]

    private func showContextMenu() {
        let menu = NSMenu()

        // Read at click time instead of tracking a flags-changed monitor: the
        // menu is rebuilt on every click anyway, and menu tracking swallows the
        // key events such a monitor needs.
        let optionHeld = NSEvent.modifierFlags.contains(.option)

        // MDM lockdown hides "Settings…" rather than disabling it. Option brings
        // it back — this keeps the window out of an end user's way, it's not a
        // barrier for a technician at the machine.
        if !monitor.disableContextMenuActions || optionHeld {
            menu.addItem(withTitle: "Settings…", action: #selector(showOptionsWindow), keyEquivalent: "")
        }

        // Outside the lockdown check on purpose: these only select a file in
        // Finder and change nothing.
        if optionHeld {
            for plist in Self.revealablePlists {
                let item = menu.addItem(
                    withTitle: plist.title,
                    action: #selector(revealPlistInFinder(_:)),
                    keyEquivalent: ""
                )
                item.representedObject = plist.path
            }
        }

        // Under lockdown with Option up the menu is just "Quit", and a leading
        // separator would be a stray line at the top.
        if !menu.items.isEmpty {
            menu.addItem(.separator())
        }
        menu.addItem(withTitle: "Quit", action: #selector(quitApp), keyEquivalent: "q")

        for item in menu.items {
            item.target = self
        }

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    // Greys out a reveal item whose file isn't there. The DDM plist only exists
    // once an update has been scheduled, and Finder silently does nothing when
    // asked to select a missing path.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.action == #selector(revealPlistInFinder(_:)),
              let path = menuItem.representedObject as? String else { return true }
        return FileManager.default.fileExists(atPath: path)
    }

    // activateFileViewerSelecting resolves /var → /private/var itself, so the
    // path constants go in as-is.
    @objc private func revealPlistInFinder(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Options window

    // Measured, not computed: SwiftUI's reported fitting size for the
    // Localization tab's Grid wasn't reliable.
    private static let optionsWindowWidth: CGFloat = 440
    private static let generalTabHeight: CGFloat = 560
    private static let localizationTabHeight: CGFloat = 711
    private static let aboutTabHeight: CGFloat = 260

    @objc private func showOptionsWindow() {
        if optionsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: Self.optionsWindowWidth, height: Self.generalTabHeight),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            // Compact, centered-title toolbar to match tabStyle = .toolbar below.
            window.toolbarStyle = .preference

            let generalItem = NSTabViewItem(viewController: Self.makeHostingController(
                rootView: GeneralOptionsView(monitor: monitor),
                height: Self.generalTabHeight
            ))
            generalItem.label = "General"
            generalItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)

            let localizationItem = NSTabViewItem(viewController: Self.makeHostingController(
                rootView: LocalizationOptionsView(monitor: monitor),
                height: Self.localizationTabHeight
            ))
            localizationItem.label = "Localization"
            localizationItem.image = NSImage(systemSymbolName: "translate", accessibilityDescription: nil)

            let aboutItem = NSTabViewItem(viewController: Self.makeHostingController(
                rootView: AboutOptionsView(),
                height: Self.aboutTabHeight
            ))
            aboutItem.label = "About"
            aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)

            let tabViewController = OptionsTabViewController()
            tabViewController.tabStyle = .toolbar
            tabViewController.tabViewItems = [generalItem, localizationItem, aboutItem]

            window.contentViewController = tabViewController
            // Set explicitly — tabView(_:didSelect:) may not fire for the
            // initial selection.
            window.title = generalItem.label
            window.center()
            optionsWindow = window
        }

        optionsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func makeHostingController(rootView: some View, height: CGFloat) -> NSHostingController<some View> {
        let controller = NSHostingController(rootView: rootView)
        // Honor preferredContentSize strictly, instead of letting SwiftUI's
        // content-driven sizing fight it.
        controller.sizingOptions = []
        controller.preferredContentSize = NSSize(width: Self.optionsWindowWidth, height: height)
        return controller
    }

    // MARK: - Reminder notification

    // Self-rescheduling: arms the repeating timer if we're already inside the
    // threshold window, otherwise a one-shot that wakes up when it starts.
    private func updateReminderScheduling() {
        reminderTimer?.invalidate()
        reminderTimer = nil

        // .scheduled already rules out "no update" and "current OS already
        // satisfies the target" — both of those fold into .none — so this guard
        // alone stops reminders once the Mac is up to date.
        guard monitor.notificationsEnabled, monitor.status == .scheduled, let target = monitor.targetDate else {
            wasWithinReminderWindow = false
            return
        }

        let remaining = target.timeIntervalSinceNow
        guard remaining > 0 else {
            wasWithinReminderWindow = false
            return
        }

        let windowStart = TimeInterval(monitor.reminderThresholdDays) * 24 * 60 * 60

        if remaining <= windowStart {
            let justEntered = !wasWithinReminderWindow
            wasWithinReminderWindow = true

            let interval = TimeInterval(max(1, monitor.reminderIntervalMinutes) * 60)
            reminderTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                Task { @MainActor [weak self] in self?.monitor.postReminderNotification() }
            }

            if justEntered {
                monitor.postReminderNotification()
            }
        } else {
            wasWithinReminderWindow = false
            let delay = remaining - windowStart
            reminderTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
                Task { @MainActor [weak self] in self?.updateReminderScheduling() }
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Show it even when the app is frontmost, e.g. with the Options window open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }

    // Tapping the action button or the notification itself opens the Software
    // Update pane, and only that — never the Settings window. Dismissing does
    // nothing.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Any response means the app came up from the notification, not from
        // someone asking for Settings, so cancel the reopen's window.
        Task { @MainActor [weak self] in self?.suppressOptionsWindowForNotification() }

        switch response.actionIdentifier {
        case UpdateMonitor.updateActionIdentifier, UNNotificationDefaultActionIdentifier:
            NSWorkspace.shared.open(Self.softwareUpdateURL)
        default:
            break
        }
        completionHandler()
    }
}

// Keeps the Options window title in sync with the selected tab.
final class OptionsTabViewController: NSTabViewController {
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        view.window?.title = tabViewItem?.label ?? ""
    }
}
