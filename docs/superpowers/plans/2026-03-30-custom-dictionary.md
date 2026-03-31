# Custom Dictionary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add custom dictionary support so users can correct words/phrases Whisper consistently mishears, using prompt hints at inference time and exact-match post-processing.

**Architecture:** Two-layer correction -- Layer 1 passes vocabulary hints via whisper-cli's `--prompt` flag to bias the decoder. Layer 2 applies greedy sliding-window exact-match replacement on the transcript output. Dictionary entries are stored in `config.json` and managed via an AppKit settings window.

**Tech Stack:** Swift 5.9, AppKit (NSWindow, NSTableView), XCTest

---

## File Structure

| Action | File | Responsibility |
|--------|------|---------------|
| Edit | `Sources/OpenWisprLib/Config.swift` | Add `DictionaryEntry` struct and `customDictionary` field |
| Create | `Sources/OpenWisprLib/DictionaryPostProcessor.swift` | Prompt building + sliding window replacement |
| Create | `Tests/OpenWisprTests/DictionaryPostProcessorTests.swift` | Unit tests for post-processing logic |
| Edit | `Sources/OpenWisprLib/Transcriber.swift` | Add `customDictionary` property, inject `--prompt` |
| Edit | `Sources/OpenWisprLib/AppDelegate.swift` | Wire dictionary into transcriber + post-processing pipeline |
| Create | `Sources/OpenWisprLib/DictionaryWindowController.swift` | NSWindow with NSTableView for managing entries |
| Edit | `Sources/OpenWisprLib/StatusBarController.swift` | Add "Custom Dictionary..." menu item |

---

### Task 1: Add DictionaryEntry to Config

**Files:**
- Modify: `Sources/OpenWisprLib/Config.swift:8-16` (Config struct)
- Modify: `Sources/OpenWisprLib/Config.swift:136-144` (defaultConfig)
- Test: `Tests/OpenWisprTests/ConfigTests.swift`

- [ ] **Step 1: Add DictionaryEntry struct to Config.swift**

Add this struct above the `Config` struct definition (after line 6, before line 8):

```swift
public struct DictionaryEntry: Codable, Equatable {
    public var from: String
    public var to: String

    public init(from: String, to: String) {
        self.from = from
        self.to = to
    }
}
```

- [ ] **Step 2: Add customDictionary field to Config struct**

Add this line after `toggleMode` (after line 15):

```swift
    public var customDictionary: [DictionaryEntry]?
```

- [ ] **Step 3: Write tests for config decoding with dictionary**

Add to `Tests/OpenWisprTests/ConfigTests.swift` before the final `}`:

```swift
    // MARK: - customDictionary decoding

    func testConfigDecodesWithCustomDictionary() throws {
        let json = """
        {
            "hotkey": {"keyCode": 63, "modifiers": []},
            "modelSize": "base.en",
            "language": "en",
            "customDictionary": [
                {"from": "nural", "to": "neural"},
                {"from": "chat gee pee tee", "to": "ChatGPT"}
            ]
        }
        """.data(using: .utf8)!
        let config = try Config.decode(from: json)
        XCTAssertEqual(config.customDictionary?.count, 2)
        XCTAssertEqual(config.customDictionary?[0].from, "nural")
        XCTAssertEqual(config.customDictionary?[0].to, "neural")
        XCTAssertEqual(config.customDictionary?[1].from, "chat gee pee tee")
        XCTAssertEqual(config.customDictionary?[1].to, "ChatGPT")
    }

    func testConfigDecodesWithoutCustomDictionary() throws {
        let json = """
        {
            "hotkey": {"keyCode": 63, "modifiers": []},
            "modelSize": "base.en",
            "language": "en"
        }
        """.data(using: .utf8)!
        let config = try Config.decode(from: json)
        XCTAssertNil(config.customDictionary)
    }

    func testConfigDecodesEmptyCustomDictionary() throws {
        let json = """
        {
            "hotkey": {"keyCode": 63, "modifiers": []},
            "modelSize": "base.en",
            "language": "en",
            "customDictionary": []
        }
        """.data(using: .utf8)!
        let config = try Config.decode(from: json)
        XCTAssertEqual(config.customDictionary?.count, 0)
    }
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter ConfigTests 2>&1 | tail -20`
Expected: All tests pass, including the 3 new ones.

- [ ] **Step 5: Commit**

```bash
git add Sources/OpenWisprLib/Config.swift Tests/OpenWisprTests/ConfigTests.swift
git commit -m "feat: add DictionaryEntry to Config for custom dictionary support"
```

---

### Task 2: Create DictionaryPostProcessor

