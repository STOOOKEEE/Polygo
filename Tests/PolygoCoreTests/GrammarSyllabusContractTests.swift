import Foundation
import XCTest

/// Contract of the grammar syllabus shipped in the daily lessons: a note every two or three
/// lessons, each with its examples and two guided-phase exercises that manipulate its structure.
///
/// The lessons are read as raw JSON: `grammarPoints` and the editorial stages are release
/// metadata that the Codable decoder ignores (it only keeps `metadata.grammarPointID`).
final class GrammarSyllabusContractTests: XCTestCase {
    private typealias JSON = [String: Any]

    private struct Note {
        let lesson: Int
        let id: String
        let block: JSON
        let markers: [String]
        let exercises: [JSON]
    }

    private let dailyLessons = 5...70

    private var contentRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Content", isDirectory: true)
    }

    private func rawLesson(_ number: Int) throws -> JSON {
        let url = contentRoot.appendingPathComponent("lessons/lesson-\(String(format: "%02d", number)).json")
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? JSON)
    }

    private func blocks(_ lesson: JSON) throws -> [JSON] {
        try XCTUnwrap(lesson["blocks"] as? [JSON])
    }

    private func grammarBlocks(_ blocks: [JSON]) -> [JSON] {
        blocks.filter { ($0["kind"] as? String) == "introduction" && (($0["id"] as? String) ?? "").contains("-grammar-") }
    }

    private func linkedExercises(_ blocks: [JSON]) -> [JSON] {
        blocks.filter { ($0["kind"] as? String) == "exercise" && (($0["metadata"] as? JSON)?["grammarPointID"] as? String) != nil }
    }

    private func notes() throws -> [Note] {
        try dailyLessons.compactMap { number in
            let lesson = try rawLesson(number)
            let lessonBlocks = try blocks(lesson)
            let grammar = grammarBlocks(lessonBlocks)
            guard !grammar.isEmpty else { return nil }
            XCTAssertEqual(grammar.count, 1, "lesson-\(number) has one grammar note")
            let point = try XCTUnwrap((lesson["grammarPoints"] as? [JSON])?.first, "lesson-\(number) lists its grammar point")
            return Note(
                lesson: number,
                id: try XCTUnwrap(point["id"] as? String),
                block: grammar[0],
                markers: try XCTUnwrap(point["markers"] as? [String]),
                exercises: linkedExercises(lessonBlocks)
            )
        }
    }

    /// The Mandarin an exercise asks the learner to produce, without punctuation.
    private func answer(of spec: JSON) throws -> String {
        let hanziOnly: (String) -> String = { text in
            text.filter { $0.unicodeScalars.contains { (0x3400...0x9FFF).contains($0.value) } }
        }
        switch spec["kind"] as? String {
        case "wordOrder", "translation":
            let tokens = try XCTUnwrap(spec["tokens"] as? [JSON])
            let pieces = Dictionary(uniqueKeysWithValues: tokens.compactMap { token -> (String, String)? in
                guard let id = token["id"] as? String, let hanzi = token["hanzi"] as? String else { return nil }
                return (id, hanzi)
            })
            let order = try XCTUnwrap(spec["correctOrder"] as? [String])
            return order.compactMap { pieces[$0] }.joined()
        case "fillBlank":
            let sentence = try XCTUnwrap(spec["sentence"] as? String)
            let accepted = try XCTUnwrap((spec["acceptedAnswers"] as? [String])?.first)
            return hanziOnly(sentence.replacingOccurrences(of: "___", with: accepted))
        case "choice":
            let choices = try XCTUnwrap(spec["choices"] as? [JSON])
            let correct = try XCTUnwrap(spec["correctChoiceID"] as? String)
            let label = try XCTUnwrap(choices.first { ($0["id"] as? String) == correct }.flatMap { ($0["label"] as? JSON)?["fr"] as? String })
            return String(label.split(separator: " ").first ?? "")
        default:
            XCTFail("unexpected grammar exercise kind \(String(describing: spec["kind"]))")
            return ""
        }
    }

    func testGrammarNotesFallEveryTwoOrThreeLessonsFromTheStartToTheEnd() throws {
        let notes = try notes()
        XCTAssertTrue((25...30).contains(notes.count), "\(notes.count) grammar notes, expected 25–30")
        XCTAssertEqual(Set(notes.map(\.id)).count, notes.count, "note IDs are unique")
        let lessons = notes.map(\.lesson)
        XCTAssertLessThanOrEqual(try XCTUnwrap(lessons.first), dailyLessons.lowerBound + 2, "the first note opens the course")
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(lessons.last), dailyLessons.upperBound - 2, "the last note closes the course")
        for (before, after) in zip(lessons, lessons.dropFirst()) {
            XCTAssertTrue((2...3).contains(after - before), "lesson-\(before) and lesson-\(after) are \(after - before) lessons apart, expected 2–3")
        }
    }

    func testEveryNoteExplainsWithThreeExamplesAndAMistakeToAvoid() throws {
        for note in try notes() {
            let title = ((note.block["title"] as? JSON)?["fr"] as? String) ?? ""
            XCTAssertTrue(title.hasPrefix("Grammaire — "), "\(note.id) title")
            let body = ((note.block["body"] as? JSON)?["fr"] as? String) ?? ""
            let lines = body.components(separatedBy: "\n")
            XCTAssertLessThanOrEqual(try XCTUnwrap(lines.first).count, 600, "\(note.id) explanation is short")
            XCTAssertTrue(lines.contains { $0.hasPrefix("Formule : ") }, "\(note.id) states its formula")
            XCTAssertTrue(lines.contains { $0.hasPrefix("Attention : ") }, "\(note.id) warns about a frequent mistake")
            let examples = lines.enumerated().filter { $0.element.hasPrefix("Exemple ") }
            XCTAssertGreaterThanOrEqual(examples.count, 3, "\(note.id) needs three examples")
            for (position, line) in examples {
                XCTAssertTrue(position + 2 < lines.count && !lines[position + 1].isEmpty && !lines[position + 2].isEmpty, "\(note.id) example needs pinyin and French")
                XCTAssertTrue(note.markers.contains { line.contains($0) }, "\(note.id) example '\(line)' shows none of \(note.markers)")
            }
        }
    }

    func testEveryNoteHasTwoGuidedExercisesWhoseAnswersUseItsStructure() throws {
        for note in try notes() {
            XCTAssertEqual(note.exercises.count, 2, "\(note.id) has two linked exercises")
            var answers: [String] = []
            for block in note.exercises {
                let metadata = try XCTUnwrap(block["metadata"] as? JSON)
                XCTAssertEqual(metadata["grammarPointID"] as? String, note.id)
                XCTAssertEqual(metadata["stage"] as? String, "guided", "\(note.id) exercises belong to guided practice")
                let spec = try XCTUnwrap(block["spec"] as? JSON)
                let text = try answer(of: spec)
                XCTAssertTrue(note.markers.contains { text.contains($0) }, "\(note.id) answer '\(text)' does not use \(note.markers)")
                answers.append(text)
            }
            XCTAssertEqual(Set(answers).count, answers.count, "\(note.id) exercises use two different sentences")
            let kinds = try note.exercises.map { try XCTUnwrap(($0["spec"] as? JSON)?["kind"] as? String) }
            XCTAssertTrue(["wordOrder", "translation"].contains(kinds[0]), "\(note.id) first exercise assembles the structure")
            XCTAssertTrue(["fillBlank", "choice"].contains(kinds[1]), "\(note.id) second exercise picks the right word")
        }
    }

    func testGrammarAppearsOnlyWhereTheSyllabusDesignsIt() throws {
        let designed = Set(try notes().map(\.lesson))
        for number in dailyLessons where !designed.contains(number) {
            let lesson = try rawLesson(number)
            XCTAssertNil(lesson["grammarPoints"], "lesson-\(number) has no grammar point")
            XCTAssertTrue(linkedExercises(try blocks(lesson)).isEmpty, "lesson-\(number) has no grammar exercise")
        }
    }
}
