import Foundation

/// OpenWispr runs with `LSUIElement = true` so it has no Dock icon while active and,
/// on most macOS versions, is excluded from Spotlight's Applications results — it's a
/// background agent, not a foreground app. That makes it genuinely hard to find or
/// relaunch after install. This gives users an explicit, one-click way to pin it to the
/// Dock like any other app, without needing to know it lives under `~/Applications`.
struct DockInstaller {
    static let dockDomain = "com.apple.dock"
    static let persistentAppsKey = "persistent-apps"

    /// Pure membership check, split out from `isInDock` so it can be unit tested without
    /// touching the real `com.apple.dock` defaults domain.
    static func isBundleInDock(bundlePath: String, persistentApps: [[String: Any]]) -> Bool {
        let normalizedTarget = bundlePath.hasSuffix("/") ? bundlePath : bundlePath + "/"
        return persistentApps.contains { entry in
            guard let tileData = entry["tile-data"] as? [String: Any],
                  let fileData = tileData["file-data"] as? [String: Any],
                  let urlString = fileData["_CFURLString"] as? String,
                  let url = URL(string: urlString) else {
                return false
            }
            let normalizedEntry = url.path.hasSuffix("/") ? url.path : url.path + "/"
            return normalizedEntry == normalizedTarget
        }
    }

    static func isInDock(bundlePath: String) -> Bool {
        guard let defaults = UserDefaults(suiteName: dockDomain),
              let persistentApps = defaults.array(forKey: persistentAppsKey) as? [[String: Any]] else {
            return false
        }
        return isBundleInDock(bundlePath: bundlePath, persistentApps: persistentApps)
    }

    /// Builds the `defaults write ... -array-add` plist fragment for a Dock tile pointing
    /// at `bundlePath`. Pulled out as its own function so the format can be unit tested.
    static func tilePlistFragment(bundlePath: String) -> String {
        let normalized = bundlePath.hasSuffix("/") ? bundlePath : bundlePath + "/"
        return """
        <dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>file://\(normalized)</string><key>_CFURLStringType</key><integer>15</integer></dict></dict></dict>
        """
    }

    /// Adds `bundlePath` to the Dock's persistent-apps list and restarts the Dock so the
    /// tile appears immediately. No public API exists for this on modern macOS — every
    /// dock-pinning utility (Rectangle, AlDente, etc.) shells out to `defaults` + `killall
    /// Dock` the same way. Restarting the Dock is a normal, expected side effect users see
    /// when installers do this; it does not quit any apps or lose Dock layout.
    @discardableResult
    static func addToDock(bundlePath: String) -> Bool {
        guard !isInDock(bundlePath: bundlePath) else { return true }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["write", dockDomain, persistentAppsKey, "-array-add", tilePlistFragment(bundlePath: bundlePath)]

        do {
            try process.run()
        } catch {
            return false
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return false }

        restartDock()
        return true
    }

    static func restartDock() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]
        try? process.run()
    }
}
