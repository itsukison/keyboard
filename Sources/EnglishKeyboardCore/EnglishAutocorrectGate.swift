import Foundation

public enum EnglishAutocorrectGate {
    public static func maxAllowedDistance(forTypedLength length: Int) -> Int {
        length >= 6 ? 2 : 1
    }

    public static func correctionPassesGate(typed: String, candidate: String) -> Bool {
        let cap = maxAllowedDistance(forTypedLength: typed.count)
        return levenshtein(typed.lowercased(), candidate.lowercased()) <= cap
    }

    public static func shouldSuppressAutocorrectionForManualCapitalization(
        typed: String,
        hasManualCapitalization: Bool
    ) -> Bool {
        hasManualCapitalization && typed.contains(where: { $0.isUppercase })
    }

    public static func levenshtein(_ a: String, _ b: String) -> Int {
        let s = Array(a)
        let t = Array(b)
        let n = s.count
        let m = t.count
        if n == 0 { return m }
        if m == 0 { return n }

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