**Files:**
- Create: `Sources/OpenWisprLib/DictionaryPostProcessor.swift`
- Create: `Tests/OpenWisprTests/DictionaryPostProcessorTests.swift`

- [ ] **Step 1: Write the test file**

Create `Tests/OpenWisprTests/DictionaryPostProcessorTests.swift`:

```swift
import XCTest
@testable import OpenWisprLib

final class DictionaryPostProcessorTests: XCTestCase {

    // MARK: - Prompt building

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
        XCTAssertEqual(result, "Vocabulary: neural, Kubernetes.")
    }

    func testBuildPromptDeduplicates() {
        let entries = [
            DictionaryEntry(from: "nural", to: "neural"),
            DictionaryEntry(from: "nueral", to: "neural"),
        ]
        let result = DictionaryPostProcessor.buildPrompt(from: entries)
        XCTAssertEqual(result, "Vocabulary: neural.")
    }

    // MARK: - Single word replacement

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

    // MARK: - Multi-word replacement

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

    // MARK: - Greedy longest match

    func testGreedyLongestMatch() {
        let entries = [
            DictionaryEntry(from: "open", to: "Open"),
            DictionaryEntry(from: "open whisper", to: "OpenWispr"),
        ]
        let result = DictionaryPostProcessor.process("I use open whisper daily", dictionary: entries)
        XCTAssertEqual(result, "I use OpenWispr daily")
    }

    // MARK: - No match

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

    // MARK: - Multiple replacements in one string

    func testMultipleReplacementsInOneSentence() {
        let entries = [
            DictionaryEntry(from: "nural", to: "neural"),
            DictionaryEntry(from: "kubernetees", to: "Kubernetes"),
        ]
        let result = DictionaryPostProcessor.process("nural nets on kubernetees", dictionary: entries)
        XCTAssertEqual(result, "neural nets on Kubernetes")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter DictionaryPostProcessorTests 2>&1 | tail -5`
Expected: Build error -- `DictionaryPostProcessor` not found.

- [ ] **Step 3: Create DictionaryPostProcessor.swift**

Create `Sources/OpenWisprLib/DictionaryPostProcessor.swift`:

```swift
import Foundation

public struct DictionaryPostProcessor {

    private static let trailingPunctuation = CharacterSet(charactersIn: ".,!?;:")

    public static func buildPrompt(from entries: [DictionaryEntry]) -> String {
        guard !entries.isEmpty else { return "" }
        let unique = Array(Set(entries.map { $0.to }))
            .sorted()
        return "Vocabulary: \(unique.joined(separator: ", "))."
    }

    public static func process(_ text: String, dictionary entries: [DictionaryEntry]) -> String {
        guard !entries.isEmpty, !text.isEmpty else { return text }

        let tokens = text.components(separatedBy: " ").filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return text }

        var lookup: [String: [DictionaryEntry]] = [:]
        for entry in entries {
            let firstWord = entry.from.lowercased().components(separatedBy: " ").first ?? ""
            lookup[firstWord, default: []].append(entry)
        }

        for key in lookup.keys {
            lookup[key]?.sort { phraseTokenCount($0.from) > phraseTokenCount($1.from) }
        }

        var result: [String] = []
        var i = 0

        while i < tokens.count {
            let stripped = stripPunctuation(tokens[i])
            let lowered = stripped.word.lowercased()

            if let candidates = lookup[lowered] {
                var matched = false
                for entry in candidates {
                    let phraseTokens = entry.from.lowercased().components(separatedBy: " ")
                    let phraseLen = phraseTokens.count

                    if i + phraseLen > tokens.count { continue }

                    var allMatch = true
                    for j in 0..<phraseLen {
                        let tokenAtJ = (j == phraseLen - 1)
                            ? stripPunctuation(tokens[i + j]).word.lowercased()
                            : tokens[i + j].lowercased()
                        if tokenAtJ != phraseTokens[j] {
                            allMatch = false
                            break
                        }
                    }

                    if allMatch {
                        let lastToken = tokens[i + phraseLen - 1]
                        let lastStripped = stripPunctuation(lastToken)
                        result.append(entry.to + lastStripped.punctuation)
                        i += phraseLen
                        matched = true
                        break
                    }
                }
                if !matched {
                    result.append(tokens[i])
                    i += 1
                }
            } else {
                result.append(tokens[i])
                i += 1
            }
        }

        return result.joined(separator: " ")
    }

    private static func phraseTokenCount(_ phrase: String) -> Int {
        phrase.components(separatedBy: " ").count
    }

    private static func stripPunctuation(_ token: String) -> (word: String, punctuation: String) {
        var word = token
        var punct = ""
        while let last = word.unicodeScalars.last, trailingPunctuation.contains(last) {
            punct = String(last) + punct
            word = String(word.dropLast())
        }
        return (word, punct)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter DictionaryPostProcessorTests 2>&1 | tail -20`
