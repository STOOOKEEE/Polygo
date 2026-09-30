#!/usr/bin/env python3
"""Bundle recorded Mandarin for the course.

The Mandarin the app says from lesson content -- dialogue lines, reading
paragraphs, vocabulary words and their examples, and the prompts of listening,
dictation, tone, conversation and speaking exercises -- carries a clip from
`Content/assets/audio/`. A clip is named after a hash of its voice, text and
pinyin, so one file serves every identical line said by the same voice.

Kokoro does not realise the tones of an isolated word reliably (a lone second
or third tone comes out flat), so a word clip -- a vocabulary word, a card, a
word prompt -- keeps Kokoro's voice but gets the canonical pitch contour of
each of its tones (WORLD analysis and resynthesis). The result is measured with
a separate pitch tracker; a word whose tones cannot be heard gets no clip and
the device voice says it.

`content_tool.py generate` attaches the clips that exist and needs no speech
engine. Running this script creates the missing clips with Kokoro-82M v1.1-zh
(Apache 2.0, see docs/AUDIO.md), deletes the clips no lesson uses, attaches
them and lints the bundle. It needs the packages listed in docs/AUDIO.md and
ffmpeg; the model is downloaded from Hugging Face at a pinned revision.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import re
import struct
import subprocess
import sys
import unicodedata
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterator

from exercise_kinds import pinyin_tones
from pinyin_format import PinyinError, syllables

AUDIO_DIR = "assets/audio"
ENGINE = "kokoro-82m-v1.1-zh"
MODEL_REPO = "hexgrad/Kokoro-82M-v1.1-zh"
MODEL_REVISION = "01e7505bd6a7a2ac4975463114c3a7650a9f7218"
MODEL_SHA256 = "b1d8410fa44dfb5c15471fd6c4225ea6b4e9ac7fa03c98e8bea47a9928476e2b"
# Chosen for the clearest tone contours among the 100 Chinese voices (see
# docs/AUDIO.md) and an octave apart in pitch, so the two are easy to tell.
VOICES = {"female": "zf_093", "male": "zm_011"}
# Mina and Lin speak with the female voice, Tao and An with the male one.
SPEAKER_VOICES = {"Mina": "female", "Lin": "female", "Tao": "male", "An": "male"}
# Words, readings and listening prompts use the female voice; vocabulary
# examples use the male one so the learner hears both from the first lesson.
NARRATOR = "female"
EXAMPLE_VOICE = "male"
# Pitch of Chao levels 1 and 5 for each voice, in Hz: the 5th and 95th
# percentiles of F0 over 60 dialogue clips of that voice.
TONE_RANGE = {"female": (195.0, 380.0), "male": (87.0, 159.0)}
# Each tone as Chao levels (1 low .. 5 high) at points of the voiced syllable
# (0 start .. 1 end), as said in isolation: a final third tone dips fully.
TONE_SHAPES = {
    1: [(0.0, 5.0), (1.0, 5.0)],
    2: [(0.0, 3.0), (0.3, 2.8), (1.0, 5.0)],
    3: [(0.0, 2.5), (0.45, 1.0), (1.0, 4.0)],
    4: [(0.0, 5.0), (0.15, 5.0), (1.0, 1.0)],
}
HALF_THIRD = [(0.0, 2.0), (0.6, 1.0), (1.0, 1.0)]
# A neutral syllable is short and level, pitched after the tone before it.
NEUTRAL_AFTER = {1: 2.2, 2: 3.0, 3: 4.0, 4: 1.5, None: 2.5}
# Changes when the contour method does, so the word clips are made again.
CONTOUR_VERSION = "world-contour-4"
# The characters' names are written in Latin letters and untoned pinyin. A
# clip says them as these Mandarin syllables.
NAME_READINGS = {"Mina": ("米娜", "mǐ nà"), "Tao": ("涛", "tāo"), "Lin": ("林", "lín"), "An": ("安", "ān")}
# Speech punctuation that a clip may contain besides Hanzi and names.
_PUNCTUATION = set("，。！？、；：“”‘’（）《》…—·,.!?;:\"'() ")
# Punctuation that makes a prompt a sentence rather than an isolated word.
_SENTENCE_PUNCTUATION = set("，。！？、；：…,.!?;:")
_NAME = re.compile(r"[A-Za-z]+")
_TONE_MARKS = {"\u0304", "\u0301", "\u030c", "\u0300"}
SAMPLE_RATE = 24000
BITRATE = "40k"


class AudioError(Exception):
    """A clip cannot be named, made or attached."""


def is_hanzi(char: str) -> bool:
    code = ord(char)
    return 0x3400 <= code <= 0x4DBF or 0x4E00 <= code <= 0x9FFF or 0xF900 <= code <= 0xFAFF or 0x20000 <= code <= 0x2FA1F


def spoken_text(text: str) -> str:
    """The text a clip says: names replaced by their Mandarin readings."""
    return _NAME.sub(lambda match: NAME_READINGS[match.group()][0], text)


def speakable(text: Any) -> bool:
    """Whether a text gets a clip: only Hanzi, speech punctuation and the
    characters' names qualify."""
    if not isinstance(text, str) or not text.strip():
        return False
    if any(name not in NAME_READINGS for name in _NAME.findall(text)):
        return False
    rest = _NAME.sub("", text)
    if not all(is_hanzi(char) or char in _PUNCTUATION for char in rest):
        return False
    return any(map(is_hanzi, spoken_text(text)))


