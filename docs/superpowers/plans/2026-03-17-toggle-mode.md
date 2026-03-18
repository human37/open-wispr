# Toggle Mode Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `toggleMode` config option so users can press-once-to-start, press-again-to-stop instead of the default hold-to-talk behavior.

**Architecture:** Add a `toggleMode` field (FlexBool, default false) to `Config`. AppDelegate handles the mode switch: in toggle mode, `handleKeyDown` alternates between starting and stopping recording, and `handleKeyUp` becomes a no-op. HotkeyManager remains unchanged.

**Tech Stack:** Swift, XCTest

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `Sources/OpenWisprLib/Config.swift` | Modify | Add `toggleMode` field |
| `Sources/OpenWisprLib/AppDelegate.swift` | Modify | Toggle-aware key handling |
| `Sources/OpenWispr/main.swift` | Modify | Show toggle mode in `status` output |
| `Tests/OpenWisprTests/ConfigTests.swift` | Modify | Tests for `toggleMode` decoding |
| `scripts/test-install.sh` | Modify | Smoke test for toggle mode in status |
| `README.md` | Modify | Document `toggleMode` in config table |

---

## Chunk 1: Config + Tests

### Task 1: Add `toggleMode` to Config

**Files:**
- Modify: `Sources/OpenWisprLib/Config.swift:3-26`
- Modify: `Tests/OpenWisprTests/ConfigTests.swift`

- [ ] **Step 1: Write failing test for toggleMode decoding**

In `Tests/OpenWisprTests/ConfigTests.swift`, add after the `testConfigDecodesWithoutMaxRecordings` test:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ConfigTests 2>&1 | tail -20`
Expected: FAIL - `toggleMode` property does not exist on Config

- [ ] **Step 3: Add `toggleMode` field to Config**

In `Sources/OpenWisprLib/Config.swift`, add the property to the struct (after `maxRecordings`):

```swift
public var toggleMode: FlexBool?
```

Update `defaultConfig` to include `toggleMode`:

```swift
public static let defaultConfig = Config(
    hotkey: HotkeyConfig(keyCode: 63, modifiers: []),
    modelPath: nil,
    modelSize: "base.en",
    language: "en",
    spokenPunctuation: FlexBool(false),
    maxRecordings: nil,
    toggleMode: FlexBool(false)
)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ConfigTests 2>&1 | tail -20`
Expected: All ConfigTests PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/OpenWisprLib/Config.swift Tests/OpenWisprTests/ConfigTests.swift
git commit -m "feat: add toggleMode config option"
```

---

## Chunk 2: AppDelegate Toggle Logic

### Task 2: Implement toggle behavior in AppDelegate

**Files:**
- Modify: `Sources/OpenWisprLib/AppDelegate.swift:142-163`

- [ ] **Step 1: Add toggle-mode key handling to AppDelegate**

The current flow uses `handleKeyDown` to start recording and `handleKeyUp` to stop. In toggle mode, `handleKeyDown` alternates between start/stop and `handleKeyUp` is ignored.

In `AppDelegate.swift`, replace `handleKeyDown()` and `handleKeyUp()` with:

```swift
private func handleKeyDown() {
    guard isReady else { return }

    let isToggle = config.toggleMode?.value ?? false

    if isToggle {
        if isPressed {
            handleRecordingStop()
        } else {
            handleRecordingStart()
        }
    } else {
        guard !isPressed else { return }
        handleRecordingStart()
    }
}

private func handleKeyUp() {
    let isToggle = config.toggleMode?.value ?? false
    if isToggle { return }

    handleRecordingStop()
}

private func handleRecordingStart() {
    guard !isPressed else { return }
    isPressed = true
    statusBar.state = .recording
    do {
        let outputURL: URL
        if Config.effectiveMaxRecordings(config.maxRecordings) == 0 {
            outputURL = RecordingStore.tempRecordingURL()
        } else {
            outputURL = RecordingStore.newRecordingURL()
        }
        try recorder.startRecording(to: outputURL)
    } catch {
        print("Error: \(error.localizedDescription)")
        isPressed = false
        statusBar.state = .idle
    }
}

private func handleRecordingStop() {
    guard isPressed else { return }
    isPressed = false

    guard let audioURL = recorder.stopRecording() else {
        statusBar.state = .idle
        return
    }

    statusBar.state = .transcribing

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        guard let self = self else { return }
        let maxRecordings = Config.effectiveMaxRecordings(self.config.maxRecordings)
        defer {
            if maxRecordings == 0 {
                try? FileManager.default.removeItem(at: audioURL)
            }
        }
        do {
            let raw = try self.transcriber.transcribe(audioURL: audioURL)
            let text = (self.config.spokenPunctuation?.value ?? false) ? TextPostProcessor.process(raw) : raw
            if maxRecordings > 0 {
                RecordingStore.prune(maxCount: maxRecordings)
            }
            DispatchQueue.main.async {
                if !text.isEmpty {
                    self.lastTranscription = text
                    self.inserter.insert(text: text)
                }
                self.statusBar.state = .idle
                self.statusBar.buildMenu()
            }
        } catch {
            if maxRecordings > 0 {
                RecordingStore.prune(maxCount: maxRecordings)
            }
            DispatchQueue.main.async {
                print("Error: \(error.localizedDescription)")
                self.statusBar.state = .idle
                self.statusBar.buildMenu()
            }
        }
    }
}
```

- [ ] **Step 2: Verify build succeeds**

Run: `swift build 2>&1 | tail -5`
Expected: Build complete

- [ ] **Step 3: Run full test suite**

Run: `swift test 2>&1 | tail -10`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add Sources/OpenWisprLib/AppDelegate.swift
git commit -m "feat: implement toggle mode key handling"
```

---

## Chunk 3: Status Output + Documentation

### Task 3: Show toggle mode in status command

**Files:**
- Modify: `Sources/OpenWispr/main.swift:107-117`

- [ ] **Step 1: Add toggle mode to status output**

In `main.swift`, in the `cmdStatus()` function, add a line after the `whisper-cpp` line:

```swift
let toggleMode = config.toggleMode?.value ?? false
print("Toggle:      \(toggleMode ? "on (press to start/stop)" : "off (hold to talk)")")
```

- [ ] **Step 2: Verify build succeeds**

Run: `swift build 2>&1 | tail -5`
Expected: Build complete

- [ ] **Step 3: Commit**

```bash
git add Sources/OpenWispr/main.swift
git commit -m "feat: show toggle mode in status output"
```

### Task 4: Add install smoke test for toggle mode in status

**Files:**
- Modify: `scripts/test-install.sh`

- [ ] **Step 1: Add status check for toggle mode**

In `scripts/test-install.sh`, add after the `status shows config path` line (grouping with the other status checks):

```bash
check_output "status shows toggle mode" "Toggle:" "$BIN" status
```

- [ ] **Step 2: Commit**

```bash
git add scripts/test-install.sh
git commit -m "test: add toggle mode status smoke test"
```

### Task 5: Document toggleMode in README

**Files:**
- Modify: `README.md:42-60`

- [ ] **Step 1: Add toggleMode to README config JSON example**

In `README.md`, add `"toggleMode": false` as the last field in the existing example JSON block (after `"maxRecordings": 0`). Do not add or remove any other fields.

- [ ] **Step 2: Add toggleMode to README config table**

In `README.md`, add a row to the configuration options table after `maxRecordings`:

```markdown
| **toggleMode** | `false` | Press hotkey once to start recording, press again to stop. Default is hold-to-talk. |
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add toggleMode to configuration docs"
```
