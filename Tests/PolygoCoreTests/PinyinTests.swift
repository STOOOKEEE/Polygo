import XCTest
@testable import PolygoCore

final class PinyinTests: XCTestCase {
    func testSyllablesSplitAWordWrittenInOnePiece() {
        XCTAssertEqual(PinyinSyllables.split("Běijīng"), ["Běi", "jīng"])
        XCTAssertEqual(PinyinSyllables.split("huǒchēzhàn"), ["huǒ", "chē", "zhàn"])
        XCTAssertEqual(PinyinSyllables.split("nǚ"), ["nǚ"])
        // Inside a word no syllable starts with a vowel: fān + guò, not fāng + uò.
        XCTAssertEqual(PinyinSyllables.split("fānguò"), ["fān", "guò"])
        XCTAssertEqual(PinyinSyllables.split("xiān"), ["xiān"])
        XCTAssertNil(PinyinSyllables.split("Bonjour"))
    }

    func testToneMarkersNumberEachSyllableOfAGroupedWord() {
        XCTAssertEqual(MandarinToneMarkers.annotated("Nǐ hǎo! Wǒ zài Běijīng."), "Nǐ³ hǎo³! Wǒ³ zài⁴ Běi³jīng¹.")
        XCTAssertEqual(MandarinToneMarkers.annotated("Xī'ān"), "Xī¹'ān¹")
        XCTAssertEqual(MandarinToneMarkers.annotated("xièxie"), "xiè⁴xie")
        XCTAssertEqual(MandarinToneMarkers.annotated("xièxie, dì-yī", toneNumbers: [4, 5, 4, 1]), "xiè⁴xie⁵, dì⁴-yī¹")
    }
}
