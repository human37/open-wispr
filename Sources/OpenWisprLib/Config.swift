import Foundation

public struct LanguageOption: Equatable, Sendable {
    public let code: String
    public let name: String
}

public struct Config: Codable {
    public var hotkey: HotkeyConfig
    public var modelPath: String?
    public var modelSize: String
    public var language: String
    public var spokenPunctuation: FlexBool?
    public var maxRecordings: Int?
    public var toggleMode: FlexBool?
    public var inputMethod: String?

    public static let supportedLanguages: [LanguageOption] = [
        LanguageOption(code: "auto", name: "Auto-Detect"),
        LanguageOption(code: "en", name: "English"),
        LanguageOption(code: "zh", name: "Chinese"),
        LanguageOption(code: "de", name: "German"),
        LanguageOption(code: "es", name: "Spanish"),
        LanguageOption(code: "ru", name: "Russian"),
        LanguageOption(code: "ko", name: "Korean"),
        LanguageOption(code: "fr", name: "French"),
        LanguageOption(code: "ja", name: "Japanese"),
        LanguageOption(code: "pt", name: "Portuguese"),
        LanguageOption(code: "tr", name: "Turkish"),
        LanguageOption(code: "pl", name: "Polish"),
        LanguageOption(code: "ca", name: "Catalan"),
        LanguageOption(code: "nl", name: "Dutch"),
        LanguageOption(code: "ar", name: "Arabic"),
        LanguageOption(code: "sv", name: "Swedish"),
        LanguageOption(code: "it", name: "Italian"),
        LanguageOption(code: "id", name: "Indonesian"),
        LanguageOption(code: "hi", name: "Hindi"),
        LanguageOption(code: "fi", name: "Finnish"),
        LanguageOption(code: "vi", name: "Vietnamese"),
        LanguageOption(code: "he", name: "Hebrew"),
        LanguageOption(code: "uk", name: "Ukrainian"),
        LanguageOption(code: "el", name: "Greek"),
        LanguageOption(code: "ms", name: "Malay"),
        LanguageOption(code: "cs", name: "Czech"),
        LanguageOption(code: "ro", name: "Romanian"),
        LanguageOption(code: "da", name: "Danish"),
        LanguageOption(code: "hu", name: "Hungarian"),
        LanguageOption(code: "ta", name: "Tamil"),
        LanguageOption(code: "no", name: "Norwegian"),
        LanguageOption(code: "th", name: "Thai"),
        LanguageOption(code: "ur", name: "Urdu"),
        LanguageOption(code: "hr", name: "Croatian"),
        LanguageOption(code: "bg", name: "Bulgarian"),
        LanguageOption(code: "lt", name: "Lithuanian"),
        LanguageOption(code: "la", name: "Latin"),
        LanguageOption(code: "mi", name: "Maori"),
        LanguageOption(code: "ml", name: "Malayalam"),
        LanguageOption(code: "cy", name: "Welsh"),
        LanguageOption(code: "sk", name: "Slovak"),
        LanguageOption(code: "te", name: "Telugu"),
        LanguageOption(code: "fa", name: "Persian"),
        LanguageOption(code: "lv", name: "Latvian"),
        LanguageOption(code: "bn", name: "Bengali"),
        LanguageOption(code: "sr", name: "Serbian"),
        LanguageOption(code: "az", name: "Azerbaijani"),
        LanguageOption(code: "sl", name: "Slovenian"),
        LanguageOption(code: "kn", name: "Kannada"),
        LanguageOption(code: "et", name: "Estonian"),
        LanguageOption(code: "mk", name: "Macedonian"),
        LanguageOption(code: "br", name: "Breton"),
        LanguageOption(code: "eu", name: "Basque"),
        LanguageOption(code: "is", name: "Icelandic"),
        LanguageOption(code: "hy", name: "Armenian"),
        LanguageOption(code: "ne", name: "Nepali"),
        LanguageOption(code: "mn", name: "Mongolian"),
        LanguageOption(code: "bs", name: "Bosnian"),
        LanguageOption(code: "kk", name: "Kazakh"),
        LanguageOption(code: "sq", name: "Albanian"),
        LanguageOption(code: "sw", name: "Swahili"),
        LanguageOption(code: "gl", name: "Galician"),
        LanguageOption(code: "mr", name: "Marathi"),
        LanguageOption(code: "pa", name: "Punjabi"),
        LanguageOption(code: "si", name: "Sinhala"),
        LanguageOption(code: "km", name: "Khmer"),
        LanguageOption(code: "sn", name: "Shona"),
        LanguageOption(code: "yo", name: "Yoruba"),
        LanguageOption(code: "so", name: "Somali"),
        LanguageOption(code: "af", name: "Afrikaans"),
        LanguageOption(code: "oc", name: "Occitan"),
        LanguageOption(code: "ka", name: "Georgian"),
        LanguageOption(code: "be", name: "Belarusian"),
        LanguageOption(code: "tg", name: "Tajik"),
        LanguageOption(code: "sd", name: "Sindhi"),
        LanguageOption(code: "gu", name: "Gujarati"),
        LanguageOption(code: "am", name: "Amharic"),
        LanguageOption(code: "yi", name: "Yiddish"),
        LanguageOption(code: "lo", name: "Lao"),
        LanguageOption(code: "uz", name: "Uzbek"),
        LanguageOption(code: "fo", name: "Faroese"),
        LanguageOption(code: "ht", name: "Haitian Creole"),
        LanguageOption(code: "ps", name: "Pashto"),
        LanguageOption(code: "tk", name: "Turkmen"),
        LanguageOption(code: "nn", name: "Nynorsk"),
        LanguageOption(code: "mt", name: "Maltese"),
        LanguageOption(code: "sa", name: "Sanskrit"),
        LanguageOption(code: "lb", name: "Luxembourgish"),
        LanguageOption(code: "my", name: "Myanmar"),
        LanguageOption(code: "bo", name: "Tibetan"),
        LanguageOption(code: "tl", name: "Tagalog"),
        LanguageOption(code: "mg", name: "Malagasy"),
        LanguageOption(code: "as", name: "Assamese"),
        LanguageOption(code: "tt", name: "Tatar"),
        LanguageOption(code: "haw", name: "Hawaiian"),
        LanguageOption(code: "ln", name: "Lingala"),
        LanguageOption(code: "ha", name: "Hausa"),
        LanguageOption(code: "ba", name: "Bashkir"),
        LanguageOption(code: "jw", name: "Javanese"),
        LanguageOption(code: "su", name: "Sundanese"),
    ]

