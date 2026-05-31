import XCTest
@testable import EnglishKeyboardCore

final class SymSpellEnglishCorrectionProviderTests: XCTestCase {
    private var provider: SymSpellEnglishCorrectionProvider!

    override func setUp() {
        super.setUp()
        provider = SymSpellEnglishCorrectionProvider()
        provider.preload()
    }

    override func tearDown() {
        provider = nil
        super.tearDown()
    }

    func testCorrectsCommonTransposition() {
        let result = provider.correctionResult(for: .init(typedWord: "teh"))

        XCTAssertEqual(result.topCorrection, "the")
        XCTAssertTrue(result.displayCandidates.contains("the"))
    }

    func testCorrectsCommonMisspelling() {
        let result = provider.correctionResult(for: .init(typedWord: "definately"))

        XCTAssertEqual(result.topCorrection, "definitely")
        XCTAssertTrue(result.displayCandidates.contains("definitely"))
    }

    func testDoesNotAutocorrectValidWords() {
        for word in ["its", "form", "meeting", "aware"] {
            let result = provider.correctionResult(for: .init(typedWord: word))

            XCTAssertTrue(result.isTypedWordValid, word)
            XCTAssertNil(result.topCorrection, word)
        }
    }

    func testShortWordsRemainConservative() {
        for word in ["we", "to", "no", "be"] {
            let result = provider.correctionResult(for: .init(typedWord: word))

            XCTAssertTrue(result.isTypedWordValid, word)
            XCTAssertNil(result.topCorrection, word)
        }
    }

    func testManualCapitalizationSuppressesAutocorrection() {
        let result = provider.correctionResult(for: .init(
            typedWord: "Teh",
            hasManualCapitalization: true
        ))

        XCTAssertNil(result.topCorrection)
        XCTAssertTrue(result.displayCandidates.contains("The"))
    }
}
