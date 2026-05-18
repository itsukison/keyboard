import XCTest
@testable import KeyboardCore

/// Coverage for the romaji→kana lookup table. The base gojuuon + dakuten +
/// yoon rows have been correct for a long time; this suite focuses on the
/// Mozc-compatible extensions (small characters via x-/l-, the v row, ts/th
/// foreign-sound rows, w/k/g/q extensions, and the small `tsu` family).
final class RomajiTableTests: XCTestCase {

    // MARK: - Sanity baselines that must never regress

    func testToProducesTo() {
        // Direct regression for the user-reported "to → ど" bug. The bug
        // lived in AzooKey's typo correction (ト → ド), not the romaji
        // table itself, but the table-level mapping must stay correct.
        XCTAssertEqual(Romaji.toKana("to"), "と")
    }

    func testDoProducesDo() {
        XCTAssertEqual(Romaji.toKana("do"), "ど")
    }

    func testGoCommonParticles() {
        XCTAssertEqual(Romaji.toKana("wa"), "わ")
        XCTAssertEqual(Romaji.toKana("ga"), "が")
        XCTAssertEqual(Romaji.toKana("no"), "の")
        XCTAssertEqual(Romaji.toKana("ni"), "に")
    }

    // MARK: - Small characters with x- prefix

    func testXAVowelSmalls() {
        XCTAssertEqual(Romaji.toKana("xa"), "ぁ")
        XCTAssertEqual(Romaji.toKana("xi"), "ぃ")
        XCTAssertEqual(Romaji.toKana("xu"), "ぅ")
        XCTAssertEqual(Romaji.toKana("xe"), "ぇ")
        XCTAssertEqual(Romaji.toKana("xo"), "ぉ")
    }

    func testLAVowelSmalls() {
        XCTAssertEqual(Romaji.toKana("la"), "ぁ")
        XCTAssertEqual(Romaji.toKana("li"), "ぃ")
        XCTAssertEqual(Romaji.toKana("lu"), "ぅ")
        XCTAssertEqual(Romaji.toKana("le"), "ぇ")
        XCTAssertEqual(Romaji.toKana("lo"), "ぉ")
    }

    func testXYaYuYoSmalls() {
        XCTAssertEqual(Romaji.toKana("xya"), "ゃ")
        XCTAssertEqual(Romaji.toKana("xyu"), "ゅ")
        XCTAssertEqual(Romaji.toKana("xyo"), "ょ")
        XCTAssertEqual(Romaji.toKana("lya"), "ゃ")
        XCTAssertEqual(Romaji.toKana("lyu"), "ゅ")
        XCTAssertEqual(Romaji.toKana("lyo"), "ょ")
    }

    func testSmallTsu() {
        XCTAssertEqual(Romaji.toKana("xtu"), "っ")
        XCTAssertEqual(Romaji.toKana("xtsu"), "っ")
        XCTAssertEqual(Romaji.toKana("ltu"), "っ")
        XCTAssertEqual(Romaji.toKana("ltsu"), "っ")
    }

    func testSmallWa() {
        XCTAssertEqual(Romaji.toKana("xwa"), "ゎ")
        XCTAssertEqual(Romaji.toKana("lwa"), "ゎ")
    }

    func testSmallKaKe() {
        XCTAssertEqual(Romaji.toKana("xka"), "ヵ")
        XCTAssertEqual(Romaji.toKana("xke"), "ヶ")
    }

    func testXn() {
        XCTAssertEqual(Romaji.toKana("xn"), "ん")
    }

    // MARK: - v row (ヴ)

    func testVRow() {
        XCTAssertEqual(Romaji.toKana("va"), "ゔぁ")
        XCTAssertEqual(Romaji.toKana("vi"), "ゔぃ")
        XCTAssertEqual(Romaji.toKana("vu"), "ゔ")
        XCTAssertEqual(Romaji.toKana("ve"), "ゔぇ")
        XCTAssertEqual(Romaji.toKana("vo"), "ゔぉ")
    }

