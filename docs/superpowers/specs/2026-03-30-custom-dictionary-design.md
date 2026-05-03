# Custom Dictionary Support

**GitHub Issue:** #34

**Goal:** Allow users to define word/phrase corrections that Whisper consistently gets wrong, applied both as model hints during inference and as exact-match replacements after transcription.

## Config & Data Model

Add a `DictionaryEntry` struct and optional `customDictionary` field to the existing `Config` struct in `Config.swift`.

```swift
public struct DictionaryEntry: Codable, Equatable {
    public var from: String
    public var to: String
}
```

Config JSON example:

```json
{
  "hotkey": { "keyCode": 63, "modifiers": [] },
  "modelSize": "base.en",
  "language": "en",
  "customDictionary": [
    { "from": "nural", "to": "neural" },
    { "from": "chat gee pee tee", "to": "ChatGPT" }
  ]
}
```

- `from` is stored and matched lowercased (case-insensitive matching)
- The field is `[DictionaryEntry]?` so existing configs without it continue to work
- No UUIDs or IDs needed -- entries are identified by position in the array

## Transcription Integration

### Layer 1: Prompt Hint (Transcriber.swift)

Add a `customDictionary: [DictionaryEntry]` property to `Transcriber`, set from config the same way `spokenPunctuation` is set today.

When the array is non-empty, append to the whisper-cli args:

```
--prompt "Vocabulary: neural, ChatGPT."
```

This is built by joining the unique `to` values with commas. The prompt biases whisper's decoder toward recognizing these words. The `--prompt` flag is already supported by whisper-cli (confirmed: `--prompt PROMPT [default: ] initial prompt (max n_text_ctx/2 tokens)`).

### Layer 2: Post-Processing (new DictionaryPostProcessor.swift)

After transcription (and after `TextPostProcessor` if spoken punctuation is enabled), run dictionary replacement on the output.

**Algorithm -- greedy sliding window for multi-word support:**

1. Tokenize transcript into words (split on whitespace)
2. Pre-compute: group dictionary entries by their first token (lowercased) for O(1) lookup
3. For each position in the token array:
   a. Check if the current token (lowercased) matches any entry's first word
   b. If so, try matching the full phrase (longest match first / greedy)
   c. On match: emit the `to` value, preserve trailing punctuation from the last matched token, advance index past matched tokens
   d. No match: emit the original token, advance by 1
4. Join tokens back with spaces

**Punctuation handling:** Strip trailing punctuation (.,!?;:) from the last token before comparison, reattach after replacement.

**Exact match only.** No fuzzy/Levenshtein matching. Users add multiple entries for different misspellings they encounter.

**Integration point in AppDelegate.swift (~line 262):**

```swift
let raw = try self.transcriber.transcribe(audioURL: audioURL)
var text = (self.config.spokenPunctuation?.value ?? false) ? TextPostProcessor.process(raw) : raw
text = DictionaryPostProcessor.process(text, dictionary: self.config.customDictionary ?? [])
```

## Settings Window (DictionaryWindowController.swift)

A new AppKit `NSWindowController` subclass that presents a dictionary management window.

### Window Layout

- **Title:** "Custom Dictionary"
- **Size:** ~400x350, resizable vertically
- **NSTableView** with two editable columns:
  - "Whisper hears" (the `from` value)
  - "Should be" (the `to` value)
- **Toolbar buttons** below the table:
  - (+) Add: appends a new blank row, begins editing in the first column
  - (-) Remove: deletes the selected row(s)
- No separate save/cancel buttons -- changes persist to config on each edit (consistent with how the menu-based settings work: immediate persistence)

### Behavior

- Editing a cell commits the change to config when the field loses focus
- Empty rows (where both fields are blank) are discarded on commit
- The window is a singleton -- clicking the menu item when it's already open brings it to front
- Reloading configuration from the menu also refreshes the window if open

### Menu Integration (StatusBarController.swift)

Add a "Custom Dictionary..." menu item with keyboard shortcut `d`, placed between "Toggle Mode" and the separator before "Copy Last Dictation":

```
Toggle Mode
Custom Dictionary...    (d)
---
Copy Last Dictation     (c)
```

Clicking opens/focuses the dictionary window.

## File Changes Summary

| Action | File | What Changes |
|--------|------|-------------|
| Edit | `Config.swift` | Add `DictionaryEntry` struct, add `customDictionary: [DictionaryEntry]?` to `Config`, add to `defaultConfig` as `nil` |
| Edit | `Transcriber.swift` | Add `customDictionary` property, append `--prompt` args when non-empty |
| Edit | `AppDelegate.swift` | Wire `customDictionary` into transcriber setup + add post-processing call after transcription |
| Edit | `StatusBarController.swift` | Add "Custom Dictionary..." menu item that opens the window |
| Create | `DictionaryPostProcessor.swift` | Prompt building + sliding window exact-match replacement logic |
| Create | `DictionaryWindowController.swift` | NSWindow with NSTableView for managing entries |

## Testing

- `DictionaryPostProcessor` is pure logic with no UI dependencies -- unit testable
- Test cases: single word replacement, multi-word phrase replacement, punctuation preservation, case insensitivity, no-match passthrough, empty dictionary passthrough, overlapping phrases (greedy longest match)
- Prompt building: verify correct `--prompt` string generation from entries
