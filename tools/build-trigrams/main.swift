import Foundation

// MARK: - Configuration

/// Boundary markers wrapped around each training token. Chosen outside [a-z0-9-]
/// so they cannot collide with real input.
private let startMark: Character = "^"
private let endMark: Character = "$"

/// Add-alpha (Laplace) smoothing constant.
private let smoothingAlpha: Double = 0.5

/// Drop trigrams whose absolute weighted count is below this threshold to keep
/// the output JSON small. Lowering this gives a fatter table but better recall
/// on rare patterns. Background log-prob still covers anything pruned.
private let minCountToKeep: Double = 1.0

// MARK: - Argument parsing

let argv = CommandLine.arguments
let repoRoot: String = {
    if let idx = argv.firstIndex(of: "--root"), idx + 1 < argv.count {
        return argv[idx + 1]
    }
    return FileManager.default.currentDirectoryPath
}()

let jaInputPath = "\(repoRoot)/tools/build-trigrams/data/ja-romaji.txt"
let enInputPath = "\(repoRoot)/tools/build-trigrams/data/en-words.txt"
let outputPath = "\(repoRoot)/Sources/KeyboardCore/Resources/trigrams.json"

// MARK: - Tokenization

struct Entry {
    let token: String
    let weight: Double
}

func loadEntries(from path: String) throws -> [Entry] {
    let text = try String(contentsOfFile: path, encoding: .utf8)
    var out: [Entry] = []
    for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
        let line = raw.trimmingCharacters(in: .whitespaces)
        if line.isEmpty || line.hasPrefix("#") { continue }
        let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: true)
        let tokenRaw = String(parts[0]).lowercased()
        // Keep only [a-z0-9-]; drop apostrophes, punctuation, etc.
        let token = tokenRaw.filter { ch in
            (ch >= "a" && ch <= "z") || (ch >= "0" && ch <= "9") || ch == "-"
        }
        if token.count < 2 { continue }
        let weight: Double
        if parts.count > 1, let w = Double(parts[1].trimmingCharacters(in: .whitespaces)), w > 0 {
            weight = w
        } else {
            weight = 1.0
        }
        out.append(Entry(token: token, weight: weight))
    }
    return out
}

// MARK: - Trigram counting

func trigramCounts(from entries: [Entry]) -> [String: Double] {
    var counts: [String: Double] = [:]
    for entry in entries {
        let padded = "\(startMark)\(entry.token)\(endMark)"
        let chars = Array(padded)
        if chars.count < 3 { continue }
        for i in 0 ... chars.count - 3 {
            let tri = String(chars[i ..< i + 3])
            counts[tri, default: 0] += entry.weight
        }
    }
    return counts
}

// MARK: - Log-prob estimation with shared vocab

struct ClassModel {
    let unseenLogProb: Double
    let trigrams: [String: Double] // logProb per kept trigram
}

func buildModel(counts: [String: Double], sharedVocabSize: Int) -> ClassModel {
    let total = counts.values.reduce(0.0, +)
    let denom = total + smoothingAlpha * Double(sharedVocabSize)
    let unseen = log(smoothingAlpha / denom)
    var out: [String: Double] = [:]
    for (tri, c) in counts {
        if c < minCountToKeep { continue }
        out[tri] = log((c + smoothingAlpha) / denom)
    }
    return ClassModel(unseenLogProb: unseen, trigrams: out)
}

// MARK: - Main

do {
    print("[build-trigrams] root: \(repoRoot)")
    let jaEntries = try loadEntries(from: jaInputPath)
    let enEntries = try loadEntries(from: enInputPath)
    print("[build-trigrams] ja entries: \(jaEntries.count), en entries: \(enEntries.count)")

    let jaCounts = trigramCounts(from: jaEntries)
    let enCounts = trigramCounts(from: enEntries)
    print("[build-trigrams] raw trigrams: ja=\(jaCounts.count), en=\(enCounts.count)")

    // Shared vocabulary across both classes so unseen probabilities are
    // comparable when computing the JA - EN log-likelihood difference.
    var sharedVocab = Set<String>()
    sharedVocab.formUnion(jaCounts.keys)
    sharedVocab.formUnion(enCounts.keys)
    let sharedVocabSize = sharedVocab.count

    let jaModel = buildModel(counts: jaCounts, sharedVocabSize: sharedVocabSize)
    let enModel = buildModel(counts: enCounts, sharedVocabSize: sharedVocabSize)
    print("[build-trigrams] kept: ja=\(jaModel.trigrams.count), en=\(enModel.trigrams.count) (shared vocab=\(sharedVocabSize))")

    // Serialize. Use a stable, sorted JSON for clean diffs.
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]

    struct OutClass: Encodable {
        let unseenLogProb: Double
        let trigrams: [String: Double]
    }
    struct Out: Encodable {
        let version: Int
        let smoothingAlpha: Double
        let sharedVocabSize: Int
        let startMark: String
        let endMark: String
        let ja: OutClass
        let en: OutClass
    }

    let out = Out(
        version: 1,
        smoothingAlpha: smoothingAlpha,
        sharedVocabSize: sharedVocabSize,
        startMark: String(startMark),
        endMark: String(endMark),
        ja: OutClass(unseenLogProb: jaModel.unseenLogProb, trigrams: jaModel.trigrams),
        en: OutClass(unseenLogProb: enModel.unseenLogProb, trigrams: enModel.trigrams)
    )

    let data = try encoder.encode(out)

    // Ensure output dir exists.
    let outURL = URL(fileURLWithPath: outputPath)
    try FileManager.default.createDirectory(
        at: outURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: outURL)
    print("[build-trigrams] wrote \(outputPath) (\(data.count) bytes)")

    // Also emit a JS module so the browser prototype (`app.js`) can share the
    // same model. Lives at repo root for direct `<script>` consumption.
    let jsPath = "\(repoRoot)/trigrams-data.js"
    let jsHeader = "// Auto-generated by TrigramBuilder. Do not edit by hand.\nwindow.TRIGRAMS = "
    let jsFooter = ";\n"
    var jsData = Data(jsHeader.utf8)
    jsData.append(data)
    jsData.append(Data(jsFooter.utf8))
    try jsData.write(to: URL(fileURLWithPath: jsPath))
    print("[build-trigrams] wrote \(jsPath) (\(jsData.count) bytes)")
} catch {
    FileHandle.standardError.write(Data("[build-trigrams] error: \(error)\n".utf8))
    exit(1)
}
