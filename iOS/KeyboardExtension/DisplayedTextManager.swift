import KeyboardCore
import UIKit

@MainActor
final class DisplayedTextManager {
    private let proxyProvider: () -> any UITextDocumentProxy
    private var expectedEditTracker = ExpectedEditTracker()
    private(set) var proxyEditSequence: UInt64 = 0
    /// Diagnostic flag (env: KB_USE_PROXY_SNAPSHOTS). Normal typing uses
    /// logical edit tracking so `insertText` is not preceded by host-context
    /// XPC reads; set the flag only when debugging reconciliation bugs.
    private let useProxySnapshots: Bool

    init(proxyProvider: @escaping () -> any UITextDocumentProxy) {
        self.proxyProvider = proxyProvider
        self.useProxySnapshots = ProcessInfo.processInfo.environment["KB_USE_PROXY_SNAPSHOTS"] != nil
    }

    func snapshot() -> ObservedTextState {
        let proxy = proxyProvider()
        return ObservedTextState(
            left: proxy.documentContextBeforeInput ?? "",
            center: proxy.selectedText ?? "",
            right: proxy.documentContextAfterInput ?? ""
        )
    }

    func insertRaw(_ text: String) {
        insertText(text, expectedEdit: .insert(text))
    }

    func insertCommitted(_ text: String) {
        insertText(text, expectedEdit: .insert(text))
    }

    func deleteBackward() {
        recordExpectedEdit(.deleteBackward) {
            proxyProvider().deleteBackward()
        }
    }

    func deleteBackward(buffer: inout String) {
        if buffer.isEmpty {
            deleteBackward()
        } else {
            buffer.removeLast()
            deleteBackward()
        }
    }

    func replaceComposition(plan: InputCommitPlanner.Replacement) {
        guard plan.deleteCount > 0 || !plan.insertedText.isEmpty else { return }
        for _ in 0..<plan.deleteCount {
            deleteBackward()
        }
        insertText(plan.preview, expectedEdit: .insert(plan.preview))
        insertText(plan.suffix, expectedEdit: .insert(plan.suffix))
    }

    func consumeExpectedEdit(before: ObservedTextState, after: ObservedTextState) -> ExpectedEditTracker.Consumption {
        expectedEditTracker.consume(before: before, after: after)
    }

    @discardableResult
    private func recordExpectedEdit(
        _ expectedEdit: ExpectedEditTracker.LogicalEdit,
        operation: () -> Void
    ) -> UInt64 {
        guard useProxySnapshots else {
            expectedEditTracker.record(expectedEdit)
            operation()
            proxyEditSequence += 1
            return proxyEditSequence
        }

        let before = snapshot()
        operation()
        let after = snapshot()
        expectedEditTracker.record(before: before, after: after)
        proxyEditSequence += 1
        return proxyEditSequence
    }

    private func insertText(_ text: String, expectedEdit: ExpectedEditTracker.LogicalEdit) {
        guard !text.isEmpty else { return }
        recordExpectedEdit(expectedEdit) {
            proxyProvider().insertText(text)
        }
    }
}