def numbered_pinyin(pinyin: Any, text: str) -> str:
    """Authored pinyin as numbered syllables (`ni3 hao3`), names read as in
    NAME_READINGS, or "" when it does not spell one syllable per Hanzi."""
    if not isinstance(pinyin, str) or not pinyin.strip():
        return ""
    words = re.sub(r"[，。！？、；：“”‘’（）《》…—·,.!?;:\"()]", " ", pinyin).split()
    parts: list[str] = []
    try:
        for word in words:
            parts += syllables(NAME_READINGS[word][1]) if word in NAME_READINGS else syllables(word)
    except PinyinError:
        return ""
    if len(parts) != sum(map(is_hanzi, spoken_text(text))):
        return ""
    numbered = []
    for part, tone in zip(parts, pinyin_tones(parts)):
        plain = "".join(char for char in unicodedata.normalize("NFD", part.lower()) if char not in _TONE_MARKS)
        numbered.append(unicodedata.normalize("NFC", plain).replace("ü", "v") + str(tone or 5))
    return " ".join(numbered)


@dataclass(frozen=True)
class Clip:
    text: str
    voice: str
    pinyin: str
    # An isolated word: said with the canonical contour of its tones.
    word: bool = False

    @property
    def name(self) -> str:
        parts = (ENGINE, VOICES[self.voice], self.text, self.pinyin) + ((CONTOUR_VERSION,) if self.word else ())
        return hashlib.sha256("\n".join(parts).encode("utf-8")).hexdigest()[:24]

    @property
    def file_name(self) -> str:
        return f"{self.name}.m4a"


@dataclass(frozen=True)
class Slot:
    holder: dict[str, Any]
    key: str
    text: str
    voice: str
    pinyin: Any
    # An isolated word or syllable, rather than a sentence.
    word: bool = False
    # A module 0 (pinyin-*) exercise: a lone syllable keeps the device voice.
    syllable_drill: bool = False


def _voice_of(speaker: Any, where: str) -> str:
    if speaker is None:
        return NARRATOR
    if speaker not in SPEAKER_VOICES:
        raise AudioError(f"{where}: speaker '{speaker}' has no voice in SPEAKER_VOICES")
    return SPEAKER_VOICES[speaker]


def _other(voice: str) -> str:
    return "male" if voice == "female" else "female"


def _is_word(text: Any) -> bool:
    """A prompt without sentence punctuation is a word, not a sentence."""
    return isinstance(text, str) and not _SENTENCE_PUNCTUATION.intersection(text)


