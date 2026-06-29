import XCTest
@testable import OpenWisprLib

final class TranscriberTests: XCTestCase {

    func testArgumentsIncludeWhisperPromptAsSingleFollowingArgument() throws {
        let prompt = "  Use punctuation, keep product names like OpenWispr.  "
        let transcriber = Transcriber(
            modelSize: "base.en",
            language: "en",
            whisperPrompt: prompt
        )
        let args = transcriber.arguments(
            modelPath: "/models/ggml-base.en.bin",
            audioURL: URL(fileURLWithPath: "/tmp/input.wav")
        )

        let promptFlagIndex = try XCTUnwrap(args.firstIndex(of: "--prompt"))
        XCTAssertEqual(args[promptFlagIndex + 1], prompt)
        XCTAssertEqual(args.filter { $0 == prompt }.count, 1)
    }

    func testArgumentsDisableCrossWindowContext() throws {
        let transcriber = Transcriber(modelSize: "base.en", language: "en")
        let args = transcriber.arguments(
            modelPath: "/models/ggml-base.en.bin",
            audioURL: URL(fileURLWithPath: "/tmp/input.wav")
        )

        let flagIndex = try XCTUnwrap(args.firstIndex(of: "-mc"))
        XCTAssertEqual(args[flagIndex + 1], "0")
    }

    func testArgumentsUseSingleNoTimestampsFlag() {
        let transcriber = Transcriber(modelSize: "base.en", language: "en")
        let args = transcriber.arguments(
            modelPath: "/models/ggml-base.en.bin",
            audioURL: URL(fileURLWithPath: "/tmp/input.wav")
        )

        XCTAssertTrue(args.contains("-nt"))
        XCTAssertFalse(args.contains("--no-timestamps"))
    }

    func testArgumentsOmitNilWhisperPrompt() {
        let transcriber = Transcriber(modelSize: "base.en", language: "en")
        let args = transcriber.arguments(
            modelPath: "/models/ggml-base.en.bin",
            audioURL: URL(fileURLWithPath: "/tmp/input.wav")
        )

        XCTAssertFalse(args.contains("--prompt"))
    }

    func testArgumentsOmitWhitespaceOnlyWhisperPrompt() {
        let transcriber = Transcriber(
            modelSize: "base.en",
            language: "en",
            whisperPrompt: " \n\t "
        )
        let args = transcriber.arguments(
            modelPath: "/models/ggml-base.en.bin",
            audioURL: URL(fileURLWithPath: "/tmp/input.wav")
        )

        XCTAssertFalse(args.contains("--prompt"))
    }

    func testArgumentsKeepSuppressRegexWhenSpokenPunctuationUsesPrompt() throws {
        let prompt = "Use punctuation and short sentences."
        let transcriber = Transcriber(
            modelSize: "base.en",
            language: "en",
            whisperPrompt: prompt
        )
        transcriber.spokenPunctuation = true

        let args = transcriber.arguments(
            modelPath: "/models/ggml-base.en.bin",
            audioURL: URL(fileURLWithPath: "/tmp/input.wav")
        )

        let promptFlagIndex = try XCTUnwrap(args.firstIndex(of: "--prompt"))
        XCTAssertEqual(args[promptFlagIndex + 1], prompt)

        let suppressFlagIndex = try XCTUnwrap(args.firstIndex(of: "--suppress-regex"))
        XCTAssertEqual(args[suppressFlagIndex + 1], "[,\\.\\?!;:\\-—]")
    }

    func testBlankAudioMarker() {
        XCTAssertEqual(Transcriber.stripWhisperMarkers("[BLANK_AUDIO]"), "")
    }

    func testBlankAudioWithWhitespace() {
        XCTAssertEqual(Transcriber.stripWhisperMarkers("  [BLANK_AUDIO]  "), "")
    }

    func testMultipleMarkers() {
        XCTAssertEqual(Transcriber.stripWhisperMarkers("[BLANK_AUDIO] [silence]"), "")
    }

    func testParenthesizedMarker() {
        XCTAssertEqual(Transcriber.stripWhisperMarkers("(BLANK_AUDIO)"), "")
    }

    func testNonSpeechEventMarkers() {
        XCTAssertEqual(Transcriber.stripWhisperMarkers("[Music] [Applause]"), "")
    }

    func testMarkerMixedWithText() {
        XCTAssertEqual(Transcriber.stripWhisperMarkers("hello [BLANK_AUDIO] world"), "hello world")
    }

    func testMarkerAtStartOfText() {
        XCTAssertEqual(Transcriber.stripWhisperMarkers("[BLANK_AUDIO] hello"), "hello")
    }

    func testMarkerAtEndOfText() {
        XCTAssertEqual(Transcriber.stripWhisperMarkers("hello [BLANK_AUDIO]"), "hello")
    }

    func testNormalTextUnchanged() {
        XCTAssertEqual(Transcriber.stripWhisperMarkers("hello world"), "hello world")
    }

    func testEmptyString() {
        XCTAssertEqual(Transcriber.stripWhisperMarkers(""), "")
    }

    func testUnknownBracketsPreserved() {
        XCTAssertEqual(Transcriber.stripWhisperMarkers("see [1] and (later)"), "see [1] and (later)")
    }

    func testKnownMarkerStrippedUnknownPreserved() {
        XCTAssertEqual(Transcriber.stripWhisperMarkers("[BLANK_AUDIO] see [1]"), "see [1]")
    }
}
