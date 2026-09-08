import Foundation
import XCTest

/// Independent checks for the versioned HSK classic reference used by course
/// plans. The PDF inventory is kept as provenance; lesson coverage is tested
/// separately against the actual IDs in this catalogue.
final class HSKLegacyCatalogContractTests: XCTestCase {
    private var contentRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Content", isDirectory: true)
    }

    private func catalog() throws -> [String: Any] {
        let url = contentRoot.appendingPathComponent("authoring/hsk-legacy-600.json")
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        return try XCTUnwrap(object as? [String: Any])
    }

    func testCatalogRetainsVersionedOfficialRanksAndExplicitBoundaries() throws {
        let raw = try catalog()
        XCTAssertEqual(raw["schemaVersion"] as? Int, 1)
        XCTAssertEqual(raw["id"] as? String, "hsk-legacy-600")
        XCTAssertFalse((raw["contentVersion"] as? String ?? "").isEmpty)
        XCTAssertFalse((raw["titleFr"] as? String ?? "").isEmpty)

        let standard = try XCTUnwrap(raw["standard"] as? [String: Any])
        XCTAssertEqual(standard["id"] as? String, "HSK-legacy-2.0")
        XCTAssertEqual(standard["version"] as? String, "2.0")

        let levels = try XCTUnwrap(standard["levels"] as? [[String: Any]])
        XCTAssertEqual(levels.count, 3)
        let expectedLevels: [(Int, [Int], Int)] = [
            (1, [1, 150], 150),
            (2, [151, 300], 300),
            (3, [301, 600], 600)
        ]
        for (level, expected) in zip(levels, expectedLevels) {
            XCTAssertEqual(level["level"] as? Int, expected.0)
            XCTAssertEqual(level["range"] as? [Int], expected.1)
            XCTAssertEqual(level["cumulativeCount"] as? Int, expected.2)
        }

        let provenance = try XCTUnwrap(raw["provenance"] as? [String: Any])
        XCTAssertTrue((provenance["inventorySource"] as? String)?.contains("cihui.pdf") == true)
        XCTAssertFalse((provenance["sourceRetrieved"] as? String ?? "").isEmpty)

        let entries = try XCTUnwrap(raw["entries"] as? [[String: Any]])
        XCTAssertEqual(entries.count, 600)
        XCTAssertEqual(entries.map { $0["rank"] as? Int }, Array(1...600))

        var IDs = Set<String>()
        var lexemeKeys = Set<String>()
        var formsByHanzi: [String: [[String: Any]]] = [:]
        for entry in entries {
            let id = try XCTUnwrap(entry["id"] as? String)
            let rank = try XCTUnwrap(entry["rank"] as? Int)
            let sourceForm = try XCTUnwrap(entry["sourceForm"] as? String)
            let hanzi = try XCTUnwrap(entry["hanzi"] as? String)
            let pinyin = try XCTUnwrap(entry["pinyin"] as? String)
            let tones = try XCTUnwrap(entry["toneNumbers"] as? [Int])
            let lexemeKey = try XCTUnwrap(entry["lexemeKey"] as? String)
            let meaning = try XCTUnwrap(entry["meaningFr"] as? String)

            XCTAssertTrue(IDs.insert(id).inserted, "Duplicate catalog ID \(id)")
            XCTAssertTrue(lexemeKeys.insert(lexemeKey).inserted, "Duplicate canonical lexeme key \(lexemeKey)")
            XCTAssertEqual(id, String(format: "hsk20-%03d", rank))
            XCTAssertEqual(lexemeKey, "\(hanzi)|\(pinyin)|\(rank)")
            XCTAssertEqual(entry["canonicalID"] as? String ?? lexemeKey, lexemeKey)
            XCTAssertFalse(sourceForm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(hanzi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(tones.isEmpty)
            XCTAssertTrue(tones.allSatisfy { (0...4).contains($0) })
            XCTAssertEqual(tones.count, pinyin.split(whereSeparator: { $0 == " " || $0 == "\t" }).count, "\(id) pinyin/tone syllable count")
            formsByHanzi[hanzi, default: []].append(entry)
        }

        XCTAssertEqual(IDs.count, entries.count)
        XCTAssertEqual(lexemeKeys.count, entries.count)
        XCTAssertEqual(formsByHanzi["长"]?.count, 2)
        XCTAssertEqual(formsByHanzi["还"]?.count, 2)
        XCTAssertEqual(formsByHanzi["长"]?.map { $0["pinyin"] as? String }, ["cháng", "zhǎng"])
        XCTAssertEqual(formsByHanzi["还"]?.map { $0["pinyin"] as? String }, ["hái", "huán"])
    }

    func testReviewedPolyphonicReadingsStayBoundToTheirGlosses() throws {
        let entries = try XCTUnwrap(try catalog()["entries"] as? [[String: Any]])
        let byRank = Dictionary(uniqueKeysWithValues: entries.compactMap { entry -> (Int, [String: Any])? in
            guard let rank = entry["rank"] as? Int else { return nil }
            return (rank, entry)
        })

        // These are context-specific readings selected by the catalogue's
        // gloss, rather than the first reading returned by a generic pinyin
        // dictionary. Keep this fixture small and reviewable.
        let reviewed: [(Int, String, String, String)] = [
            (159, "长", "cháng", "long"),
            (188, "过", "guo", "déjà"),
            (195, "还", "hái", "encore"),
            (333, "长", "zhǎng", "grandir"),
            (353, "地", "de", "adverbiale"),
            (402, "还", "huán", "rembourser"),
            (421, "教", "jiāo", "enseigner"),
            (562, "一会儿", "yí huìr", "moment"),
            (588, "种", "zhǒng", "sorte")
        ]

        for (rank, hanzi, expectedPinyin, meaningFragment) in reviewed {
            let entry = try XCTUnwrap(byRank[rank], "Missing reviewed rank \(rank)")
            XCTAssertEqual(entry["hanzi"] as? String, hanzi)
            XCTAssertEqual(entry["pinyin"] as? String, expectedPinyin)
            XCTAssertTrue(
                (entry["meaningFr"] as? String)?.lowercased().contains(meaningFragment.lowercased()) == true,
                "Rank \(rank) gloss must justify \(expectedPinyin)"
            )
        }
    }

    func testCatalogMappingsPointToExistingCanonicalLexemes() throws {
        let raw = try catalog()
        let entries = try XCTUnwrap(raw["entries"] as? [[String: Any]])
        let IDs = Set(entries.compactMap { $0["id"] as? String })
        let mappings = try XCTUnwrap(raw["existingCourseMappings"] as? [[String: Any]])
        var existingIDs = Set<String>()
        for mapping in mappings {
            let existingID = try XCTUnwrap(mapping["existingVocabularyID"] as? String)
            let canonicalID = try XCTUnwrap(mapping["canonicalLexemeID"] as? String)
            XCTAssertTrue(existingIDs.insert(existingID).inserted)
            XCTAssertTrue(IDs.contains(canonicalID), "\(canonicalID) must resolve in the canonical catalogue")
        }
    }
}
