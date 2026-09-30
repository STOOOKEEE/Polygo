import Foundation

/// The four Mandarin tones as textbook pitch shapes, in semitones from the
/// speaker's own median pitch, at five evenly spaced points of the syllable.
/// They illustrate the expected tone on a chart; classification uses the
/// features of `PronunciationAnalyzer`.
public enum MandarinToneShape {
    /// The expected shape of `tone` (1…4); empty for a neutral tone.
    public static func template(_ tone: Int) -> [Double] {
        switch tone {
        case 1: return [2.5, 2.5, 2.5, 2.5, 2.5]
        case 2: return [-1, -1, 0.5, 2, 3.5]
        case 3: return [-2, -4, -4.5, -3, -0.5]
        case 4: return [4, 3, 1, -1.5, -4]
        default: return []
        }
    }

    /// French description used in feedback (« ton 3 (bas, descend-remonte) »).
    public static func label(_ tone: Int) -> String {
        switch tone {
        case 1: return "ton 1 (haut et plat)"
        case 2: return "ton 2 (monte)"
        case 3: return "ton 3 (bas, descend-remonte)"
        case 4: return "ton 4 (descend)"
        default: return "ton neutre"
        }
    }
}

/// The tone heard on one expected syllable.
public struct SyllableToneAssessment: Codable, Hashable, Sendable {
    public let expected: ExpectedSyllable
    /// The most likely tone heard, nil when the syllable was not measured.
    public let heardTone: Int?
    /// Probability (0…1) that an accepted tone was said; nil when not scored.
    public let score: Double?
    /// Learner pitch through the syllable, in semitones from their median.
    public let contour: [Double]
    public let feedback: String

    /// nil for a neutral or unmeasured syllable.
    public var isCorrect: Bool? {
        guard !expected.acceptedTones.isEmpty, let heardTone else { return nil }
        return expected.acceptedTones.contains(heardTone)
    }
}

/// Comparison of the on-device transcript with the reference characters.
public struct PronunciationWordCheck: Codable, Hashable, Sendable {
    public let transcript: String
    /// 0…1: characters found in order, penalised by extra characters.
    public let score: Double
    public let missing: [String]
    public let extra: [String]
}

/// Offline pronunciation analysis of one recording: tones measured from the
/// pitch of each syllable, words from the on-device transcript when there is
/// one. It does not evaluate consonants or vowels.
public struct PronunciationAnalysis: Codable, Hashable, Sendable {
    public enum Issue: String, Codable, Hashable, Sendable {
        case tooQuiet
        case noVoice
        case tooShort
        case segmentation
        case nothingToScore
    }

    public let verdict: SpeechPronunciationVerdict
    /// Combined score 0…1, nil when the analysis is inconclusive.
    public let score: Double?
    public let toneScore: Double?
    /// nil when no transcript was available: the score is then tones only.
    public let words: PronunciationWordCheck?
    public let syllables: [SyllableToneAssessment]
    public let issue: Issue?

    /// One-sentence French summary of the result.
    public var summary: String {
        if let issue {
            switch issue {
            case .tooQuiet: return "L’enregistrement est trop faible pour mesurer les tons. Rapproche-toi du micro et réessaie."
            case .noVoice: return "Aucune voix n’a été détectée dans l’enregistrement."
            case .tooShort: return "L’enregistrement est trop court pour la phrase attendue. Dis toute la phrase, puis arrête."
            case .segmentation: return "Les syllabes n’ont pas pu être repérées avec assez de certitude. Parle un peu plus lentement et réessaie."
            case .nothingToScore: return "Cette phrase n’a aucun ton mesurable."
            }
        }
        let scored = syllables.filter { $0.isCorrect != nil }
        let correct = scored.filter { $0.isCorrect == true }.count
        var parts = scored.isEmpty ? [] : ["Tons : \(correct) sur \(scored.count) entendus comme attendu."]
        if let words {
            if words.missing.isEmpty && words.extra.isEmpty {
                parts.append("Mots : tout est reconnu.")
            } else {
                if !words.missing.isEmpty { parts.append("Manquant : " + words.missing.joined(separator: "、") + ".") }
                if !words.extra.isEmpty { parts.append("En trop : " + words.extra.joined(separator: "、") + ".") }
            }
        } else {
            parts.append("Score calculé sur les tons seulement, sans transcription des mots.")
        }
        return parts.joined(separator: " ")
    }
}

