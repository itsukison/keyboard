import Foundation
import KeyboardCore

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

var args = Array(CommandLine.arguments.dropFirst())
var outputPath: String? = nil
if let outIdx = args.firstIndex(of: "--out"), outIdx + 1 < args.count {
    outputPath = args[outIdx + 1]
    args.removeSubrange(outIdx ... outIdx + 1)
}
var weightPath: String? = nil
if let wIdx = args.firstIndex(of: "--weight"), wIdx + 1 < args.count {
    weightPath = args[wIdx + 1]
    args.removeSubrange(wIdx ... wIdx + 1)
}
let useZenzai = args.contains("--zenzai")
args.removeAll { $0 == "--zenzai" }
let rawCases = args.isEmpty ? defaultCases : args

let zenzaiWeightURL: URL? = {
    guard useZenzai else { return nil }
    let path = weightPath ?? "weights/zenz-v3-small-Q5_K_M.gguf"
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: url.path) else {
        FileHandle.standardError.write(Data("zenzai weight not found at \(url.path); falling back to dictionary-only.\n".utf8))
        return nil
    }
    return url
}()

let detector = BilingualSpanDetector()
let adapter = KanaKanjiAdapter(zenzaiWeightURL: zenzaiWeightURL)
let zenzaiActive = zenzaiWeightURL != nil

var cases: [BenchmarkCase] = []
for raw in rawCases {
    let controller = InputController(detector: detector, adapter: adapter, useZenzai: zenzaiActive)
    let result = controller.convert(raw)
    cases.append(.init(raw: raw, spans: result.spans, conversions: result.conversions))
}

let report = HarnessReport(
    converter: "AzooKeyKanaKanjiConverter",
    minimumIOSTarget: "iOS 16+",
    zenzaiMode: zenzaiActive ? "zenzaiV3" : "off",
    learningType: "nothing",
    coldStartMs: adapter.coldStartMs,
    cases: cases
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
let data = try encoder.encode(report)
if let outputPath {
    try data.write(to: URL(fileURLWithPath: outputPath))
    FileHandle.standardError.write(Data("Wrote report to \(outputPath)\n".utf8))
} else {
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}
