import XCTest
@testable import EnglishKeyboardCore

final class EnglishAutocorrectGateTests: XCTestCase {
    func testDamerauLevenshteinCountsAdjacentTranspositionAsOneEdit() {
        XCTAssertEqual(EnglishAutocorrectGate.levenshtein("teh", "the"), 1)
        XCTAssertEqual(EnglishAutocorrectGate.levenshtein("form", "from"), 1)
    }

    func testDistanceCapsAreTighterForShortWords() {
        XCTAssertEqual(EnglishAutocorrectGate.maxAllowedDistance(forTypedLength: 3), 1)
        XCTAssertEqual(EnglishAutocorrectGate.maxAllowedDistance(forTypedLength: 5), 1)
        XCTAssertEqual(EnglishAutocorrectGate.maxAllowedDistance(forTypedLength: 6), 2)
    }

    func testLikelyCorrectionsPassGate() {
        XCTAssertTrue(EnglishAutocorrectGate.correctionPassesGate(typed: "teh", candidate: "the"))
        XCTAssertTrue(EnglishAutocorrectGate.correctionPassesGate(typed: "definately", candidate: "definitely"))
    }

    func testUnrelatedCandidatesDoNotPassGate() {
        XCTAssertFalse(EnglishAutocorrectGate.correctionPassesGate(typed: "xyz", candidate: "the"))
        XCTAssertFalse(EnglishAutocorrectGate.correctionPassesGate(typed: "abcdef", candidate: "xyzxyz"))
    }

    func testManualCapitalizationSuppressesAutocorrection() {
        XCTAssertTrue(EnglishAutocorrectGate.shouldSuppressAutocorrectionForManualCapitalization(
            typed: "Itsuki",
            hasManualCapitalization: true
        ))
        XCTAssertFalse(EnglishAutocorrectGate.shouldSuppressAutocorrectionForManualCapitalization(
            typed: "Itsuki",
            hasManualCapitalization: false
        ))
    }
}
