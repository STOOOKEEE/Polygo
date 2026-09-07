import Foundation

public struct StoryDocument: Codable, Hashable, Sendable, Identifiable {
    public let id: StoryID
    public let title: LocalizedText
    public let summary: LocalizedText
    public let level: String
    public let estimatedMinutes: Int
    public let audio: AssetReference?
    public let paragraphs: [ReadingParagraph]

    public init(id: StoryID, title: LocalizedText, summary: LocalizedText, level: String, estimatedMinutes: Int, audio: AssetReference? = nil, paragraphs: [ReadingParagraph]) {
        self.id = id; self.title = title; self.summary = summary; self.level = level; self.estimatedMinutes = estimatedMinutes; self.audio = audio; self.paragraphs = paragraphs
    }
}
public extension ContentStore {
    /// Content agents can expose story JSON through an app-specific catalogue;
    /// the core keeps the searchable vocabulary contract independent of that UI.
    func searchVocabulary(_ entries: [VocabularyEntry], query: String) -> [VocabularyEntry] {
        let normalizedQuery = TextNormalizer.normalize(query)
        guard !normalizedQuery.isEmpty else { return entries }
        func matches(_ entry: VocabularyEntry) -> Bool {
            let candidates = [entry.hanzi, entry.traditionalHanzi ?? "", entry.pinyin, entry.meaning.resolve(preferred: ["fr", "en"]) ?? ""]
            return candidates.contains { candidate in
                let normalized = TextNormalizer.normalize(candidate)
                return normalized == normalizedQuery || normalized.hasPrefix(normalizedQuery)
            }
        }
        return entries.filter(matches).sorted { $0.hanzi < $1.hanzi }
    }
}
