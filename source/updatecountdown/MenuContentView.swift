//
//  MenuContentView.swift
//  updatecountdown
//
//  What you see when clicking the menu bar icon: the update deadline, the
//  restart warning, the Scheduler, Update Now and Check for Updates buttons.
//

import SwiftUI

struct MenuContentView: View {
    @ObservedObject var monitor: UpdateMonitor
    let onUpdateNow: () -> Void
    let onScheduler: () -> Void

    var body: some View {
        PopoverStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(monitor.popoverTitle)
                    .font(.headline)
                progressLineIfAny
            }

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
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }

                softwareUpdateButton(BuiltInStrings.current.checkForUpdates)
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
                            .fontWeight(.medium)
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
            } else if let version = monitor.recommendedOSVersion {
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
                        if let build = monitor.recommendedUpdateBuild {
                            Text("Build \(build)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                }

                softwareUpdateButton(monitor.popoverUpdateButton)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Update progress

    @ViewBuilder private var progressLineIfAny: some View {
        if let progress = monitor.updateProgress {
            progressLine(for: progress)
        }
    }

    private func progressLine(for progress: UpdateMonitor.UpdateProgress) -> some View {
        Text(lineText(progress))
            .font(.caption)
            //.fontWeight(.medium)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    // "Pending download · Low disk space"
    private func lineText(_ progress: UpdateMonitor.UpdateProgress) -> String {
        let text = progressText(for: progress)
        return monitor.isLowDiskSpace ? "\(text) · \(BuiltInStrings.current.lowDiskSpace)" : text
    }

    private func progressText(for progress: UpdateMonitor.UpdateProgress) -> String {
        switch progress {
        case .pendingDownload: BuiltInStrings.current.pending
        case .downloading: BuiltInStrings.current.downloading
        case .preparing: BuiltInStrings.current.preparing
        case .readyToInstall: BuiltInStrings.current.ready
        }
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

    private var actionButtons: some View {
        HStack(spacing: 8) {
            schedulerButton
            softwareUpdateButton(monitor.popoverUpdateButton)
        }
    }

    @ViewBuilder
    private var schedulerButton: some View {
        if monitor.popupEnabled {
            Button(action: onScheduler) {
                Image(systemName: "calendar")
            }
            .accessibilityLabel("Scheduler")
        }
    }

    private func softwareUpdateButton(_ title: String) -> some View {
        Button {
            openSoftwareUpdate()
        } label: {
            Text(title)
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

// VStack sized by its content. Views marked WrapsToWidth can widen it up to 270pt,
// then wrap and the popover shrinks to their widest line.
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
        let idealWidths = { (wraps: Bool) in
            subviews
                .filter { $0[WrapsToWidth.self] == wraps }
                .map { $0.sizeThatFits(.unspecified).width }
                .max() ?? 0
        }
        let base = idealWidths(false)
        let wrapIdeal = idealWidths(true)
        let capped = max(base, min(wrapIdeal, Self.maxWrapWidth))
        guard wrapIdeal > capped else { return capped }

        // Wrapped lines rarely fill the cap, so shrink to the widest one.
        let wrapping = subviews.filter { $0[WrapsToWidth.self] }
        let sizes = { (width: CGFloat) in
            wrapping.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
        }
        let atCap = sizes(capped)
        let shrunk = max(base, atCap.map(\.width).max() ?? 0)
        let fewerOrSameLines = zip(sizes(shrunk), atCap).allSatisfy { $0.height <= $1.height }
        return fewerOrSameLines ? shrunk : capped
    }

    private static let maxWrapWidth: CGFloat = 270
}

private nonisolated struct WrapsToWidth: LayoutValueKey {
    static let defaultValue = false
}
