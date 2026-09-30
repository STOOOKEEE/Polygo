import Foundation

/// One 10 ms analysis frame of a recording.
public struct PitchFrame: Codable, Hashable, Sendable {
    /// Fundamental frequency in hertz, nil when the frame is not voiced.
    public let frequency: Double?
    /// Loudness in dB relative to full scale.
    public let level: Double
}

/// A pitch track: one frame every `PitchTracker.frameDuration` seconds.
public struct PitchTrack: Codable, Hashable, Sendable {
    public let frames: [PitchFrame]

    /// Median F0 of the voiced frames: the speaker's own reference, so that a
    /// low and a high voice are compared in semitones from their own level.
    public var medianFrequency: Double? {
        let voiced = frames.compactMap(\.frequency).sorted()
        guard !voiced.isEmpty else { return nil }
        return voiced[voiced.count / 2]
    }

    public var peakLevel: Double {
        frames.map(\.level).max() ?? PitchTracker.silenceLevel
    }
}

/// YIN fundamental-frequency estimation (de Cheveigné & Kawahara, 2002) on
/// mono samples, with voicing detection, octave-jump repair and median
/// smoothing. Runs entirely on the device.
public enum PitchTracker {
    public static let frameDuration = 0.01
    static let silenceLevel = -120.0
    static let minimumFrequency = 60.0
    static let maximumFrequency = 500.0
    /// Rate of the signal given to YIN; voice F0 needs no more.
    private static let analysisRate = 8_000.0
    private static let windowDuration = 0.025
    private static let yinThreshold: Float = 0.15
    private static let maximumAperiodicity: Float = 0.35
    /// A voiced frame must be within this many dB of the loudest frame.
    private static let voicingRange = 35.0
    private static let voicingFloor = -55.0

    public static func track(samples: [Float], sampleRate: Double) -> PitchTrack {
        guard sampleRate > 0, !samples.isEmpty else { return PitchTrack(frames: []) }
        let hop = max(1, Int((sampleRate * frameDuration).rounded()))
        let frameCount = samples.count / hop
        guard frameCount > 0 else { return PitchTrack(frames: []) }

        let levels = frameLevels(samples, hop: hop, frameCount: frameCount, window: Int(sampleRate * windowDuration))
        let factor = max(1, Int(sampleRate / analysisRate))
        let rate = sampleRate / Double(factor)
        let decimated = decimate(samples, by: factor)
        let raw = yin(decimated, rate: rate, hop: Double(hop) / Double(factor), frameCount: frameCount)

        let loudest = levels.max() ?? silenceLevel
        let gate = max(voicingFloor, loudest - voicingRange)
        var frequencies: [Double?] = raw.indices.map { index in
            guard levels[index] >= gate, let estimate = raw[index], estimate.aperiodicity <= maximumAperiodicity else { return nil }
            return estimate.frequency
        }
        frequencies = bridgeRuns(repairOctaves(frequencies))
        frequencies = medianSmoothed(frequencies)
        return PitchTrack(frames: frequencies.indices.map { PitchFrame(frequency: frequencies[$0], level: levels[$0]) })
    }

    private static func frameLevels(_ samples: [Float], hop: Int, frameCount: Int, window: Int) -> [Double] {
        samples.withUnsafeBufferPointer { x in
            (0..<frameCount).map { frame in
                let center = frame * hop + hop / 2
                let start = max(0, center - window / 2)
                let end = min(x.count, center + window / 2)
                guard end > start else { return silenceLevel }
                var sum: Float = 0
                for index in start..<end { sum += x[index] * x[index] }
                let rms = Double((sum / Float(end - start)).squareRoot())
                return rms > 0 ? max(silenceLevel, 20 * log10(rms)) : silenceLevel
            }
        }
    }

    /// Two-sample moving average per step before keeping one sample in
    /// `factor`: enough to keep aliasing away from the F0 band.
    private static func decimate(_ samples: [Float], by factor: Int) -> [Float] {
        guard factor > 1 else { return samples }
        let count = samples.count / factor
        return samples.withUnsafeBufferPointer { x in
            (0..<count).map { index in
                let start = index * factor
                var sum: Float = 0
                for offset in 0..<factor { sum += x[start + offset] }
                return sum / Float(factor)
            }
        }
    }

