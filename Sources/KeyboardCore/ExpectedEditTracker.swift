import Foundation

public struct ObservedTextState: Equatable, Sendable {
    public var left: String
    public var center: String
    public var right: String

    public init(left: String, center: String, right: String) {
        self.left = left
        self.center = center
        self.right = right
    }
}

public struct ExpectedEditTracker: Sendable {
    public enum Consumption: Equatable, Sendable {
        case noMatch
        case matched(hasMoreEdits: Bool)
    }

    public enum LogicalEdit: Equatable, Sendable {
        case insert(String)
        case deleteBackward
    }

    private struct ExpectedEdit: Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            case observed(before: ObservedTextState, after: ObservedTextState)
            case logical(LogicalEdit)
        }

        var kind: Kind
    }

    private let maxStoredEdits: Int
    private var expectedEdits: [ExpectedEdit] = []

    public init(maxStoredEdits: Int = 32) {
        self.maxStoredEdits = maxStoredEdits
    }

    public mutating func record(before: ObservedTextState?, after: ObservedTextState?) {
        guard let before, let after, before != after else { return }
        append(.init(kind: .observed(before: before, after: after)))
    }

    public mutating func record(_ edit: LogicalEdit) {
        append(.init(kind: .logical(edit)))
    }

    public mutating func record(_ edits: [LogicalEdit]) {
        for edit in edits {
            append(.init(kind: .logical(edit)))
        }
    }

    private mutating func append(_ edit: ExpectedEdit) {
        expectedEdits.append(edit)
        if expectedEdits.count > maxStoredEdits {
            expectedEdits.removeFirst(expectedEdits.count - maxStoredEdits)
        }
    }

    public mutating func consume(before: ObservedTextState, after: ObservedTextState) -> Consumption {
        for startIndex in expectedEdits.indices {
            if startIndex > expectedEdits.startIndex,
               case .logical = expectedEdits[startIndex].kind {
                continue
            }
            guard var currentAfter = apply(expectedEdits[startIndex], to: before) else {
                continue
            }
            if currentAfter == after {
                expectedEdits.removeFirst(startIndex + 1)
                return .matched(hasMoreEdits: firstPendingEditCanStart(from: after))
            }

            var endIndex = startIndex
            while endIndex + 1 < expectedEdits.endIndex {
                endIndex += 1
                guard let nextAfter = apply(expectedEdits[endIndex], to: currentAfter) else {
                    break
                }
                currentAfter = nextAfter
                if currentAfter == after {
                    expectedEdits.removeFirst(endIndex + 1)
                    return .matched(hasMoreEdits: firstPendingEditCanStart(from: after))
                }
            }
        }
        return .noMatch
    }

    private func firstPendingEditCanStart(from state: ObservedTextState) -> Bool {
        guard let first = expectedEdits.first else { return false }
        return apply(first, to: state) != nil
    }

    private func apply(_ edit: ExpectedEdit, to state: ObservedTextState) -> ObservedTextState? {
        switch edit.kind {
        case .observed(let before, let after):
            return before == state ? after : nil
        case .logical(let logical):
            return apply(logical, to: state)
        }
    }

    private func apply(_ edit: LogicalEdit, to state: ObservedTextState) -> ObservedTextState {
        switch edit {
        case .insert(let text):
            return ObservedTextState(left: state.left + text, center: "", right: state.right)
        case .deleteBackward:
            if !state.center.isEmpty {
                return ObservedTextState(left: state.left, center: "", right: state.right)
            }
            var left = state.left
            if !left.isEmpty {
                left.removeLast()
            }
            return ObservedTextState(left: left, center: "", right: state.right)
        }
    }
}