/// Hybrid offline analysis: pitch tracking for tones, transcript comparison
/// for words. Everything runs locally on the samples it is given.
public struct PronunciationAnalyzer: Sendable {
    /// Share of measured tones heard as expected needed to pass. Measured on
    /// the bundled Kokoro clips (docs/AUDIO.md), 78 % of native-like
    /// recordings reach it, against 12 % for tones drawn at random.
    public static let minimumToneScore = 0.5
    /// Share of reference characters found in order in the transcript.
    public static let minimumWordScore = 0.75

    public init() {}

    public func analyze(
        samples: [Float],
        sampleRate: Double,
        exercise: SpeakingExercise,
        transcript: String?
    ) -> PronunciationAnalysis {
        let expected = MandarinToneTargets.syllables(
            referenceText: exercise.referenceText,
            referencePinyin: exercise.referencePinyin
        )
        let references = [exercise.referenceText] + exercise.acceptedTranscripts
        let wordCheck = transcript.flatMap { Self.checkWords(transcript: $0, references: references) }
        let track = PitchTracker.track(samples: samples, sampleRate: sampleRate)
        return analyze(track: track, expected: expected, words: wordCheck)
    }

    func analyze(track: PitchTrack, expected: [ExpectedSyllable], words: PronunciationWordCheck?) -> PronunciationAnalysis {
        func inconclusive(_ issue: PronunciationAnalysis.Issue) -> PronunciationAnalysis {
            PronunciationAnalysis(verdict: .inconclusive, score: nil, toneScore: nil, words: words, syllables: [], issue: issue)
        }
        guard !expected.isEmpty else { return inconclusive(.nothingToScore) }
        guard track.peakLevel >= Self.quietLevel else { return inconclusive(.tooQuiet) }
        guard let median = track.medianFrequency,
              track.frames.lazy.filter({ $0.frequency != nil }).count >= Self.minimumVoicedFrames else {
            return inconclusive(.noVoice)
        }
        guard let segments = Self.segment(track, count: expected.count) else { return inconclusive(.segmentation) }

        let pitch = track.frames.map { $0.frequency.map { PitchTracker.semitones($0, from: median) } }
        let voiced = segments.map { range in range.compactMap { pitch[$0] } }
        let levels = voiced.map { $0.isEmpty ? nil : $0.reduce(0, +) / Double($0.count) }
        var assessments: [SyllableToneAssessment] = []
        for (index, syllable) in expected.enumerated() {
            // The level of the neighbouring syllables absorbs the slow fall
            // of pitch through a sentence.
            let neighbours = levels[max(0, index - 2)...min(levels.count - 1, index + 2)].compactMap { $0 }
            let local = neighbours.isEmpty ? 0 : neighbours.reduce(0, +) / Double(neighbours.count)
            let contour = voiced[index].count >= Self.minimumSyllableFrames ? Self.trimmed(voiced[index]) : []
            assessments.append(Self.assess(syllable, contour: contour, localLevel: local))
        }

        let scored = assessments.filter { !$0.expected.acceptedTones.isEmpty }
        let measured = scored.compactMap(\.isCorrect)
        if !scored.isEmpty, Double(measured.count) < Double(scored.count) * 0.6 {
            return inconclusive(.segmentation)
        }
        let toneScore = measured.isEmpty ? nil : Double(measured.filter { $0 }.count) / Double(measured.count)
        let score: Double
        switch (toneScore, words?.score) {
        case let (tones?, words?): score = (tones + words) / 2
        case let (tones?, nil): score = tones
        case let (nil, words?): score = words
        case (nil, nil): return inconclusive(.nothingToScore)
        }
        let passed = (toneScore ?? 1) >= Self.minimumToneScore && (words?.score ?? 1) >= Self.minimumWordScore
        return PronunciationAnalysis(
            verdict: passed ? .pass : .needsPractice,
            score: score,
            toneScore: toneScore,
            words: words,
            syllables: assessments,
            issue: nil
        )
    }

    // MARK: Segmentation

    static let quietLevel = -50.0
    static let minimumVoicedFrames = 10
    static let minimumSyllableFrames = 4
    private static let minimumSegmentFrames = 3
    private static let durationWeight = 0.6