    public static let supportedModels: [String] = [
        "tiny.en", "tiny",
        "base.en", "base",
        "small.en", "small",
        "medium.en", "medium",
        "large-v3-turbo", "large",
    ]

    public static let defaultMaxRecordings = 0

    public static func effectiveMaxRecordings(_ value: Int?) -> Int {
        let raw = value ?? Config.defaultMaxRecordings
        if raw == 0 { return 0 }
        return min(max(1, raw), 100)
    }

    public static let defaultConfig = Config(
        hotkey: HotkeyConfig(keyCode: 63, modifiers: []),
        modelPath: nil,
        modelSize: "base.en",
        language: "en",
        spokenPunctuation: FlexBool(false),
        maxRecordings: nil,
        toggleMode: FlexBool(false),
        inputMethod: nil
    )

    public static var configDir: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/open-wispr")
    }

    public static var configFile: URL {
        configDir.appendingPathComponent("config.json")
    }

    public static func load() -> Config {
        guard let data = try? Data(contentsOf: configFile) else {
            let config = Config.defaultConfig
            try? config.save()
            return config
        }

        do {
            return try JSONDecoder().decode(Config.self, from: data)
        } catch {
            fputs("Warning: unable to parse \(configFile.path): \(error.localizedDescription)\n", stderr)
            return Config.defaultConfig
        }
    }

    public static func decode(from data: Data) throws -> Config {
        return try JSONDecoder().decode(Config.self, from: data)
    }

    public func save() throws {
        try FileManager.default.createDirectory(at: Config.configDir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(self)
        try data.write(to: Config.configFile)
    }
}

public struct FlexBool: Codable {
    public let value: Bool

    public init(_ value: Bool) { self.value = value }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let b = try? container.decode(Bool.self) {
            value = b
        } else if let s = try? container.decode(String.self) {
            value = ["true", "yes", "1"].contains(s.lowercased())
        } else if let i = try? container.decode(Int.self) {
            value = i != 0
        } else {
            value = false
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

public struct HotkeyConfig: Codable {
    public var keyCode: UInt16
    public var modifiers: [String]

    public init(keyCode: UInt16, modifiers: [String]) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public var modifierFlags: UInt64 {
        var flags: UInt64 = 0
        for mod in modifiers {
            switch mod.lowercased() {
            case "cmd", "command": flags |= UInt64(1 << 20)
            case "shift": flags |= UInt64(1 << 17)
            case "ctrl", "control": flags |= UInt64(1 << 18)
            case "opt", "option", "alt": flags |= UInt64(1 << 19)
            default: break
            }
        }
        return flags
    }
}
