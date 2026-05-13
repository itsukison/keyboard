import XCTest
@testable import KeyboardCore

final class EnglishAutocorrectGateTests: XCTestCase {

    // MARK: - Levenshtein

    func testLevenshteinIdentical() {
        XCTAssertEqual(EnglishAutocorrectGate.levenshtein("its", "its"), 0)
    }

    func testLevenshteinSingleInsertion() {
        XCTAssertEqual(EnglishAutocorrectGate.levenshtein("its", "it's"), 1)
    }

    func testDamerauTranspositionIsOneEdit() {
        // Adjacent transposition counts as 1 (Damerau-Levenshtein / OSA).
        XCTAssertEqual(EnglishAutocorrectGate.levenshtein("teh", "the"), 1)
        XCTAssertEqual(EnglishAutocorrectGate.levenshtein("form", "from"), 1)
    }

    func testSubstitutionStillOneEdit() {
        // "definately" → "definitely": single substitution a→i at position 5.
        XCTAssertEqual(EnglishAutocorrectGate.levenshtein("definately", "definitely"), 1)
    }

    func testLevenshteinEmptyInputs() {
        XCTAssertEqual(EnglishAutocorrectGate.levenshtein("", ""), 0)
        XCTAssertEqual(EnglishAutocorrectGate.levenshtein("abc", ""), 3)
        XCTAssertEqual(EnglishAutocorrectGate.levenshtein("", "abc"), 3)
    }

    // MARK: - Edit-distance cap

    func testMaxAllowedDistanceShortWords() {
        XCTAssertEqual(EnglishAutocorrectGate.maxAllowedDistance(forTypedLength: 3), 1)
        XCTAssertEqual(EnglishAutocorrectGate.maxAllowedDistance(forTypedLength: 5), 1)
    }

    func testMaxAllowedDistanceLongerWords() {
        XCTAssertEqual(EnglishAutocorrectGate.maxAllowedDistance(forTypedLength: 6), 2)
        XCTAssertEqual(EnglishAutocorrectGate.maxAllowedDistance(forTypedLength: 12), 2)
    }

    // MARK: - Gate

    func testGateRejectsTooFarCorrection() {
        // "its" → "it's" is distance 1 with len 3 (cap 1) → passes. This is
        // the case we WANT to suppress, but the gate alone allows it —
        // suppression comes from the validity check ("its" is a real word).
        XCTAssertTrue(EnglishAutocorrectGate.correctionPassesGate(typed: "its", candidate: "it's"))
    }

    func testGateAcceptsCloseCorrectionOnShortWord() {
        XCTAssertTrue(EnglishAutocorrectGate.correctionPassesGate(typed: "teh", candidate: "the"))
    }

    func testGateAcceptsTwoEditsOnLongerWord() {
        XCTAssertTrue(EnglishAutocorrectGate.correctionPassesGate(typed: "definately", candidate: "definitely"))
    }

    func testGateRejectsThreeEdits() {
        // distance 3 > cap 2 for a 6-letter word.
        XCTAssertFalse(EnglishAutocorrectGate.correctionPassesGate(typed: "abcdef", candidate: "xyzxyz"))
    }

    func testGateRejectsWildlyDifferentShortWord() {
        // "xyz" → "the" distance 3 > cap 1.
        XCTAssertFalse(EnglishAutocorrectGate.correctionPassesGate(typed: "xyz", candidate: "the"))
    }
}
