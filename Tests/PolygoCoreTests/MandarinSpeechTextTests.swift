import XCTest
@testable import PolygoCore

final class MandarinSpeechTextTests: XCTestCase {
    func testMandarinTargetDropsFrenchInstruction() {
        XCTAssertEqual(
            MandarinSpeechText.target(from: "Dis 你好 à la personne en face de toi."),
            "你好"
        )
    }

    func testMandarinTargetKeepsDigitsInsideChinesePhrase() {
        XCTAssertEqual(MandarinSpeechText.target(from: "我20岁"), "我20岁")
        XCTAssertEqual(MandarinSpeechText.target(from: "20岁"), "20岁")
    }

    func testMandarinTargetReturnsEmptyWhenNoHanziExists() {
        XCTAssertEqual(MandarinSpeechText.target(from: "Écoute le modèle."), "")
        XCTAssertFalse(MandarinSpeechText.containsHanzi("Bonjour"))
    }

    func testMandarinTargetPreservesChinesePunctuation() {
        XCTAssertEqual(
            MandarinSpeechText.target(from: "你好！你叫什么名字？"),
            "你好！你叫什么名字？"
        )
        XCTAssertTrue(MandarinSpeechText.isTargetOnly("你好！"))
        XCTAssertFalse(MandarinSpeechText.isTargetOnly("Dis 你好！"))
    }
}