    private static func yin(_ x: [Float], rate: Double, hop: Double, frameCount: Int) -> [(frequency: Double, aperiodicity: Float)?] {
        let minimumLag = max(2, Int(rate / maximumFrequency))
        let maximumLag = Int(rate / minimumFrequency) + 1
        let window = Int(rate * windowDuration)
        var difference = [Float](repeating: 0, count: maximumLag + 2)
        var normalized = [Float](repeating: 1, count: maximumLag + 2)

        return x.withUnsafeBufferPointer { signal in
            (0..<frameCount).map { frame -> (frequency: Double, aperiodicity: Float)? in
                let center = Int(Double(frame) * hop + hop / 2)
                let start = center - (window + maximumLag) / 2
                guard start >= 0, start + window + maximumLag + 1 < signal.count else { return nil }

                var running: Float = 0
                for lag in 1...(maximumLag + 1) {
                    var sum: Float = 0
                    for index in start..<(start + window) {
                        let delta = signal[index] - signal[index + lag]
                        sum += delta * delta
                    }
                    difference[lag] = sum
                    running += sum
                    normalized[lag] = running > 0 ? sum * Float(lag) / running : 1
                }

                var chosen: Int?
                var lag = minimumLag
                while lag <= maximumLag {
                    if normalized[lag] < yinThreshold {
                        while lag + 1 <= maximumLag, normalized[lag + 1] < normalized[lag] { lag += 1 }
                        chosen = lag
                        break
                    }
                    lag += 1
                }
                if chosen == nil {
                    chosen = (minimumLag...maximumLag).min { normalized[$0] < normalized[$1] }
                }
                guard let best = chosen, best > minimumLag, best < maximumLag else { return nil }

                // Parabolic interpolation between the neighbouring lags.
                let before = normalized[best - 1], here = normalized[best], after = normalized[best + 1]
                let curvature = before - 2 * here + after
                let shift = curvature > 0 ? Double((before - after) / (2 * curvature)) : 0
                let period = Double(best) + max(-1, min(1, shift))
                return (rate / period, here)
            }
        }
    }

    /// Halving and doubling errors: a frame an octave away from its voiced
    /// neighbourhood is folded back, or dropped if folding does not help.
    private static func repairOctaves(_ track: [Double?]) -> [Double?] {
        track.indices.map { index in
            guard let value = track[index] else { return nil }
            let neighbourhood = track[max(0, index - 7)...min(track.count - 1, index + 7)].compactMap { $0 }.sorted()
            guard neighbourhood.count >= 5 else { return value }
            let reference = neighbourhood[neighbourhood.count / 2]
            let distance = abs(semitones(value, from: reference))
            guard distance > 8 else { return value }
            let folded = [value * 2, value / 2].min { abs(semitones($0, from: reference)) < abs(semitones($1, from: reference)) } ?? value
            return abs(semitones(folded, from: reference)) < 4 ? folded : nil
        }
    }

    /// Fills single-frame dropouts inside voicing and removes isolated
    /// voiced frames, which are noise rather than speech.
    private static func bridgeRuns(_ track: [Double?]) -> [Double?] {
        var result = track
        for index in track.indices.dropFirst().dropLast() where track[index] == nil {
            if let before = track[index - 1], let after = track[index + 1] {
                result[index] = (before + after) / 2
            }
        }
        var index = 0
        while index < result.count {
            guard result[index] != nil else {
                index += 1
                continue
            }
            var end = index
            while end + 1 < result.count, result[end + 1] != nil { end += 1 }
            if end - index + 1 < 3 {
                for position in index...end { result[position] = nil }
            }
            index = end + 1
        }
        return result
    }

    private static func medianSmoothed(_ track: [Double?]) -> [Double?] {
        track.indices.map { index in
            guard track[index] != nil else { return nil }
            let window = track[max(0, index - 2)...min(track.count - 1, index + 2)].compactMap { $0 }.sorted()
            return window[window.count / 2]
        }
    }

    static func semitones(_ frequency: Double, from reference: Double) -> Double {
        12 * log2(frequency / reference)
    }
}
