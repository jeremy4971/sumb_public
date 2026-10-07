//
//  UpdateMonitor.swift
//  updatecountdown
//
//  Finds the macOS update scheduled by the organization and works out the
//  countdown. Also holds the app settings and sends the reminders.
//

import Foundation
import Combine
import UserNotifications

@MainActor
final class UpdateMonitor: ObservableObject {

    static let plistPath = "/var/db/softwareupdate/SoftwareUpdateDDMStatePersistence.plist"

    // Apple's own update catalog. Separate from any MDM enforcement, so we can
    // still spot a newer macOS when nothing has been scheduled.
    static let softwareUpdatePlistPath = "/Library/Preferences/com.apple.SoftwareUpdate.plist"

    // Below this, show a live HH:mm:ss countdown instead of a day count.
    private static let urgentThreshold: TimeInterval = 24 * 60 * 60

    // MARK: - UserDefaults keys

    // Internal, not private, so OptionsView can call isManaged(_:) per field.
    enum Keys {
        static let demoMode = "demoMode"
        static let demoDate = "demoDate"
        static let demoOSVersion = "demoOSVersion"
        static let hideIconWhenUpToDate = "hideIconWhenUpToDate"
        static let showDockIcon = "showDockIcon"
        static let dotBlinkingDays = "dotBlinkingDays"
        static let hideNotch = "hideNotch"
        static let ignoreAppleUpdateChannel = "ignoreAppleUpdateChannel"
        static let notificationsEnabled = "notificationsEnabled"
        static let reminderThresholdDays = "reminderThresholdDays"
        static let reminderIntervalMinutes = "reminderIntervalMinutes"
        static let reminderNotificationTitle = "reminderNotificationTitle"
        static let reminderNotificationBody = "reminderNotificationBody"
        static let notificationSound = "notificationSound"
        static let localizedPopoverTitle = "localizedPopoverTitle"
        static let localizedUpdateNowButton = "localizedUpdateNowButton"
        static let localizedRestartWarning = "localizedRestartWarning"
        static let localizedUpToDateMessage = "localizedUpToDateMessage"
        static let localizedUpdatingMenuBar = "localizedUpdatingMenuBar"
        static let localizedDayPrefix = "localizedDayPrefix"
        static let localizedDaySuffix = "localizedDaySuffix"
        // Backs the "Hide settings" toggle. A profile can lock it.
        static let disableContextMenuActions = "disableContextMenuActions"

        // hideNotch is missing on purpose, see the property below.
        static let all: [String] = [
            demoMode, demoDate, demoOSVersion, hideIconWhenUpToDate, showDockIcon, dotBlinkingDays,
            ignoreAppleUpdateChannel,
            notificationsEnabled, reminderThresholdDays, reminderIntervalMinutes,
            reminderNotificationTitle, reminderNotificationBody, notificationSound,
            localizedPopoverTitle, localizedUpdateNowButton, localizedRestartWarning,
            localizedUpToDateMessage, localizedUpdatingMenuBar,
            localizedDayPrefix, localizedDaySuffix,
            disableContextMenuActions,
        ]
    }

    // The category itself is registered once at launch in AppDelegate, not on
    // every post.
    nonisolated static let updateActionIdentifier = "OPEN_SOFTWARE_UPDATE"
    nonisolated static let reminderCategoryIdentifier = "UPDATE_REMINDER"

    nonisolated static let softwareUpdateURL = URL(string: "x-apple.systempreferences:com.apple.Software-Update-Settings.extension")!

    // MARK: - Published state

    /// Text drawn to the right of the SF Symbol (nil = symbol only).
    @Published private(set) var countdownText: String?

    /// Seconds left while the live HH:mm:ss countdown shows, nil otherwise.
    /// Set together with countdownText, so it's always in step with it.
    private(set) var countdownSeconds: Int?

    @Published private(set) var targetDate: Date?
    @Published private(set) var targetOSVersion: String?

    /// A newer macOS from Apple's catalog, with no MDM deadline attached. nil
    /// unless it's actually newer than what's running.
    @Published private(set) var recommendedOSVersion: String?
    /// Build for `recommendedOSVersion`, e.g. "25F84". Shown in the popover in
    /// place of a deadline, since nothing is being enforced here.
    @Published private(set) var recommendedUpdateBuild: String?

    enum Status {
        /// Nothing scheduled, or the running OS already satisfies the target.
        case none
        case scheduled
        case expired
    }

