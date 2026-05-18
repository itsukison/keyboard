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
        XCTAssertFalse(NativeKeyboardPolicy.allowsAutocorrection(autocorrectionEnabled: false, contentKind: .prose))
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
