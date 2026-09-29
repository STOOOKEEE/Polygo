#!/usr/bin/env python3
"""Bundle recorded Mandarin for the course.

The Mandarin the app says from lesson content -- dialogue lines, reading
paragraphs, vocabulary words and their examples, and the prompts of listening,
dictation, tone, conversation and speaking exercises -- carries a clip from
`Content/assets/audio/`. A clip is named after a hash of its voice, text and
pinyin, so one file serves every identical line said by the same voice.

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
from pinyin_module import PinyinError, syllables

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
# The characters' names are written in Latin letters and untoned pinyin. A
# clip says them as these Mandarin syllables.
NAME_READINGS = {"Mina": ("米娜", "mǐ nà"), "Tao": ("涛", "tāo"), "Lin": ("林", "lín"), "An": ("安", "ān")}
# Speech punctuation that a clip may contain besides Hanzi and names.
_PUNCTUATION = set("，。！？、；：“”‘’（）《》…—·,.!?;:\"'() ")
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
    """Whether a text gets a clip.

    Only Hanzi, speech punctuation and the characters' names qualify, and at
    least two syllables: Kokoro does not realise the tone of a lone syllable
    reliably, so single characters stay with the device voice.
    """
    if not isinstance(text, str) or not text.strip():
        return False
    if any(name not in NAME_READINGS for name in _NAME.findall(text)):
        return False
    rest = _NAME.sub("", text)
    if not all(is_hanzi(char) or char in _PUNCTUATION for char in rest):
        return False
    return sum(map(is_hanzi, spoken_text(text))) >= 2


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

    @property
    def name(self) -> str:
        key = "\n".join((ENGINE, VOICES[self.voice], self.text, self.pinyin))
        return hashlib.sha256(key.encode("utf-8")).hexdigest()[:24]

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
    tone_drill: bool = False


def _voice_of(speaker: Any, where: str) -> str:
    if speaker is None:
        return NARRATOR
    if speaker not in SPEAKER_VOICES:
        raise AudioError(f"{where}: speaker '{speaker}' has no voice in SPEAKER_VOICES")
    return SPEAKER_VOICES[speaker]


def _other(voice: str) -> str:
    return "male" if voice == "female" else "female"


def slots(lesson: dict[str, Any]) -> Iterator[Slot]:
    """Every audio field of a lesson that this tool manages."""
    lesson_id = lesson.get("id", "?")
    speaker_of: dict[str, str] = {}
    for block in lesson.get("blocks", []):
        if block.get("kind") == "dialogue":
            for line in block.get("lines", []):
                speaker_of.setdefault(line["hanzi"], line["speaker"])
    for entry in lesson.get("vocabulary", []):
        yield Slot(entry, "audio", entry["hanzi"], NARRATOR, entry.get("pinyin"))
        example = entry.get("example")
        if isinstance(example, dict):
            yield Slot(example, "audio", example["hanzi"], EXAMPLE_VOICE, example.get("pinyin"))
    vocabulary = {entry["id"]: entry for entry in lesson.get("vocabulary", [])}
    for card in lesson.get("cards", []):
        entry = vocabulary.get(card.get("vocabularyID"))
        for side in ("front", "back"):
            if entry is not None and isinstance(card.get(side), dict):
                yield Slot(card[side], "audio", entry["hanzi"], NARRATOR, entry.get("pinyin"))
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
                yield Slot(spec, "promptAudio", spec.get("promptText"), NARRATOR, None, spec_kind == "toneDiscrimination")
            elif spec_kind == "conversationChoice":
                voice = _voice_of(spec.get("speaker"), where)
                yield Slot(spec, "promptAudio", spec.get("promptText"), voice, None)
                for reply in spec.get("replies", []):
                    yield Slot(reply, "audio", reply["hanzi"], _other(voice), reply.get("pinyin"))
            elif spec_kind == "speaking":
                text = spec["referenceText"]
                yield Slot(spec, "referenceAudio", text, _voice_of(speaker_of.get(text), where), spec.get("referencePinyin"))
            elif spec_kind == "dialogueOrder":
                for line in spec.get("lines", []):
                    yield Slot(line, "audio", line["hanzi"], _voice_of(line.get("speaker"), where), line.get("pinyin"))


def pinyin_index(lessons: dict[str, dict[str, Any]]) -> dict[str, str]:
    """The pinyin authored for each text anywhere in the course, for prompts
    that carry none: the most frequent spelling, ties broken alphabetically."""
    seen: dict[str, Counter[str]] = {}
    for lesson in lessons.values():
        for slot in slots(lesson):
            if speakable(slot.text):
                numbered = numbered_pinyin(slot.pinyin, slot.text)
                if numbered:
                    seen.setdefault(slot.text.strip(), Counter())[numbered] += 1
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
    return Clip(text, slot.voice, numbered_pinyin(slot.pinyin, text) or indexed_pinyin(text, index))


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


def wanted_clips(lessons: dict[str, dict[str, Any]]) -> tuple[dict[str, Clip], set[str]]:
    """The clips the course uses, by name, and the names used by tone drills."""
    index = pinyin_index(lessons)
    clips: dict[str, Clip] = {}
    tone_drills: set[str] = set()
    for lesson in lessons.values():
        for slot in slots(lesson):
            clip = clip_for(slot, index)
            if clip is not None:
                clips[clip.name] = clip
                if slot.tone_drill:
                    tone_drills.add(clip.name)
    return clips, tone_drills


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


def tones_heard(numpy: Any, audio: Any, spans: list[tuple[int, int, int]]) -> bool:
    """Whether the pitch of each full-tone syllable moves the way its tone does.

    A coarse autocorrelation pitch track, in semitones around the clip's
    median, is compared per syllable: tone 1 stays level, tone 2 rises, tone 3
    dips or stays low, tone 4 falls. Neutral syllables are not checked.
    """
    frame, hop = int(0.04 * SAMPLE_RATE), int(0.005 * SAMPLE_RATE)
    centres, pitches = [], []
    peak = max(float(numpy.sqrt(numpy.mean(audio[i:i + frame] ** 2))) for i in range(0, max(1, len(audio) - frame), hop))
    for i in range(0, max(1, len(audio) - frame), hop):
        window = audio[i:i + frame] * numpy.hanning(frame)
        if numpy.sqrt(numpy.mean(window ** 2)) < 0.12 * peak:
            continue
        correlation = numpy.correlate(window, window, "full")[frame - 1:]
        low, high = SAMPLE_RATE // 450, SAMPLE_RATE // 65
        lag = low + int(numpy.argmax(correlation[low:high]))
        if correlation[0] > 0 and correlation[lag] / correlation[0] > 0.4:
            centres.append(i + frame // 2)
            pitches.append(SAMPLE_RATE / lag)
    if not pitches:
        return False
    centres_array, semitones = numpy.array(centres), 12 * numpy.log2(numpy.array(pitches) / numpy.median(pitches))
    for tone, start, end in spans:
        if tone == 5:
            continue
        inside = semitones[(centres_array >= start + (end - start) * 0.15) & (centres_array <= end - (end - start) * 0.1)]
        if len(inside) < 4:
            return False
        quarter = max(1, len(inside) // 4)
        head, tail = float(numpy.mean(inside[:quarter])), float(numpy.mean(inside[-quarter:]))
        middle = inside[len(inside) // 5: len(inside) - len(inside) // 5] if len(inside) >= 5 else inside
        dip = float(numpy.min(middle))
        if tone == 1 and not (abs(tail - head) < 2 and dip > min(head, tail) - 1.5):
            return False
        if tone == 2 and not (tail - head >= 2):
            return False
        if tone == 3 and not (dip <= min(head, tail) - 1.5 or float(numpy.mean(inside)) <= -2):
            return False
        if tone == 4 and not (head - tail >= 2.5):
            return False
    return True


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
        clips, tone_drills = wanted_clips(all_lesson_files(args.root))
        missing = sorted(name for name in clips if not (directory / clips[name].file_name).exists())
        rejected: list[Clip] = []
        if missing:
            engine = Kokoro()
            for done, name in enumerate(missing, start=1):
                clip = clips[name]
                audio, spans = engine.say(clip)
                if name in tone_drills and not tones_heard(engine.numpy, audio, spans):
                    rejected.append(clip)
                    continue
                encode(engine.numpy, audio, directory / clip.file_name)
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
    for clip in rejected:
        print(f"tone check failed, device voice kept: {clip.text} ({clip.voice})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