def slots(lesson: dict[str, Any]) -> Iterator[Slot]:
    """Every audio field of a lesson that this tool manages."""
    lesson_id = lesson.get("id", "?")
    # Vocabulary is canonical across lessons; only module 0's exercises drill syllables.
    drill = str(lesson_id).startswith("pinyin-")
    speaker_of: dict[str, str] = {}
    for block in lesson.get("blocks", []):
        if block.get("kind") == "dialogue":
            for line in block.get("lines", []):
                speaker_of.setdefault(line["hanzi"], line["speaker"])
    for entry in lesson.get("vocabulary", []):
        yield Slot(entry, "audio", entry["hanzi"], NARRATOR, entry.get("pinyin"), word=True)
        example = entry.get("example")
        if isinstance(example, dict):
            yield Slot(example, "audio", example["hanzi"], EXAMPLE_VOICE, example.get("pinyin"))
    vocabulary = {entry["id"]: entry for entry in lesson.get("vocabulary", [])}
    words = {entry["hanzi"] for entry in vocabulary.values()}
    for card in lesson.get("cards", []):
        entry = vocabulary.get(card.get("vocabularyID"))
        for side in ("front", "back"):
            if entry is not None and isinstance(card.get(side), dict):
                yield Slot(card[side], "audio", entry["hanzi"], NARRATOR, entry.get("pinyin"), word=True)
    for block in lesson.get("blocks", []):
        kind = block.get("kind")
        where = f"{lesson_id}.{block.get('id', kind)}"
        if kind == "dialogue":
            for line in block.get("lines", []):
                yield Slot(line, "audio", line["hanzi"], _voice_of(line["speaker"], where), line.get("pinyin"))
        elif kind == "reading":
            for paragraph in block.get("paragraphs", []):
                yield Slot(paragraph, "audio", paragraph["hanzi"], NARRATOR, paragraph.get("pinyin"))
        elif kind == "exercise":
            spec = block["spec"]
            spec_kind = spec.get("kind")
            where = f"{lesson_id}.{spec['header']['id']}"
            if spec_kind in ("listeningChoice", "dictation", "toneDiscrimination"):
                text = spec.get("promptText")
                yield Slot(spec, "promptAudio", text, NARRATOR, None, word=_is_word(text), syllable_drill=drill)
            elif spec_kind == "conversationChoice":
                voice = _voice_of(spec.get("speaker"), where)
                yield Slot(spec, "promptAudio", spec.get("promptText"), voice, None)
                for reply in spec.get("replies", []):
                    yield Slot(reply, "audio", reply["hanzi"], _other(voice), reply.get("pinyin"))
            elif spec_kind == "speaking":
                text = spec["referenceText"]
                yield Slot(spec, "referenceAudio", text, _voice_of(speaker_of.get(text), where), spec.get("referencePinyin"), word=text in words, syllable_drill=drill)
            elif spec_kind == "dialogueOrder":
                for line in spec.get("lines", []):
                    yield Slot(line, "audio", line["hanzi"], _voice_of(line.get("speaker"), where), line.get("pinyin"))


def pinyin_index(lessons: dict[str, dict[str, Any]]) -> dict[str, str]:
    """The pinyin authored for each text anywhere in the course, for prompts
    that carry none: the most frequent spelling, ties broken alphabetically.
    Module 0's carriers count as authored pinyin."""
    seen: dict[str, Counter[str]] = {}
    for lesson in lessons.values():
        pairs = [(slot.text, slot.pinyin) for slot in slots(lesson)]
        pairs += list(lesson.get("metadata", {}).get("carriers", {}).items())
        for text, pinyin in pairs:
            if speakable(text):
                numbered = numbered_pinyin(pinyin, text)
                if numbered:
                    seen.setdefault(text.strip(), Counter())[numbered] += 1
    return {text: min(counts, key=lambda value: (-counts[value], value)) for text, counts in seen.items()}


def indexed_pinyin(text: str, index: dict[str, str]) -> str:
    """The indexed pinyin of `text`, or of the first indexed text that
    contains it (a prompt is often one sentence of a line), else ""."""
    if text in index:
        return index[text]
    for container in sorted(index):
        at = container.find(text)
        if at >= 0:
            before = sum(map(is_hanzi, spoken_text(container[:at])))
            count = sum(map(is_hanzi, spoken_text(text)))
            return " ".join(index[container].split()[before:before + count])
    return ""


def clip_for(slot: Slot, index: dict[str, str]) -> Clip | None:
    if not speakable(slot.text):
        return None
    text = slot.text.strip()
    one_syllable = sum(map(is_hanzi, spoken_text(text))) == 1
    # Pitch-shaped Kokoro sounded worse than the device voice on module 0's
    # syllable drills (listened on an iPhone): those get no clip.
    if slot.syllable_drill and one_syllable:
        return None
    # One syllable is a word wherever it is said.
    word = slot.word or one_syllable
    return Clip(text, slot.voice, numbered_pinyin(slot.pinyin, text) or indexed_pinyin(text, index), word)


