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
