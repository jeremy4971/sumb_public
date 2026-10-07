//
//  AppDelegate.swift
//  updatecountdown
//
//  The menu bar icon and its countdown, the Dock icon, the click and
//  right-click menus, the Settings window and the reminder notifications.
//

import Cocoa
import SwiftUI
import Combine
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSMenuItemValidation, NSWindowDelegate {

    let monitor = UpdateMonitor()

    private var statusItem: NSStatusItem?

    private var mainMenu: NSMenu?
    private var mainMenuHostingView: NSHostingView<MenuContentView>?
    private lazy var contextMenu = NSMenu()

    private var optionsWindow: NSWindow?
    private var reminderTimer: Timer?
    private var wasWithinReminderWindow = false
    private var didSendExpiredNotification = false
    private var blinkTimer: Timer?
    private var halfSecondBlinkTimer: Timer?
    private var isBadgeDotVisible = true
    private let dockTileView = DockTileView()
    private var pendingOptionsWindowTimer: Timer?
    private var suppressReopenUntil: Date = .distantPast
    private var cancellables = Set<AnyCancellable>()

    private static let notificationReopenGrace: TimeInterval = 0.5

    // SUMB lives in the menu bar; closing Options is not quitting.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // A Dock click opens Software Update. With the Dock icon hidden, a relaunch
    // opens Settings instead.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard NSApp.activationPolicy() == .accessory else {
            NSWorkspace.shared.open(UpdateMonitor.softwareUpdateURL)
            return false
        }

        // Deferred because a notification click also lands here as a reopen.
        guard Date() >= suppressReopenUntil else { return false }
        pendingOptionsWindowTimer?.invalidate()
        pendingOptionsWindowTimer = Timer.scheduledTimer(
            withTimeInterval: Self.notificationReopenGrace, repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.showOptionsWindow() }
        }
        return false
    }

    private func suppressOptionsWindowForNotification() {
        pendingOptionsWindowTimer?.invalidate()
        pendingOptionsWindowTimer = nil
        suppressReopenUntil = Date().addingTimeInterval(Self.notificationReopenGrace)
    }

    // Same rule as the right-click menu: hidden under lockdown unless Option is held.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        guard !monitor.disableContextMenuActions || NSEvent.modifierFlags.contains(.option) else { return nil }
        let menu = NSMenu()
        let item = menu.addItem(withTitle: "Settings…", action: #selector(showOptionsWindow), keyEquivalent: "")
        item.target = self
        return menu
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
                DispatchQueue.main.async {
                    self?.refreshStatusItem()
                    self?.updateDockVisibility()
                    self?.refreshDockTile()
                }
            }
            .store(in: &cancellables)

        dockTileView.frame = NSRect(origin: .zero, size: NSApp.dockTile.size)
        refreshStatusItem()
        updateDockVisibility()
        refreshDockTile()

        // @Published emits on subscribe, so this also applies at launch and a
        // forced value takes effect right away.
        monitor.$hideNotch
            .receive(on: RunLoop.main)
            .sink { hidden in NotchDisplay.setHidden(hidden) }
            .store(in: &cancellables)

        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // Registered once at launch, and again only if the button label is edited.
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

        Publishers.Merge5(
            monitor.$targetDate.map { _ in () },
            monitor.$reminderThresholdDays.map { _ in () },
            monitor.$reminderIntervalMinutes.map { _ in () },
            monitor.$notificationsEnabled.map { _ in () },
            monitor.$status.map { _ in () }
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in self?.updateReminderScheduling() }
        .store(in: &cancellables)

        // Once per crossing. The flag resets when status leaves .expired so a
        // later crossing can fire again.
        monitor.$status
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

    // Built once so the SF Symbol isn't parsed on every tick. Colors still
    // resolve against the current appearance when AppKit draws them.
    private static let baseSymbolConfig = NSImage.SymbolConfiguration(textStyle: .body, scale: .large)

    // Black or white at 85%, so the gear feels a bit translucent.
    private static let gearOpacity: CGFloat = 0.85

    private static let solidGearColor = makeGearColor(alpha: 1)
    private static let gearColor = makeGearColor(alpha: gearOpacity)

    private static func makeGearColor(alpha: CGFloat) -> NSColor {
        NSColor(name: nil) { appearance in
            let white: CGFloat = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? 1 : 0
            return NSColor(white: white, alpha: alpha)
        }
    }

    private static let badgedStatusImage: NSImage? = {
        // Two colorable layers: gear and badge dot. isTemplate has to be false
        // or the palette colors are thrown away.
        let config = baseSymbolConfig.applying(
            NSImage.SymbolConfiguration(paletteColors: [.systemRed, gearColor])
        )
        let image = NSImage(systemSymbolName: "gear.badge", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        image?.isTemplate = false
        return image
    }()

    // Blink "off" frame. Plain "gear" drawn at the bottom of a canvas the size
    // of gear.badge (1pt taller), so the gear doesn't shift when it swaps.
    private static let badgeDotHiddenStatusImage: NSImage? = {
        guard let badged = badgedStatusImage,
              let gear = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)?
                .withSymbolConfiguration(baseSymbolConfig.applying(
                    NSImage.SymbolConfiguration(paletteColors: [solidGearColor])
                ))
        else { return nil }

        // "gear" applies a see-through palette color twice (72% instead of 85%),
        // so it's drawn solid and faded here instead.
        let image = NSImage(size: badged.size, flipped: false) { _ in
            gear.draw(in: NSRect(origin: .zero, size: gear.size), from: .zero,
                      operation: .sourceOver, fraction: gearOpacity)
            return true
        }
        image.isTemplate = false
        return image
    }()

    private static let upToDateStatusImage: NSImage? = {
        // Template image: monochrome, matches the menu bar.
        let image = NSImage(systemSymbolName: "gear.badge.checkmark", accessibilityDescription: nil)?
            .withSymbolConfiguration(baseSymbolConfig)
        image?.isTemplate = true
        return image
    }()

    private func refreshStatusItem() {
        guard let button = statusItem?.button else { return }

        var showsRedBadge = false
        switch monitor.status {
        case .scheduled:
            button.title = monitor.countdownText.map { " \($0)" } ?? ""
            showsRedBadge = true
        case .expired:
            // Deadline passed but macOS hasn't updated yet.
            button.title = " \(monitor.localizedUpdatingMenuBar)"
            showsRedBadge = true
        case .none where monitor.recommendedOSVersion != nil:
            // No MDM deadline, but a newer macOS version is available.
            button.title = ""
            showsRedBadge = true
        case .none:
            button.title = ""
        }

        updateBadgeBlinking(showsRedBadge && shouldBlinkDot)
        button.image = showsRedBadge ? currentBadgedImage : Self.upToDateStatusImage

        statusItem?.isVisible = !(monitor.hideIconWhenUpToDate && isUpToDate)
    }

    private var isUpToDate: Bool {
        monitor.status == .none && monitor.recommendedOSVersion == nil
    }

    // Also blinks once the deadline has passed, but not for a newer version with
    // no deadline since there's nothing to count down to.
    private var shouldBlinkDot: Bool {
        let days = monitor.dotBlinkingDays
        guard days > 0 else { return false }
        if monitor.status == .expired { return true }
        guard monitor.status == .scheduled, let target = monitor.targetDate else { return false }
        return target.timeIntervalSinceNow <= TimeInterval(days) * 24 * 60 * 60
    }

    private var currentBadgedImage: NSImage? {
        isBadgeDotVisible ? Self.badgedStatusImage : Self.badgeDotHiddenStatusImage
    }

    // Blinks the red dot, 0.5 s on and 0.5 s off.
    private func updateBadgeBlinking(_ active: Bool) {
        halfSecondBlinkTimer?.invalidate()
        halfSecondBlinkTimer = nil

        guard active else {
            stopBlinkTimer()
            isBadgeDotVisible = true
            return
        }

        // Live HH:mm:ss: dot on for the first half of each second, off for the rest,
        // timed against the digit on screen.
        if let seconds = monitor.countdownSeconds, let target = monitor.targetDate {
            stopBlinkTimer()
            let intoSecond = target.timeIntervalSinceNow - Double(seconds)
            isBadgeDotVisible = intoSecond >= 0.5
            if isBadgeDotVisible {
                let timer = Timer.scheduledTimer(withTimeInterval: intoSecond - 0.5 + 0.01, repeats: false) { [weak self] _ in
                    Task { @MainActor [weak self] in self?.refreshStatusItem() }
                }
                timer.tolerance = 0
                halfSecondBlinkTimer = timer
            }
            return
        }

        guard blinkTimer == nil else { return }

        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isBadgeDotVisible.toggle()
                self.statusItem?.button?.image = self.currentBadgedImage
            }
        }
        timer.tolerance = 0.05
        blinkTimer = timer
    }

    private func stopBlinkTimer() {
        blinkTimer?.invalidate()
        blinkTimer = nil
    }

    // MARK: - Dock tile

    // Shown while an update is available if the setting is on, and always while
    // Settings is open so it behaves like a normal app window.
    private func updateDockVisibility() {
        let showsDock = (monitor.showDockIcon && !isUpToDate) || optionsWindow != nil
        let policy: NSApplication.ActivationPolicy = showsDock ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        if showsDock { NSApp.dockTile.display() }
    }

    // The menu bar countdown in the badge, "!" past the deadline. Up to date,
    // the content view is removed so the Dock draws the regular icon.
    private func refreshDockTile() {
        let badge: String?
        switch monitor.status {
        case .scheduled: badge = monitor.countdownText
        case .expired: badge = "!"
        // A newer macOS with no deadline.
        case .none: badge = isUpToDate ? nil : "1"
        }

        guard badge != dockTileView.badge else { return }
        dockTileView.centersBadge = monitor.countdownSeconds != nil
        dockTileView.badge = badge
        NSApp.dockTile.contentView = badge == nil ? nil : dockTileView
        NSApp.dockTile.display()
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
        let menu = mainMenu ?? makeMainMenu()

        // Re-measured on every open since the content changes shape between states.
        // Zeroing the frame first stops the old width acting as a minimum.
        if let hostingView = mainMenuHostingView {
            hostingView.frame = .zero
            hostingView.frame = NSRect(origin: .zero, size: hostingView.fittingSize)
        }

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    private func makeMainMenu() -> NSMenu {
        let menu = NSMenu()
        let item = NSMenuItem()

        // MenuContentView tracks `monitor` itself, so the cached view stays
        // current without being rebuilt.
        let hostingView = NSHostingView(rootView: MenuContentView(monitor: monitor, onUpdateNow: { [weak self] in
            self?.mainMenu?.cancelTracking()
        }))
        item.view = hostingView
        menu.addItem(item)

        mainMenu = menu
        mainMenuHostingView = hostingView
        return menu
    }

    // MARK: - Context menu

    // The two plists the countdown comes from, revealed in Finder with Option
    // held. The path rides along in representedObject so one action covers both.
    private static let revealablePlists: [(title: String, path: String)] = [
        ("SoftwareUpdateDDMStatePersistence", UpdateMonitor.plistPath),
        ("com.apple.SoftwareUpdate", UpdateMonitor.softwareUpdatePlistPath),
    ]

    private func showContextMenu() {
        // Same NSMenu every time, but items are rebuilt since they depend on
        // the Option key and the lockdown setting.
        let menu = contextMenu
        menu.removeAllItems()

        // Read at click time: the menu is rebuilt on every click, and menu
        // tracking swallows the events a flags-changed monitor would need.
        let optionHeld = NSEvent.modifierFlags.contains(.option)

        // "Hide settings" hides the item rather than disabling it. Option brings
        // it back, so a technician can still get in.
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

            // hideNotch can't be locked by a profile, so this ignores the lockdown too.
            menu.addItem(withTitle: "Toggle Notch", action: #selector(toggleNotch), keyEquivalent: "")
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

    // Greys out a reveal item whose file is missing (the DDM plist only exists
    // once an update is scheduled), and Toggle Notch on a Mac without a notch.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(toggleNotch):
            return NotchDisplay.hasNotch()
        case #selector(revealPlistInFinder(_:)):
            guard let path = menuItem.representedObject as? String else { return true }
            return FileManager.default.fileExists(atPath: path)
        default:
            return true
        }
    }

    // activateFileViewerSelecting resolves /var → /private/var itself, so the
    // path constants go in as-is.
    @objc private func revealPlistInFinder(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    // Flip the setting, not the display, so the Settings toggle stays in sync.
    @objc private func toggleNotch() {
        monitor.hideNotch.toggle()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Options window

    // Measured, not computed: SwiftUI's reported fitting size for the
    // Localization tab's Grid wasn't reliable.
    private static let optionsWindowWidth: CGFloat = 440
    private static let generalTabHeight: CGFloat = 590
    private static let localizationTabHeight: CGFloat = 590
    private static let aboutTabHeight: CGFloat = 260

    // Saved as "NSWindow Frame SUMBSettingsWindow" in defaults.
    private static let optionsWindowAutosaveName = "SUMBSettingsWindow"

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

            // Read before adding the tabs, selecting the first one saves index 0.
            let savedIndex = UserDefaults.standard.integer(forKey: OptionsTabViewController.selectedTabKey)

            let tabViewController = OptionsTabViewController()
            tabViewController.tabStyle = .toolbar
            tabViewController.tabViewItems = [generalItem, localizationItem, aboutItem]
            // Reopen on the last tab, as the HIG suggests for settings windows.
            if tabViewController.tabViewItems.indices.contains(savedIndex) {
                tabViewController.selectedTabViewItemIndex = savedIndex
            }

            window.contentViewController = tabViewController
            // Set explicitly since tabView(_:didSelect:) may not fire for the
            // initial selection.
            let selectedItem = tabViewController.tabViewItems[tabViewController.selectedTabViewItemIndex]
            window.title = selectedItem.label

            // Centered on first open, then wherever it was last left.
            // force is needed because the window isn't resizable.
            window.center()
            if window.setFrameUsingName(Self.optionsWindowAutosaveName, force: true),
               let size = selectedItem.viewController?.preferredContentSize {
                // Keep the saved spot but use the current tab height.
                let topLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
                window.setContentSize(size)
                window.setFrameTopLeftPoint(topLeft)
            }
            window.setFrameAutosaveName(Self.optionsWindowAutosaveName)
            window.delegate = self
            optionsWindow = window
        }

        updateDockVisibility()

        // Activate first, or the window stays behind the frontmost app.
        NSApp.activate()
        if let window = optionsWindow {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
            // In case activation lags behind.
            window.orderFrontRegardless()
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === optionsWindow else { return }
        // Deferred: hiding the Dock icon while the window is still on screen
        // leaves the menu bar and the Dock icon behind for a frame.
        Task { @MainActor [weak self] in
            // Free the autosave name so the next window can take it.
            self?.optionsWindow?.setFrameAutosaveName("")
            self?.optionsWindow?.delegate = nil
            self?.optionsWindow?.contentViewController = nil
            self?.optionsWindow = nil
            self?.updateDockVisibility()
        }
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

        // .scheduled already rules out "no update" and an OS that meets the
        // target, so this guard alone stops reminders once up to date.
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
            reminderTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.monitor.postReminderNotification() }
            }

            if justEntered {
                monitor.postReminderNotification()
            }
        } else {
            wasWithinReminderWindow = false
            let delay = remaining - windowStart
            reminderTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
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
    // Update pane, never the Settings window. Dismissing does nothing.
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
            NSWorkspace.shared.open(UpdateMonitor.softwareUpdateURL)
        default:
            break
        }
        completionHandler()
    }
}

// Keeps the Options window title in sync with the selected tab.
final class OptionsTabViewController: NSTabViewController {
    static let selectedTabKey = "optionsSelectedTab"

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        view.window?.title = tabViewItem?.label ?? ""
        UserDefaults.standard.set(selectedTabViewItemIndex, forKey: Self.selectedTabKey)
    }
}
