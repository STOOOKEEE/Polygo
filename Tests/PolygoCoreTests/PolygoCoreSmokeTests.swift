import Foundation
import XCTest
@testable import PolygoCore

final class PolygoCoreSmokeTests: XCTestCase {
    func testLocalizedTextAcceptsContentShape() throws {
        let data = Data("{\"fr\":\"Bonjour\"}".utf8)
        let value = try JSONDecoder().decode(LocalizedText.self, from: data)
        XCTAssertEqual(value.resolve(preferred: ["fr"]), "Bonjour")
    }

    func testChoiceEvaluationUsesStableChoiceID() throws {
        let id = ExerciseID(rawValue: "exercise")!
        let header = ExerciseHeader(id: id, prompt: .unchecked(["fr": "Choisis"]), objectiveIDs: ["one"])
        let spec = ExerciseSpec.choice(ChoiceExercise(header: header, choices: [], correctChoiceID: "right"))
        let result = DefaultExerciseEngine().evaluate(spec: spec, answer: .choice(choiceID: "right"))
        XCTAssertTrue(result.accepted)
        XCTAssertEqual(result.score, 1)
    }
}
