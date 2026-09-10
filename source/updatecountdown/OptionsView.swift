//
//  OptionsView.swift
//  updatecountdown
//
//  Content for the Options window, opened from the status item's right-click
//  menu. One view per tab.
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
                    Toggle("Hide icon when up-to-date", isOn: $monitor.hideIconWhenUpToDate)
                        .disabled(monitor.isManaged(UpdateMonitor.Keys.hideIconWhenUpToDate))
                    Text("Launch SUMB.app to re-open settings.")
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
            }

            Section {
                Toggle("Enable notification", isOn: $monitor.notificationsEnabled)
                    .disabled(monitor.isManaged(UpdateMonitor.Keys.notificationsEnabled))

                LabeledContent("Remind starting") {
                    HStack {
                        TextField("", value: $monitor.reminderThresholdDays, format: .number)
                            .frame(width: 50)
                        Text("days before update")
                    }
                }
                .disabled(!monitor.notificationsEnabled || monitor.isManaged(UpdateMonitor.Keys.reminderThresholdDays))
                .opacity(monitor.notificationsEnabled ? 1 : 0.4)

                LabeledContent("Every") {
                    HStack {
                        TextField("", value: $monitor.reminderIntervalMinutes, format: .number)
                            .frame(width: 50)
                        Text("minutes")
                    }
                }
                .disabled(!monitor.notificationsEnabled || monitor.isManaged(UpdateMonitor.Keys.reminderIntervalMinutes))
                .opacity(monitor.notificationsEnabled ? 1 : 0.4)
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
                        .frame(width: 100)
                }
                .disabled(!monitor.demoMode || monitor.isManaged(UpdateMonitor.Keys.demoOSVersion))
                .opacity(monitor.demoMode ? 1 : 0.4)

                Button("Send Test Notification") {
                    monitor.postReminderNotification()
                }
                .disabled(!monitor.demoMode)
                .opacity(monitor.demoMode ? 1 : 0.4)
            }
        }
        .formStyle(.grouped)
    }

}

struct LocalizationOptionsView: View {
    @ObservedObject var monitor: UpdateMonitor

    var body: some View {
        VStack(spacing: 0) {
            localizationForm
            Divider()
            ManagedPreferencesFooterView(hasManagedPreferences: monitor.hasManagedPreferences)
        }
        .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var localizationForm: some View {
        Form {
            Section("Popover") {
                TextField("Title", text: $monitor.localizedPopoverTitle)
                    .disabled(monitor.isManaged(UpdateMonitor.Keys.localizedPopoverTitle))

                TextField("Update button", text: $monitor.localizedUpdateNowButton)
                    .disabled(monitor.isManaged(UpdateMonitor.Keys.localizedUpdateNowButton))

                multilineField("Restart warning", text: $monitor.localizedRestartWarning,
                                lines: 3, caption: "Link : [text](https://example.com)")
                    .disabled(monitor.isManaged(UpdateMonitor.Keys.localizedRestartWarning))

                TextField("Up-to-date message", text: $monitor.localizedUpToDateMessage)
                    .disabled(monitor.isManaged(UpdateMonitor.Keys.localizedUpToDateMessage))
            }

            Section("Notification") {
                TextField("Title", text: $monitor.reminderNotificationTitle)
                    .disabled(monitor.isManaged(UpdateMonitor.Keys.reminderNotificationTitle))

                multilineField("Body", text: $monitor.reminderNotificationBody,
                                lines: 3, caption: "Variables : $VERSION · $DATE")
                    .disabled(monitor.isManaged(UpdateMonitor.Keys.reminderNotificationBody))
            }

            Section("Menubar") {
                TextField("Updating text", text: $monitor.localizedUpdatingMenuBar)
                    .disabled(monitor.isManaged(UpdateMonitor.Keys.localizedUpdatingMenuBar))

                LabeledContent("Day prefix") {
                    TextField("", text: $monitor.localizedDayPrefix)
                        .frame(width: 50)
                }
                .disabled(monitor.isManaged(UpdateMonitor.Keys.localizedDayPrefix))

                LabeledContent("Day suffix") {
                    TextField("", text: $monitor.localizedDaySuffix)
                        .frame(width: 50)
                }
                .disabled(monitor.isManaged(UpdateMonitor.Keys.localizedDaySuffix))
            }
        }
        .formStyle(.grouped)
    }

    // Not LabeledContent. Whether it renders side-by-side or stacked is an
    // adaptive heuristic that changed between macOS versions — the same build
    // was full-width on one Mac and clipped on another. A VStack row in a Form
    // is full-width everywhere.
    @ViewBuilder
    private func multilineField(_ label: String, text: Binding<String>,
                                lines: Int, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)

            TextEditor(text: text)
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

            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let editorPadding: CGFloat = 4

    // Measured from the real font metrics instead of a fixed point value, so it
    // still fits if the system text size changes.
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
                 ? "These settings has been configured by a profile."
                 : "No managed preferences detected")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
