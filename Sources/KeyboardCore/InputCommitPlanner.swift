import Foundation

/// Pure planning for the IME delete-and-replace commit used by the iOS keyboard.
///
/// The keyboard inserts raw romaji into the host immediately. When a conversion
/// is committed, the host tail is replaced by deleting the whole live raw buffer
/// and inserting the converted snapshot plus any raw suffix typed after that
/// snapshot. Keeping this logic pure makes the "never drop input" invariant
/// easy to test outside an iOS keyboard extension.
public enum InputCommitPlanner {
    public struct Replacement: Equatable, Sendable {
        public let snapshot: String
        public let preview: String
        public let suffix: String
        public let deleteCount: Int
        public let nextBuffer: String

        public var insertedText: String { preview + suffix }

        public init(
            snapshot: String,
            preview: String,
            suffix: String,
            deleteCount: Int,
            nextBuffer: String
        ) {
            self.snapshot = snapshot
            self.preview = preview
            self.suffix = suffix
            self.deleteCount = deleteCount
            self.nextBuffer = nextBuffer
        }
    }

    /// Returns nil when the conversion snapshot no longer matches the live
    /// buffer prefix. In that case callers must preserve raw host text and skip
    /// the commit rather than risk deleting newer user input.
    public static func replacement(buffer: String, snapshot: String, preview: String) -> Replacement? {
        guard buffer.hasPrefix(snapshot) else { return nil }
        let suffix = String(buffer.dropFirst(snapshot.count))
        return Replacement(
            snapshot: snapshot,
            preview: preview,
            suffix: suffix,
            deleteCount: buffer.count,
            nextBuffer: suffix
        )
    }
}