    /// Splits the voiced part of the track into `count` syllables. Pauses and
    /// dips in loudness are the candidate boundaries; a dynamic programme picks
    /// the strongest set that keeps syllable lengths plausible. Returns nil
    /// when the recording cannot hold `count` syllables or the boundaries are
    /// too weak to trust.
    static func segment(_ track: PitchTrack, count: Int) -> [Range<Int>]? {
        let frames = track.frames
        guard let first = frames.firstIndex(where: { $0.frequency != nil }),
              let last = frames.lastIndex(where: { $0.frequency != nil }) else { return nil }
        let voiced = frames.map { $0.frequency != nil ? 1 : 0 }
        var prefix = [0]
        for value in voiced { prefix.append(prefix[prefix.count - 1] + value) }
        let total = prefix[last + 1] - prefix[first]
        guard total >= count * minimumSegmentFrames else { return nil }
        guard count > 1 else { return [first..<(last + 1)] }

        let candidates = boundaryCandidates(track, from: first, to: last)
        // Positions are boundaries between frames: segment k covers
        // positions[k]..<positions[k + 1].
        let positions = [first] + candidates.map(\.position) + [last + 1]
        let strengths = [0] + candidates.map(\.strength) + [0]
        let mean = Double(total) / Double(count)
        func voicedCount(_ a: Int, _ b: Int) -> Int { prefix[positions[b]] - prefix[positions[a]] }
        func lengthCost(_ frames: Int) -> Double {
            let ratio = log(Double(frames) / mean)
            return durationWeight * ratio * ratio
        }

        // best[k][i]: best score with k segments ending at position i.
        let unreachable = -Double.infinity
        var best = Array(repeating: Array(repeating: unreachable, count: positions.count), count: count + 1)
        var back = Array(repeating: Array(repeating: -1, count: positions.count), count: count + 1)
        best[0][0] = 0
        for k in 1...count {
            for i in 1..<positions.count {
                if (k == count) != (i == positions.count - 1) { continue }
                for j in 0..<i where best[k - 1][j] > unreachable {
                    let length = voicedCount(j, i)
                    guard length >= minimumSegmentFrames else { continue }
                    let value = best[k - 1][j] - lengthCost(length) + (k < count ? strengths[i] : 0)
                    if value > best[k][i] {
                        best[k][i] = value
                        back[k][i] = j
                    }
                }
            }
        }
        guard best[count][positions.count - 1] > unreachable else { return nil }

        var chosen: [Int] = []
        var index = positions.count - 1
        for k in stride(from: count, through: 1, by: -1) {
            chosen.append(index)
            index = back[k][index]
        }
        let ends = chosen.reversed().map { positions[$0] }
        let starts = [first] + ends.dropLast()

        // A boundary is clear when it falls in a pause or a marked dip; too
        // many guessed boundaries mean the syllables were not found.
        let boundaries = chosen.dropFirst().map { strengths[$0] }
        let clear = boundaries.filter { $0 >= clearBoundary }.count
        guard Double(clear) >= Double(boundaries.count) * minimumClearFraction else { return nil }
        // Long pauses left inside a syllable mean extra speech.
        let unusedPauses = candidates.enumerated().filter { offset, candidate in
            candidate.isLongPause && !chosen.contains(offset + 1)
        }.count
        guard unusedPauses <= max(1, count / 4) else { return nil }
        return zip(starts, ends).map { $0..<$1 }
    }

    private static let clearBoundary = 1.0
    private static let minimumClearFraction = 0.5

    struct Candidate {
        let position: Int
        let strength: Double
        let isLongPause: Bool
    }

    /// Unvoiced gaps (one candidate each) and loudness dips inside voicing.
    static func boundaryCandidates(_ track: PitchTrack, from first: Int, to last: Int) -> [Candidate] {
        let frames = track.frames
        let level = frames.indices.map { index -> Double in
            let window = frames[max(0, index - 1)...min(frames.count - 1, index + 1)]
            return window.map(\.level).reduce(0, +) / Double(window.count)
        }
        var result: [Candidate] = []
        var index = first + 1
        while index <= last {
            if frames[index].frequency == nil {
                var end = index
                while end + 1 <= last, frames[end + 1].frequency == nil { end += 1 }
                let length = end - index + 1
                result.append(Candidate(
                    position: (index + end + 1) / 2,
                    strength: 2 + min(3, Double(length) / 5),
                    isLongPause: length >= 25
                ))
                index = end + 1
                continue
            }
            if frames[index - 1].frequency != nil, index + 1 <= last, frames[index + 1].frequency != nil,
               level[index] <= level[index - 1], level[index] <= level[index + 1] {
                let left = runPeak(level, frames, from: index, step: -1)
                let right = runPeak(level, frames, from: index, step: 1)
                let depth = min(left, right) - level[index]
                if depth >= 1 {
                    result.append(Candidate(position: index, strength: min(2, depth / 4), isLongPause: false))
                    index += 1
                    continue
                }
            }
            // A weak candidate every few voiced frames keeps a long voiced
            // run divisible when it holds several syllables.
            if (index - first) % 3 == 0 {
                result.append(Candidate(position: index, strength: 0, isLongPause: false))
            }
            index += 1
        }
        return result
    }

