import Foundation
import KeyboardCore

FileHandle.standardError.write(Data("probe: starting\n".utf8))

let jsonPath = "/Users/itsuki/Desktop/keyboard/Sources/KeyboardCore/Resources/trigrams.json"
FileHandle.standardError.write(Data("probe: reading \(jsonPath)\n".utf8))
let data: Data
do {
    data = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
} catch {
    FileHandle.standardError.write(Data("probe: failed to read: \(error)\n".utf8))
    exit(2)
}
FileHandle.standardError.write(Data("probe: read \(data.count) bytes\n".utf8))

let scorer: TrigramScorer
do {
    scorer = try TrigramScorer(payload: data)
} catch {
    FileHandle.standardError.write(Data("probe: scorer init failed: \(error)\n".utf8))
    exit(3)
}
FileHandle.standardError.write(Data("probe: scorer ready\n".utf8))

let words = CommandLine.arguments.dropFirst().isEmpty
    ? ["hashi", "wanna", "gonna", "kinda", "korekara", "kyou", "meeting", "watashi", "the"]
    : Array(CommandLine.arguments.dropFirst())

print("=== TrigramScorer ===")
for w in words {
    let s = scorer.score(w)
    let pad = w.padding(toLength: 12, withPad: " ", startingAt: 0)
    let line = String(format: "%@ ja=%8.3f en=%8.3f diff=%+8.3f", pad, s.ja, s.en, s.diff)
    print(line)
}

print("\n=== BilingualSpanDetector ===")
let d = BilingualSpanDetector(trigramScorer: scorer)
for w in words {
    let spans = d.detect(w)
    let parts = spans.map { "\($0.kind.rawValue):\($0.raw)" }
    print("\(w) -> \(parts)")
}
