import Foundation

/// Deterministic rule-based text polishing applied to the Whisper transcript
/// before it gets pasted. No AI, no network.
///
/// Pipeline:
///   1. Voice commands  — "new line" → "\n" etc.   (opt-in)
///   2. Filler removal  — um / uh / like / you know … (opt-in)
///   3. Spacing         — collapse double spaces, fix space-before-punctuation
///   4. Capitalization  — sentence starts + standalone "i"
///
/// Steps 1 and 2 are off by default and gated by the caller. Voice commands
/// duplicate `TextPostProcessor` and must follow the same `spokenPunctuation`
/// gate, or "comma" gets substituted for users who turned that off. Filler
/// removal matches ordinary English words ("like", "actually", …) so it can
/// never run unconditionally. Spacing and capitalization are always safe.
public enum TextPolisher {

    // MARK: - Defaults

    static let voiceCommands: [(pattern: String, replacement: String)] = [
        ("new paragraph", "\n\n"),
        ("new line", "\n"),
        ("open paren", "("),
        ("close paren", ")"),
        ("open bracket", "["),
        ("close bracket", "]"),
        ("open brace", "{"),
        ("close brace", "}"),
        ("exclamation point", "!"),
        ("question mark", "?"),
        ("period", "."),
        ("comma", ","),
        ("colon", ":"),
        ("semicolon", ";"),
        ("ellipsis", "..."),
        ("dash", "-"),
        ("hyphen", "-"),
    ]

    static let fillers: [String] = [
        "you know", "i mean", "sort of", "kind of", "i guess", "or whatever",
        "you see", "um", "uh", "uhh", "umm", "erm", "ah",
        "like", "basically", "literally", "actually",
    ]

    // MARK: - Public entry point

    /// - Parameters:
    ///   - voiceCommands: substitute "comma" → "," etc. Pass the same value as
    ///     the `spokenPunctuation` setting so this can't bypass that gate.
    ///   - removeFillers: strip disfluencies/fillers. Off by default because the
    ///     list includes ordinary English words.
    public static func polish(
        _ text: String,
        voiceCommands: Bool = false,
        removeFillers: Bool = false
    ) -> String {
        var s = text
        if voiceCommands { s = applyVoiceCommands(s) }
        if removeFillers { s = removeFillerWords(s) }
        s = fixSpacing(s)
        s = fixCapitalization(s)
        return s
    }

    // MARK: - Steps

    private static func applyVoiceCommands(_ text: String) -> String {
        var s = text
        // Longest first so "new paragraph" wins over "new"
        for cmd in voiceCommands.sorted(by: { $0.pattern.count > $1.pattern.count }) {
            s = wholeWordReplace(s, find: cmd.pattern, replace: cmd.replacement)
        }
        return s
    }

    private static func removeFillerWords(_ text: String) -> String {
        var s = text
        for filler in fillers.sorted(by: { $0.count > $1.count }) {
            // whole word/phrase, optionally followed by a comma
            let pat = "(?i)(?<!\\w)\(NSRegularExpression.escapedPattern(for: filler))(?!\\w),?"
            if let re = try? NSRegularExpression(pattern: pat) {
                let range = NSRange(s.startIndex..., in: s)
                s = re.stringByReplacingMatches(in: s, range: range, withTemplate: "")
            }
        }
        return s
    }

    private static func fixSpacing(_ text: String) -> String {
        var s = text
        // Collapse multiple spaces/tabs
        s = re(s, "[ \\t]+", " ")
        // No space before close punctuation
        s = re(s, "\\s+([,.;:!?\\)\\]])", "$1")
        // No space after open brackets
        s = re(s, "([\\(\\[]) +", "$1")
        // Space after sentence punctuation, but only when preceded by 2+ word chars
        // and followed by a capital/opening quote. Splits run-on sentences ("end.Next")
        // without breaking URLs, emails, decimals, or abbreviations (github.com, e.g., U.S.).
        s = re(s, "(?<=\\w\\w)([.!?])(?=[\"'A-Z])", "$1 ")
        // Space after comma/colon/semicolon glued to a letter (protects http:// and decimals/times).
        s = re(s, "([,;:])(?=[A-Za-z])", "$1 ")
        // Tidy newlines
        s = re(s, " *\\n *", "\n")
        s = re(s, "\\n{3,}", "\n\n")
        return s.trimmingCharacters(in: .whitespaces)
    }

    private static func fixCapitalization(_ text: String) -> String {
        var s = text
        // Capitalize first letter after sentence-end or start of string. The
        // sentence-end form requires 2+ word chars before the punctuation so
        // abbreviations ("U.S. last") don't capitalize the following word.
        if let re = try? NSRegularExpression(pattern: "(?:^|(?<=\\w\\w)[.!?]\\s+|\\n)([a-z])") {
            var result = s
            let matches = re.matches(in: s, range: NSRange(s.startIndex..., in: s)).reversed()
            for match in matches {
                guard let charRange = Range(match.range(at: 1), in: s) else { continue }
                result.replaceSubrange(charRange, with: s[charRange].uppercased())
            }
            s = result
        }
        // Standalone "i" → "I"
        s = re(s, "(?<!\\w)i(?!\\w)", "I")
        s = re(s, "(?<!\\w)i'", "I'")
        return s
    }

    // MARK: - Helpers

    private static func wholeWordReplace(_ text: String, find: String, replace: String) -> String {
        let pat = "(?i)(?<!\\w)\(NSRegularExpression.escapedPattern(for: find))(?!\\w)"
        guard let re = try? NSRegularExpression(pattern: pat) else { return text }
        return re.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text),
            withTemplate: NSRegularExpression.escapedTemplate(for: replace)
        )
    }

    private static func re(_ text: String, _ pattern: String, _ replacement: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return text }
        return re.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text),
            withTemplate: replacement
        )
    }
}
