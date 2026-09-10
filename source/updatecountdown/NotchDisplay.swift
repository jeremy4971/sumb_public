//
//  NotchDisplay.swift
//  updatecountdown
//
//  Hides the notch by switching the main display to a shorter Retina mode.
//  There's no public API for this.
//

import AppKit
import CoreGraphics
import Darwin

private typealias CGDisplayModeGetIOFlagsFn = @convention(c) (CGDisplayMode) -> UInt32

// CoreGraphics exports this but declares it in no public header. Looked up at
// runtime instead of via @_silgen_name: a link-time dependency on a private
// symbol would turn its removal into a launch failure, and there's no recovering
// from that under the Hardened Runtime. If it's missing, resolve() just falls
// through to its next heuristic.
private let cgDisplayModeGetIOFlags: CGDisplayModeGetIOFlagsFn? = {
    // RTLD_DEFAULT — search every image already loaded into the process.
    guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2),
                             "CGDisplayModeGetIOFlags") else { return nil }
    return unsafeBitCast(symbol, to: CGDisplayModeGetIOFlagsFn.self)
}()

// From IOGraphicsTypesPrivate.h.
private let kDisplayModeDefaultFlag: UInt32 = 0x00000004

enum NotchDisplay {

    // MARK: - Model detection

    private static func modelIdentifier() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    // Models with a physical notch. Update as Apple ships new ones.
    private static let notchedModelIdentifiers: Set<String> = [
        // 14"/16" MacBook Pro, 2021 (M1 Pro / M1 Max)
        "MacBookPro18,1", "MacBookPro18,2", "MacBookPro18,3", "MacBookPro18,4",
        // 14"/16" MacBook Pro, 2023 (M2 Pro / M2 Max)
        "Mac14,5", "Mac14,6", "Mac14,9", "Mac14,10",
        // 14"/16" MacBook Pro, 2023 (M3 / M3 Pro / M3 Max)
        "Mac15,3", "Mac15,6", "Mac15,7", "Mac15,8", "Mac15,9", "Mac15,10", "Mac15,11",
        // MacBook Air 13"/15", 2022+ (M2, M3, M4)
        "Mac14,2", "Mac14,15", "Mac15,12", "Mac15,13", "Mac16,12", "Mac16,13",
        // 14"/16" MacBook Pro, 2024+ (M4 family)
        "Mac16,1", "Mac16,5", "Mac16,6", "Mac16,7", "Mac16,8",
    ]

    // Known models first, then the live safe-area inset as a fallback.
    static func hasNotch() -> Bool {
        if notchedModelIdentifiers.contains(modelIdentifier()) {
            return true
        }
        for screen in NSScreen.screens where screen.safeAreaInsets.top > 0 {
            return true
        }
        return false
    }

    // MARK: - Known default / no-notch resolutions

    private struct KnownResolutionPair {
        let defaultSize: (width: Int, height: Int)
        let noNotchSize: (width: Int, height: Int)
    }

