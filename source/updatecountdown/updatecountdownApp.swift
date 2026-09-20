//
//  updatecountdownApp.swift
//  updatecountdown
//
//  The menu bar item lives in AppDelegate, as an AppKit NSStatusItem, so the
//  countdown can be drawn next to the icon.
//

import SwiftUI

@main
struct updatecountdownApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // -notch / -nonotch let a sysadmin set the notch preference from a script.
    // Seeds the initial value only, it doesn't lock the checkbox in Options.
    init() {
        switch CommandLine.arguments.dropFirst().first {
        case "-nonotch":
            Self.applyNotchFlag(hidden: true)
        case "-notch":
            Self.applyNotchFlag(hidden: false)
        default:
            break
        }
    }

    private static func applyNotchFlag(hidden: Bool) {
        guard NotchDisplay.hasNotch() else {
            print("This Mac has no notch to hide. Doing nothing.")
            exit(0)
        }

        UserDefaults.standard.set(hidden, forKey: UpdateMonitor.Keys.hideNotch)
        if NotchDisplay.setHidden(hidden) {
            print(hidden ? "Notch hidden." : "Default resolution restored.")
            exit(0)
        } else {
            print("Failed to apply the notch setting.")
            exit(1)
        }
    }

    var body: some Scene {
        // No visible windows; the app lives entirely in the menu bar.
        Settings {
            EmptyView()
        }
        // The empty Settings scene only exists because an App needs one. Keep
        // it out of the menu bar.
        .commands {
            CommandGroup(replacing: .appSettings) { }
        }
    }
}