    @Published private(set) var status: Status = .none

    // MARK: - Demo mode

    @Published var demoMode: Bool {
        didSet {
            UserDefaults.standard.set(demoMode, forKey: Keys.demoMode)
            reload()
        }
    }

    @Published var demoDate: Date {
        didSet {
            UserDefaults.standard.set(demoDate, forKey: Keys.demoDate)
            if demoMode { reload() }
        }
    }

    @Published var demoOSVersion: String {
        didSet {
            UserDefaults.standard.set(demoOSVersion, forKey: Keys.demoOSVersion)
            if demoMode { reload() }
        }
    }

    // MARK: - Menu bar icon

    @Published var hideIconWhenUpToDate: Bool {
        didSet { UserDefaults.standard.set(hideIconWhenUpToDate, forKey: Keys.hideIconWhenUpToDate) }
    }

    // MARK: - Dock icon

    /// Shows the Dock icon while an update is available. Off never shows it.
    @Published var showDockIcon: Bool {
        didSet { UserDefaults.standard.set(showDockIcon, forKey: Keys.showDockIcon) }
    }

    /// Days before the deadline when the red badge dot starts blinking. 0 means never.
    @Published var dotBlinkingDays: Int {
        didSet { UserDefaults.standard.set(dotBlinkingDays, forKey: Keys.dotBlinkingDays) }
    }

    // Experimental, and only meaningful on notched Macs. Kept out of Keys.all so
    // a profile can never lock it.
    @Published var hideNotch: Bool {
        didSet { UserDefaults.standard.set(hideNotch, forKey: Keys.hideNotch) }
    }

    // MARK: - Update channel

    // When on, Apple's catalog is ignored entirely and up-to-date status comes
    // only from the MDM/DDM plist.
    @Published var ignoreAppleUpdateChannel: Bool {
        didSet {
            UserDefaults.standard.set(ignoreAppleUpdateChannel, forKey: Keys.ignoreAppleUpdateChannel)
            reloadRecommendedUpdate()
        }
    }

    // MARK: - Reminder notification

    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    @Published var reminderThresholdDays: Int {
        didSet { UserDefaults.standard.set(reminderThresholdDays, forKey: Keys.reminderThresholdDays) }
    }

    @Published var reminderIntervalMinutes: Int {
        didSet { UserDefaults.standard.set(reminderIntervalMinutes, forKey: Keys.reminderIntervalMinutes) }
    }

    @Published var reminderNotificationTitle: String {
        didSet { UserDefaults.standard.set(reminderNotificationTitle, forKey: Keys.reminderNotificationTitle) }
    }

    @Published var reminderNotificationBody: String {
        didSet { UserDefaults.standard.set(reminderNotificationBody, forKey: Keys.reminderNotificationBody) }
    }

    /// A file name from /System/Library/Sounds, e.g. "Glass.aiff". Empty means
    /// the system default sound.
    @Published var notificationSound: String {
        didSet { UserDefaults.standard.set(notificationSound, forKey: Keys.notificationSound) }
    }

    // MARK: - Localization

    @Published var localizedPopoverTitle: String {
        didSet { UserDefaults.standard.set(localizedPopoverTitle, forKey: Keys.localizedPopoverTitle) }
    }

    @Published var localizedUpdateNowButton: String {
        didSet { UserDefaults.standard.set(localizedUpdateNowButton, forKey: Keys.localizedUpdateNowButton) }
    }

    @Published var localizedRestartWarning: String {
        didSet { UserDefaults.standard.set(localizedRestartWarning, forKey: Keys.localizedRestartWarning) }
    }

    @Published var localizedUpToDateMessage: String {
        didSet { UserDefaults.standard.set(localizedUpToDateMessage, forKey: Keys.localizedUpToDateMessage) }
    }

    @Published var localizedUpdatingMenuBar: String {
        didSet { UserDefaults.standard.set(localizedUpdatingMenuBar, forKey: Keys.localizedUpdatingMenuBar) }
    }

    /// Goes before the day count, e.g. "D-" for "D-4". Empty by default.
    @Published var localizedDayPrefix: String {
        didSet {
            UserDefaults.standard.set(localizedDayPrefix, forKey: Keys.localizedDayPrefix)
            recomputeDisplay()
        }
    }