    private static let knownResolutionsByModel: [String: KnownResolutionPair] = [
        // MacBook Air 13" (M2 / M3 / M4)
        "Mac14,2": KnownResolutionPair(defaultSize: (1470, 956), noNotchSize: (1470, 918)),
        "Mac15,12": KnownResolutionPair(defaultSize: (1470, 956), noNotchSize: (1470, 918)),
        "Mac16,12": KnownResolutionPair(defaultSize: (1470, 956), noNotchSize: (1470, 918)),
        // MacBook Air 15" (M2 / M3 / M4)
        "Mac14,15": KnownResolutionPair(defaultSize: (1680, 1050), noNotchSize: (1680, 1012)),
        "Mac15,13": KnownResolutionPair(defaultSize: (1680, 1050), noNotchSize: (1680, 1012)),
        "Mac16,13": KnownResolutionPair(defaultSize: (1680, 1050), noNotchSize: (1680, 1012)),
        // MacBook Pro 14" (M1 / M2 / M3 / M4)
        "MacBookPro18,3": KnownResolutionPair(defaultSize: (1512, 982), noNotchSize: (1512, 945)),
        "MacBookPro18,4": KnownResolutionPair(defaultSize: (1512, 982), noNotchSize: (1512, 945)),
        "Mac14,5": KnownResolutionPair(defaultSize: (1512, 982), noNotchSize: (1512, 945)),
        "Mac14,9": KnownResolutionPair(defaultSize: (1512, 982), noNotchSize: (1512, 945)),
        "Mac15,3": KnownResolutionPair(defaultSize: (1512, 982), noNotchSize: (1512, 945)),
        "Mac15,6": KnownResolutionPair(defaultSize: (1512, 982), noNotchSize: (1512, 945)),
        "Mac15,8": KnownResolutionPair(defaultSize: (1512, 982), noNotchSize: (1512, 945)),
        "Mac15,10": KnownResolutionPair(defaultSize: (1512, 982), noNotchSize: (1512, 945)),
        "Mac16,1": KnownResolutionPair(defaultSize: (1512, 982), noNotchSize: (1512, 945)),
        "Mac16,6": KnownResolutionPair(defaultSize: (1512, 982), noNotchSize: (1512, 945)),
        "Mac16,8": KnownResolutionPair(defaultSize: (1512, 982), noNotchSize: (1512, 945)),
        // MacBook Pro 16" (M1 / M2 / M3 / M4)
        "MacBookPro18,1": KnownResolutionPair(defaultSize: (1728, 1117), noNotchSize: (1728, 1080)),
        "MacBookPro18,2": KnownResolutionPair(defaultSize: (1728, 1117), noNotchSize: (1728, 1080)),
        "Mac14,6": KnownResolutionPair(defaultSize: (1728, 1117), noNotchSize: (1728, 1080)),
        "Mac14,10": KnownResolutionPair(defaultSize: (1728, 1117), noNotchSize: (1728, 1080)),
        "Mac15,7": KnownResolutionPair(defaultSize: (1728, 1117), noNotchSize: (1728, 1080)),
        "Mac15,9": KnownResolutionPair(defaultSize: (1728, 1117), noNotchSize: (1728, 1080)),
        "Mac15,11": KnownResolutionPair(defaultSize: (1728, 1117), noNotchSize: (1728, 1080)),
        "Mac16,5": KnownResolutionPair(defaultSize: (1728, 1117), noNotchSize: (1728, 1080)),
        "Mac16,7": KnownResolutionPair(defaultSize: (1728, 1117), noNotchSize: (1728, 1080)),
    ]

    // Fallback: match by current default resolution instead of model.
    private static let knownResolutionsByDefaultSize: [String: KnownResolutionPair] = {
        var map: [String: KnownResolutionPair] = [:]
        for pair in knownResolutionsByModel.values {
            map["\(pair.defaultSize.width)x\(pair.defaultSize.height)"] = pair
        }
        return map
    }()

    // MARK: - Display mode helpers

    private static func allModes(for display: CGDirectDisplayID) -> [CGDisplayMode] {
        let options: [CFString: Any] = [kCGDisplayShowDuplicateLowResolutionModes: true]
        guard let modes = CGDisplayCopyAllDisplayModes(display, options as CFDictionary) as? [CGDisplayMode] else {
            return []
        }
        return modes
    }

    private static func sameResolution(_ a: CGDisplayMode, _ b: CGDisplayMode) -> Bool {
        a.width == b.width && a.height == b.height
    }

    // pixelWidth > width means the mode is scaled (Retina).
    private static func isHiDPI(_ mode: CGDisplayMode) -> Bool {
        mode.pixelWidth > mode.width
    }

    private static func findMode(width: Int, height: Int, in modes: [CGDisplayMode]) -> CGDisplayMode? {
        modes.first { $0.width == width && $0.height == height }
    }

    // False when CGDisplayModeGetIOFlags couldn't be resolved.
    private static func isDriverFlaggedDefault(_ mode: CGDisplayMode) -> Bool {
        guard let getIOFlags = cgDisplayModeGetIOFlags else { return false }
        return (getIOFlags(mode) & kDisplayModeDefaultFlag) != 0
    }

    // MARK: - Resolving the default / no-notch modes

    private struct ResolvedModes {
        let display: CGDirectDisplayID
        let modes: [CGDisplayMode]
        let current: CGDisplayMode
        let defaultMode: CGDisplayMode
        let noNotchMode: CGDisplayMode?
    }