    private static func runPeak(_ level: [Double], _ frames: [PitchFrame], from index: Int, step: Int) -> Double {
        var peak = level[index]
        var position = index
        for _ in 0..<15 {
            position += step
            guard level.indices.contains(position), frames[position].frequency != nil else { break }
            peak = max(peak, level[position])
        }
        return peak
    }

    // MARK: Tones

    /// Multinomial logistic regression over contour features, one column per
    /// tone 1…4. Fitted on the bundled Kokoro clips (1 388 texts, two voices)
    /// segmented by `segment`, plus textbook contours of careful learner
    /// speech; its held-out accuracy is in docs/AUDIO.md.
    private static let toneWeights: [[Double]] = [
        [1.2130, -0.5560, -0.0615, -0.5954], // bias
        [0.0341, 0.0087, -0.0418, -0.0010], // level
        [0.2134, -0.0187, -0.2651, 0.0704], // level from the neighbours
        [-0.0246, 0.1455, -0.0146, -0.1063], // slope
        [-0.0859, 0.0364, 0.0249, 0.0246], // curvature
        [-0.0127, -0.3124, 0.0379, 0.2872], // head
        [-0.0315, 0.3361, -0.0685, -0.2361], // tail
        [0.8758, -0.4959, -0.0863, -0.2937], // dip
    ]

    /// Drops the onset, where the previous syllable and the consonant still
    /// pull the pitch, and the very end.
    static func trimmed(_ contour: [Double]) -> [Double] {
        let start = Int(Double(contour.count) * 0.2)
        let end = contour.count - Int(Double(contour.count) * 0.1)
        return end - start >= minimumSyllableFrames ? Array(contour[start..<end]) : contour
    }

