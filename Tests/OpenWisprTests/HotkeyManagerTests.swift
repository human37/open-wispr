import AppKit
import XCTest
@testable import OpenWisprLib

final class HotkeyManagerTests: XCTestCase {
    func testFnCmdDoesNotActivateOnPlainCmd() throws {
        var handler: ((NSEvent) -> Void)?
        var downCount = 0
        var upCount = 0
        let hotkey = HotkeyConfig(keyCode: 55, modifiers: ["fn"])
        let manager = HotkeyManager(
            keyCode: hotkey.keyCode,
            modifiers: hotkey.modifierFlags,
            addGlobalMonitor: { _, callback in handler = callback; return NSObject() },
            addLocalMonitor: { _, _ in nil }
        )
        manager.start(onKeyDown: { downCount += 1 }, onKeyUp: { upCount += 1 })
        defer { manager.stop() }

        handler?(try XCTUnwrap(makeKeyEvent(type: .flagsChanged, keyCode: 55, flags: [.command])))
        handler?(try XCTUnwrap(makeKeyEvent(type: .flagsChanged, keyCode: 55)))
        XCTAssertEqual(downCount, 0)
        XCTAssertEqual(upCount, 0)

        handler?(try XCTUnwrap(makeKeyEvent(type: .flagsChanged, keyCode: 55, flags: [.command, .function])))
        handler?(try XCTUnwrap(makeKeyEvent(type: .flagsChanged, keyCode: 55, flags: [.function])))
        XCTAssertEqual(downCount, 1)
        XCTAssertEqual(upCount, 1)
    }

    func testMonitorsHotkeyEventsFromOtherAppsAndOpenWisprItself() throws {
        let globalToken = NSObject()
        let localToken = NSObject()
        var globalHandler: ((NSEvent) -> Void)?
        var localHandler: ((NSEvent) -> NSEvent?)?
        var removedTokens: [AnyObject] = []
        var keyDownCount = 0
        var keyUpCount = 0

        let manager = HotkeyManager(
            keyCode: 49,
            addGlobalMonitor: { mask, handler in
                XCTAssertTrue(mask.contains(.keyDown))
                XCTAssertTrue(mask.contains(.keyUp))
                XCTAssertTrue(mask.contains(.flagsChanged))
                globalHandler = handler
                return globalToken
            },
            addLocalMonitor: { mask, handler in
                XCTAssertTrue(mask.contains(.keyDown))
                XCTAssertTrue(mask.contains(.keyUp))
                XCTAssertTrue(mask.contains(.flagsChanged))
                localHandler = handler
                return localToken
            },
            removeMonitor: { removedTokens.append($0 as AnyObject) }
        )

        manager.start(
            onKeyDown: { keyDownCount += 1 },
            onKeyUp: { keyUpCount += 1 }
        )

        let keyDown = try XCTUnwrap(makeKeyEvent(type: .keyDown, keyCode: 49))
        let keyUp = try XCTUnwrap(makeKeyEvent(type: .keyUp, keyCode: 49))
        globalHandler?(keyDown)
        let returnedEvent = localHandler?(keyUp)

        XCTAssertEqual(keyDownCount, 1)
        XCTAssertEqual(keyUpCount, 1)
        XCTAssertTrue(returnedEvent === keyUp)

        manager.stop()

        XCTAssertEqual(removedTokens.count, 2)
        XCTAssertTrue(removedTokens.contains { $0 === globalToken })
        XCTAssertTrue(removedTokens.contains { $0 === localToken })
    }

    private func makeKeyEvent(
        type: NSEvent.EventType,
        keyCode: UInt16,
        flags: NSEvent.ModifierFlags = []
    ) -> NSEvent? {
        NSEvent.keyEvent(
            with: type,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: " ",
            charactersIgnoringModifiers: " ",
            isARepeat: false,
            keyCode: keyCode
        )
    }
}
