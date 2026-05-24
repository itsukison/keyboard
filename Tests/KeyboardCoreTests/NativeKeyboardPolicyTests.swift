import XCTest
@testable import KeyboardCore

final class NativeKeyboardPolicyTests: XCTestCase {
    func testSentenceAutocapitalizationAtFieldStartAndAfterTerminators() {
        XCTAssertTrue(NativeKeyboardPolicy.shouldAutoCapitalize(after: "", mode: .sentences, contentKind: .prose))
        XCTAssertTrue(NativeKeyboardPolicy.shouldAutoCapitalize(after: "Hello.  ", mode: .sentences, contentKind: .prose))
        XCTAssertTrue(NativeKeyboardPolicy.shouldAutoCapitalize(after: "Hello\n", mode: .sentences, contentKind: .prose))
        XCTAssertFalse(NativeKeyboardPolicy.shouldAutoCapitalize(after: "Hello ", mode: .sentences, contentKind: .prose))
    }

    func testWordAutocapitalizationAtWordBoundaries() {
        XCTAssertTrue(NativeKeyboardPolicy.shouldAutoCapitalize(after: "Hello ", mode: .words, contentKind: .prose))
        XCTAssertTrue(NativeKeyboardPolicy.shouldAutoCapitalize(after: "Hello-", mode: .words, contentKind: .prose))
        XCTAssertFalse(NativeKeyboardPolicy.shouldAutoCapitalize(after: "Hel", mode: .words, contentKind: .prose))
    }

    func testNoAutocapitalizationInUrlAndEmailContexts() {
        XCTAssertFalse(NativeKeyboardPolicy.shouldAutoCapitalize(after: "", mode: .sentences, contentKind: .url))
        XCTAssertFalse(NativeKeyboardPolicy.shouldAutoCapitalize(after: "", mode: .allCharacters, contentKind: .email))
    }

    func testAutocorrectionEligibilityFollowsContentKind() {
        XCTAssertTrue(NativeKeyboardPolicy.allowsAutocorrection(autocorrectionEnabled: true, contentKind: .prose))
        XCTAssertTrue(NativeKeyboardPolicy.allowsAutocorrection(autocorrectionEnabled: true, contentKind: .webSearch))
        XCTAssertFalse(NativeKeyboardPolicy.allowsAutocorrection(autocorrectionEnabled: true, contentKind: .url))
        XCTAssertFalse(NativeKeyboardPolicy.allowsAutocorrection(autocorrectionEnabled: true, contentKind: .email))
        XCTAssertFalse(NativeKeyboardPolicy.allowsAutocorrection(autocorrectionEnabled: true, contentKind: .numeric))
        XCTAssertFalse(NativeKeyboardPolicy.allowsAutocorrection(autocorrectionEnabled: true, contentKind: .phone))
        XCTAssertFalse(NativeKeyboardPolicy.allowsAutocorrection(autocorrectionEnabled: false, contentKind: .prose))
    }

    func testBilingualConversionSuggestionEligibilityFollowsContentKind() {
        XCTAssertTrue(NativeKeyboardPolicy.allowsBilingualConversionSuggestions(contentKind: .prose))
        XCTAssertTrue(NativeKeyboardPolicy.allowsBilingualConversionSuggestions(contentKind: .webSearch))
        XCTAssertTrue(NativeKeyboardPolicy.allowsBilingualConversionSuggestions(contentKind: .url))
        XCTAssertFalse(NativeKeyboardPolicy.allowsBilingualConversionSuggestions(contentKind: .email))
        XCTAssertFalse(NativeKeyboardPolicy.allowsBilingualConversionSuggestions(contentKind: .numeric))
        XCTAssertFalse(NativeKeyboardPolicy.allowsBilingualConversionSuggestions(contentKind: .phone))
    }

    func testDoubleSpacePeriodAppliesAfterEnglishWord() {
        XCTAssertTrue(NativeKeyboardPolicy.shouldApplyDoubleSpacePeriod(
            beforeInput: "hello ",
            autocorrectionEnabled: true,
            contentKind: .prose
        ))
    }

    func testDoubleSpacePeriodSuppressions() {
        XCTAssertFalse(NativeKeyboardPolicy.shouldApplyDoubleSpacePeriod(
            beforeInput: "hello  ",
            autocorrectionEnabled: true,
            contentKind: .prose
        ))
        XCTAssertFalse(NativeKeyboardPolicy.shouldApplyDoubleSpacePeriod(
            beforeInput: "hello. ",
            autocorrectionEnabled: true,
            contentKind: .prose
        ))
        XCTAssertFalse(NativeKeyboardPolicy.shouldApplyDoubleSpacePeriod(
            beforeInput: "hello ",
            autocorrectionEnabled: true,
            contentKind: .url
        ))
        XCTAssertFalse(NativeKeyboardPolicy.shouldApplyDoubleSpacePeriod(
            beforeInput: "こんにちは ",
            autocorrectionEnabled: true,
            contentKind: .prose
        ))
    }
}