    /// Goes after the day count, e.g. "4d" or "4j".
    @Published var localizedDaySuffix: String {
        didSet {
            UserDefaults.standard.set(localizedDaySuffix, forKey: Keys.localizedDaySuffix)
            recomputeDisplay()
        }
    }

    // MARK: - Timers

    // kqueue-backed, so nothing polls.
    private var fileWatchSource: DispatchSourceFileSystemObject?
    private var softwareUpdatePlistWatchSource: DispatchSourceFileSystemObject?
    // Picks up a profile install/update/removal while running, not just at next
    // launch.
    private var managedPreferencesWatchSources: [DispatchSourceFileSystemObject] = []
    private var displayTimer: Timer?
    // An MDM push often writes the plist several times within a few seconds, so
    // reloadManagedPreferences() runs once, 5s after the last change.
    private var managedPreferencesChangeDebounceTimer: Timer?

    // UserDefaults.standard already returns a profile's forced value over the
    // user's own, so this reads correctly either way.
    private struct LoadedSettings {
        let demoMode: Bool
        let demoDate: Date
        let demoOSVersion: String
        let hideIconWhenUpToDate: Bool
        let showDockIcon: Bool
        let dotBlinkingDays: Int
        let hideNotch: Bool
        let ignoreAppleUpdateChannel: Bool
        let notificationsEnabled: Bool
        let reminderThresholdDays: Int
        let reminderIntervalMinutes: Int
        let reminderNotificationTitle: String
        let reminderNotificationBody: String
        let notificationSound: String
        let localizedPopoverTitle: String
        let localizedUpdateNowButton: String
        let localizedRestartWarning: String
        let localizedUpToDateMessage: String
        let localizedUpdatingMenuBar: String
        let localizedDayPrefix: String
        let localizedDaySuffix: String
        let disableContextMenuActions: Bool
    }

    private static func loadSettingsFromDefaults() -> LoadedSettings {
        let defaults = UserDefaults.standard
        return LoadedSettings(
            demoMode: defaults.bool(forKey: Keys.demoMode),
            demoDate: (defaults.object(forKey: Keys.demoDate) as? Date)
                ?? Calendar.current.date(from: DateComponents(year: 2028, month: 1, day: 1, hour: 0, minute: 0))
                ?? Date(),
            demoOSVersion: (defaults.string(forKey: Keys.demoOSVersion))
                ?? "27.9.0",
            hideIconWhenUpToDate: (defaults.object(forKey: Keys.hideIconWhenUpToDate) as? Bool) ?? false,
            showDockIcon: (defaults.object(forKey: Keys.showDockIcon) as? Bool) ?? false,
            dotBlinkingDays: (defaults.object(forKey: Keys.dotBlinkingDays) as? Int) ?? 0,
            hideNotch: (defaults.object(forKey: Keys.hideNotch) as? Bool) ?? NotchDisplay.isHidden(),
            ignoreAppleUpdateChannel: (defaults.object(forKey: Keys.ignoreAppleUpdateChannel) as? Bool) ?? false,
            notificationsEnabled: (defaults.object(forKey: Keys.notificationsEnabled) as? Bool) ?? false,
            reminderThresholdDays: (defaults.object(forKey: Keys.reminderThresholdDays) as? Int) ?? 2,
            reminderIntervalMinutes: (defaults.object(forKey: Keys.reminderIntervalMinutes) as? Int) ?? 120,
            reminderNotificationTitle: (defaults.string(forKey: Keys.reminderNotificationTitle)) ?? "Managed Update",
            reminderNotificationBody: (defaults.string(forKey: Keys.reminderNotificationBody))
                ?? "An update to macOS $VERSION has been scheduled for $DATE.",
            notificationSound: (defaults.string(forKey: Keys.notificationSound)) ?? "",
            localizedPopoverTitle: (defaults.string(forKey: Keys.localizedPopoverTitle))
                ?? "macOS Update",
            localizedUpdateNowButton: (defaults.string(forKey: Keys.localizedUpdateNowButton))
                ?? "Open Software Update",
            localizedRestartWarning: (defaults.string(forKey: Keys.localizedRestartWarning))
                ?? "Be aware that your Mac will automatically restart after the deadline. [Learn more...](https://support.apple.com/en-us/100100)",
            localizedUpToDateMessage: (defaults.string(forKey: Keys.localizedUpToDateMessage))
                ?? "Your Mac is up to date.",
            localizedUpdatingMenuBar: (defaults.string(forKey: Keys.localizedUpdatingMenuBar))
                ?? "Preparing update...",
            localizedDayPrefix: (defaults.string(forKey: Keys.localizedDayPrefix)) ?? "",
            localizedDaySuffix: (defaults.string(forKey: Keys.localizedDaySuffix)) ?? "d",
            disableContextMenuActions: defaults.bool(forKey: Keys.disableContextMenuActions)
        )
    }