def mp4_duration_ms(data: bytes) -> int | None:
    """Duration from the movie header of an MP4/M4A file."""
    at = data.find(b"mvhd")
    if at < 0:
        return None
    version = data[at + 4]
    if version == 1:
        timescale, duration = struct.unpack(">IQ", data[at + 24:at + 36])
    else:
        timescale, duration = struct.unpack(">II", data[at + 16:at + 24])
    return round(duration * 1000 / timescale) if timescale else None


class References:
    """Asset references of the clips present under a content root."""

    def __init__(self, root: Path) -> None:
        self.directory = root / AUDIO_DIR
        self._cache: dict[str, dict[str, Any] | None] = {}

    def __call__(self, clip: Clip | None) -> dict[str, Any] | None:
        if clip is None:
            return None
        if clip.name not in self._cache:
            path = self.directory / clip.file_name
            if path.is_file():
                data = path.read_bytes()
                self._cache[clip.name] = {
                    "id": f"audio-{clip.name}",
                    "kind": "audio",
                    "relativePath": f"{AUDIO_DIR}/{clip.file_name}",
                    "sha256": hashlib.sha256(data).hexdigest(),
                    "durationMilliseconds": mp4_duration_ms(data),
                }
            else:
                self._cache[clip.name] = None
        return self._cache[clip.name]


def attach(lesson: dict[str, Any], index: dict[str, str], references: References) -> bool:
    """Point every managed audio field at its clip, or null; True if changed."""
    changed = False
    for slot in slots(lesson):
        reference = references(clip_for(slot, index))
        if slot.holder.get(slot.key) != reference:
            slot.holder[slot.key] = reference
            changed = True
    return changed


def wanted_clips(lessons: dict[str, dict[str, Any]]) -> dict[str, Clip]:
    """The clips the course uses, by name."""
    index = pinyin_index(lessons)
    clips: dict[str, Clip] = {}
    for lesson in lessons.values():
        for slot in slots(lesson):
            clip = clip_for(slot, index)
            if clip is not None:
                clips[clip.name] = clip
    return clips


def problems(root: Path, lessons: dict[str, dict[str, Any]]) -> list[str]:
    """Stale or dangling audio references, and clips no lesson uses."""
    found: list[str] = []
    index = pinyin_index(lessons)
    references = References(root)
    used: set[str] = set()
    for lesson_id, lesson in sorted(lessons.items()):
        expected = copy.deepcopy(lesson)
        attach(expected, index, references)
        for actual_slot, expected_slot in zip(slots(lesson), slots(expected)):
            actual, wanted = actual_slot.holder.get(actual_slot.key), expected_slot.holder.get(expected_slot.key)
            if actual != wanted:
                found.append(f"{lesson_id}: audio of '{actual_slot.text}' is {'stale' if actual else 'missing'}; run content_tool.py generate")
            if isinstance(wanted, dict):
                used.add(Path(wanted["relativePath"]).name)
    directory = root / AUDIO_DIR
    if directory.is_dir():
        for path in sorted(directory.glob("*.m4a")):
            if path.name not in used:
                found.append(f"{AUDIO_DIR}/{path.name}: no lesson uses this clip; run build_audio.py")
    return found


# -- synthesis ----------------------------------------------------------------


