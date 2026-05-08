import Foundation
import KanaKanjiConverterModuleWithDefaultDictionary

enum SpanKind: String, Codable {
    case japanese
    case english
}

enum ConversionMode: String, Codable {
    case dictionaryOnly
    case zenzaiDisabledForMVP
}

struct AdapterInput: Codable {
    var rawRomaji: String
    var kana: String
    var contextBefore: String
    var contextAfter: String
    var maxCandidates: Int
    var conversionMode: ConversionMode
}

struct DetectedSpan: Codable {
    var raw: String
    var kind: SpanKind
    var kana: String?
}

struct AdapterOutput: Codable {
    var input: AdapterInput
    var mainCandidate: String
    var candidates: [String]
    var segments: [String]
    var coldStartMs: Double
    var requestLatencyMs: Double
    var contextPassed: String
}

struct BenchmarkCase: Codable {
    var raw: String
    var spans: [DetectedSpan]
    var conversions: [AdapterOutput]
}

struct HarnessReport: Codable {
    var converter: String
    var minimumIOSTarget: String
    var zenzaiMode: String
    var learningType: String
    var coldStartMs: Double
    var cases: [BenchmarkCase]
}

let englishWords: Set<String> = [
    "amazing", "and", "are", "be", "call", "can", "car", "computer", "for",
    "from", "get", "going", "hello", "honest", "in", "is", "it", "meeting",
    "no", "problem", "smart", "strong", "that", "the", "this", "to", "was",
    "we", "with", "you",
]

let embeddedEnglishWords = englishWords.filter { $0.count >= 4 }.sorted { lhs, rhs in
    if lhs.count == rhs.count { return lhs < rhs }
    return lhs.count > rhs.count
}

let kanaTable: [String: String] = [
    "a": "あ", "i": "い", "u": "う", "e": "え", "o": "お",
    "ka": "か", "ki": "き", "ku": "く", "ke": "け", "ko": "こ",
    "sa": "さ", "si": "し", "shi": "し", "su": "す", "se": "せ", "so": "そ",
    "ta": "た", "ti": "ち", "chi": "ち", "tu": "つ", "tsu": "つ", "te": "て", "to": "と",
    "na": "な", "ni": "に", "nu": "ぬ", "ne": "ね", "no": "の",
    "ha": "は", "hi": "ひ", "hu": "ふ", "fu": "ふ", "he": "へ", "ho": "ほ",
    "ma": "ま", "mi": "み", "mu": "む", "me": "め", "mo": "も",
    "ya": "や", "yu": "ゆ", "yo": "よ",
    "ra": "ら", "ri": "り", "ru": "る", "re": "れ", "ro": "ろ",
    "wa": "わ", "wi": "うぃ", "we": "うぇ", "wo": "を", "n": "ん", "nn": "ん",
    "ga": "が", "gi": "ぎ", "gu": "ぐ", "ge": "げ", "go": "ご",
    "za": "ざ", "zi": "じ", "ji": "じ", "zu": "ず", "ze": "ぜ", "zo": "ぞ",
    "da": "だ", "di": "ぢ", "du": "づ", "de": "で", "do": "ど",
    "ba": "ば", "bi": "び", "bu": "ぶ", "be": "べ", "bo": "ぼ",
    "pa": "ぱ", "pi": "ぴ", "pu": "ぷ", "pe": "ぺ", "po": "ぽ",
    "kya": "きゃ", "kyu": "きゅ", "kyo": "きょ",
    "sha": "しゃ", "shu": "しゅ", "sho": "しょ", "sya": "しゃ", "syu": "しゅ", "syo": "しょ",
    "cha": "ちゃ", "chu": "ちゅ", "cho": "ちょ", "tya": "ちゃ", "tyu": "ちゅ", "tyo": "ちょ",
    "nya": "にゃ", "nyu": "にゅ", "nyo": "にょ",
    "hya": "ひゃ", "hyu": "ひゅ", "hyo": "ひょ",
    "mya": "みゃ", "myu": "みゅ", "myo": "みょ",
    "rya": "りゃ", "ryu": "りゅ", "ryo": "りょ",
    "gya": "ぎゃ", "gyu": "ぎゅ", "gyo": "ぎょ",
    "ja": "じゃ", "ju": "じゅ", "jo": "じょ", "jya": "じゃ", "jyu": "じゅ", "jyo": "じょ",
    "bya": "びゃ", "byu": "びゅ", "byo": "びょ",
    "pya": "ぴゃ", "pyu": "ぴゅ", "pyo": "ぴょ",
    "fa": "ふぁ", "fi": "ふぃ", "fe": "ふぇ", "fo": "ふぉ",
]

let consonants = Set("bcdfghjklmnpqrstvwxyz")
let vowels = Set("aiueo")

func elapsedMs(_ block: () -> Void) -> Double {
    let start = DispatchTime.now().uptimeNanoseconds
    block()
    let end = DispatchTime.now().uptimeNanoseconds
    return Double(end - start) / 1_000_000
}