    // Known table first, then current resolution, then a guess for hardware we
    // don't recognise.
    private static func resolve() -> ResolvedModes? {
        let display = CGMainDisplayID()
        guard let currentMode = CGDisplayCopyDisplayMode(display) else { return nil }

        let modes = allModes(for: display)
        guard !modes.isEmpty else { return nil }

        var bestByResolution: [String: CGDisplayMode] = [:]
        for mode in modes {
            guard mode.isUsableForDesktopGUI(), isHiDPI(mode) else { continue }
            let key = "\(mode.width)x\(mode.height)"
            if let existing = bestByResolution[key] {
                if mode.refreshRate > existing.refreshRate {
                    bestByResolution[key] = mode
                }
            } else {
                bestByResolution[key] = mode
            }
        }
        let sorted = bestByResolution.values.sorted { ($0.width * $0.height) > ($1.width * $1.height) }
        guard !sorted.isEmpty else { return nil }

        let defaultMode: CGDisplayMode
        var noNotchMode: CGDisplayMode?

        if let pair = knownResolutionsByModel[modelIdentifier()],
           let d = findMode(width: pair.defaultSize.width, height: pair.defaultSize.height, in: sorted) {
            defaultMode = d
            noNotchMode = findMode(width: pair.noNotchSize.width, height: pair.noNotchSize.height, in: sorted)
        } else if let pair = knownResolutionsByDefaultSize["\(currentMode.width)x\(currentMode.height)"],
                  let d = findMode(width: pair.defaultSize.width, height: pair.defaultSize.height, in: sorted) {
            defaultMode = d
            noNotchMode = findMode(width: pair.noNotchSize.width, height: pair.noNotchSize.height, in: sorted)
        } else {
            func isExactRetina2x(_ mode: CGDisplayMode) -> Bool {
                mode.pixelWidth == mode.width * 2 && mode.pixelHeight == mode.height * 2
            }
            let guessed = sorted.first(where: { isDriverFlaggedDefault($0) })
                ?? sorted.first(where: { isExactRetina2x($0) })
                ?? sorted[0]
            defaultMode = guessed

            let sameWidthDescending = sorted
                .filter { $0.width == guessed.width }
                .sorted { $0.height > $1.height }
            if let pos = sameWidthDescending.firstIndex(where: { sameResolution($0, guessed) }) {
                let nextIndex = pos + 1
                noNotchMode = nextIndex < sameWidthDescending.count ? sameWidthDescending[nextIndex] : nil
            }
        }

        return ResolvedModes(display: display, modes: modes, current: currentMode, defaultMode: defaultMode, noNotchMode: noNotchMode)
    }

    // MARK: - Applying a mode

    private static func apply(_ mode: CGDisplayMode, on display: CGDirectDisplayID) -> Bool {
        var configRef: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&configRef) == .success, let config = configRef else {
            return false
        }
        guard CGConfigureDisplayWithDisplayMode(config, display, mode, nil) == .success else {
            CGCancelDisplayConfiguration(config)
            return false
        }
        return CGCompleteDisplayConfiguration(config, .permanently) == .success
    }

    // Switching resolution can drop ProMotion to 60Hz even when a higher-
    // refresh mode exists for that same size. Bump it back up.
    private static func restoreHighestRefreshRateIfNeeded(
        width: Int, height: Int, previousRefreshRate: Double,
        on display: CGDirectDisplayID, allModes: [CGDisplayMode]
    ) {
        guard let resultingMode = CGDisplayCopyDisplayMode(display),
              resultingMode.refreshRate < previousRefreshRate else {
            return
        }
        let candidates = allModes.filter { $0.width == width && $0.height == height }
        guard let best = candidates.max(by: { $0.refreshRate < $1.refreshRate }),
              best.refreshRate > resultingMode.refreshRate else {
            return
        }
        _ = apply(best, on: display)
    }

    // MARK: - Public API

    static func isHidden() -> Bool {
        guard let resolved = resolve() else { return false }
        return !sameResolution(resolved.current, resolved.defaultMode)
    }

    /// Switches to the no-notch resolution, or back to the default. No-ops if
    /// already in that state, if this Mac has no notch, or if the target mode
    /// can't be worked out. Returns whether the requested state is in effect.
    @discardableResult
    static func setHidden(_ hidden: Bool) -> Bool {
        guard hasNotch(), let resolved = resolve() else { return false }

        let alreadyHidden = !sameResolution(resolved.current, resolved.defaultMode)
        if hidden == alreadyHidden { return true }

        guard let target = hidden ? resolved.noNotchMode : resolved.defaultMode else {
            return false
        }

        let previousRefreshRate = resolved.current.refreshRate
        guard apply(target, on: resolved.display) else { return false }
        restoreHighestRefreshRateIfNeeded(
            width: target.width, height: target.height,
            previousRefreshRate: previousRefreshRate,
            on: resolved.display, allModes: resolved.modes
        )
        return true
    }
}
