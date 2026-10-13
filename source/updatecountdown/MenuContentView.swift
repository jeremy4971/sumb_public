//
//  MenuContentView.swift
//  updatecountdown
//
//  What you see when clicking the menu bar icon: the update deadline, the
//  restart warning, the Scheduler and Update Now buttons.
//

import SwiftUI

struct MenuContentView: View {
    @ObservedObject var monitor: UpdateMonitor
    let onUpdateNow: () -> Void
    let onScheduler: () -> Void

    var body: some View {
        PopoverStack(spacing: 10) {
            Text(monitor.popoverTitle)
                .font(.headline)

            Divider()

            if monitor.status == .none, monitor.recommendedOSVersion == nil {
                HStack(spacing: 10) {
                    Image("checkmark-su")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(monitor.popoverUpToDateMessage)
                            .fontWeight(.medium)
                        Text("macOS \(UpdateMonitor.currentOSVersionString())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if monitor.status != .none, let target = monitor.targetDate {
                HStack(spacing: 10) {
                    Image(updateImageName(for: monitor.targetOSVersion))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        if let version = monitor.targetOSVersion {
                            Text("macOS \(version)")
                                .fontWeight(.medium)
                        }
                        Text("⚠️ \(UpdateMonitor.formattedDateTime(target))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }

                actionButtons

                if !monitor.popoverFooter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Divider()

                    Text(restartWarningAttributedString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .layoutValue(key: WrapsToWidth.self, value: true)
                }
            } else if let version = monitor.recommendedOSVersion, let bundle = monitor.recommendedUpdateBuild {
                // Apple's catalog has something newer, but no MDM deadline.
                // No restart warning here since nothing is being enforced.
                HStack(spacing: 10) {
                    Image(updateImageName(for: version))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("macOS \(version)")
                            .fontWeight(.medium)
                        Text("Build \(bundle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }

                actionButtons
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Restart warning

    // Parsed as inline Markdown so admins can put a [text](url) link in the
    // string. Falls back to the raw text if it doesn't parse.
    private var restartWarningAttributedString: AttributedString {
        let text = monitor.popoverFooter
        return (try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }

    // MARK: - Artwork

    private func updateImageName(for version: String?) -> String {
        switch version?.split(separator: ".").first.flatMap({ Int($0) }) {
        case 15: "macos15-update"
        case 26: "macos26-update"
        case 27: "macos27-update"
        default: "macos-logo2"
        }
    }

    // MARK: - Actions

    // Under the version block, the update button fills the row.
    private var actionButtons: some View {
        HStack(spacing: 8) {
            schedulerButton
            updateButton
        }
    }

    // Opens the user's Scheduler. Hidden when popup reminders are off.
    @ViewBuilder
    private var schedulerButton: some View {
        if monitor.popupEnabled {
            Button(action: onScheduler) {
                Image(systemName: "calendar")
            }
            .accessibilityLabel("Scheduler")
        }
    }

    private var updateButton: some View {
        Button {
            openSoftwareUpdate()
        } label: {
            Text(monitor.popoverUpdateButton)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
    }

    private func openSoftwareUpdate() {
        NSWorkspace.shared.open(UpdateMonitor.softwareUpdateURL)
        onUpdateNow()
    }
}

// MARK: - Layout

// VStack sized by its content, except views marked WrapsToWidth that wrap
// to that width. A plain Text would stretch the popover to its one-line width.
private struct PopoverStack: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = width(for: proposal, subviews: subviews)
        let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
        let gaps = spacing * CGFloat(max(subviews.count - 1, 0))
        return CGSize(width: width, height: heights.reduce(0, +) + gaps)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for subview in subviews {
            let height = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
            subview.place(at: CGPoint(x: bounds.minX, y: y),
                          proposal: ProposedViewSize(width: bounds.width, height: height))
            y += height + spacing
        }
    }

    private func width(for proposal: ProposedViewSize, subviews: Subviews) -> CGFloat {
        if let width = proposal.width, width.isFinite { return width }
        return subviews
            .filter { !$0[WrapsToWidth.self] }
            .map { $0.sizeThatFits(.unspecified).width }
            .max() ?? 0
    }
}

private nonisolated struct WrapsToWidth: LayoutValueKey {
    static let defaultValue = false
}
