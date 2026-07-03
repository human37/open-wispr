import XCTest
@testable import OpenWisprLib

final class TextPolisherTests: XCTestCase {

    // MARK: - Spacing must not corrupt URLs / emails / abbreviations
    // Regression net for the bug where "github.com" became "github. Com".

    func testURLNotBroken() {
        XCTAssertEqual(TextPolisher.polish("visit github.com today"),
                       "Visit github.com today")
    }

    func testSchemeURLNotBroken() {
        XCTAssertEqual(TextPolisher.polish("go to https://github.com now"),
                       "Go to https://github.com now")
    }

    func testEmailNotBroken() {
        XCTAssertEqual(TextPolisher.polish("email me at user@example.com please"),
                       "Email me at user@example.com please")
    }

    func testLowercaseAbbreviationNotBroken() {
        XCTAssertEqual(TextPolisher.polish("use e.g. a cat for this"),
                       "Use e.g. a cat for this")
    }

    func testDottedAbbreviationNotBroken() {
        XCTAssertEqual(TextPolisher.polish("the U.S. last year"),
                       "The U.S. last year")
    }

    func testDecimalNotBroken() {
        XCTAssertEqual(TextPolisher.polish("the price is 3.14 dollars"),
                       "The price is 3.14 dollars")
    }

    func testTimeColonNotBroken() {
        XCTAssertEqual(TextPolisher.polish("meet at 12:30 today"),
                       "Meet at 12:30 today")
    }

    func testNumericCommaNotBroken() {
        XCTAssertEqual(TextPolisher.polish("I have 1,000 apples"),
                       "I have 1,000 apples")
    }

    // MARK: - Spacing still does its job

    func testRunOnSentenceSplit() {
        XCTAssertEqual(TextPolisher.polish("I finished the report.Then I left"),
                       "I finished the report. Then I left")
    }

    func testCommaGluedToLetterGetsSpace() {
        XCTAssertEqual(TextPolisher.polish("I have apples,oranges,pears"),
                       "I have apples, oranges, pears")
    }

    func testSpaceBeforePunctuationRemoved() {
        XCTAssertEqual(TextPolisher.polish("hello world , how are you ?"),
                       "Hello world, how are you?")
    }

    func testMultipleSpacesCollapsed() {
        XCTAssertEqual(TextPolisher.polish("too    many     spaces"),
                       "Too many spaces")
    }

    // MARK: - Capitalization

    func testSentenceStartCapitalized() {
        XCTAssertEqual(TextPolisher.polish("hello world. this is fine"),
                       "Hello world. This is fine")
    }

    func testStandaloneIUppercased() {
        XCTAssertEqual(TextPolisher.polish("i think i can do it"),
                       "I think I can do it")
    }

    // MARK: - Filler / voice-command flags are gated (off by default)

    func testFillersKeptByDefault() {
        XCTAssertEqual(TextPolisher.polish("this is um basically done"),
                       "This is um basically done")
    }

    func testFillersRemovedWhenEnabled() {
        XCTAssertEqual(TextPolisher.polish("this is um basically done", removeFillers: true),
                       "This is done")
    }

    func testVoiceCommandsOffByDefault() {
        XCTAssertEqual(TextPolisher.polish("add a comma here"),
                       "Add a comma here")
    }

    func testVoiceCommandsWhenEnabled() {
        XCTAssertEqual(TextPolisher.polish("add a comma here", voiceCommands: true),
                       "Add a, here")
    }
}
