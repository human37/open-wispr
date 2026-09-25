import XCTest
@testable import OpenWisprLib

final class DockInstallerTests: XCTestCase {

    // MARK: - isBundleInDock

    private func entry(forURLString urlString: String) -> [String: Any] {
        return [
            "tile-data": [
                "file-data": [
                    "_CFURLString": urlString,
                    "_CFURLStringType": 15
                ]
            ]
        ]
    }

    func testDetectsExactMatch() {
        let apps = [entry(forURLString: "file:///opt/homebrew/opt/open-wispr/OpenWispr.app/")]
        XCTAssertTrue(DockInstaller.isBundleInDock(bundlePath: "/opt/homebrew/opt/open-wispr/OpenWispr.app", persistentApps: apps))
    }

    func testMatchIsInsensitiveToTrailingSlashOnInput() {
        let apps = [entry(forURLString: "file:///opt/homebrew/opt/open-wispr/OpenWispr.app/")]
        XCTAssertTrue(DockInstaller.isBundleInDock(bundlePath: "/opt/homebrew/opt/open-wispr/OpenWispr.app/", persistentApps: apps))
    }

    func testReturnsFalseWhenNotPresent() {
        let apps = [entry(forURLString: "file:///Applications/Slack.app/")]
        XCTAssertFalse(DockInstaller.isBundleInDock(bundlePath: "/opt/homebrew/opt/open-wispr/OpenWispr.app", persistentApps: apps))
    }

    func testReturnsFalseForEmptyList() {
        XCTAssertFalse(DockInstaller.isBundleInDock(bundlePath: "/opt/homebrew/opt/open-wispr/OpenWispr.app", persistentApps: []))
    }

    func testIgnoresMalformedEntries() {
        let apps: [[String: Any]] = [["tile-data": ["not-file-data": [:]]], [:]]
        XCTAssertFalse(DockInstaller.isBundleInDock(bundlePath: "/opt/homebrew/opt/open-wispr/OpenWispr.app", persistentApps: apps))
    }

    func testDoesNotMatchDifferentAppAtSimilarPath() {
        // Guards against substring/prefix matching a different app in a sibling directory.
        let apps = [entry(forURLString: "file:///opt/homebrew/opt/open-wispr/OpenWisprHelper.app/")]
        XCTAssertFalse(DockInstaller.isBundleInDock(bundlePath: "/opt/homebrew/opt/open-wispr/OpenWispr.app", persistentApps: apps))
    }

    // MARK: - tilePlistFragment

    func testTilePlistFragmentContainsFileURL() {
        let fragment = DockInstaller.tilePlistFragment(bundlePath: "/opt/homebrew/opt/open-wispr/OpenWispr.app")
        XCTAssertTrue(fragment.contains("file:///opt/homebrew/opt/open-wispr/OpenWispr.app/"))
        XCTAssertTrue(fragment.contains("_CFURLStringType"))
        XCTAssertTrue(fragment.contains("<integer>15</integer>"))
    }

    func testTilePlistFragmentNormalizesTrailingSlash() {
        let withSlash = DockInstaller.tilePlistFragment(bundlePath: "/opt/homebrew/opt/open-wispr/OpenWispr.app/")
        let withoutSlash = DockInstaller.tilePlistFragment(bundlePath: "/opt/homebrew/opt/open-wispr/OpenWispr.app")
        XCTAssertEqual(withSlash, withoutSlash)
    }
}
