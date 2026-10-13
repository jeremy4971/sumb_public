//
//  OptionsView.swift
//  updatecountdown
//
//  The Settings window content, with its General, Menubar, Notification,
//  Popup and About tabs.
//

import SwiftUI

struct GeneralOptionsView: View {
    @ObservedObject var monitor: UpdateMonitor

    var body: some View {
        VStack(spacing: 0) {
            generalForm
            Divider()
            ManagedPreferencesFooterView(hasManagedPreferences: monitor.hasManagedPreferences)
        }
        .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // The hardware doesn't change mid-run, so check once.
    private static let hasNotch = NotchDisplay.hasNotch()

    private var generalForm: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Ignore Apple's update channel", isOn: $monitor.ignoreAppleUpdateChannel)
                        .disabled(monitor.isManaged(UpdateMonitor.Keys.ignoreAppleUpdateChannel))
                    Text("Only DDMs will determine if the Mac is up to date.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Hide menu bar icon when up-to-date", isOn: $monitor.hideIconWhenUpToDate)
                        .disabled(monitor.isManaged(UpdateMonitor.Keys.hideIconWhenUpToDate))
                    Text("Launch SUMB.app to re-open settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Show Dock icon", isOn: $monitor.showDockIcon)
                        .disabled(monitor.isManaged(UpdateMonitor.Keys.showDockIcon))
                    Text("Visible only when there is an update available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Hide notch", isOn: $monitor.hideNotch)
                        .disabled(!Self.hasNotch)
                    Text("Prevent the notch from hiding your menu bar items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Hide settings", isOn: $monitor.hideSettings)
                        .disabled(monitor.isManaged(UpdateMonitor.Keys.hideSettings))
                    Text("Option-right-clicking the menu bar icon will reveal the settings menu.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Not tied to the notification toggle, the popup plays it too.
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent("Alert sound") {
                        HStack {
                            // Previews the sound through a real notification, even when a profile locks it.
                            Button {
                                monitor.postReminderNotification()
                            } label: {
                                Image(systemName: "play.fill")
                            }
                            .accessibilityLabel("Send Test Notification")

                            Picker("", selection: $monitor.notificationSound) {
                                Text("Default").tag("")
                                Divider()
                                ForEach(UpdateMonitor.availableSystemSounds, id: \.self) { file in
                                    Text((file as NSString).deletingPathExtension).tag(file)
                                }
                            }
                            .labelsHidden()
                            .disabled(monitor.isManaged(UpdateMonitor.Keys.notificationSound))
                        }
                    }
                    Text("Played with the notification and the popup.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Demo mode", isOn: $monitor.demoMode)
                        .disabled(monitor.isManaged(UpdateMonitor.Keys.demoMode))
                    Text("Your Mac won't actually update or restart during the demo.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                DatePicker(
                    "Deadline",
                    selection: $monitor.demoDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .disabled(!monitor.demoMode || monitor.isManaged(UpdateMonitor.Keys.demoDate))
                .opacity(monitor.demoMode ? 1 : 0.4)

                LabeledContent("Target OS version") {
                    TextField("", text: $monitor.demoOSVersion)
                        .labelsHidden()
                        .frame(width: 100)
                }
                .disabled(!monitor.demoMode || monitor.isManaged(UpdateMonitor.Keys.demoOSVersion))
                .opacity(monitor.demoMode ? 1 : 0.4)
            }

            Section {
                Button("Copy settings to clipboard") {
                    guard let xml = monitor.settingsPropertyListXML() else { return }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(xml, forType: .string)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct MenubarOptionsView: View {
    @ObservedObject var monitor: UpdateMonitor

    var body: some View {
        VStack(spacing: 0) {
            form
            Divider()
            ManagedPreferencesFooterView(hasManagedPreferences: monitor.hasManagedPreferences)
        }
        .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var form: some View {
        Form {
            Section("Popover") {
                TextField("Title", text: $monitor.popoverTitle)
                    .disabled(monitor.isManaged(UpdateMonitor.Keys.popoverTitle))

                TextField("Update button", text: $monitor.popoverUpdateButton)
                    .disabled(monitor.isManaged(UpdateMonitor.Keys.popoverUpdateButton))

                MultilineField(label: "Restart warning", text: $monitor.popoverFooter,
                               lines: 3, caption: "Link: [text](https://example.com)")
                    .disabled(monitor.isManaged(UpdateMonitor.Keys.popoverFooter))

                TextField("Up-to-date message", text: $monitor.popoverUpToDateMessage)
                    .disabled(monitor.isManaged(UpdateMonitor.Keys.popoverUpToDateMessage))
            }

            Section("Menubar") {
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent("Dot blinking") {
                        HStack(alignment: .firstTextBaseline) {
                            TextField("", value: $monitor.menubarDotBlinkingThresholdDays, format: .number)
                                .labelsHidden()
                                .frame(width: 50)
                            Text("days before update")
                        }
                    }
                    .disabled(monitor.isManaged(UpdateMonitor.Keys.menubarDotBlinkingThresholdDays))
                    Text("Blink the red dot as the deadline gets close. Set to 0 to turn it off.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("Updating text", text: $monitor.menubarPreparingMessage)
                    .disabled(monitor.isManaged(UpdateMonitor.Keys.menubarPreparingMessage))

                // Same labelsHidden() fix as on the Notification tab.
                LabeledContent("Day prefix") {
                    TextField("", text: $monitor.menubarPrefix)
                        .labelsHidden()
                        .frame(width: 50)
                }
                .disabled(monitor.isManaged(UpdateMonitor.Keys.menubarPrefix))

                LabeledContent("Day suffix") {
                    TextField("", text: $monitor.menubarSuffix)
                        .labelsHidden()
                        .frame(width: 50)
                }
                .disabled(monitor.isManaged(UpdateMonitor.Keys.menubarSuffix))
            }
        }
        .formStyle(.grouped)
    }
}

struct NotificationOptionsView: View {
    @ObservedObject var monitor: UpdateMonitor

    var body: some View {
        VStack(spacing: 0) {
            form
            Divider()
            ManagedPreferencesFooterView(hasManagedPreferences: monitor.hasManagedPreferences)
        }
        .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var form: some View {
        Form {
            Section {
                // Plain HStack so the label stays centered with the switch.
                HStack {
                    Text("Enable notification")
                    Spacer()
                    Button("Send Test Notification") { monitor.postReminderNotification() }
                    Button("Settings") { openNotificationSettings() }
                    // Nested in an HStack, the Form no longer restyles it,
                    // so it falls back to a checkbox without this.
                    Toggle("Enable notification", isOn: $monitor.notificationsEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(monitor.isManaged(UpdateMonitor.Keys.notificationsEnabled))
                }
            }

            Section {
                // macOS 27 leaves room for an empty label, hence labelsHidden().
                // Baseline alignment keeps the unit level with the number.
                LabeledContent("Notification starting") {
                    HStack(alignment: .firstTextBaseline) {
                        TextField("", value: $monitor.notificationThresholdDays, format: .number)
                            .labelsHidden()
                            .frame(width: 50)
                        Text("days before update")
                    }
                }
                .disabled(!monitor.notificationsEnabled || monitor.isManaged(UpdateMonitor.Keys.notificationThresholdDays))
                .opacity(monitor.notificationsEnabled ? 1 : 0.4)

                LabeledContent("Every") {
                    HStack(alignment: .firstTextBaseline) {
                        TextField("", value: $monitor.notificationIntervalMinutes, format: .number)
                            .labelsHidden()
                            .frame(width: 50)
                        Text("minutes")
                    }
                }
                .disabled(!monitor.notificationsEnabled || monitor.isManaged(UpdateMonitor.Keys.notificationIntervalMinutes))
                .opacity(monitor.notificationsEnabled ? 1 : 0.4)

                TextField("Title", text: $monitor.notificationTitle)
                    .disabled(!monitor.notificationsEnabled || monitor.isManaged(UpdateMonitor.Keys.notificationTitle))
                    .opacity(monitor.notificationsEnabled ? 1 : 0.4)

                MultilineField(label: "Body", text: $monitor.notificationBody,
                               lines: 3, caption: "Variables: $VERSION · $DATE · $COUNTDOWN")
                    .disabled(!monitor.notificationsEnabled || monitor.isManaged(UpdateMonitor.Keys.notificationBody))
                    .opacity(monitor.notificationsEnabled ? 1 : 0.4)
            }
        }
        .formStyle(.grouped)
    }

    // Opens the Notifications pane with SUMB already selected. The id query
    // takes the app's bundle identifier.
    private func openNotificationSettings() {
        let identifier = Bundle.main.bundleIdentifier ?? "fr.jeremyb.sumb"
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(identifier)") else { return }
        NSWorkspace.shared.open(url)
    }
}

struct PopupOptionsView: View {
    @ObservedObject var monitor: UpdateMonitor
    let onOpenUserSchedule: () -> Void
    let onSendTestPopup: () -> Void
    @StateObject private var draft: SchedulerDraft

    init(monitor: UpdateMonitor, onOpenUserSchedule: @escaping () -> Void,
         onSendTestPopup: @escaping () -> Void) {
        self.monitor = monitor
        self.onOpenUserSchedule = onOpenUserSchedule
        self.onSendTestPopup = onSendTestPopup
        _draft = StateObject(wrappedValue: SchedulerDraft(hours: monitor.suggestedSchedule))
    }

    var body: some View {
        VStack(spacing: 0) {
            schedulerForm
            Divider()
            ManagedPreferencesFooterView(hasManagedPreferences: monitor.hasManagedPreferences)
        }
        .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var schedulerForm: some View {
        Form {
            Section {
                // Same row layout as on the Notification tab.
                HStack {
                    HStack(spacing: 4) {
                        Text("Enable popup reminders")
                        InfoButton(text: "One popup per allowed hour. Users can override the times in their own scheduler. Popups currently don't honor Focus Mode. However, they wait during virtual meetings (mic or camera in use), full screen Keynote, PowerPoint or Canva presentations, and full screen videos in QuickTime, VLC or IINA. Edge case: Google Slides outside of a virtual meeting is not supported.")
                    }
                    Spacer()
                    Button("Send Test Popup") { onSendTestPopup() }
                    Toggle("Enable popup reminders", isOn: $monitor.popupEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(monitor.isManaged(UpdateMonitor.Keys.popupEnabled))
                }
            }

            Section {
                // Same layout as Notification starting.
                LabeledContent("Popup reminder starting") {
                    HStack(alignment: .firstTextBaseline) {
                        TextField("", value: $monitor.popupThresholdDays, format: .number)
                            .labelsHidden()
                            .frame(width: 50)
                        Text("days before update")
                    }
                }
                .disabled(!monitor.popupEnabled || monitor.isManaged(UpdateMonitor.Keys.popupThresholdDays))
                .opacity(monitor.popupEnabled ? 1 : 0.4)

                TextField("Title", text: $monitor.popupTitle)
                    .disabled(!monitor.popupEnabled || monitor.isManaged(UpdateMonitor.Keys.popupTitle))
                    .opacity(monitor.popupEnabled ? 1 : 0.4)

                MultilineField(label: "Message", text: $monitor.popupBody,
                               lines: 3, caption: "Variables: $VERSION · $DATE · $COUNTDOWN")
                    .disabled(!monitor.popupEnabled || monitor.isManaged(UpdateMonitor.Keys.popupBody))
                    .opacity(monitor.popupEnabled ? 1 : 0.4)

                TextField("Reschedule button", text: $monitor.popupRescheduleButton)
                    .disabled(!monitor.popupEnabled || monitor.isManaged(UpdateMonitor.Keys.popupRescheduleButton))
                    .opacity(monitor.popupEnabled ? 1 : 0.4)

                TextField("Update button", text: $monitor.popupUpdateButton)
                    .disabled(!monitor.popupEnabled || monitor.isManaged(UpdateMonitor.Keys.popupUpdateButton))
                    .opacity(monitor.popupEnabled ? 1 : 0.4)
            }

            Section("Popup scheduler") {
                MultilineField(label: "Help text", text: $monitor.popupSchedulerHelp, lines: 3)
                    .disabled(!monitor.popupEnabled || monitor.isManaged(UpdateMonitor.Keys.popupSchedulerHelp))
                    .opacity(monitor.popupEnabled ? 1 : 0.4)
            }

            Section {
                // Saved after each change, like any other setting.
                SchedulerGrid(draft: draft, isEditable: !isScheduleManaged, onColor: .green,
                              onOpenUserSchedule: onOpenUserSchedule, onCommit: {
                    if monitor.suggestedSchedule != draft.hours {
                        monitor.suggestedSchedule = draft.hours
                    }
                })
                .frame(maxWidth: .infinity)
                .disabled(!monitor.popupEnabled)
                .opacity(monitor.popupEnabled ? 1 : 0.4)
            } header: {
                Text("Admin suggested times")
            }
        }
        .formStyle(.grouped)
        // Follows a profile change.
        .onReceive(monitor.$suggestedSchedule) { hours in
            if draft.hours != hours { draft.hours = hours }
        }
    }

    // One locked day locks the whole grid.
    private var isScheduleManaged: Bool {
        UpdateMonitor.Keys.scheduleDays.contains(where: monitor.isManaged)
    }
}

// Small "i" button that shows a longer explanation in a popover.
private struct InfoButton: View {
    let text: String
    @State private var isShown = false

    var body: some View {
        Button { isShown.toggle() } label: {
            Image(systemName: "info.circle")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("More Info")
        .popover(isPresented: $isShown, arrowEdge: .bottom) {
            Text(text)
                .font(.callout)
                .frame(width: 320, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding()
        }
    }
}

// Shared by the Notification, Menubar and Popup tabs. Not LabeledContent: side-by-side
// or stacked varies by macOS version, a VStack row in a Form is full-width everywhere.
private struct MultilineField: View {
    let label: String
    @Binding var text: String
    let lines: Int
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)

            TextEditor(text: $text)
                .font(.body)
                // Form's value column would right-align it otherwise.
                .multilineTextAlignment(.leading)
                .scrollContentBackground(.hidden)
                .padding(Self.editorPadding)
                .frame(maxWidth: .infinity)
                .frame(height: Self.editorHeight(lines: lines))
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color(nsColor: .separatorColor))
                )

            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let editorPadding: CGFloat = 4

    // Measured from the font metrics so it still fits if the text size changes.
    private static func editorHeight(lines: Int) -> CGFloat {
        let font = NSFont.preferredFont(forTextStyle: .body)
        let lineHeight = NSLayoutManager().defaultLineHeight(for: font)
        return lineHeight * CGFloat(lines) + editorPadding * 2
    }
}

struct AboutOptionsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("Software Update Menu Bar")
                .font(.headline)
            Text("Version \(Self.appVersion) (\(Self.buildNumber))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
    }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    private static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }
}

private struct ManagedPreferencesFooterView: View {
    let hasManagedPreferences: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: hasManagedPreferences ? "checkmark.seal.fill" : "seal")
                .foregroundStyle(.secondary)
            Text(hasManagedPreferences
                 ? "These settings have been configured by a profile."
                 : "No managed preferences detected")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