    // MARK: - Foreign-sound rows

    func testTsForeign() {
        XCTAssertEqual(Romaji.toKana("tsa"), "つぁ")
        XCTAssertEqual(Romaji.toKana("tsi"), "つぃ")
        XCTAssertEqual(Romaji.toKana("tse"), "つぇ")
        XCTAssertEqual(Romaji.toKana("tso"), "つぉ")
    }

    func testThRow() {
        XCTAssertEqual(Romaji.toKana("tha"), "てゃ")
        XCTAssertEqual(Romaji.toKana("thi"), "てぃ")
        XCTAssertEqual(Romaji.toKana("the"), "てぇ")
    }

    func testDhRow() {
        XCTAssertEqual(Romaji.toKana("dha"), "でゃ")
        XCTAssertEqual(Romaji.toKana("dhi"), "でぃ")
        XCTAssertEqual(Romaji.toKana("dhu"), "でゅ")
    }

    func testSheCheJe() {
        XCTAssertEqual(Romaji.toKana("she"), "しぇ")
        XCTAssertEqual(Romaji.toKana("che"), "ちぇ")
        XCTAssertEqual(Romaji.toKana("je"), "じぇ")
    }

    // MARK: - Composition with existing rules

    func testForeignWordRomanization() {
        // Common loanword spellings the table should handle. `ti` deliberately
        // maps to ち (existing Mozc-compatible behavior); users wanting てぃ
        // should type `thi` instead.
        XCTAssertEqual(Romaji.toKana("vaiorin"), "ゔぁいおりん")    // ヴァイオリン
        XCTAssertEqual(Romaji.toKana("paathii"), "ぱあてぃい")      // パーティー
        XCTAssertEqual(Romaji.toKana("fasshon"), "ふぁっしょん")    // ファッション
    }

    // MARK: - Existing yoon rules must still match (4-char loop must not break 3-char matches)

    func testYoonStillWork() {
        XCTAssertEqual(Romaji.toKana("kyoto"), "きょと")
        XCTAssertEqual(Romaji.toKana("ryuu"), "りゅう")
        XCTAssertEqual(Romaji.toKana("sha"), "しゃ")
        XCTAssertEqual(Romaji.toKana("cho"), "ちょ")
    }

    // MARK: - n disambiguation

    func testNDisambiguation() {
        XCTAssertEqual(Romaji.toKana("na"), "な")
        XCTAssertEqual(Romaji.toKana("nn"), "ん")
        XCTAssertEqual(Romaji.toKana("n'a"), "んあ")
        XCTAssertEqual(Romaji.toKana("nko"), "んこ")
        XCTAssertEqual(Romaji.toKana("nya"), "にゃ")
    }

    // MARK: - Live composition

    func testLiveKanaConvertsSingleVowelImmediately() {
        XCTAssertEqual(Romaji.toLiveKana("a"), "あ")
    }

    func testLiveKanaKeepsIncompleteTrailingConsonant() {
        XCTAssertEqual(Romaji.toLiveKana("k"), "k")
        XCTAssertEqual(Romaji.toLiveKana("ky"), "ky")
        XCTAssertEqual(Romaji.toLiveKana("ka"), "か")
        XCTAssertEqual(Romaji.toLiveKana("kyo"), "きょ")
    }

    func testLiveKanaConvertsCommonJapanesePhrase() {
        XCTAssertEqual(Romaji.toLiveKana("gohan"), "ごはん")
    }

    func testLiveKanaShowsInvalidFragmentsInsideKanaRun() {
        XCTAssertEqual(Romaji.toLiveKana("dokotde"), "どこtで")
    }

    func testLiveKanaBackspaceFriendlyIntermediateState() {
        XCTAssertEqual(Romaji.toLiveKana("ka"), "か")
        XCTAssertEqual(Romaji.toLiveKana("k"), "k")
    }
}