class Kokoro:
    """Kokoro-82M v1.1-zh, saying the authored pinyin rather than guessing it."""

    def __init__(self) -> None:
        try:
            import numpy
            import torch
            from huggingface_hub import hf_hub_download
            from kokoro import KModel, KPipeline
            from pypinyin.contrib.tone_convert import to_finals_tone3, to_initials
        except ImportError as exc:
            raise AudioError(f"the speech engine is not installed ({exc}); see docs/AUDIO.md") from exc
        self.numpy, self.torch, self.infer = numpy, torch, KPipeline.infer
        self._to_initials, self._to_finals = to_initials, to_finals_tone3
        weights = hf_hub_download(MODEL_REPO, "kokoro-v1_1-zh.pth", revision=MODEL_REVISION)
        if hashlib.sha256(Path(weights).read_bytes()).hexdigest() != MODEL_SHA256:
            raise AudioError(f"{weights}: unexpected model checksum")
        config = hf_hub_download(MODEL_REPO, "config.json", revision=MODEL_REVISION)
        self.model = KModel(repo_id=MODEL_REPO, config=config, model=weights).eval()
        self.pipeline = KPipeline(lang_code="z", repo_id=MODEL_REPO, model=self.model)
        self.voices = {
            voice: torch.load(hf_hub_download(MODEL_REPO, f"voices/{name}.pt", revision=MODEL_REVISION), weights_only=True)
            for voice, name in VOICES.items()
        }
        # The frontend asks pypinyin for each word it segments; while a clip
        # has authored pinyin, its syllables are handed out instead, and the
        # frontend's tone sandhi still applies to them.
        self._queue: list[tuple[str, str]] = []
        frontend = self.pipeline.g2p.frontend
        guess = frontend._get_initials_finals

        def authored(word: str) -> tuple[list[str], list[str]]:
            if not self._queue:
                return guess(word)
            taken, self._queue = self._queue[:len(word)], self._queue[len(word):]
            if len(taken) != len(word):
                raise AudioError(f"'{word}': the pinyin has fewer syllables than the text")
            return [initial for initial, _ in taken], [final for _, final in taken]

        frontend._get_initials_finals = authored

    def _syllable(self, numbered: str) -> tuple[str, str]:
        """pypinyin's (initial, final) for a numbered syllable, with the
        frontend's spelling of the apical vowels (zi -> ii, zhi -> iii)."""
        initial = self._to_initials(numbered, strict=True)
        final = self._to_finals(numbered, strict=True, neutral_tone_with_five=True)
        if re.fullmatch(r"i\d", final) and initial in ("z", "c", "s"):
            final = "ii" + final[1:]
        elif re.fullmatch(r"i\d", final) and initial in ("zh", "ch", "sh", "r"):
            final = "iii" + final[1:]
        return initial, final

    def say(self, clip: Clip) -> tuple[Any, list[tuple[int, int, int]]]:
        """Samples at 24 kHz, and each syllable's tone and sample span. Each
        sentence is synthesized alone, then joined with 300 ms of silence."""
        numbered = clip.pinyin.split()
        pieces, spans, offset = [], [], 0
        gap = self.numpy.zeros(int(0.3 * SAMPLE_RATE), dtype=self.numpy.float32)
        sentences = re.findall(r"[^。！？!?]+[。！？!?”’」』）)]*", spoken_text(clip.text))
        for sentence in (part for part in sentences if any(map(is_hanzi, part))):
            count = sum(map(is_hanzi, sentence))
            mine, numbered = numbered[:count], numbered[count:]
            self._queue = [self._syllable(syllable) for syllable in mine]
            phonemes, _ = self.pipeline.g2p(sentence)
            if self._queue:
                raise AudioError(f"'{clip.text}': the text has fewer syllables than the pinyin")
            # The vocoder adds noise: a fixed seed makes every clip reproducible.
            self.torch.manual_seed(0)
            with self.torch.no_grad():
                output = self.infer(self.model, phonemes, self.voices[clip.voice], 1.0)
            audio = output.audio.numpy().astype(self.numpy.float32)
            start, end = _voiced_bounds(self.numpy, audio)
            spans += [(tone, offset + a - start, offset + b - start) for tone, a, b in _syllable_spans(phonemes, output.pred_dur.tolist())]
            if pieces:
                pieces.append(gap)
                offset += len(gap)
            pieces.append(audio[start:end])
            offset += end - start
        if not pieces:
            raise AudioError(f"'{clip.text}': nothing to say")
        return self.numpy.concatenate(pieces), spans


