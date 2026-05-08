import Foundation

public enum Romaji {
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
    ]

    static let consonants = Set("bcdfghjklmnpqrstvwxyz")
    static let vowels = Set("aiueo")

    public static func toKana(_ raw: String) -> String {
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
}
