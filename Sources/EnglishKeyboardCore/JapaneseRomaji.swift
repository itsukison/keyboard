import Foundation

public enum JapaneseRomaji {
    static let kanaTable: [String: String] = [
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
        "xa": "ぁ", "xi": "ぃ", "xu": "ぅ", "xe": "ぇ", "xo": "ぉ",
        "la": "ぁ", "li": "ぃ", "lu": "ぅ", "le": "ぇ", "lo": "ぉ",
        "xya": "ゃ", "xyu": "ゅ", "xyo": "ょ", "lya": "ゃ", "lyu": "ゅ", "lyo": "ょ",
        "xtu": "っ", "xtsu": "っ", "ltu": "っ", "ltsu": "っ",
        "xwa": "ゎ", "lwa": "ゎ", "xka": "ヵ", "xke": "ヶ", "lka": "ヵ", "lke": "ヶ", "xn": "ん",
        "va": "ゔぁ", "vi": "ゔぃ", "vu": "ゔ", "ve": "ゔぇ", "vo": "ゔぉ",
        "vya": "ゔゃ", "vyu": "ゔゅ", "vyo": "ゔょ",
        "tsa": "つぁ", "tsi": "つぃ", "tse": "つぇ", "tso": "つぉ",
        "tha": "てゃ", "thi": "てぃ", "thu": "てゅ", "the": "てぇ", "tho": "てょ",
        "dha": "でゃ", "dhi": "でぃ", "dhu": "でゅ", "dhe": "でぇ", "dho": "でょ",
        "twa": "とぁ", "twi": "とぃ", "twu": "とぅ", "twe": "とぇ", "two": "とぉ",
        "dwa": "どぁ", "dwi": "どぃ", "dwu": "どぅ", "dwe": "どぇ", "dwo": "どぉ",
        "she": "しぇ", "che": "ちぇ", "je": "じぇ",
        "sye": "しぇ", "zye": "じぇ", "jye": "じぇ", "cye": "ちぇ",
        "fya": "ふゃ", "fyu": "ふゅ", "fyo": "ふょ",
        "fwa": "ふぁ", "fwi": "ふぃ", "fwu": "ふぅ", "fwe": "ふぇ", "fwo": "ふぉ",
        "wha": "うぁ", "whi": "うぃ", "whu": "う", "whe": "うぇ", "who": "うぉ",
        "wyi": "ゐ", "wye": "ゑ",
        "kwa": "くぁ", "kwi": "くぃ", "kwu": "くぅ", "kwe": "くぇ", "kwo": "くぉ",
        "gwa": "ぐぁ", "gwi": "ぐぃ", "gwu": "ぐぅ", "gwe": "ぐぇ", "gwo": "ぐぉ",
        "kye": "きぇ", "gye": "ぎぇ",
        "qa": "くぁ", "qi": "くぃ", "qu": "く", "qe": "くぇ", "qo": "くぉ",
        "qwa": "くぁ", "qwi": "くぃ", "qwu": "くぅ", "qwe": "くぇ", "qwo": "くぉ",
        "nye": "にぇ", "hye": "ひぇ", "bye": "びぇ", "pye": "ぴぇ", "mye": "みぇ", "rye": "りぇ",
    ]

    static let consonants = Set("bcdfghjklmnpqrstvwxyz")
    static let vowels = Set("aiueo")

    public struct Parse: Equatable, Sendable {
        public let kana: String
        public let isComplete: Bool
        public let moraCount: Int
    }

    public static func parse(_ raw: String) -> Parse {
        let chars = Array(raw.lowercased())
        var index = 0
        var output = ""
        var moraCount = 0
        var complete = true

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
            if current == "'", next != "\0" {
                index += 1
                continue
            }
            if current == "n", next == "'" || next == "n" {
                output += "ん"
                moraCount += 1
                index += 2
                continue
            }
            if current == "n", next != "\0", !vowels.contains(next), next != "y" {
                output += "ん"
                moraCount += 1
                index += 1
                continue
            }
            if consonants.contains(current), current == next, current != "n" {
                output += "っ"
                index += 1
                continue
            }

            var matched = false
            for length in [4, 3, 2, 1] where index + length <= chars.count {
                let piece = String(chars[index ..< index + length])
                if let kana = kanaTable[piece] {
                    output += kana
                    moraCount += 1
                    index += length
                    matched = true
                    break
                }
            }
            if !matched {
                complete = false
                output.append(current)
                index += 1
            }
        }

        return Parse(kana: output, isComplete: complete && moraCount > 0, moraCount: moraCount)
    }

    public static func toKana(_ raw: String) -> String {
        parse(raw).kana
    }

    public static func toLiveKana(_ raw: String) -> String {
        let chars = Array(raw.lowercased())
        var index = 0
        var output = ""

        while index < chars.count {
            let current = chars[index]
            let next = index + 1 < chars.count ? chars[index + 1] : "\0"
            let remaining = String(chars[index...])

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
            if current == "'", next != "\0" {
                index += 1
                continue
            }
            if current == "n", next == "'" || next == "n" {
                output += "ん"
                index += 2
                continue
            }
            if remainingCouldBecomeKana(remaining) {
                output += remaining
                break
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
            for length in [4, 3, 2, 1] where index + length <= chars.count {
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

    private static func remainingCouldBecomeKana(_ remaining: String) -> Bool {
        guard !remaining.isEmpty else { return false }
        guard kanaTable[remaining] == nil else { return false }
        return kanaTable.keys.contains { $0.hasPrefix(remaining) }
    }
}