func romajiToKana(_ raw: String) -> String {
    let chars = Array(raw.lowercased())
    var index = 0
    var output = ""

    while index < chars.count {
        let current = chars[index]
        let next = index + 1 < chars.count ? chars[index + 1] : "\0"

        if current == "-" {
            output += "ー"
            index += 1
            continue
        }

        if current.isNumber {
            output.append(current)
            index += 1
            continue
        }

        if current == "n", next == "'" {
            output += "ん"
            index += 2
            continue
        }

        if current == "n", next == "n" {
            output += "ん"
            index += 2
            continue
        }

        if current == "n", next != "\0", !vowels.contains(next), next != "y" {
            output += "ん"
            index += 1
            continue
        }

        if consonants.contains(current), current == next, current != "n" {
            output += "っ"
            index += 1
            continue
        }

        var matched = false
        for length in [3, 2, 1] where index + length <= chars.count {
            let piece = String(chars[index ..< index + length])
            if let kana = kanaTable[piece] {
                output += kana
                index += length
                matched = true
                break
            }
        }

        if !matched {
            output.append(current)
            index += 1
        }
    }

    return output
}

func splitEmbeddedEnglish(_ word: String) -> [DetectedSpan] {
    let lower = word.lowercased()
    var spans: [DetectedSpan] = []
    var index = lower.startIndex
    var japaneseBuffer = ""

    while index < lower.endIndex {
        let suffix = lower[index...]
        if let match = embeddedEnglishWords.first(where: { suffix.hasPrefix($0) }) {
            if !japaneseBuffer.isEmpty {
                spans.append(.init(raw: japaneseBuffer, kind: .japanese, kana: romajiToKana(japaneseBuffer)))
                japaneseBuffer = ""
            }
            spans.append(.init(raw: match, kind: .english, kana: nil))
            index = lower.index(index, offsetBy: match.count)
        } else {
            japaneseBuffer.append(lower[index])
            index = lower.index(after: index)
        }
    }

    if !japaneseBuffer.isEmpty {
        let wholeWordIsEnglish = spans.isEmpty && englishWords.contains(japaneseBuffer)
        spans.append(.init(
            raw: japaneseBuffer,
            kind: wholeWordIsEnglish ? .english : .japanese,
            kana: wholeWordIsEnglish ? nil : romajiToKana(japaneseBuffer)
        ))
    }

    return spans
}

func detectSpans(_ raw: String) -> [DetectedSpan] {
    raw.split(separator: " ").flatMap { token -> [DetectedSpan] in
        splitEmbeddedEnglish(String(token))
    }
}

final class ConversionHarness {
    private let converter: KanaKanjiConverter
    let coldStartMs: Double

    init() {
        var localConverter: KanaKanjiConverter?
        self.coldStartMs = elapsedMs {
            localConverter = KanaKanjiConverter.withDefaultDictionary()
        }
        self.converter = localConverter!
    }

    func convert(_ input: AdapterInput) -> AdapterOutput {
        var composingText = ComposingText()
        composingText.insertAtCursorPosition(input.kana, inputStyle: .direct)

        let supportURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "KanaKanjiHarness",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)

        var resultCandidates: [String] = []
        let requestLatencyMs = elapsedMs {
            let results = converter.requestCandidates(composingText, options: .init(
                N_best: input.maxCandidates,
                requireJapanesePrediction: .disabled,
                requireEnglishPrediction: .disabled,
                keyboardLanguage: .ja_JP,
                englishCandidateInRoman2KanaInput: true,
                fullWidthRomanCandidate: false,
                halfWidthKanaCandidate: false,
                learningType: .nothing,
                maxMemoryCount: 0,
                shouldResetMemory: false,
                memoryDirectoryURL: supportURL,
                sharedContainerURL: supportURL,
                textReplacer: .withDefaultEmojiDictionary(),
                specialCandidateProviders: KanaKanjiConverter.defaultSpecialCandidateProviders,
                zenzaiMode: .off,
                metadata: .init(versionString: "KanaKanjiHarness/0.1")
            ))
            resultCandidates = Array(results.mainResults.prefix(input.maxCandidates).map(\.text))
        }

        return AdapterOutput(
            input: input,
            mainCandidate: resultCandidates.first ?? input.kana,
            candidates: resultCandidates,
            segments: [],
            coldStartMs: coldStartMs,
            requestLatencyMs: requestLatencyMs,
            contextPassed: input.contextBefore
        )
    }
}

let defaultCases = [
    "hashiwowatarumaenitaberu",
    "watashihaashitano",
    "kyounomeetingha3jini",
    "watashihaashitano meeting niiku",
    "korekara we can get in the car",
    "hashi",
    "hana",
    "kaeru",
]

let rawCases = CommandLine.arguments.dropFirst().isEmpty
    ? defaultCases
    : Array(CommandLine.arguments.dropFirst())

let harness = ConversionHarness()
var cases: [BenchmarkCase] = []

for raw in rawCases {
    let spans = detectSpans(raw)
    var contextBefore = ""
    var conversions: [AdapterOutput] = []

    for span in spans {
        switch span.kind {
        case .english:
            contextBefore += span.raw
        case .japanese:
            guard let kana = span.kana else { continue }
            let input = AdapterInput(
                rawRomaji: span.raw,
                kana: kana,
                contextBefore: contextBefore,
                contextAfter: "",
                maxCandidates: 10,
                conversionMode: .dictionaryOnly
            )
            let output = harness.convert(input)
            conversions.append(output)
            contextBefore += output.mainCandidate
        }
    }

    cases.append(.init(raw: raw, spans: spans, conversions: conversions))
}

let report = HarnessReport(
    converter: "AzooKeyKanaKanjiConverter",
    minimumIOSTarget: "iOS 16+",
    zenzaiMode: "off",
    learningType: "nothing",
    coldStartMs: harness.coldStartMs,
    cases: cases
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
let data = try encoder.encode(report)
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data("\n".utf8))
