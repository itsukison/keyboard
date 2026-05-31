import XCTest
@testable import KeyboardPreferences

final class ConversionPreferenceStoreTests: XCTestCase {
    func testRecordsSelectionAndRoundTrips() {
        let suiteName = "ConversionPreferenceStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSince1970: 10)

        ConversionPreferenceStore.recordSelection(
            scope: .japanese,
            input: "Hashi",
            candidate: "箸",
            defaults: defaults,
            now: now
        )

        XCTAssertEqual(ConversionPreferenceStore.readEntries(defaults: defaults), [
            ConversionPreferenceEntry(
                scope: .japanese,
                inputKey: "hashi",
                candidateKey: "箸",
                displayText: "箸",
                acceptedCount: 1,
                lastUsedAt: now,
                updatedAt: now
            ),
        ])
    }

    func testRepeatedSelectionReranksCandidateFirst() {
        let firstUse = Date(timeIntervalSince1970: 10)
        let secondUse = Date(timeIntervalSince1970: 20)
        var entries: [ConversionPreferenceEntry] = []
        entries.append(entry(input: "hashi", candidate: "箸", count: 2, date: secondUse))

        let ranked = ConversionPreferenceStore.rerank(
            scope: .japanese,
            input: "hashi",
            candidates: ["橋", "端", "箸"],
            entries: entries,
            now: firstUse
        )

        XCTAssertEqual(ranked, ["箸", "橋", "端"])
    }

    func testSingleSelectionDoesNotJumpFromFarBackToFirst() {
        let now = Date(timeIntervalSince1970: 10)
        let entries = [entry(input: "hashi", candidate: "箸", count: 1, date: now)]

        let ranked = ConversionPreferenceStore.rerank(
            scope: .japanese,
            input: "hashi",
            candidates: ["橋", "端", "箸"],
            entries: entries,
            now: now
        )

        XCTAssertEqual(ranked.first, "橋")
    }

    func testEnglishAndJapanesePreferencesAreSeparated() {
        let now = Date(timeIntervalSince1970: 10)
        let entries = [entry(scope: .japanese, input: "teh", candidate: "てh", count: 3, date: now)]

        let ranked = ConversionPreferenceStore.rerank(
            scope: .english,
            input: "teh",
            candidates: ["the", "tech"],
            entries: entries,
            now: now
        )

        XCTAssertEqual(ranked, ["the", "tech"])
    }

    func testRepeatedKeepRawSuppressesReplacementUntilCandidateWinsBack() {
        let now = Date(timeIntervalSince1970: 10)
        var entries = [
            entry(input: "hashi", candidate: "hashi", count: 2, date: now),
        ]

        XCTAssertTrue(ConversionPreferenceStore.shouldPreferRaw(
            scope: .japanese,
            input: "hashi",
            entries: entries
        ))

        entries.append(entry(input: "hashi", candidate: "橋", count: 2, date: now))
        XCTAssertFalse(ConversionPreferenceStore.shouldPreferRaw(
            scope: .japanese,
            input: "hashi",
            entries: entries
        ))
    }

    func testCapsStoredEntriesByMostRecentUsage() {
        let oldDate = Date(timeIntervalSince1970: 1)
        let newDate = Date(timeIntervalSince1970: 2)
        let suiteName = "ConversionPreferenceStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let entries = (0 ... ConversionPreferenceStore.maxStoredEntries).map { index in
            entry(input: "input\(index)", candidate: "candidate\(index)", count: 1, date: index == 0 ? oldDate : newDate)
        }

        ConversionPreferenceStore.writeEntries(entries, defaults: defaults)
        let stored = ConversionPreferenceStore.readEntries(defaults: defaults)

        XCTAssertEqual(stored.count, ConversionPreferenceStore.maxStoredEntries)
        XCTAssertFalse(stored.contains { $0.inputKey == "input0" })
    }

    private func entry(
        scope: ConversionPreferenceScope = .japanese,
        input: String,
        candidate: String,
        count: Int,
        date: Date
    ) -> ConversionPreferenceEntry {
        ConversionPreferenceEntry(
            scope: scope,
            inputKey: input,
            candidateKey: candidate.lowercased(),
            displayText: candidate,
            acceptedCount: count,
            lastUsedAt: date,
            updatedAt: date
        )
    }
}