def _voiced_bounds(numpy: Any, audio: Any) -> tuple[int, int]:
    """The span above -40 dB of the loudest 10 ms, with 50 ms before and 100 ms after."""
    hop = SAMPLE_RATE // 100
    frames = numpy.sqrt(numpy.convolve(audio ** 2, numpy.ones(hop) / hop, mode="same"))
    loud = numpy.nonzero(frames > frames.max() * 0.01)[0]
    if len(loud) == 0:
        return 0, len(audio)
    return max(0, int(loud[0]) - SAMPLE_RATE // 20), min(len(audio), int(loud[-1]) + SAMPLE_RATE // 10)


def _syllable_spans(phonemes: str, durations: list[int]) -> list[tuple[int, int, int]]:
    """(tone, start, end) of each syllable: a Kokoro duration unit is 600 samples,
    with one unit list entry per phoneme character between BOS and EOS."""
    spans: list[tuple[int, int, int]] = []
    position = durations[0] * 600
    start = None
    for char, units in zip(phonemes, durations[1:-1]):
        size = units * 600
        if char in "12345":
            if start is not None:
                spans.append((int(char), start, position + size))
            start = None
        elif "\u3100" <= char <= "\u312f" or is_hanzi(char):
            start = position if start is None else start
        else:
            start = None
        position += size
    return spans


def spoken_tones(numbered: str) -> list[int]:
    """The tone said on each syllable of numbered pinyin (5 for neutral): in a
    run of third tones, all but the last are said as second tones."""
    tones = [int(syllable[-1]) for syllable in numbered.split()]
    for position in range(len(tones) - 1):
        if tones[position] == tones[position + 1] == 3:
            tones[position] = 2
    return tones


def _contour(tones: list[int], position: int) -> list[tuple[float, float]]:
    tone = tones[position]
    if tone == 5:
        before = tones[position - 1] if position else None
        level = NEUTRAL_AFTER[before if before != 5 else None]
        return [(0.0, level), (1.0, level - 0.4)]
    if tone == 3 and position < len(tones) - 1:
        return HALF_THIRD
    return TONE_SHAPES[tone]


def impose_tones(numpy: Any, audio: Any, spans: list[tuple[int, int, int]], tones: list[int], voice: str) -> tuple[Any, list[tuple[int, int, int]]]:
    """The clip said with the canonical contour of `tones`, and the loud part
    (tone, start, end) of each syllable in it.

    WORLD (pyworld) analyses the clip into pitch, spectral envelope and
    aperiodicity; the pitch of each voiced syllable is replaced by its tone's
    contour, scaled to the voice's range, smoothed over 25 ms, and the clip is
    resynthesized: timbre and durations stay Kokoro's. Kokoro's durations place
    the syllables relative to each other but not in absolute time: when the
    voiced runs of the clip (unvoiced initials part them) are as many as the
    syllables, each run is a syllable; otherwise Kokoro's syllables are
    stretched onto the voiced part of the clip.
    """
    try:
        import pyworld
    except ImportError as exc:
        raise AudioError(f"pyworld is not installed ({exc}); see docs/AUDIO.md") from exc
    signal = audio.astype(numpy.float64)
    frame_ms = 5.0
    f0, times = pyworld.harvest(signal, SAMPLE_RATE, f0_floor=60.0, f0_ceil=600.0, frame_period=frame_ms)
    envelope = pyworld.cheaptrick(signal, f0, times, SAMPLE_RATE)
    aperiodicity = pyworld.d4c(signal, f0, times, SAMPLE_RATE)
    hop = SAMPLE_RATE * frame_ms / 1000
    window = int(0.02 * SAMPLE_RATE)
    energy = numpy.sqrt(numpy.convolve(signal ** 2, numpy.ones(window) / window, mode="same"))
    positions = numpy.arange(len(f0)) * hop
    frame_energy = energy[numpy.minimum(positions.astype(int), len(energy) - 1)]
    # Harvest also finds voicing in near-silence and in fricatives: speech is
    # where DIO agrees and the clip is audible.
    agreed, _ = pyworld.dio(signal, SAMPLE_RATE, f0_floor=60.0, f0_ceil=600.0, frame_period=frame_ms)
    voiced = numpy.nonzero((f0 > 0) & (agreed[:len(f0)] > 0) & (frame_energy >= 0.05 * frame_energy.max()))[0]
    if len(voiced) == 0 or len(spans) != len(tones):
        raise AudioError("no voiced syllables to shape")
    first, last = voiced[0] * hop, (voiced[-1] + 1) * hop
    start, end = spans[0][1], spans[-1][2]
    scale = (last - first) / max(1, end - start)
    bounds = [first] + [first + (b - start) * scale for _, _, b in spans[:-1]] + [last]
    # Each inner boundary moves to the quietest 5 ms within 60 ms: the
    # consonant or the transition between two vowels.
    reach = int(0.06 * SAMPLE_RATE)
    for position in range(1, len(bounds) - 1):
        low_edge = max(int(bounds[position - 1]) + reach // 2, int(bounds[position]) - reach)
        high_edge = min(int(bounds[position + 1]) - reach // 2, int(bounds[position]) + reach)
        if low_edge < high_edge:
            bounds[position] = low_edge + int(numpy.argmin(energy[low_edge:high_edge:int(hop)])) * int(hop)
    target = f0.copy()
    low, high = TONE_RANGE[voice]
    cores = []
    for position, tone in enumerate(tones):
        frames = numpy.nonzero((positions >= bounds[position]) & (positions < bounds[position + 1]) & (f0 > 0))[0]
        spoken = frames[agreed[frames] > 0]
        if len(spoken) == 0:
            raise AudioError("a syllable has no voiced frame")
        # The contour spans the loud voiced part of the syllable, where it is
        # heard; the quiet voicing around it holds the contour's ends.
        loud = spoken[frame_energy[spoken] >= 0.2 * frame_energy[spoken].max()]
        where = numpy.clip((frames - loud[0]) / max(1, loud[-1] - loud[0]), 0.0, 1.0)
        points = _contour(tones, position)
        levels = numpy.interp(where, [at for at, _ in points], [level for _, level in points])
        target[frames] = low * (high / low) ** ((levels - 1) / 4)
        cores.append((tone, int(loud[0] * hop), int((loud[-1] + 1) * hop)))
    is_voiced = (target > 0).astype(numpy.float64)
    kernel = numpy.ones(5)
    total = numpy.convolve(numpy.log(numpy.maximum(target, 1.0)) * is_voiced, kernel, mode="same")
    count = numpy.convolve(is_voiced, kernel, mode="same")
    smoothed = numpy.where(target > 0, numpy.exp(total / numpy.maximum(count, 1.0)), 0.0)
    shaped = pyworld.synthesize(smoothed, envelope, aperiodicity, SAMPLE_RATE, frame_ms)
    return shaped.astype(numpy.float32), cores


@dataclass(frozen=True)
class Pitch:
    """A syllable's measured pitch, in Chao levels of the voice's range
    (1 low .. 5 high; one level is about 3 semitones)."""
    tone: int
    head: float
    tail: float
    dip: float
    mean: float

    def heard(self) -> bool:
        """Tone 1 stays high and level, tone 2 rises, tone 3 goes low and
        either rises again or stays low, tone 4 falls."""
        if self.tone == 1:
            return abs(self.tail - self.head) < 0.7 and self.dip > min(self.head, self.tail) - 1.0 and self.mean >= 3.5
        if self.tone == 2:
            return self.tail - self.head >= 0.7
        if self.tone == 3:
            return self.dip <= 1.8 and (self.tail - self.dip >= 1 or self.mean <= 2)
        if self.tone == 4:
            return self.head - self.tail >= 0.9
        return True


def measure_pitch(numpy: Any, audio: Any, spans: list[tuple[int, int, int]], voice: str) -> list[Pitch] | None:
    """Each full-tone syllable's pitch, tracked by DIO and StoneMask (another
    estimator than the Harvest that shaped it), or None when a syllable has
    too few voiced frames."""
    import pyworld
    signal = audio.astype(numpy.float64)
    f0, times = pyworld.dio(signal, SAMPLE_RATE, f0_floor=60.0, f0_ceil=600.0, frame_period=5.0)
    f0 = pyworld.stonemask(signal, f0, times, SAMPLE_RATE)
    centres = times * SAMPLE_RATE
    low_hz, high_hz = TONE_RANGE[voice]
    measured = []
    for tone, start, end in spans:
        if tone == 5:
            continue
        pitches = f0[(centres >= start) & (centres < end) & (f0 > 0)]
        if len(pitches) < 8:
            return None
        inside = 1 + 4 * numpy.log2(pitches / low_hz) / numpy.log2(high_hz / low_hz)
        quarter = max(1, len(inside) // 4)
        middle = inside[len(inside) // 5: len(inside) - len(inside) // 5]
        # The 10th percentile, not the minimum: one octave slip is not a dip.
        measured.append(Pitch(
            tone, float(numpy.mean(inside[:quarter])), float(numpy.mean(inside[-quarter:])), float(numpy.percentile(middle, 10)), float(numpy.mean(inside)),
        ))
    return measured


def decode(path: Path, numpy: Any) -> Any:
    """The samples of an encoded clip, as the app plays them."""
    raw = subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", str(SAMPLE_RATE), "-"],
        capture_output=True, check=True,
    ).stdout
    return numpy.frombuffer(raw, dtype="<f4").astype(numpy.float32)


def encode(numpy: Any, audio: Any, target: Path) -> None:
    """Level the clip to -16 dBFS RMS over its voiced frames (peaks at most
    -1 dBFS), fade its ends over 5 ms and write mono AAC in MP4."""
    hop = SAMPLE_RATE // 100
    frames = numpy.sqrt(numpy.convolve(audio ** 2, numpy.ones(hop) / hop, mode="same"))
    voiced = audio[frames > frames.max() * 0.1]
    gain = 10 ** (-16 / 20) / max(float(numpy.sqrt(numpy.mean(voiced ** 2))), 1e-6)
    gain = min(gain, 10 ** (-1 / 20) / max(float(numpy.max(numpy.abs(audio))), 1e-6))
    audio = audio * gain
    fade = numpy.linspace(0, 1, SAMPLE_RATE // 200, dtype=numpy.float32)
    audio[:len(fade)] *= fade
    audio[-len(fade):] *= fade[::-1]
    partial = target.with_suffix(".partial.m4a")
    subprocess.run(
        [
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-f", "f32le", "-ar", str(SAMPLE_RATE), "-ac", "1", "-i", "-",
            "-c:a", "aac", "-b:a", BITRATE, "-map_metadata", "-1",
            "-fflags", "+bitexact", "-flags:a", "+bitexact", "-movflags", "+faststart",
            str(partial),
        ],
        input=audio.astype("<f4").tobytes(),
        check=True,
    )
    partial.replace(target)


def main(argv: list[str]) -> int:
    from content_tool import ContentError, all_lesson_files, attach_audio, lint_bundle

    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=Path("Content"))
    args = parser.parse_args(argv)
    directory = args.root / AUDIO_DIR
    directory.mkdir(parents=True, exist_ok=True)
    try:
        clips = wanted_clips(all_lesson_files(args.root))
        missing = sorted(name for name in clips if not (directory / clips[name].file_name).exists())
        rejected: list[Clip] = []
        unshaped: list[Clip] = []
        measured: list[Pitch] = []
        if missing:
            engine = Kokoro()

            def heard(target: Path, cores: list[tuple[int, int, int]], voice: str) -> list[Pitch] | None:
                pitch = measure_pitch(engine.numpy, decode(target, engine.numpy), cores, voice)
                return pitch if pitch is not None and all(syllable.heard() for syllable in pitch) else None

            for done, name in enumerate(missing, start=1):
                clip = clips[name]
                target = directory / clip.file_name
                audio, spans = engine.say(clip)
                if not clip.word:
                    encode(engine.numpy, audio, target)
                else:
                    tones = spoken_tones(clip.pinyin)
                    try:
                        shaped, cores = impose_tones(engine.numpy, audio, spans, tones, clip.voice)
                    except AudioError:
                        rejected.append(clip)
                        continue
                    # The shaped clip, else Kokoro's own when its tones are
                    # heard, else none: the device voice says the word.
                    encode(engine.numpy, shaped, target)
                    pitch = heard(target, cores, clip.voice)
                    if pitch is None:
                        encode(engine.numpy, audio, target)
                        pitch = heard(target, cores, clip.voice)
                        if pitch is None:
                            target.unlink()
                            rejected.append(clip)
                            continue
                        unshaped.append(clip)
                    measured += pitch
                if done % 50 == 0 or done == len(missing):
                    print(f"{done}/{len(missing)} clips", flush=True)
        for path in sorted(directory.glob("*.m4a")):
            if path.stem not in clips:
                path.unlink()
        attach_audio(args.root)
        lint_bundle(args.root)
    except (AudioError, ContentError) as exc:
        print(f"audio error: {exc}", file=sys.stderr)
        return 2
    present = sorted(directory.glob("*.m4a"))
    size = sum(path.stat().st_size for path in present)
    duration = sum(mp4_duration_ms(path.read_bytes()) or 0 for path in present)
    print(f"{len(present)} clips, {size / 1_000_000:.1f} MB, {duration / 60000:.1f} min")
    for tone in range(1, 5):
        of_tone = [syllable for syllable in measured if syllable.tone == tone]
        if of_tone:
            mean = sum(syllable.mean for syllable in of_tone) / len(of_tone)
            rise = sum(syllable.tail - syllable.head for syllable in of_tone) / len(of_tone)
            dip = sum(min(syllable.head, syllable.tail) - syllable.dip for syllable in of_tone) / len(of_tone)
            print(f"tone {tone}: {len(of_tone)} syllables, Chao level {mean:.1f}, end - start {rise:+.1f}, dip {dip:.1f}")
    for clip in unshaped:
        print(f"shaped tones not heard, Kokoro's own kept: {clip.text} {clip.pinyin} ({clip.voice})")
    for clip in rejected:
        print(f"tones not heard, device voice kept: {clip.text} {clip.pinyin} ({clip.voice})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
