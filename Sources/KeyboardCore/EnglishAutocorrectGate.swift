import Foundation

/// Pure-logic part of the native-style English autocorrect gate. The UIKit
/// glue (UITextChecker, UILexicon) lives in the iOS target; this module owns
/// the decisions so they can be unit-tested without a host.
public enum EnglishAutocorrectGate {
    /// Maximum edit distance allowed between the typed word and a candidate
    /// correction. Mirrors observable native-iOS behavior: short words get a
    /// tighter cap so single-letter typos don't snap to unrelated words.
    public static func maxAllowedDistance(forTypedLength length: Int) -> Int {
        length >= 6 ? 2 : 1
    }

    /// Whether `candidate` is close enough to `typed` to be an acceptable
    /// auto-correction. ASCII-only inputs (English dictionary words).
    public static func correctionPassesGate(typed: String, candidate: String) -> Bool {
        let cap = maxAllowedDistance(forTypedLength: typed.count)
        return levenshtein(typed.lowercased(), candidate.lowercased()) <= cap
    }

    /// User-triggered capitalization is a strong signal that the token may be a
    /// name, acronym, brand, or other specific spelling. Auto-capitalization at
    /// sentence start is tracked by the caller and should not set this flag.
    public static func shouldSuppressAutocorrectionForManualCapitalization(
        typed: String,
        hasManualCapitalization: Bool
    ) -> Bool {
        hasManualCapitalization && typed.contains(where: { $0.isUppercase })
    }

    /// Optimal String Alignment (Damerau-Levenshtein) distance. Counts an
    /// adjacent transposition (`teh` ↔ `the`) as a single edit, which is
    /// what real autocorrect engines do. Falls back to plain insert / delete
    /// / substitute for non-adjacent swaps.
    public static func levenshtein(_ a: String, _ b: String) -> Int {
        let s = Array(a)
        let t = Array(b)
        let n = s.count
        let m = t.count
        if n == 0 { return m }
        if m == 0 { return n }
        // Three rows: d2 (i-2), d1 (i-1), d0 (current). Avoids full matrix
        // while still allowing the transposition lookup at [i-2][j-2].
        var d2 = [Int](repeating: 0, count: m + 1)
        var d1 = Array(0...m)
        var d0 = [Int](repeating: 0, count: m + 1)
        for i in 1...n {
            d0[0] = i
            for j in 1...m {
                let cost = s[i - 1] == t[j - 1] ? 0 : 1
                var v = min(d1[j] + 1, d0[j - 1] + 1, d1[j - 1] + cost)
                if i > 1, j > 1, s[i - 1] == t[j - 2], s[i - 2] == t[j - 1] {
                    v = min(v, d2[j - 2] + 1)
                }
                d0[j] = v
            }
            d2 = d1
            d1 = d0
            d0 = [Int](repeating: 0, count: m + 1)
        }
        return d1[m]
    }
}
