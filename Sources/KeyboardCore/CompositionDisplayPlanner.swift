import Foundation

public enum CompositionDisplayPlanner {
    public struct Replacement: Equatable, Sendable {
        public let snapshot: String
        public let replacementText: String
        public let suffix: String
        public let deleteCount: Int
        public let nextBuffer: String
        public let nextDisplayedComposition: String

        public init(
            snapshot: String,
            replacementText: String,
            suffix: String,
            deleteCount: Int,
            nextBuffer: String,
            nextDisplayedComposition: String
        ) {
            self.snapshot = snapshot
            self.replacementText = replacementText
            self.suffix = suffix
            self.deleteCount = deleteCount
            self.nextBuffer = nextBuffer
            self.nextDisplayedComposition = nextDisplayedComposition
        }
    }

    public static func liveReplacement(
        buffer: String,
        snapshot: String,
        displayedComposition: String,
        displayPreview: String
    ) -> Replacement? {
        guard buffer.hasPrefix(snapshot) else { return nil }
        let suffix = String(buffer.dropFirst(snapshot.count))
        let nextDisplay = displayPreview + suffix
        guard nextDisplay != displayedComposition else { return nil }
        let sharedPrefixLength = commonPrefixLength(displayedComposition, nextDisplay)
        return Replacement(
            snapshot: snapshot,
            replacementText: String(nextDisplay.dropFirst(sharedPrefixLength)),
            suffix: suffix,
            deleteCount: displayedComposition.count - sharedPrefixLength,
            nextBuffer: buffer,
            nextDisplayedComposition: nextDisplay
        )
    }

    public static func commitReplacement(
        buffer: String,
        snapshot: String,
        displayedComposition: String,
        commitPreview: String
    ) -> Replacement? {
        guard buffer.hasPrefix(snapshot) else { return nil }
        let suffix = String(buffer.dropFirst(snapshot.count))
        let insertedText = commitPreview + suffix
        let sharedPrefixLength = commonPrefixLength(displayedComposition, insertedText)
        return Replacement(
            snapshot: snapshot,
            replacementText: String(insertedText.dropFirst(sharedPrefixLength)),
            suffix: suffix,
            deleteCount: displayedComposition.count - sharedPrefixLength,
            nextBuffer: suffix,
            nextDisplayedComposition: suffix
        )
    }

    private static func commonPrefixLength(_ lhs: String, _ rhs: String) -> Int {
        var count = 0
        var leftIndex = lhs.startIndex
        var rightIndex = rhs.startIndex
        while leftIndex < lhs.endIndex, rightIndex < rhs.endIndex, lhs[leftIndex] == rhs[rightIndex] {
            count += 1
            leftIndex = lhs.index(after: leftIndex)
            rightIndex = rhs.index(after: rightIndex)
        }
        return count
    }
}
