import XCTest
@testable import OpenWisprLib

final class ConfigTests: XCTestCase {

    // MARK: - effectiveMaxRecordings

    func testEffectiveMaxRecordingsNilDefaultsToZero() {
        XCTAssertEqual(Config.effectiveMaxRecordings(nil), 0)
    }

    func testEffectiveMaxRecordingsZero() {
        XCTAssertEqual(Config.effectiveMaxRecordings(0), 0)
    }

    func testEffectiveMaxRecordingsNegativeClampsToOne() {
        XCTAssertEqual(Config.effectiveMaxRecordings(-5), 1)
    }

    func testEffectiveMaxRecordingsWithinRange() {
        XCTAssertEqual(Config.effectiveMaxRecordings(1), 1)
        XCTAssertEqual(Config.effectiveMaxRecordings(10), 10)
        XCTAssertEqual(Config.effectiveMaxRecordings(100), 100)
    }

    func testEffectiveMaxRecordingsClampsAbove100() {
        XCTAssertEqual(Config.effectiveMaxRecordings(200), 100)
        XCTAssertEqual(Config.effectiveMaxRecordings(999), 100)
    }

    // MARK: - FlexBool decoding

    func testFlexBoolDecodesBool() throws {
        let json = #"{"spokenPunctuation": true}"#.data(using: .utf8)!
        let wrapper = try JSONDecoder().decode(FlexBoolWrapper.self, from: json)
        XCTAssertTrue(wrapper.spokenPunctuation.value)
    }

    func testFlexBoolDecodesStringTrue() throws {
        let json = #"{"spokenPunctuation": "yes"}"#.data(using: .utf8)!
        let wrapper = try JSONDecoder().decode(FlexBoolWrapper.self, from: json)
        XCTAssertTrue(wrapper.spokenPunctuation.value)
    }

    func testFlexBoolDecodesStringFalse() throws {
        let json = #"{"spokenPunctuation": "no"}"#.data(using: .utf8)!
        let wrapper = try JSONDecoder().decode(FlexBoolWrapper.self, from: json)
        XCTAssertFalse(wrapper.spokenPunctuation.value)
    }

    func testFlexBoolDecodesInt() throws {
        let json1 = #"{"spokenPunctuation": 1}"#.data(using: .utf8)!
        let wrapper1 = try JSONDecoder().decode(FlexBoolWrapper.self, from: json1)
        XCTAssertTrue(wrapper1.spokenPunctuation.value)

        let json0 = #"{"spokenPunctuation": 0}"#.data(using: .utf8)!
        let wrapper0 = try JSONDecoder().decode(FlexBoolWrapper.self, from: json0)
        XCTAssertFalse(wrapper0.spokenPunctuation.value)
    }

    // MARK: - Config JSON decoding

    func testConfigDecodesWithMaxRecordings() throws {
        let json = """
        {
            "hotkey": {"keyCode": 63, "modifiers": []},
            "modelSize": "base.en",
            "language": "en",
            "spokenPunctuation": false,
            "maxRecordings": 5
        }
        """.data(using: .utf8)!
        let config = try Config.decode(from: json)
        XCTAssertEqual(config.maxRecordings, 5)
        XCTAssertEqual(config.modelSize, "base.en")
    }

    func testConfigDecodesWithoutMaxRecordings() throws {
        let json = """
        {
            "hotkey": {"keyCode": 63, "modifiers": []},
            "modelSize": "small.en",
            "language": "en"
        }
        """.data(using: .utf8)!
        let config = try Config.decode(from: json)
        XCTAssertNil(config.maxRecordings)
        XCTAssertEqual(Config.effectiveMaxRecordings(config.maxRecordings), 0)
    }

    // MARK: - toggleMode decoding

    func testConfigDecodesToggleModeTrue() throws {
        let json = """
        {
            "hotkey": {"keyCode": 63, "modifiers": []},
            "modelSize": "base.en",
            "language": "en",
            "toggleMode": true
        }
        """.data(using: .utf8)!
        let config = try Config.decode(from: json)
        XCTAssertEqual(config.toggleMode?.value, true)
    }

    func testConfigDecodesToggleModeFalse() throws {
        let json = """
        {
            "hotkey": {"keyCode": 63, "modifiers": []},
            "modelSize": "base.en",
            "language": "en",
            "toggleMode": false
        }
        """.data(using: .utf8)!
        let config = try Config.decode(from: json)
        XCTAssertEqual(config.toggleMode?.value, false)
    }

    func testConfigDecodesWithoutToggleMode() throws {
        let json = """
        {
            "hotkey": {"keyCode": 63, "modifiers": []},
            "modelSize": "base.en",
            "language": "en"
        }
        """.data(using: .utf8)!
        let config = try Config.decode(from: json)
        XCTAssertNil(config.toggleMode)
    }

    func testConfigDefaultToggleModeIsFalse() {
        let config = Config.defaultConfig
        XCTAssertEqual(config.toggleMode?.value, false)
    }

    // MARK: - Language and model constants

    func testSupportedLanguagesContainsEnglish() {
        XCTAssertTrue(Config.supportedLanguages.contains(where: { $0.code == "en" }))
    }

    func testSupportedLanguagesContainsAuto() {
        XCTAssertTrue(Config.supportedLanguages.contains(where: { $0.code == "auto" }))
    }

    func testSupportedModelsContainsDefault() {
        XCTAssertTrue(Config.supportedModels.contains("base.en"))
    }

    func testConfigDecodesLanguageAuto() throws {
        let json = """
        {
            "hotkey": {"keyCode": 63, "modifiers": []},
            "modelSize": "base.en",
            "language": "auto"
        }
        """.data(using: .utf8)!
        let config = try Config.decode(from: json)
        XCTAssertEqual(config.language, "auto")
    }

    // MARK: - HotkeyConfig modifier flags

    func testModifierFlagsSingle() {
        let config = HotkeyConfig(keyCode: 49, modifiers: ["cmd"])
        XCTAssertEqual(config.modifierFlags, UInt64(1 << 20))
    }

    func testModifierFlagsMultiple() {
        let config = HotkeyConfig(keyCode: 49, modifiers: ["cmd", "shift"])
        let expected = UInt64(1 << 20) | UInt64(1 << 17)
        XCTAssertEqual(config.modifierFlags, expected)
    }

    func testModifierFlagsEmpty() {
        let config = HotkeyConfig(keyCode: 63, modifiers: [])
        XCTAssertEqual(config.modifierFlags, 0)
    }

    func testModifierFlagsIgnoresUnknown() {
        let config = HotkeyConfig(keyCode: 49, modifiers: ["cmd", "bogus"])
        XCTAssertEqual(config.modifierFlags, UInt64(1 << 20))
    }
}

private struct FlexBoolWrapper: Codable {
    let spokenPunctuation: FlexBool
}