Expected: All 16 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/OpenWisprLib/DictionaryPostProcessor.swift Tests/OpenWisprTests/DictionaryPostProcessorTests.swift
git commit -m "feat: add DictionaryPostProcessor with prompt building and sliding window replacement"
```

---

### Task 3: Wire Prompt Hint into Transcriber

**Files:**
- Modify: `Sources/OpenWisprLib/Transcriber.swift:6` (add property)
- Modify: `Sources/OpenWisprLib/Transcriber.swift:30-33` (add --prompt args)

- [ ] **Step 1: Add customDictionary property to Transcriber**

In `Sources/OpenWisprLib/Transcriber.swift`, after line 6 (`public var spokenPunctuation: Bool = false`), add:

```swift
    public var customDictionary: [DictionaryEntry] = []
```

- [ ] **Step 2: Add --prompt injection to the args array**

In the same file, after the `spokenPunctuation` block (after line 33, `args += ["--suppress-regex", ...`), add:

```swift
        let prompt = DictionaryPostProcessor.buildPrompt(from: customDictionary)
        if !prompt.isEmpty {
            args += ["--prompt", prompt]
        }
```

- [ ] **Step 3: Verify build compiles**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Sources/OpenWisprLib/Transcriber.swift
git commit -m "feat: inject --prompt vocabulary hints from custom dictionary into whisper-cli"
```

---

### Task 4: Wire Post-Processing into AppDelegate

**Files:**
- Modify: `Sources/OpenWisprLib/AppDelegate.swift:38` (setup transcriber dictionary)
- Modify: `Sources/OpenWisprLib/AppDelegate.swift:153-154` (applyConfigChange transcriber dictionary)
- Modify: `Sources/OpenWisprLib/AppDelegate.swift:262` (post-processing in handleRecordingStop)
- Modify: `Sources/OpenWisprLib/AppDelegate.swift:302` (post-processing in reprocess)

- [ ] **Step 1: Set customDictionary on transcriber during setup**

In `Sources/OpenWisprLib/AppDelegate.swift`, after line 38 (`transcriber.spokenPunctuation = config.spokenPunctuation?.value ?? false`), add:

```swift
        transcriber.customDictionary = config.customDictionary ?? []
```

- [ ] **Step 2: Set customDictionary on transcriber during config reload**

In the same file, after line 154 (`transcriber.spokenPunctuation = config.spokenPunctuation?.value ?? false`), add:

```swift
        transcriber.customDictionary = config.customDictionary ?? []
```

- [ ] **Step 3: Add dictionary post-processing in handleRecordingStop**

In the same file, replace line 262:

```swift
                let text = (self.config.spokenPunctuation?.value ?? false) ? TextPostProcessor.process(raw) : raw
```

with:

```swift
                var text = (self.config.spokenPunctuation?.value ?? false) ? TextPostProcessor.process(raw) : raw
                text = DictionaryPostProcessor.process(text, dictionary: self.config.customDictionary ?? [])
```

- [ ] **Step 4: Add dictionary post-processing in reprocess**

In the same file, replace line 302:

```swift
                let text = (self.config.spokenPunctuation?.value ?? false) ? TextPostProcessor.process(raw) : raw
```

with:

```swift
                var text = (self.config.spokenPunctuation?.value ?? false) ? TextPostProcessor.process(raw) : raw
                text = DictionaryPostProcessor.process(text, dictionary: self.config.customDictionary ?? [])
```

- [ ] **Step 5: Verify build compiles**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds.

- [ ] **Step 6: Commit**

```bash
git add Sources/OpenWisprLib/AppDelegate.swift
git commit -m "feat: wire custom dictionary into transcription pipeline (prompt + post-processing)"
```

---

### Task 5: Create DictionaryWindowController

**Files:**
- Create: `Sources/OpenWisprLib/DictionaryWindowController.swift`

- [ ] **Step 1: Create DictionaryWindowController.swift**

Create `Sources/OpenWisprLib/DictionaryWindowController.swift`:

```swift
import AppKit

class DictionaryWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {

    private var tableView: NSTableView!
    private var entries: [DictionaryEntry] = []
    private let fromColumnID = NSUserInterfaceItemIdentifier("from")
    private let toColumnID = NSUserInterfaceItemIdentifier("to")

    static let shared = DictionaryWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 350),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Custom Dictionary"
        window.minSize = NSSize(width: 350, height: 200)
        window.center()

        super.init(window: window)

        setupUI()
        loadEntries()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reload() {
        loadEntries()
        tableView.reloadData()
    }

    private func loadEntries() {
        entries = Config.load().customDictionary ?? []
    }

    private func saveEntries() {
        var config = Config.load()
        let cleaned = entries.filter { !$0.from.isEmpty && !$0.to.isEmpty }
        config.customDictionary = cleaned.isEmpty ? nil : cleaned
        try? config.save()

        if let delegate = NSApplication.shared.delegate as? AppDelegate {
            delegate.reloadConfig()
        }
    }

    private func setupUI() {
        guard let window = self.window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 36, width: contentView.bounds.width, height: contentView.bounds.height - 36))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        tableView = NSTableView()
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.delegate = self
        tableView.dataSource = self

        let fromColumn = NSTableColumn(identifier: fromColumnID)
        fromColumn.title = "Whisper hears"
        fromColumn.width = 180
        fromColumn.isEditable = true
        tableView.addTableColumn(fromColumn)

        let toColumn = NSTableColumn(identifier: toColumnID)
        toColumn.title = "Should be"
        toColumn.width = 180
        toColumn.isEditable = true
        tableView.addTableColumn(toColumn)

        scrollView.documentView = tableView
        contentView.addSubview(scrollView)

        let addButton = NSButton(frame: NSRect(x: 8, y: 4, width: 24, height: 24))
        addButton.bezelStyle = .smallSquare
        addButton.title = "+"
        addButton.target = self
        addButton.action = #selector(addEntry)
        contentView.addSubview(addButton)

        let removeButton = NSButton(frame: NSRect(x: 34, y: 4, width: 24, height: 24))
        removeButton.bezelStyle = .smallSquare
        removeButton.title = "-"
        removeButton.target = self
        removeButton.action = #selector(removeEntry)
        contentView.addSubview(removeButton)

        window.contentView = contentView
    }

    @objc private func addEntry() {
        entries.append(DictionaryEntry(from: "", to: ""))
        tableView.reloadData()
        let newRow = entries.count - 1
        tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        tableView.editColumn(0, row: newRow, with: nil, select: true)
    }

    @objc private func removeEntry() {
        let selected = tableView.selectedRowIndexes
        guard !selected.isEmpty else { return }
        entries.remove(atOffsets: selected)
        tableView.reloadData()
        saveEntries()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row < entries.count, let columnID = tableColumn?.identifier else { return nil }
        if columnID == fromColumnID { return entries[row].from }
        if columnID == toColumnID { return entries[row].to }
        return nil
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard row < entries.count, let columnID = tableColumn?.identifier, let value = object as? String else { return }
        if columnID == fromColumnID {
            entries[row].from = value.trimmingCharacters(in: .whitespaces).lowercased()
        } else if columnID == toColumnID {
            entries[row].to = value.trimmingCharacters(in: .whitespaces)
        }
        saveEntries()
    }
}
```

- [ ] **Step 2: Verify build compiles**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/OpenWisprLib/DictionaryWindowController.swift
git commit -m "feat: add DictionaryWindowController with NSTableView for managing entries"
```

---

### Task 6: Add Menu Item to StatusBarController

**Files:**
- Modify: `Sources/OpenWisprLib/StatusBarController.swift:237-238`

- [ ] **Step 1: Add "Custom Dictionary..." menu item**

In `Sources/OpenWisprLib/StatusBarController.swift`, after line 236 (`menu.addItem(toggleItem)`), add:

```swift
        let dictTarget = MenuItemTarget {
            DictionaryWindowController.shared.showWindow(nil)
            DictionaryWindowController.shared.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(activateIgnoringOtherApps: true)
        }
        menuItemTargets.append(dictTarget)
        let dictItem = NSMenuItem(title: "Custom Dictionary...", action: #selector(MenuItemTarget.invoke), keyEquivalent: "d")
        dictItem.target = dictTarget
        menu.addItem(dictItem)
```

- [ ] **Step 2: Refresh dictionary window on config reload**

In the same file, in the `reloadConfiguration()` method (line 290-292), after line 292 (`delegate.reloadConfig()`), add:

```swift
        DictionaryWindowController.shared.reload()
```

- [ ] **Step 3: Verify build compiles**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds.

- [ ] **Step 4: Run all tests**

Run: `swift test 2>&1 | tail -20`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/OpenWisprLib/StatusBarController.swift
git commit -m "feat: add Custom Dictionary menu item and config reload integration"
```
