import XCTest
@testable import OpenWisprLib

final class KeyCodesTests: XCTestCase {

    // MARK: - nameToCode

    func testNameToCodeContainsAllLetters() {
        for char in "abcdefghijklmnopqrstuvwxyz" {
            XCTAssertNotNil(KeyCodes.nameToCode[String(char)], "Missing key: \(char)")
        }
    }

    func testNameToCodeContainsDigits() {
        for digit in 0...9 {
            XCTAssertNotNil(KeyCodes.nameToCode[String(digit)], "Missing digit: \(digit)")
        }
    }

    func testNameToCodeContainsFunctionKeys() {
        for n in 1...15 {
            XCTAssertNotNil(KeyCodes.nameToCode["f\(n)"], "Missing function key: f\(n)")
        }
    }

    func testNameToCodeContainsModifiers() {
        let modifiers = ["cmd", "leftcmd", "rightcmd", "shift", "leftshift", "rightshift",
                         "option", "leftoption", "rightoption", "alt", "leftalt", "rightalt",
                         "ctrl", "leftctrl", "rightctrl", "control", "rightcontrol",
                         "fn", "globe", "capslock"]
        for mod in modifiers {
            XCTAssertNotNil(KeyCodes.nameToCode[mod], "Missing modifier: \(mod)")
        }
    }

    func testFnAndGlobeShareKeyCode() {
        XCTAssertEqual(KeyCodes.nameToCode["fn"], KeyCodes.nameToCode["globe"])
    }

    // MARK: - codeToName

    func testCodeToNameRoundTripsKnownKeys() {
        let testCases: [(String, UInt16)] = [
            ("space", 49), ("return", 36), ("tab", 48), ("escape", 53), ("delete", 51)
        ]
        for (name, code) in testCases {
            XCTAssertEqual(KeyCodes.nameToCode[name], code)
            XCTAssertNotNil(KeyCodes.codeToName[code])
        }
    }

    // MARK: - parse

    func testParseSingleKey() {
        let result = KeyCodes.parse("space")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.keyCode, 49)
        XCTAssertTrue(result?.modifiers.isEmpty ?? false)
    }

    func testParseKeyWithModifier() {
        let result = KeyCodes.parse("ctrl+space")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.keyCode, 49)
        XCTAssertEqual(result?.modifiers, ["ctrl"])
    }

    func testParseKeyWithMultipleModifiers() {
        let result = KeyCodes.parse("cmd+shift+a")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.keyCode, 0)
        XCTAssertEqual(result?.modifiers, ["cmd", "shift"])
    }

    func testParseIsCaseInsensitive() {
        let result = KeyCodes.parse("CMD+Space")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.keyCode, 49)
    }

    func testParseUnknownKeyReturnsNil() {
        XCTAssertNil(KeyCodes.parse("nonexistent"))
    }

    func testParseTrimsWhitespace() {
        let result = KeyCodes.parse("ctrl + space")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.keyCode, 49)
    }

    // MARK: - describe

    func testDescribeSingleKey() {
        let name = KeyCodes.describe(keyCode: 63, modifiers: [])
        XCTAssertTrue(name == "fn" || name == "globe", "Expected fn or globe, got \(name)")
    }

    func testDescribeWithModifiers() {
        let desc = KeyCodes.describe(keyCode: 49, modifiers: ["cmd", "shift"])
        XCTAssertEqual(desc, "cmd+shift+space")
    }

    func testDescribeUnknownKeyCode() {
        let desc = KeyCodes.describe(keyCode: 999, modifiers: [])
        XCTAssertEqual(desc, "key(999)")
    }

    // MARK: - parse + describe round-trip

    func testParseDescribeRoundTrip() {
        let inputs = ["fn", "space", "f5", "escape"]
        for input in inputs {
            guard let parsed = KeyCodes.parse(input) else {
                XCTFail("Failed to parse: \(input)")
                continue
            }
            let described = KeyCodes.describe(keyCode: parsed.keyCode, modifiers: parsed.modifiers)
            let reparsed = KeyCodes.parse(described)
            XCTAssertEqual(reparsed?.keyCode, parsed.keyCode, "Round-trip failed for: \(input)")
        }
    }
}
