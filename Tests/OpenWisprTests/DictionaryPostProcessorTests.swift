import XCTest
@testable import OpenWisprLib

final class DictionaryPostProcessorTests: XCTestCase {

    func testBuildPromptEmpty() {
        let result = DictionaryPostProcessor.buildPrompt(from: [])
        XCTAssertEqual(result, "")
    }

    func testBuildPromptSingleEntry() {
        let entries = [DictionaryEntry(from: "nural", to: "neural")]
        let result = DictionaryPostProcessor.buildPrompt(from: entries)
        XCTAssertEqual(result, "Vocabulary: neural.")
    }

    func testBuildPromptMultipleEntries() {
        let entries = [
            DictionaryEntry(from: "nural", to: "neural"),
            DictionaryEntry(from: "kubernetees", to: "Kubernetes"),
        ]
        let result = DictionaryPostProcessor.buildPrompt(from: entries)
        XCTAssertEqual(result, "Vocabulary: Kubernetes, neural.")
    }

    func testBuildPromptDeduplicates() {
        let entries = [
            DictionaryEntry(from: "nural", to: "neural"),
            DictionaryEntry(from: "nueral", to: "neural"),
        ]
        let result = DictionaryPostProcessor.buildPrompt(from: entries)
        XCTAssertEqual(result, "Vocabulary: neural.")
    }

    func testSingleWordReplacement() {
        let entries = [DictionaryEntry(from: "nural", to: "neural")]
        let result = DictionaryPostProcessor.process("the nural network", dictionary: entries)
        XCTAssertEqual(result, "the neural network")
    }

    func testSingleWordCaseInsensitive() {
        let entries = [DictionaryEntry(from: "nural", to: "neural")]
        let result = DictionaryPostProcessor.process("the Nural network", dictionary: entries)
        XCTAssertEqual(result, "the neural network")
    }

    func testSingleWordWithTrailingPunctuation() {
        let entries = [DictionaryEntry(from: "nural", to: "neural")]
        let result = DictionaryPostProcessor.process("it is nural, right?", dictionary: entries)
        XCTAssertEqual(result, "it is neural, right?")
    }

    func testSingleWordWithPeriod() {
        let entries = [DictionaryEntry(from: "nural", to: "neural")]
        let result = DictionaryPostProcessor.process("it is nural.", dictionary: entries)
        XCTAssertEqual(result, "it is neural.")
    }

    func testMultiWordReplacement() {
        let entries = [DictionaryEntry(from: "chat gee pee tee", to: "ChatGPT")]
        let result = DictionaryPostProcessor.process("I use chat gee pee tee daily", dictionary: entries)
        XCTAssertEqual(result, "I use ChatGPT daily")
    }

    func testMultiWordWithTrailingPunctuation() {
        let entries = [DictionaryEntry(from: "chat gee pee tee", to: "ChatGPT")]
        let result = DictionaryPostProcessor.process("I use chat gee pee tee.", dictionary: entries)
        XCTAssertEqual(result, "I use ChatGPT.")
    }

    func testMultiWordCaseInsensitive() {
        let entries = [DictionaryEntry(from: "chat gee pee tee", to: "ChatGPT")]
        let result = DictionaryPostProcessor.process("I use Chat Gee Pee Tee daily", dictionary: entries)
        XCTAssertEqual(result, "I use ChatGPT daily")
    }

    func testGreedyLongestMatch() {
        let entries = [
            DictionaryEntry(from: "open", to: "Open"),
            DictionaryEntry(from: "open whisper", to: "OpenWispr"),
        ]
        let result = DictionaryPostProcessor.process("I use open whisper daily", dictionary: entries)
        XCTAssertEqual(result, "I use OpenWispr daily")
    }

    func testNoMatchPassesThrough() {
        let entries = [DictionaryEntry(from: "nural", to: "neural")]
        let result = DictionaryPostProcessor.process("hello world", dictionary: entries)
        XCTAssertEqual(result, "hello world")
    }

    func testEmptyDictionaryPassesThrough() {
        let result = DictionaryPostProcessor.process("hello world", dictionary: [])
        XCTAssertEqual(result, "hello world")
    }

    func testEmptyStringPassesThrough() {
        let entries = [DictionaryEntry(from: "nural", to: "neural")]
        let result = DictionaryPostProcessor.process("", dictionary: entries)
        XCTAssertEqual(result, "")
    }

    func testDuplicateFromUsesFirstEntry() {
        let entries = [
            DictionaryEntry(from: "nural", to: "neural"),
            DictionaryEntry(from: "nural", to: "NEURAL"),
        ]
        let result = DictionaryPostProcessor.process("the nural network", dictionary: entries)
        XCTAssertEqual(result, "the neural network")
    }

    func testMultipleReplacementsInOneSentence() {
        let entries = [
            DictionaryEntry(from: "nural", to: "neural"),
            DictionaryEntry(from: "kubernetees", to: "Kubernetes"),
        ]
        let result = DictionaryPostProcessor.process("nural nets on kubernetees", dictionary: entries)
        XCTAssertEqual(result, "neural nets on Kubernetes")
    }
}