    static func resampled(_ contour: [Double], points: Int) -> [Double] {
        (0..<points).map { point in
            let start = contour.count * point / points
            let end = max(start + 1, contour.count * (point + 1) / points)
            let slice = contour[start..<min(end, contour.count)]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }

    /// Features of a trimmed contour in semitones: level, level against the
    /// neighbouring syllables, least-squares slope and curvature over the
    /// syllable (time 0…1), start and end thirds and lowest point against
    /// the mean. Duration is left out so that slow speech is not penalised.
    static func toneFeatures(_ contour: [Double], localLevel: Double) -> [Double] {
        let mean = contour.reduce(0, +) / Double(contour.count)
        let times = contour.indices.map { contour.count > 1 ? Double($0) / Double(contour.count - 1) : 0 }
        let third = max(1, contour.count / 3)
        let head = contour.prefix(third).reduce(0, +) / Double(third) - mean
        let tail = contour.suffix(third).reduce(0, +) / Double(third) - mean
        let dip = (contour.min() ?? mean) - mean
        let (slope, curvature) = fit(times, contour)
        return [1, mean, mean - localLevel, slope, curvature, head, tail, dip]
    }

    /// Slope of the least-squares line and leading coefficient of the
    /// least-squares parabola through the points.
    private static func fit(_ x: [Double], _ y: [Double]) -> (slope: Double, curvature: Double) {
        var s = [Double](repeating: 0, count: 5)
        var t = [Double](repeating: 0, count: 3)
        for (xi, yi) in zip(x, y) {
            var power = 1.0
            for k in 0..<5 {
                s[k] += power
                if k < 3 { t[k] += power * yi }
                power *= xi
            }
        }
        let lineDenominator = s[0] * s[2] - s[1] * s[1]
        let slope = lineDenominator != 0 ? (s[0] * t[1] - s[1] * t[0]) / lineDenominator : 0
        // Normal equations of y = a x² + b x + c, solved for a (Cramer).
        func determinant(_ m: [[Double]]) -> Double {
            m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
                - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
                + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])
        }
        let matrix = [[s[4], s[3], s[2]], [s[3], s[2], s[1]], [s[2], s[1], s[0]]]
        let denominator = determinant(matrix)
        guard denominator != 0 else { return (slope, 0) }
        let numerator = determinant([[t[2], s[3], s[2]], [t[1], s[2], s[1]], [t[0], s[1], s[0]]])
        return (slope, numerator / denominator)
    }

    /// Probability of each tone 1…4 for a trimmed contour.
    static func toneProbabilities(_ contour: [Double], localLevel: Double) -> [Int: Double] {
        let features = toneFeatures(contour, localLevel: localLevel)
        let logits = (0..<4).map { tone in zip(features, toneWeights).reduce(0) { $0 + $1.0 * $1.1[tone] } }
        let highest = logits.max() ?? 0
        let weights = logits.map { exp($0 - highest) }
        let sum = weights.reduce(0, +)
        return Dictionary(uniqueKeysWithValues: weights.enumerated().map { ($0.offset + 1, $0.element / sum) })
    }

    static func assess(_ syllable: ExpectedSyllable, contour: [Double], localLevel: Double) -> SyllableToneAssessment {
        let name = syllable.pinyin
        guard !contour.isEmpty else {
            let feedback = syllable.acceptedTones.isEmpty
                ? "\(name) : ton neutre, non noté"
                : "\(name) : ton non mesuré (voix trop faible ou trop brève)"
            return SyllableToneAssessment(expected: syllable, heardTone: nil, score: nil, contour: [], feedback: feedback)
        }
        let probabilities = toneProbabilities(contour, localLevel: localLevel)
        let heard = probabilities.max { $0.value < $1.value }?.key
        let chart = resampled(contour, points: min(10, contour.count))
        guard let expected = syllable.spokenTone, let heard else {
            return SyllableToneAssessment(
                expected: syllable,
                heardTone: heard,
                score: nil,
                contour: chart,
                feedback: "\(name) : ton neutre, non noté"
            )
        }
        let score = syllable.acceptedTones.reduce(0) { $0 + (probabilities[$1] ?? 0) }
        let note = syllable.sandhiNote.map { " — \($0)" } ?? ""
        let feedback = syllable.acceptedTones.contains(heard)
            ? "\(name) : \(MandarinToneShape.label(heard)) bien entendu\(note)"
            : "\(name) : attendu \(MandarinToneShape.label(expected)), entendu \(MandarinToneShape.label(heard))\(note)"
        return SyllableToneAssessment(expected: syllable, heardTone: heard, score: score, contour: chart, feedback: feedback)
    }

    // MARK: Words

    private static let digits: [Character: Character] = [
        "0": "零", "1": "一", "2": "二", "3": "三", "4": "四",
        "5": "五", "6": "六", "7": "七", "8": "八", "9": "九",
    ]

    /// Characters of the transcript aligned with the reference (longest
    /// common subsequence). An empty transcript gives no word check.
    static func checkWords(transcript: String, references: [String]) -> PronunciationWordCheck? {
        let heard = Array(TextNormalizer.normalize(transcript)).map { digits[$0] ?? $0 }
        guard !heard.isEmpty, let reference = references.first else { return nil }
        let normalizedReferences = references.map { TextNormalizer.normalize($0) }
        if normalizedReferences.contains(String(heard)) {
            return PronunciationWordCheck(transcript: transcript, score: 1, missing: [], extra: [])
        }
        let expected = Array(TextNormalizer.normalize(reference))
        var table = Array(repeating: Array(repeating: 0, count: heard.count + 1), count: expected.count + 1)
        for i in stride(from: expected.count - 1, through: 0, by: -1) {
            for j in stride(from: heard.count - 1, through: 0, by: -1) {
                table[i][j] = expected[i] == heard[j] ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
            }
        }
        var missing: [String] = [], extra: [String] = []
        var pendingMissing = "", pendingExtra = ""
        func flush() {
            if !pendingMissing.isEmpty { missing.append(pendingMissing) }
            if !pendingExtra.isEmpty { extra.append(pendingExtra) }
            pendingMissing = ""
            pendingExtra = ""
        }
        var i = 0, j = 0
        while i < expected.count || j < heard.count {
            if i < expected.count, j < heard.count, expected[i] == heard[j] {
                flush()
                i += 1
                j += 1
            } else if j == heard.count || (i < expected.count && table[i + 1][j] >= table[i][j + 1]) {
                pendingMissing.append(expected[i])
                i += 1
            } else {
                pendingExtra.append(heard[j])
                j += 1
            }
        }
        flush()
        let matched = Double(table[0][0])
        return PronunciationWordCheck(
            transcript: transcript,
            score: 2 * matched / Double(expected.count + heard.count),
            missing: missing,
            extra: extra
        )
    }
}
