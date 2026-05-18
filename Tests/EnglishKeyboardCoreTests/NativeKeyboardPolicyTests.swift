import XCTest
@testable import EnglishKeyboardCore

final class NativeKeyboardPolicyTests: XCTestCase {
    func testSentenceAutocapitalization() {
        XCTAssertTrue(NativeKeyboardPolicy.shouldAutoCapitalize(
            after: "",
            mode: .sentences,
            contentKind: .prose
        ))
        XCTAssertTrue(NativeKeyboardPolicy.shouldAutoCapitalize(
            after: "Hello. ",
            mode: .sentences,
            contentKind: .prose
        ))
        XCTAssertFalse(NativeKeyboardPolicy.shouldAutoCapitalize(
            after: "Hello ",
            mode: .sentences,
            contentKind: .prose
        ))
    }

    func testAutocorrectionDisabledForStructuredInputs() {
        XCTAssertTrue(NativeKeyboardPolicy.allowsAutocorrection(autocorrectionEnabled: true, contentKind: .prose))
        XCTAssertTrue(NativeKeyboardPolicy.allowsAutocorrection(autocorrectionEnabled: true, contentKind: .webSearch))
        XCTAssertFalse(NativeKeyboardPolicy.allowsAutocorrection(autocorrectionEnabled: true, contentKind: .url))
        XCTAssertFalse(NativeKeyboardPolicy.allowsAutocorrection(autocorrectionEnabled: true, contentKind: .email))
        XCTAssertFalse(NativeKeyboardPolicy.allowsAutocorrection(autocorrectionEnabled: true, contentKind: .numeric))
        XCTAssertFalse(NativeKeyboardPolicy.allowsAutocorrection(autocorrectionEnabled: false, contentKind: .prose))
    }

    func testDoubleSpacePeriod() {
        XCTAssertTrue(NativeKeyboardPolicy.shouldApplyDoubleSpacePeriod(
            beforeInput: "Hello ",
            autocorrectionEnabled: true,
            contentKind: .prose
        ))
        XCTAssertFalse(NativeKeyboardPolicy.shouldApplyDoubleSpacePeriod(
            beforeInput: "Hello. ",
            autocorrectionEnabled: true,
            contentKind: .prose
        ))
        XCTAssertFalse(NativeKeyboardPolicy.shouldApplyDoubleSpacePeriod(
            beforeInput: "https://example ",
            autocorrectionEnabled: true,
            contentKind: .url
        ))
    }
}
