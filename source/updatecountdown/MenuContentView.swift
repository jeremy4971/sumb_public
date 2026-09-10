//
//  MenuContentView.swift
//  updatecountdown
//
//  The dropdown shown when the menu bar item is clicked. It's a custom
//  NSMenuItem view rather than an NSPopover, so it sits flush under the
//  status item with no gap or show animation.
//

import SwiftUI

struct MenuContentView: View {
    @ObservedObject var monitor: UpdateMonitor
    var onUpdateNow: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(monitor.localizedPopoverTitle)
                .font(.headline)

            Divider()

            if monitor.status == .none, monitor.recommendedOSVersion == nil {
                HStack(spacing: 10) {
                    Image("checkmark-su")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(monitor.localizedUpToDateMessage)
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

                    Spacer()

                    Button(monitor.localizedUpdateNowButton) {
                        openSoftwareUpdate()
                    }
                }

                Divider()

                Text(restartWarningAttributedString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
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

                    Spacer()

                    Button(monitor.localizedUpdateNowButton) {
                        openSoftwareUpdate()
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        // 280 is the compact "up to date" width. Longer dates or custom MDM
        // strings grow the popover rather than getting truncated.
        .frame(minWidth: 280, alignment: .leading)
    }

    // MARK: - Restart warning

    // Parsed as inline Markdown so admins can put a [text](url) link in the
    // string. Falls back to the raw text if it doesn't parse.
    private var restartWarningAttributedString: AttributedString {
        let wrapped = Self.wordWrapped(monitor.localizedRestartWarning, maxLineLength: 90)
        return (try? AttributedString(
            markdown: wrapped,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(wrapped)
    }

    // Greedy word wrap. A whole [text](url) counts as one unbreakable token so
    // we never split inside link syntax, and it's measured by its visible label
    // length so a long URL doesn't push it onto its own line.
    private static func wordWrapped(_ text: String, maxLineLength: Int) -> String {
        var words: [(token: Substring, weight: Int)] = []
        var i = text.startIndex
        while i < text.endIndex {
            while i < text.endIndex, text[i] == " " { i = text.index(after: i) }
            guard i < text.endIndex else { break }
            var end = text[i...].firstIndex(of: " ") ?? text.endIndex
            var weight = text.distance(from: i, to: end)
            if text[i] == "[",
               let closeBracket = text[i...].firstIndex(of: "]"),
               text.index(after: closeBracket) < text.endIndex,
               text[text.index(after: closeBracket)] == "(",
               let closeParen = text[closeBracket...].firstIndex(of: ")") {
                end = text.index(after: closeParen)
                weight = text.distance(from: text.index(after: i), to: closeBracket)
            }
            words.append((text[i..<end], weight))
            i = end
        }

        var lines: [String] = []
        var current = ""
        var currentWeight = 0
        for (token, weight) in words {
            if current.isEmpty {
                current = String(token)
                currentWeight = weight
            } else if currentWeight + 1 + weight <= maxLineLength {
                current += " " + token
                currentWeight += 1 + weight
            } else {
                lines.append(current)
                current = String(token)
                currentWeight = weight
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines.joined(separator: "\n")
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

    private func openSoftwareUpdate() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Software-Update-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
        onUpdateNow()
    }
}