    private func applySettings(_ loaded: LoadedSettings) {
        demoMode = loaded.demoMode
        demoDate = loaded.demoDate
        demoOSVersion = loaded.demoOSVersion
        hideIconWhenUpToDate = loaded.hideIconWhenUpToDate
        showDockIcon = loaded.showDockIcon
        dotBlinkingDays = loaded.dotBlinkingDays
        hideNotch = loaded.hideNotch
        ignoreAppleUpdateChannel = loaded.ignoreAppleUpdateChannel
        notificationsEnabled = loaded.notificationsEnabled
        reminderThresholdDays = loaded.reminderThresholdDays
        reminderIntervalMinutes = loaded.reminderIntervalMinutes
        reminderNotificationTitle = loaded.reminderNotificationTitle
        reminderNotificationBody = loaded.reminderNotificationBody
        notificationSound = loaded.notificationSound
        localizedPopoverTitle = loaded.localizedPopoverTitle
        localizedUpdateNowButton = loaded.localizedUpdateNowButton
        localizedRestartWarning = loaded.localizedRestartWarning
        localizedUpToDateMessage = loaded.localizedUpToDateMessage
        localizedUpdatingMenuBar = loaded.localizedUpdatingMenuBar
        localizedDayPrefix = loaded.localizedDayPrefix
        localizedDaySuffix = loaded.localizedDaySuffix
        disableContextMenuActions = loaded.disableContextMenuActions
    }

    // Same format as configuration_profile/fr.jeremyb.sumb.plist. Demo keys
    // and hideNotch stay out: they're per-machine.
    func settingsPropertyListXML() -> String? {
        let settings: [String: Any] = [
            Keys.disableContextMenuActions: disableContextMenuActions,
            Keys.dotBlinkingDays: dotBlinkingDays,
            Keys.hideIconWhenUpToDate: hideIconWhenUpToDate,
            Keys.ignoreAppleUpdateChannel: ignoreAppleUpdateChannel,
            Keys.localizedDayPrefix: localizedDayPrefix,
            Keys.localizedDaySuffix: localizedDaySuffix,
            Keys.localizedPopoverTitle: localizedPopoverTitle,
            Keys.localizedRestartWarning: localizedRestartWarning,
            Keys.localizedUpToDateMessage: localizedUpToDateMessage,
            Keys.localizedUpdateNowButton: localizedUpdateNowButton,
            Keys.localizedUpdatingMenuBar: localizedUpdatingMenuBar,
            Keys.notificationSound: notificationSound,
            Keys.notificationsEnabled: notificationsEnabled,
            Keys.reminderIntervalMinutes: reminderIntervalMinutes,
            Keys.reminderNotificationBody: reminderNotificationBody,
            Keys.reminderNotificationTitle: reminderNotificationTitle,
            Keys.reminderThresholdDays: reminderThresholdDays,
            Keys.showDockIcon: showDockIcon,
        ]
        guard let data = try? PropertyListSerialization.data(fromPropertyList: settings, format: .xml, options: 0) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    init() {
        managedKeys = Self.computeManagedKeys()
        let loaded = Self.loadSettingsFromDefaults()
        disableContextMenuActions = loaded.disableContextMenuActions
        demoMode = loaded.demoMode
        demoDate = loaded.demoDate
        demoOSVersion = loaded.demoOSVersion
        hideIconWhenUpToDate = loaded.hideIconWhenUpToDate
        showDockIcon = loaded.showDockIcon
        dotBlinkingDays = loaded.dotBlinkingDays
        hideNotch = loaded.hideNotch
        ignoreAppleUpdateChannel = loaded.ignoreAppleUpdateChannel
        notificationsEnabled = loaded.notificationsEnabled
        reminderThresholdDays = loaded.reminderThresholdDays
        reminderIntervalMinutes = loaded.reminderIntervalMinutes
        reminderNotificationTitle = loaded.reminderNotificationTitle
        reminderNotificationBody = loaded.reminderNotificationBody
        notificationSound = loaded.notificationSound
        localizedPopoverTitle = loaded.localizedPopoverTitle
        localizedUpdateNowButton = loaded.localizedUpdateNowButton
        localizedRestartWarning = loaded.localizedRestartWarning
        localizedUpToDateMessage = loaded.localizedUpToDateMessage
        localizedUpdatingMenuBar = loaded.localizedUpdatingMenuBar
        localizedDayPrefix = loaded.localizedDayPrefix
        localizedDaySuffix = loaded.localizedDaySuffix

        reload()
        startWatchingPlist()
        startWatchingManagedPreferences()
        reloadRecommendedUpdate()
        startWatchingSoftwareUpdatePlist()
    }

    // MARK: - Public

    /// Reads the plist, or the demo values, and refreshes everything.
    func reload() {
        if demoMode {
            targetDate = demoDate
            targetOSVersion = demoOSVersion
        } else {
            let parsed = Self.readScheduledUpdate()
            targetDate = parsed?.date
            targetOSVersion = parsed?.osVersion
        }

        recomputeDisplay()
    }

    // A real system signal, so demoMode doesn't apply here the way it does in
    // reload() above.
    private func reloadRecommendedUpdate() {
        guard !ignoreAppleUpdateChannel,
              let found = Self.readRecommendedMacOSUpdate(),
              Self.compareVersions(Self.currentOSVersionString(), found.version) < 0 else {
            recommendedOSVersion = nil
            recommendedUpdateBuild = nil
            return
        }
        recommendedOSVersion = found.version
        recommendedUpdateBuild = Self.buildString(fromIdentifier: found.identifier)
    }

    // MARK: - Reminder notification

    /// Used by both the automatic schedule and the "Send Test Notification"
    /// button in Options.
    func postReminderNotification() {
        guard !reminderNotificationBody.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = expandingVariables(in: reminderNotificationTitle)
        content.body = expandingVariables(in: reminderNotificationBody)
        // Most prominent level we can ask for. The user's per-app style in
        // System Settings still wins.
        content.interruptionLevel = .timeSensitive
        content.sound = notificationSoundForContent()
        content.categoryIdentifier = Self.reminderCategoryIdentifier

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// One-shot, posted when the deadline passes.
    func postExpiredNotification() {
        guard !localizedUpdatingMenuBar.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = expandingVariables(in: reminderNotificationTitle)
        content.body = localizedUpdatingMenuBar
        content.interruptionLevel = .timeSensitive
        content.sound = notificationSoundForContent()
        content.categoryIdentifier = Self.reminderCategoryIdentifier

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // Just a name, no path. macOS searches the sound folders itself, so system
    // sounds work without shipping them.
    private func notificationSoundForContent() -> UNNotificationSound {
        guard !notificationSound.isEmpty else { return .default }
        return UNNotificationSound(named: UNNotificationSoundName(notificationSound))
    }

    // Read from disk rather than hard-coded, since the list can change between
    // macOS releases.
    static let availableSystemSounds: [String] = {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: "/System/Library/Sounds")) ?? []
        return files.filter { $0.hasSuffix(".aiff") }.sorted()
    }()

    // Fills in $DATE, $COUNTDOWN and $VERSION in the notification title and
    // body so they don't have to be hard-coded into the localized text.
    private func expandingVariables(in text: String) -> String {
        var text = text
        if let target = targetDate {
            text = text.replacingOccurrences(of: "$DATE", with: Self.formattedDateTime(target))
            text = text.replacingOccurrences(of: "$COUNTDOWN", with: Self.notificationCountdown(until: target))
        }
        if let version = targetOSVersion {
            text = text.replacingOccurrences(of: "$VERSION", with: version)
        }
        return text
    }

    // Days left, rounded up like the menu bar. In the last 24h it becomes a
    // decimal rounded down (0.9, 0.8...), never below 0.1 until the deadline.
    private static func notificationCountdown(until target: Date) -> String {
        let remaining = target.timeIntervalSinceNow
        guard remaining > 0 else { return "0" }
        if remaining > urgentThreshold {
            return String(daysRemaining(remaining))
        }
        // 8640s is a tenth of a day.
        let days = Double(min(9, max(1, Int(remaining / 8640)))) / 10
        return days.formatted(.number.precision(.fractionLength(1)).locale(preferredLocale))
    }

    // MARK: - Managed preferences (MDM)

    // Which of Keys.all a profile currently forces. Cached because
    // CFPreferencesAppValueIsForced is a slow cross-process lookup.
    @Published private(set) var managedKeys: Set<String> = []

    private static func computeManagedKeys() -> Set<String> {
        guard let bundleID = Bundle.main.bundleIdentifier else { return [] }
        return Set(Keys.all.filter { CFPreferencesAppValueIsForced($0 as CFString, bundleID as CFString) })
    }

    // CFPreferencesAppSynchronize flushes our cached copy so the re-read picks
    // up what changed underneath us.
    private func reloadManagedPreferences() {
        if let bundleID = Bundle.main.bundleIdentifier {
            CFPreferencesAppSynchronize(bundleID as CFString)
        }
        managedKeys = Self.computeManagedKeys()
        applySettings(Self.loadSettingsFromDefaults())
    }

    /// Whether a profile forces `key`. Used to grey out a control.
    func isManaged(_ key: String) -> Bool {
        managedKeys.contains(key)
    }

    /// Drives the "configured by a profile" footer in Options.
    var hasManagedPreferences: Bool {
        !managedKeys.isEmpty
    }

    /// Hides "Settings…" from the right-click and Dock menus. Option-right-click
    /// or relaunching the app with the Dock icon hidden still gets you there.
    @Published var disableContextMenuActions: Bool {
        didSet { UserDefaults.standard.set(disableContextMenuActions, forKey: Keys.disableContextMenuActions) }
    }

    // A profile can be scoped to one user or to the whole system, and the two
    // land in different places, so watch both.
    private static var managedPreferencesPlistPaths: [String] {
        guard let bundleID = Bundle.main.bundleIdentifier else { return [] }
        return [
            "/Library/Managed Preferences/\(NSUserName())/\(bundleID).plist",
            "/Library/Managed Preferences/\(bundleID).plist",
        ]
    }

    private func startWatchingManagedPreferences() {
        managedPreferencesWatchSources.forEach { $0.cancel() }
        managedPreferencesWatchSources.removeAll()

        for path in Self.managedPreferencesPlistPaths {
            watchManagedPreferencesPlist(at: path)
        }
    }

    private func watchManagedPreferencesPlist(at path: String) {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            // No profile at this scope yet, watch the directory instead.
            watchManagedPreferencesDirectoryForCreation(of: path)
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main
        )
        // Drop the old source before re-arming, or each event leaves one behind.
        source.setEventHandler { [weak self, weak source] in
            Task { @MainActor in
                guard let source, !source.isCancelled else { return }
                source.cancel()
                self?.managedPreferencesWatchSources.removeAll { $0 === source }
                self?.scheduleManagedPreferencesChanged()
                self?.watchManagedPreferencesPlist(at: path)
            }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        managedPreferencesWatchSources.append(source)
    }

    // Cancels any pending timer first, so a burst of file events collapses into
    // one reload 5s after the last one.
    private func scheduleManagedPreferencesChanged() {
        managedPreferencesChangeDebounceTimer?.invalidate()
        managedPreferencesChangeDebounceTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.reloadManagedPreferences() }
        }
    }

    // For when the plist doesn't exist yet: watch the parent directory so we
    // notice a profile being installed. Most events there are unrelated.
    private func watchManagedPreferencesDirectoryForCreation(of path: String) {
        let directory = (path as NSString).deletingLastPathComponent
        let fd = open(directory, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write], queue: .main)
        source.setEventHandler { [weak self, weak source] in
            guard FileManager.default.fileExists(atPath: path) else { return }
            Task { @MainActor in
                // Several events can queue up during an install. Only the first re-arms.
                guard let source, !source.isCancelled else { return }
                source.cancel()
                self?.managedPreferencesWatchSources.removeAll { $0 === source }
                // A fresh install counts as a change like any edit does.
                self?.scheduleManagedPreferencesChanged()
                self?.watchManagedPreferencesPlist(at: path)
            }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        managedPreferencesWatchSources.append(source)
    }

    // MARK: - Plist watching

    // Re-arms on every event. The file is replaced rather than written in
    // place, so the old descriptor goes deaf.
    private func startWatchingPlist() {
        fileWatchSource?.cancel()
        fileWatchSource = nil

        let fd = open(Self.plistPath, O_EVTONLY)
        guard fd >= 0 else {
            // Doesn't exist yet, watch the directory instead.
            watchDirectoryForPlistCreation()
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.reload()
                self?.startWatchingPlist()
            }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        fileWatchSource = source
    }

    // Waits for softwareupdated to create the plist.
    private func watchDirectoryForPlistCreation() {
        let directory = (Self.plistPath as NSString).deletingLastPathComponent
        let fd = open(directory, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write], queue: .main)
        source.setEventHandler { [weak self] in
            guard FileManager.default.fileExists(atPath: Self.plistPath) else { return }
            Task { @MainActor in
                self?.reload()
                self?.startWatchingPlist()
            }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        fileWatchSource = source
    }

    // MARK: - Software update plist watching

    // Same re-arm-on-every-event approach as startWatchingPlist(), but for
    // Apple's catalog.
    private func startWatchingSoftwareUpdatePlist() {
        softwareUpdatePlistWatchSource?.cancel()
        softwareUpdatePlistWatchSource = nil

        let fd = open(Self.softwareUpdatePlistPath, O_EVTONLY)
        guard fd >= 0 else {
            watchDirectoryForSoftwareUpdatePlistCreation()
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.reloadRecommendedUpdate()
                self?.startWatchingSoftwareUpdatePlist()
            }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        softwareUpdatePlistWatchSource = source
    }

    private func watchDirectoryForSoftwareUpdatePlistCreation() {
        let directory = (Self.softwareUpdatePlistPath as NSString).deletingLastPathComponent
        let fd = open(directory, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write], queue: .main)
        source.setEventHandler { [weak self] in
            guard FileManager.default.fileExists(atPath: Self.softwareUpdatePlistPath) else { return }
            Task { @MainActor in
                self?.reloadRecommendedUpdate()
                self?.startWatchingSoftwareUpdatePlist()
            }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        softwareUpdatePlistWatchSource = source
    }

    // MARK: - Display computation

    private func recomputeDisplay() {
        defer { scheduleDisplayTimer() }
        countdownSeconds = nil

        guard let target = targetDate else {
            setDisplay(status: .none, countdownText: nil)
            return
        }

        // Running version already at or above the target: the update no longer
        // applies, so show nothing.
        if let targetVersion = targetOSVersion,
           Self.compareVersions(Self.currentOSVersionString(), targetVersion) >= 0 {
            setDisplay(status: .none, countdownText: nil)
            return
        }

        let remaining = target.timeIntervalSinceNow

        if remaining <= 0 {
            setDisplay(status: .expired, countdownText: nil)
            return
        }

        let text: String
        if remaining <= Self.urgentThreshold {
            let totalSeconds = Int(remaining)
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60
            text = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            countdownSeconds = totalSeconds
        } else {
            // Days remaining, rounded up, wrapped in the configured prefix and
            // suffix: "4d", "4j", "D-4". Either can be empty.
            let days = Self.daysRemaining(remaining)
            text = "\(localizedDayPrefix)\(days)\(localizedDaySuffix)"
        }

        setDisplay(status: .scheduled, countdownText: text)
    }

    // Shared by the menu bar and $COUNTDOWN so they always agree.
    private static func daysRemaining(_ remaining: TimeInterval) -> Int {
        Int(ceil(remaining / (24 * 60 * 60)))
    }

    // @Published fires on every assignment, even with the same value. Only
    // assign on change so subscribers aren't woken on every tick.
    private func setDisplay(status newStatus: Status, countdownText newText: String?) {
        if status != newStatus { status = newStatus }
        if countdownText != newText { countdownText = newText }
    }

    // Every second inside the urgent window so HH:mm:ss ticks live, every minute
    // otherwise.
    private func scheduleDisplayTimer() {
        displayTimer?.invalidate()
        let remaining = targetDate?.timeIntervalSinceNow ?? -1
        let isUrgent = remaining > 0 && remaining <= Self.urgentThreshold
        // Lands just past the next whole second, so the digits don't drift or skip.
        let interval: TimeInterval = isUrgent ? remaining - floor(remaining) + 0.01 : 60
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.recomputeDisplay() }
        }
        if isUrgent { timer.tolerance = 0 }
        displayTimer = timer
    }

    // MARK: - Date formatting

    // Two formatters so date and time can be joined with ", " rather than the
    // locale's own connector word ("at").
    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    private static let timeOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    // Locale.autoupdatingCurrent is clamped to the languages this app
    // declares, so it ignores the system language. preferredLanguages isn't.
    private static var preferredLocale: Locale {
        Locale.preferredLanguages.first.map(Locale.init(identifier:)) ?? .autoupdatingCurrent
    }

    static func formattedDateTime(_ date: Date) -> String {
        let locale = preferredLocale
        dateOnlyFormatter.locale = locale
        timeOnlyFormatter.locale = locale
        return "\(dateOnlyFormatter.string(from: date)), \(timeOnlyFormatter.string(from: date))"
    }

    // MARK: - Version helpers

    static func currentOSVersionString() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    /// -1 if lhs < rhs, 0 if equal, 1 if lhs > rhs.
    static func compareVersions(_ lhs: String, _ rhs: String) -> Int {
        let l = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let r = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(l.count, r.count)
        for i in 0..<count {
            let a = i < l.count ? l[i] : 0
            let b = i < r.count ? r[i] : 0
            if a != b { return a < b ? -1 : 1 }
        }
        return 0
    }

    // MARK: - Plist parsing

    struct ScheduledUpdate {
        let date: Date
        let osVersion: String?
    }

    static func readScheduledUpdate() -> ScheduledUpdate? {
        guard let data = FileManager.default.contents(atPath: plistPath) else {
            return nil
        }

        guard let root = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: nil
        ) as? [String: Any] else {
            return nil
        }

        // Collected by key name from anywhere in the plist, because the real
        // structure is nested several levels down under dynamic keys.
        var candidates: [ScheduledUpdate] = []
        collectTargets(from: root, into: &candidates)

        // A target the running OS already meets can't apply anymore, so it
        // shouldn't win over one that still does.
        let current = currentOSVersionString()
        candidates.removeAll { candidate in
            guard let version = candidate.osVersion else { return false }
            return compareVersions(current, version) >= 0
        }

        // Soonest upcoming. If they're all past, take the latest one: that's
        // the deadline that just expired, not some old leftover.
        let now = Date()
        let upcoming = candidates.filter { $0.date >= now }.sorted { $0.date < $1.date }
        if let next = upcoming.first {
            return next
        }
        return candidates.max { $0.date < $1.date }
    }

    private static func collectTargets(from object: Any, into result: inout [ScheduledUpdate]) {
        if let dict = object as? [String: Any] {
            if let raw = dict["TargetLocalDateTime"] as? String,
               let date = parseLocalDateTime(raw) {
                let version = dict["TargetOSVersion"] as? String
                result.append(ScheduledUpdate(date: date, osVersion: version))
            }
            // softwareupdated keeps rejected declarations around under this
            // key. They're never enforced, so skip them.
            for (key, value) in dict where key != "invalidDeclarations" {
                collectTargets(from: value, into: &result)
            }
        } else if let array = object as? [Any] {
            for value in array {
                collectTargets(from: value, into: &result)
            }
        }
    }

    /// "yyyy-MM-dd'T'HH:mm:ss", read in the local timezone.
    private static func parseLocalDateTime(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = formatter.date(from: string) {
            return date
        }
        // Some entries include a timezone offset.
        let iso = ISO8601DateFormatter()
        return iso.date(from: string)
    }

    /// The highest-versioned "macOS" entry in RecommendedUpdates, with its
    /// identifier.
    static func readRecommendedMacOSUpdate() -> (version: String, identifier: String)? {
        guard let data = FileManager.default.contents(atPath: softwareUpdatePlistPath) else {
            return nil
        }
        guard let root = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: nil
        ) as? [String: Any] else {
            return nil
        }
        guard let updates = root["RecommendedUpdates"] as? [[String: Any]] else {
            return nil
        }

        var best: (version: String, identifier: String)?
        for update in updates {
            guard let name = update["Display Name"] as? String, name.hasPrefix("macOS"),
                  let version = update["Display Version"] as? String else { continue }
            let identifier = update["Identifier"] as? String ?? ""
            if best == nil || compareVersions(version, best!.version) > 0 {
                best = (version, identifier)
            }
        }
        return best
    }

    // "MSU_UPDATE_25F84_patch_26.5.2_major" → "25F84", or the raw identifier if
    // it doesn't match that shape.
    private static func buildString(fromIdentifier identifier: String) -> String {
        let parts = identifier.split(separator: "_")
        guard parts.count > 2 else { return identifier }
        return String(parts[2])
    }
}
