"""Derive a daily lesson's practice exercises from its authored material.

The authoring pack ships six hand-written exercises per lesson. This module
extends them to a three-phase session (discovery, guided practice, re-use)
without inventing any Mandarin, pinyin, or French: every new exercise is a
recombination of vocabulary rows, example sentences, dialogue lines and reading
sentences that already belong to the lesson. Distractors come from other
vocabulary or sentences of the same lesson and of the two preceding lessons.

Every exercise family PolygoCore decodes may be emitted: `choice`, `wordOrder`,
`fillBlank`, `listeningChoice`, `speaking`, and the kinds of `exercise_kinds`
(`matching`, `dictation`, `toneDiscrimination`, `translation`,
`conversationChoice`, `dialogueOrder`). Every exercise block carries its phase
in `metadata.stage`: the newer kinds open the discovery phase (matching,
dictation, tones), guided practice (translation, conversation) and re-use
(dialogue ordering), and each lesson gets at least `MIN_NEW_KINDS` of them.

A lesson with a grammar note also carries the note's two exercises (`metadata.grammarPointID`): they
lead the guided phase, count in the session's length and in the exposure of the words they present,
but not in the phase's share of derived exercises.

The session is planned as a cover: the lesson introduces at most
`MAX_NEW_WORDS` words, and each of them must be presented by at least
`MIN_EXPOSURES` exercises of at least `MIN_EXPOSURE_KINDS` different kinds.
A sentence exercise counts for every new word it presents.
"""
from __future__ import annotations

import random
import re
from collections import Counter
from dataclasses import dataclass
from typing import Any

from exercise_kinds import (
    CONVERSATION_REPLIES,
    MATCHING_PAIRS,
    MIN_NEW_KINDS,
    NEW_KINDS,
    entry_tones,
    tone_choice_id,
    tone_label,
    tone_options,
)

PHASES = ("discover", "guided", "reuse")
EXERCISE_BUDGET = (15, 20)
EXERCISE_TARGET = 18
MAX_NEW_WORDS = 8
MIN_EXPOSURES = 3
MIN_EXPOSURE_KINDS = 3
GRAMMAR_FAMILY = "grammar"
_PHASE_CAPS = {"discover": 8, "guided": 7, "reuse": 7}
_PHASE_MINIMUM = 5
# Speaking is self-rated and quick to build, so it must not crowd out the rest.
# Each newer kind appears twice at most, so that no lesson is a single drill;
# two orderings of one short dialogue would only repeat each other.
_MAX_PER_KIND = {"speaking": 3, **{kind: 2 for kind in NEW_KINDS}, "dialogueOrder": 1}
# The two matchings and the two dictations of a lesson differ in what they ask.
_VARIED_KINDS = {"matching", "dictation"}
_MAX_TRANSLATION_TILES = 6
_MAX_DICTATION_CHARS = 12

_PUNCTUATION = "，。！？、；：“”‘’（）…—·"
_SENTENCE_END = "。！？"
_STOP_WORDS = {
    "de", "du", "des", "le", "la", "les", "un", "une", "à", "a", "se", "s", "l", "d",
    "en", "au", "aux", "et", "ou", "qui", "que", "pour", "sur", "dans",
}
_LETTERS = "abcdefgh"
# Very common particles and pronouns make a poor blank: many words fit them.
_WEAK_BLANKS = {"的", "了", "吗", "呢", "吧", "啊", "我", "你", "他", "她", "们", "是", "不", "没", "很", "也", "都", "个"}
_MAX_LEXEME = 4
_MAX_TILES = 7
_MIN_LISTENING_CHARS = 4


class ExpansionError(ValueError):
    """A lesson does not contain enough material for the exercise budget."""


@dataclass(frozen=True)
class Sentence:
    hanzi: str
    pinyin: str
    fr: str
    source: str
    label: str | None = None
    vocabulary_id: str | None = None

    @property
    def chars(self) -> list[str]:
        return [char for char in self.hanzi if _is_hanzi(char)]

    @property
    def syllables(self) -> list[str]:
        return re.sub(f"[{re.escape(_PUNCTUATION)}.,!?;:]", " ", self.pinyin).split()

    @property
    def is_clean(self) -> bool:
        """Pure Mandarin text with a translation."""
        stripped = self.hanzi.strip()
        if not stripped or not all(_is_hanzi(char) or char in _PUNCTUATION for char in stripped):
            return False
        return bool(self.fr.strip())

    @property
    def is_aligned(self) -> bool:
        """Whether the pinyin has one syllable per Hanzi (tiles need it; erhua breaks it)."""
        return len(self.chars) == len(self.syllables)

    @property
    def has_inner_punctuation(self) -> bool:
        return any(char in _PUNCTUATION for char in self.hanzi.rstrip(_SENTENCE_END))


@dataclass(frozen=True)
class Exercise:
    phase: str
    spec: dict[str, Any]


def lesson_number(lesson: dict[str, Any]) -> int:
    """The number in a daily lesson's ID (`lesson-10` is 10); `order` follows the course sequence."""
    match = re.fullmatch(r"lesson-(\d+)", lesson["id"])
    if match is None:
        raise ExpansionError(f"{lesson['id']}: not a daily lesson ID")
    return int(match.group(1))


def _is_hanzi(char: str) -> bool:
    return "\u3400" <= char <= "\u4dbf" or "\u4e00" <= char <= "\u9fff"


def _fr(value: Any) -> str:
    if isinstance(value, dict) and isinstance(value.get("fr"), str):
        return value["fr"].strip()
    return ""


def _meaning_tokens(meaning: str) -> set[str]:
    text = re.sub(r"\([^)]*\)", "", meaning.lower())
    tokens = {word for word in re.findall(r"[a-zàâçéèêëîïôûùüÿœ]+", text) if word not in _STOP_WORDS and len(word) > 1}
    return tokens or {text.strip()}


def _meanings_overlap(left: str, right: str) -> bool:
    return bool(_meaning_tokens(left) & _meaning_tokens(right))


def _similar_sentences(left: str, right: str) -> bool:
    """True when two French sentences share most of their content words."""
    words = [_meaning_tokens(value) for value in (left, right)]
    union = words[0] | words[1]
    return not union or len(words[0] & words[1]) / len(union) >= 0.6


def split_sentences(pinyin: str) -> list[str]:
    parts: list[str] = []
    current = ""
    for char in pinyin:
        current += char
        # Some pinyin lines still use ASCII sentence punctuation.
        if char in _SENTENCE_END or char in ".!?":
            parts.append(current)
            current = ""
    if current.strip():
        parts.append(current)
    return parts


def split_french(text: str) -> list[str]:
    return [part for part in re.split(r"(?<=[.!?])\s+", text.strip()) if part]


def _tokenize(text: str, lexicon: set[str]) -> list[tuple[int, str]]:
    """Greedy longest-match segmentation of each Hanzi run, with offsets."""
    tokens: list[tuple[int, str]] = []
    for match in re.finditer(r"[\u3400-\u4dbf\u4e00-\u9fff]+", text):
        run, base, index = match.group(), match.start(), 0
        while index < len(run):
            for size in range(min(_MAX_LEXEME, len(run) - index), 0, -1):
                word = run[index:index + size]
                if size == 1 or word in lexicon:
                    tokens.append((base + index, word))
                    index += size
                    break
    return tokens


@dataclass(frozen=True)
class Candidate:
    """An exercise together with the new words it presents."""

    exercise: Exercise
    words: frozenset[str]
    family: str
    sentence: str | None = None
    # Position of the lesson the exercise draws on, oldest first; reviews sort by it.
    origin: int = 0

    @property
    def kind(self) -> str:
        return self.exercise.spec["kind"]


def _pieces(spec: dict[str, Any]) -> dict[str, str]:
    """The Hanzi of each tile or dialogue line, by identifier."""
    return {item["id"]: item["hanzi"] for key in ("tokens", "lines") for item in spec.get(key, [])}


def exercise_text(spec: dict[str, Any]) -> str:
    """The Mandarin an exercise presents: prompt, sentence, tiles, lines, choices, pairs and expected answer."""
    answers = spec.get("acceptedAnswers") or [""]
    pieces = _pieces(spec)
    parts = [
        spec["header"]["prompt"].get("fr", ""),
        spec.get("promptText") or "",
        spec.get("referenceText") or "",
        spec.get("sentence", "").replace("___", answers[0]),
        "".join(pieces[piece_id] for piece_id in spec.get("correctOrder", [])),
    ]
    parts.extend(_fr(choice.get("label")) for choice in spec.get("choices", []))
    parts.extend(item["hanzi"] for key in ("tokens", "lines", "replies") for item in spec.get(key, []))
    parts.extend(pair["left"] for pair in spec.get("pairs", []))
    return "\n".join(parts)


def word_exposures(specs: list[dict[str, Any]], words: dict[str, str]) -> dict[str, tuple[int, set[str]]]:
    """Count, per word ID, the exercises presenting its Hanzi and their kinds."""
    exposures: dict[str, tuple[int, set[str]]] = {word_id: (0, set()) for word_id in words}
    for spec in specs:
        text = exercise_text(spec)
        for word_id, hanzi in words.items():
            if hanzi in text:
                count, kinds = exposures[word_id]
                exposures[word_id] = (count + 1, kinds | {spec["kind"]})
    return exposures


def exposure_shortfalls(exposures: dict[str, tuple[int, set[str]]]) -> dict[str, tuple[int, int]]:
    return {
        word_id: (count, len(kinds))
        for word_id, (count, kinds) in exposures.items()
        if count < MIN_EXPOSURES or len(kinds) < MIN_EXPOSURE_KINDS
    }


def _spread_kinds(items: list[Candidate]) -> list[Candidate]:
    """Reorder a phase so that two exercises of one kind rarely follow each other."""
    remaining = list(items)
    result: list[Candidate] = []
    while remaining:
        index = next((i for i, item in enumerate(remaining) if not result or item.kind != result[-1].kind), 0)
        result.append(remaining.pop(index))
    return result


class SessionBuilder:
    """Every exercise a lesson's material can produce (see `candidates`).

    Review lessons subclass it with their own material and exercise identity.
    """

    def __init__(
        self,
        lesson: dict[str, Any],
        new_ids: set[str],
        earlier_vocabulary: list[dict[str, Any]],
        lexicon: set[str],
        identity: tuple[int, str] | None = None,
    ) -> None:
        self.lesson = lesson
        # The number offsets the walk of correct answers; the prefix opens every exercise ID.
        self.lesson_no, self.exercise_prefix = identity or (lesson_number(lesson), f"ex-l{lesson_number(lesson)}")
        self.new_ids = new_ids
        self.lexicon = lexicon
        self.vocabulary = [entry for entry in lesson["vocabulary"] if _fr(entry.get("meaning"))]
        self.hanzi = {entry["id"]: entry["hanzi"] for entry in self.vocabulary if entry["id"] in new_ids}
        self.earlier = [entry for entry in earlier_vocabulary if _fr(entry.get("meaning"))]
        # Two rows with one Hanzi (还 hái, 还 huán) cannot be told apart by the
        # exercises that name a word by its Hanzi alone.
        self.homographs = {hanzi for hanzi, count in Counter(entry["hanzi"] for entry in self.vocabulary).items() if count > 1}
        self.serial = 0
        self.used_prompts: set[tuple[str, str]] = set()
        self.asked: set[str] = set()
        self.objectives = {
            "understand": self._objective("understand", 0),
            "produce": self._objective("produce", -1),
        }
        self.turns = self._dialogue_turns()
        self.dialogue = [turn for turn in self.turns if turn is not None]
        self.reading, self.reading_title = self._reading_sentences()
        self.examples = self._example_sentences()
        self._reserve_authored()

    # -- source material -------------------------------------------------

    def _objective(self, suffix: str, fallback_index: int) -> str:
        ids = [objective["id"] for objective in self.lesson["objectives"]]
        matching = [value for value in ids if value.endswith("-" + suffix)]
        return matching[0] if matching else ids[fallback_index]

    def _block(self, kind: str) -> dict[str, Any] | None:
        return next((block for block in self.lesson["blocks"] if block.get("kind") == kind), None)

    def _dialogue_turns(self) -> list[Sentence | None]:
        """Each dialogue line in order, None where it is not clean Mandarin."""
        block = self._block("dialogue")
        lines = block.get("lines", []) if block else []
        turns: list[Sentence | None] = []
        for line in lines:
            sentence = Sentence(
                line.get("hanzi", ""), line.get("pinyin", ""), _fr(line.get("translation")),
                "dialogue", label=line.get("speaker"),
            )
            turns.append(sentence if sentence.is_clean else None)
        return turns

    def _reading_sentences(self) -> tuple[list[Sentence], str]:
        block = self._block("reading")
        if not block:
            return [], ""
        result: list[Sentence] = []
        for paragraph in block.get("paragraphs", []):
            hanzi_parts = split_sentences(paragraph.get("hanzi", ""))
            pinyin_parts = split_sentences(paragraph.get("pinyin", ""))
            french_parts = split_french(_fr(paragraph.get("translation")))
            if not (len(hanzi_parts) == len(pinyin_parts) == len(french_parts)):
                continue
            for hanzi, pinyin, french in zip(hanzi_parts, pinyin_parts, french_parts):
                sentence = Sentence(hanzi.strip(), pinyin.strip(), french, "reading")
                if sentence.is_clean:
                    result.append(sentence)
        return result, _fr(block.get("title"))

    def _example_sentences(self) -> list[Sentence]:
        ordered = sorted(self.vocabulary, key=lambda entry: entry["id"] not in self.new_ids)
        result = []
        for entry in ordered:
            example = entry.get("example")
            if not isinstance(example, dict):
                continue
            sentence = Sentence(
                example.get("hanzi", ""), example.get("pinyin", ""), _fr(example.get("translation")),
                "example", vocabulary_id=entry["id"],
            )
            if sentence.is_clean:
                result.append(sentence)
        return result

    def _reserve_authored(self) -> None:
        """Keep the authored prompts, and the words they ask about, out of the new exercises."""
        by_hanzi = {entry["hanzi"]: entry["id"] for entry in self.vocabulary}
        for block in self.lesson["blocks"]:
            spec = block.get("spec") if block.get("kind") == "exercise" else None
            if not isinstance(spec, dict):
                continue
            prompt = _fr(spec["header"].get("prompt"))
            self.used_prompts.add((prompt, spec.get("promptText") or ""))
            if prompt.startswith("Que signifie"):
                self.asked.update(vocabulary_id for hanzi, vocabulary_id in by_hanzi.items() if hanzi in prompt)

    # -- helpers ---------------------------------------------------------

    def _rng(self, name: str) -> random.Random:
        return random.Random(f"{self.lesson['id']}:{name}")

    @staticmethod
    def key(sentence: Sentence) -> str:
        return re.sub(f"[{re.escape(_PUNCTUATION)}]", "", sentence.hanzi)

    def _choice_position(self, size: int) -> int:
        # A stride coprime with the choice count walks every slot and never
        # repeats one twice in a row; the lesson number offsets the walk.
        stride = 3 if size == 4 else 2
        position = (self.lesson_no + self.serial * stride) % size
        self.serial += 1
        return position

    def _header(
        self, exercise_id: str, prompt: str, instruction: str, objective: str, subject: str = ""
    ) -> dict[str, Any] | None:
        """Return None when this prompt already asks about the same subject.

        Listening prompts are generic by design, so the Mandarin they play is
        part of the identity of the question.
        """
        if (prompt, subject) in self.used_prompts:
            return None
        self.used_prompts.add((prompt, subject))
        return {
            "id": f"{self.exercise_prefix}-{exercise_id}",
            "prompt": {"fr": prompt},
            "instruction": {"fr": instruction},
            "objectiveIDs": [self.objectives[objective]],
            "required": True,
        }

    def _choices(self, correct: str, distractors: list[str]) -> tuple[list[dict[str, Any]], str]:
        labels = list(distractors)
        position = self._choice_position(len(labels) + 1)
        labels.insert(position, correct)
        choices = [
            {"id": _LETTERS[index], "label": {"fr": label}, "audio": None}
            for index, label in enumerate(labels)
        ]
        return choices, _LETTERS[position]

    def _meaning_distractors(self, target: dict[str, Any], count: int, name: str) -> list[str]:
        meaning = _fr(target["meaning"])
        chosen: list[str] = []
        for pool in (self.vocabulary, self.earlier):
            candidates = [
                entry for entry in pool
                if entry["id"] != target["id"] and entry["hanzi"] != target["hanzi"]
            ]
            self._rng(name + str(len(pool))).shuffle(candidates)
            for entry in candidates:
                label = _fr(entry["meaning"])
                if _meanings_overlap(meaning, label) or any(_meanings_overlap(label, other) for other in chosen):
                    continue
                chosen.append(label)
                if len(chosen) == count:
                    return chosen
        return chosen

    def _word_distractors(self, target: dict[str, Any], count: int, name: str) -> list[dict[str, Any]]:
        meaning = _fr(target["meaning"])
        chosen: list[dict[str, Any]] = []
        for pool in (self.vocabulary, self.earlier):
            candidates = [
                entry for entry in pool
                if entry["id"] != target["id"] and entry["hanzi"] != target["hanzi"]
                and entry["hanzi"] not in {other["hanzi"] for other in chosen}
            ]
            self._rng(name + str(len(pool))).shuffle(candidates)
            # New words make the best wrong answers: each choice shows them again.
            candidates.sort(key=lambda entry: (entry["id"] not in self.new_ids, abs(len(entry["hanzi"]) - len(target["hanzi"]))))
            for entry in candidates:
                label = _fr(entry["meaning"])
                if _meanings_overlap(meaning, label) or any(_meanings_overlap(label, _fr(other["meaning"])) for other in chosen):
                    continue
                chosen.append(entry)
                if len(chosen) == count:
                    return chosen
        return chosen

    def _sentence_distractors(self, target: Sentence, count: int, name: str) -> list[str]:
        pool = self.dialogue + self.reading + self.examples
        candidates = [
            sentence for sentence in pool
            if sentence.hanzi != target.hanzi and sentence.fr != target.fr
        ]
        self._rng(name).shuffle(candidates)
        candidates.sort(key=lambda sentence: abs(len(sentence.fr) - len(target.fr)) // 25)
        chosen: list[str] = []
        for sentence in candidates:
            if _similar_sentences(sentence.fr, target.fr) or any(_similar_sentences(sentence.fr, other) for other in chosen):
                continue
            chosen.append(sentence.fr)
            if len(chosen) == count:
                break
        return chosen

    # -- exercise families -----------------------------------------------

    def word_meaning(self, phase: str, name: str, entry: dict[str, Any]) -> Exercise | None:
        distractors = self._meaning_distractors(entry, 3, name)
        if len(distractors) < 2:
            return None
        choices, correct = self._choices(_fr(entry["meaning"]), distractors)
        header = self._header(
            name, f"Que signifie {entry['hanzi']} ({entry['pinyin']}) ?",
            "Choisis le sens du mot.", "understand",
        )
        if header is None:
            return None
        return Exercise(phase, {"kind": "choice", "header": header, "choices": choices, "correctChoiceID": correct})

    def word_reverse(self, phase: str, name: str, entry: dict[str, Any]) -> Exercise | None:
        others = self._word_distractors(entry, 3, name)
        if len(others) < 2:
            return None
        choices, correct = self._choices(
            f"{entry['hanzi']} ({entry['pinyin']})",
            [f"{item['hanzi']} ({item['pinyin']})" for item in others],
        )
        header = self._header(
            name, f"Comment dit-on « {_fr(entry['meaning'])} » en chinois ?",
            "Choisis le mot chinois qui convient.", "understand",
        )
        if header is None:
            return None
        return Exercise(phase, {"kind": "choice", "header": header, "choices": choices, "correctChoiceID": correct})

    def word_listening(self, phase: str, name: str, entry: dict[str, Any]) -> Exercise | None:
        distractors = self._meaning_distractors(entry, 3, name)
        if len(distractors) < 2:
            return None
        choices, correct = self._choices(_fr(entry["meaning"]), distractors)
        header = self._header(
            name, "Écoute le mot, puis choisis son sens.",
            "Appuie sur l’écoute, puis choisis le sens du mot.", "understand", entry["hanzi"],
        )
        if header is None:
            return None
        return Exercise(phase, {
            "kind": "listeningChoice", "header": header, "promptText": entry["hanzi"],
            "choices": choices, "correctChoiceID": correct,
        })

    def word_pick(self, phase: str, name: str, entry: dict[str, Any]) -> Exercise | None:
        """Hear a word, then find it among written words."""
        others = self._word_distractors(entry, 3, name)
        if len(others) < 2:
            return None
        choices, correct = self._choices(
            f"{entry['hanzi']} ({entry['pinyin']})",
            [f"{item['hanzi']} ({item['pinyin']})" for item in others],
        )
        header = self._header(
            name, "Écoute le mot, puis choisis-le à l’écrit.",
            "Appuie sur l’écoute, puis choisis le mot que tu entends.", "understand", entry["hanzi"],
        )
        if header is None:
            return None
        return Exercise(phase, {
            "kind": "listeningChoice", "header": header, "promptText": entry["hanzi"],
            "choices": choices, "correctChoiceID": correct,
        })

    def sentence_listening(self, phase: str, name: str, sentence: Sentence) -> Exercise | None:
        if len(sentence.chars) < _MIN_LISTENING_CHARS:
            return None
        distractors = self._sentence_distractors(sentence, 2, name)
        if len(distractors) < 2:
            return None
        choices, correct = self._choices(sentence.fr, distractors)
        prompt = (
            f"Écoute la réplique de {sentence.label}, puis choisis son sens."
            if sentence.label else "Écoute la phrase, puis choisis son sens."
        )
        header = self._header(
            name, prompt, "Écoute la phrase en mandarin, puis choisis son sens.", "understand", sentence.hanzi
        )
        if header is None:
            return None
        return Exercise(phase, {
            "kind": "listeningChoice", "header": header, "promptText": sentence.hanzi,
            "choices": choices, "correctChoiceID": correct,
        })

    def sentence_meaning(self, phase: str, name: str, sentence: Sentence) -> Exercise | None:
        if len(sentence.chars) < _MIN_LISTENING_CHARS:
            return None
        distractors = self._sentence_distractors(sentence, 2, name)
        if len(distractors) < 2:
            return None
        choices, correct = self._choices(sentence.fr, distractors)
        if sentence.source == "reading" and self.reading_title:
            prompt = f"Dans le texte « {self.reading_title} », que signifie : {sentence.hanzi}"
        elif sentence.label:
            prompt = f"Dans le dialogue, que signifie la réplique de {sentence.label} : {sentence.hanzi}"
        else:
            prompt = f"Que signifie la phrase : {sentence.hanzi}"
        header = self._header(name, prompt, "Lis la phrase, puis choisis son sens.", "understand")
        if header is None:
            return None
        return Exercise(phase, {"kind": "choice", "header": header, "choices": choices, "correctChoiceID": correct})

    def word_order(self, phase: str, name: str, sentence: Sentence) -> Exercise | None:
        if sentence.has_inner_punctuation or not sentence.is_aligned:
            return None
        chars, syllables = sentence.chars, sentence.syllables
        spans = _tokenize(sentence.hanzi, self.lexicon)
        if not 3 <= len(spans) <= _MAX_TILES or len({word for _, word in spans}) != len(spans):
            return None
        tokens: list[dict[str, Any]] = []
        cursor = 0
        for index, (_, word) in enumerate(spans):
            tokens.append({
                "id": _LETTERS[index], "hanzi": word,
                "pinyin": " ".join(syllables[cursor:cursor + len(word)]), "audio": None,
            })
            cursor += len(word)
        if "".join(chars) != "".join(token["hanzi"] for token in tokens):
            return None
        correct_order = [token["id"] for token in tokens]
        shuffled = list(tokens)
        rng = self._rng(name)
        while [token["id"] for token in shuffled] == correct_order:
            rng.shuffle(shuffled)
        body = sentence.hanzi.rstrip(_SENTENCE_END)
        header = self._header(
            name, f"Construis « {sentence.fr.rstrip('. ')} ».",
            "Replace chaque groupe dans l’ordre, puis relis la phrase complète.", "produce",
        )
        if header is None:
            return None
        return Exercise(phase, {
            "kind": "wordOrder", "header": header, "tokens": shuffled, "correctOrder": correct_order,
            "acceptedVariants": [sentence.hanzi] if body == sentence.hanzi else [sentence.hanzi, body],
        })

    def fill_blank(self, phase: str, name: str, sentence: Sentence) -> Exercise | None:
        by_hanzi = {entry["hanzi"]: entry for entry in self.vocabulary}
        spans = _tokenize(sentence.hanzi, self.lexicon)
        words = [word for _, word in spans]
        candidates = [
            (start, word) for start, word in spans
            if word in by_hanzi and len(word) <= 2 and words.count(word) == 1
            and sentence.hanzi.count(word) == 1 and len(sentence.chars) >= 4
        ]
        strong = [item for item in candidates if item[1] not in _WEAK_BLANKS]
        candidates = strong or candidates
        candidates.sort(key=lambda item: by_hanzi[item[1]]["id"] not in self.new_ids)
        if not candidates:
            return None
        start, word = candidates[0]
        blanked = sentence.hanzi[:start] + "___" + sentence.hanzi[start + len(word):]
        header = self._header(
            name, f"Complète : {blanked} (« {sentence.fr.rstrip('. ')} »)",
            "Choisis le mot manquant.", "produce",
        )
        if header is None:
            return None
        return Exercise(phase, {
            "kind": "fillBlank", "header": header, "sentence": blanked,
            "acceptedAnswers": [word], "caseSensitive": False,
        })

    def speaking(self, phase: str, name: str, sentence: Sentence) -> Exercise | None:
        header = self._header(name, f"Dis « {sentence.fr.rstrip('. ')} ».", "Écoute le modèle, dis la phrase, puis auto-évalue-toi.", "produce", sentence.hanzi)
        if header is None:
            return None
        header["required"] = False
        return Exercise(phase, {
            "kind": "speaking", "header": header, "referenceText": sentence.hanzi, "referencePinyin": sentence.pinyin,
            "referenceAudio": None, "acceptedTranscripts": [sentence.hanzi], "allowSelfRating": True,
        })

    # -- newer exercise kinds ----------------------------------------------

    def _matching_group(self, pool: list[dict[str, Any]], mode: str) -> list[dict[str, Any]]:
        """Up to five words whose meanings (or pinyin) cannot be mistaken for one another."""
        group: list[dict[str, Any]] = []
        for entry in pool:
            if len(group) == MATCHING_PAIRS[1]:
                break
            if entry["hanzi"] in self.homographs or any(entry["hanzi"] == other["hanzi"] for other in group):
                continue
            if mode == "meaning":
                clash = any(_meanings_overlap(_fr(entry["meaning"]), _fr(other["meaning"])) for other in group)
            else:
                clash = any(entry["pinyin"] == other["pinyin"] for other in group)
            if not clash:
                group.append(entry)
        return group

    def matching(self, phase: str, name: str, entries: list[dict[str, Any]], mode: str) -> Exercise | None:
        if len(entries) < MATCHING_PAIRS[0]:
            return None
        pairs = [
            {
                "id": _LETTERS[index], "left": entry["hanzi"],
                "pinyin": entry["pinyin"] if mode == "meaning" else None,
                "right": {"fr": _fr(entry["meaning"]) if mode == "meaning" else entry["pinyin"]},
            }
            for index, entry in enumerate(entries)
        ]
        header = self._header(
            name, "Associe chaque mot à son sens." if mode == "meaning" else "Associe chaque mot à son pinyin.",
            "Touche un mot, puis touche ce qui lui correspond.", "understand", " ".join(entry["hanzi"] for entry in entries),
        )
        if header is None:
            return None
        return Exercise(phase, {"kind": "matching", "header": header, "pairs": pairs})

    def _dictation(
        self, phase: str, name: str, script: str, spoken: str, correct: str, distractors: list[str], prompt: str,
    ) -> Exercise | None:
        if len({correct, *distractors}) != len(distractors) + 1:
            return None
        choices, correct_id = self._choices(correct, distractors)
        header = self._header(name, prompt, "Appuie sur l’écoute, puis choisis ce que tu as entendu.", "understand", spoken)
        if header is None:
            return None
        return Exercise(phase, {
            "kind": "dictation", "header": header, "script": script, "promptText": spoken,
            "choices": choices, "correctChoiceID": correct_id,
        })

    def _dictation_words(self, entry: dict[str, Any], name: str) -> list[dict[str, Any]]:
        """Wrong words of the same length that sound different, so the audio decides."""
        others = [
            item for item in self._word_distractors(entry, 8, name)
            if item["pinyin"] != entry["pinyin"] and len(item["hanzi"]) == len(entry["hanzi"])
        ]
        return others[:3]

    def dictation_pinyin(self, phase: str, name: str, entry: dict[str, Any]) -> Exercise | None:
        others = self._dictation_words(entry, name)
        if len(others) < 2 or entry["hanzi"] in self.homographs:
            return None
        return self._dictation(
            phase, name, "pinyin", entry["hanzi"], entry["pinyin"], [item["pinyin"] for item in others],
            "Écoute le mot, puis choisis son pinyin.",
        )

    def dictation_hanzi(self, phase: str, name: str, entry: dict[str, Any]) -> Exercise | None:
        others = self._dictation_words(entry, name)
        if len(others) < 2 or entry["hanzi"] in self.homographs:
            return None
        return self._dictation(
            phase, name, "hanzi", entry["hanzi"], entry["hanzi"], [item["hanzi"] for item in others],
            "Écoute le mot, puis choisis les caractères.",
        )

    def dictation_sentence(self, phase: str, name: str, sentence: Sentence) -> Exercise | None:
        # Only dialogue and example lines: their pinyin is checkable against the lesson.
        if sentence.source == "reading" or not _MIN_LISTENING_CHARS <= len(sentence.chars) <= _MAX_DICTATION_CHARS:
            return None
        if not sentence.pinyin.strip():
            return None
        candidates = [
            other for other in self.dialogue + self.examples
            if other.hanzi != sentence.hanzi and other.pinyin.strip() and other.pinyin != sentence.pinyin
        ]
        self._rng(name).shuffle(candidates)
        candidates.sort(key=lambda other: abs(len(other.syllables) - len(sentence.syllables)))
        distractors: list[str] = []
        for other in candidates:
            if other.pinyin not in distractors:
                distractors.append(other.pinyin)
            if len(distractors) == 2:
                break
        if len(distractors) < 2:
            return None
        return self._dictation(
            phase, name, "pinyin", sentence.hanzi, sentence.pinyin, distractors,
            "Écoute la phrase, puis choisis son pinyin.",
        )

    def tone_discrimination(self, phase: str, name: str, entry: dict[str, Any]) -> Exercise | None:
        tones = entry_tones(entry)
        if tones is None or entry["hanzi"] in self.homographs:
            return None
        choices = [
            {"id": tone_choice_id(option), "label": {"fr": tone_label(option)}, "audio": None}
            for option in tone_options(tones, self._rng(name))
        ]
        header = self._header(
            name, "Écoute la syllabe, puis choisis son ton." if len(tones) == 1 else "Écoute le mot, puis choisis ses deux tons.",
            "Appuie sur l’écoute, puis choisis la mélodie que tu entends.", "understand", entry["hanzi"],
        )
        if header is None:
            return None
        return Exercise(phase, {
            "kind": "toneDiscrimination", "header": header, "promptText": entry["hanzi"],
            "choices": choices, "correctChoiceID": tone_choice_id(tones),
        })

    def translation(self, phase: str, name: str, sentence: Sentence) -> Exercise | None:
        if sentence.has_inner_punctuation or not sentence.is_aligned:
            return None
        spans = _tokenize(sentence.hanzi, self.lexicon)
        if not 3 <= len(spans) <= _MAX_TRANSLATION_TILES or len({word for _, word in spans}) != len(spans):
            return None
        syllables = sentence.syllables
        tokens: list[dict[str, Any]] = []
        cursor = 0
        for index, (_, word) in enumerate(spans):
            tokens.append({
                "id": _LETTERS[index], "hanzi": word,
                "pinyin": " ".join(syllables[cursor:cursor + len(word)]), "audio": None,
            })
            cursor += len(word)
        if "".join(sentence.chars) != "".join(token["hanzi"] for token in tokens):
            return None
        distractors = self._tile_distractors(sentence, tokens, 1 if len(tokens) == 3 else 2, name)
        if not distractors:
            return None
        correct_order = [token["id"] for token in tokens]
        tiles = tokens + [
            {"id": _LETTERS[len(tokens) + index], "hanzi": entry["hanzi"], "pinyin": entry["pinyin"], "audio": None}
            for index, entry in enumerate(distractors)
        ]
        shuffled = list(tiles)
        rng = self._rng(name)
        while [token["id"] for token in shuffled if token["id"] in correct_order] == correct_order:
            rng.shuffle(shuffled)
        header = self._header(
            name, f"Traduis en chinois : « {sentence.fr.rstrip('. ')} »",
            "Assemble la phrase avec les tuiles. Attention : certaines tuiles sont en trop.", "produce",
        )
        if header is None:
            return None
        return Exercise(phase, {
            "kind": "translation", "header": header, "tokens": shuffled,
            "correctOrder": correct_order, "acceptedOrders": [],
        })

    def _tile_distractors(self, sentence: Sentence, tokens: list[dict[str, Any]], count: int, name: str) -> list[dict[str, Any]]:
        """Known words the sentence does not contain and whose meaning it does not mention."""
        french = _meaning_tokens(sentence.fr)
        lengths = {len(token["hanzi"]) for token in tokens}
        seen: set[str] = set()
        candidates: list[dict[str, Any]] = []
        for entry in self.vocabulary + self.earlier:
            hanzi = entry["hanzi"]
            if (
                hanzi in seen or hanzi in sentence.hanzi or len(hanzi) > 2
                or len(entry["pinyin"].split()) != len(hanzi) or _meaning_tokens(_fr(entry["meaning"])) & french
            ):
                continue
            seen.add(hanzi)
            candidates.append(entry)
        self._rng(name + "-tiles").shuffle(candidates)
        candidates.sort(key=lambda entry: (entry["id"] not in self.new_ids, len(entry["hanzi"]) not in lengths))
        return candidates[:count]

    def dialogue_order(self, phase: str, name: str, start: int, size: int) -> Exercise | None:
        turns = self.turns[start:start + size]
        if len(turns) < size or any(turn is None for turn in turns) or len({turn.hanzi for turn in turns}) != size:
            return None
        lines = [
            {"id": _LETTERS[index], "speaker": turn.label, "hanzi": turn.hanzi, "pinyin": turn.pinyin, "audio": None}
            for index, turn in enumerate(turns)
        ]
        correct_order = [line["id"] for line in lines]
        shuffled = list(lines)
        rng = self._rng(name)
        while [line["id"] for line in shuffled] == correct_order:
            rng.shuffle(shuffled)
        header = self._header(
            name, "Remets le dialogue dans l’ordre.",
            "Touche les répliques dans l’ordre de la conversation, de la première à la dernière.", "understand",
            "".join(turn.hanzi for turn in turns),
        )
        if header is None:
            return None
        return Exercise(phase, {"kind": "dialogueOrder", "header": header, "lines": shuffled, "correctOrder": correct_order})

    def conversation_choice(self, phase: str, name: str, index: int) -> Exercise | None:
        """Answer the line at `index` with the line the dialogue gives next."""
        if index + 1 >= len(self.turns):
            return None
        line, reply = self.turns[index], self.turns[index + 1]
        # Only a question leaves one clearly best reply.
        if line is None or reply is None or line.hanzi == reply.hanzi or not line.hanzi.rstrip().endswith("？"):
            return None
        others = [
            turn for position, turn in enumerate(self.turns)
            if turn is not None and position not in (index, index + 1) and turn.hanzi not in (line.hanzi, reply.hanzi)
        ]
        self._rng(name).shuffle(others)
        # Lines of the replying speaker make the more tempting wrong answers.
        others.sort(key=lambda turn: turn.label != reply.label)
        wrong: list[Sentence] = []
        for turn in others:
            if all(turn.hanzi != chosen.hanzi for chosen in wrong):
                wrong.append(turn)
            if len(wrong) == CONVERSATION_REPLIES - 1:
                break
        if len(wrong) < CONVERSATION_REPLIES - 1:
            return None
        position = self._choice_position(CONVERSATION_REPLIES)
        wrong.insert(position, reply)
        header = self._header(
            name,
            f"Écoute {line.label}, puis choisis la meilleure réponse." if line.label else "Écoute la réplique, puis choisis la meilleure réponse.",
            "Appuie sur l’écoute, lis la réplique, puis choisis la réponse qui convient.", "understand", line.hanzi,
        )
        if header is None:
            return None
        return Exercise(phase, {
            "kind": "conversationChoice", "header": header, "speaker": line.label, "promptText": line.hanzi,
            "replies": [
                {"id": _LETTERS[order], "hanzi": turn.hanzi, "pinyin": turn.pinyin, "audio": None}
                for order, turn in enumerate(wrong)
            ],
            "correctReplyID": _LETTERS[position],
        })

    # -- candidate pool --------------------------------------------------

    def _origin_of(self, item: dict[str, Any] | Sentence | None) -> int:
        """Where the material comes from; a lesson has a single source."""
        return 0

    def candidate(self, exercise: Exercise, family: str, origin: int = 0) -> Candidate:
        spec = exercise.spec
        text_shown = exercise_text(spec)
        answers = spec.get("acceptedAnswers") or [""]
        pieces = _pieces(spec)
        text = next((
            value for value in (
                spec.get("promptText"), spec.get("referenceText"), spec.get("sentence", "").replace("___", answers[0]),
                "".join(pieces[piece_id] for piece_id in spec.get("correctOrder", [])),
            ) if value
        ), None)
        return Candidate(
            exercise,
            frozenset(word_id for word_id, hanzi in self.hanzi.items() if hanzi in text_shown),
            family,
            re.sub(f"[{re.escape(_PUNCTUATION)}]", "", text) if text else None,
            origin,
        )

    def _matching_groups(self, ordered: list[dict[str, Any]]) -> list[tuple[str, str, list[dict[str, Any]]]]:
        """The matchings to offer: by meaning, then by pinyin over the words the first left out."""
        first = self._matching_group(ordered, "meaning")
        first_ids = {entry["id"] for entry in first}
        second = self._matching_group([entry for entry in ordered if entry["id"] not in first_ids] + first, "pinyin")
        return [(f"match-{mode}", mode, group) for mode, group in (("meaning", first), ("pinyin", second))]

    def candidates(self) -> list[Candidate]:
        """Every exercise this lesson's material can produce, new words first."""
        result: list[Candidate] = []
        ordered = sorted(self.vocabulary, key=lambda entry: entry["id"] not in self.new_ids)
        for name, mode, group in self._matching_groups(ordered):
            exercise = self.matching("discover", name, group, mode)
            if exercise is not None:
                result.append(self.candidate(exercise, f"match-{mode}", min(self._origin_of(entry) for entry in group)))
        for entry in ordered:
            slug = entry["id"].removeprefix("vocab-").removeprefix("hsk20-")
            builds = [
                ("reverse", self.word_reverse), ("listen-word", self.word_listening), ("pick", self.word_pick),
                ("tone", self.tone_discrimination), ("dict-py", self.dictation_pinyin), ("dict-zh", self.dictation_hanzi),
            ]
            if entry["id"] not in self.asked:
                builds.insert(0, ("meaning", self.word_meaning))
            for family, build in builds:
                exercise = build("discover", f"{family}-{slug}", entry)
                if exercise is not None:
                    result.append(self.candidate(exercise, family, self._origin_of(entry)))
        seen: set[str] = set()
        for source, sentences in (("dialogue", self.dialogue), ("reading", self.reading), ("example", self.examples)):
            for index, sentence in enumerate(sentences, start=1):
                if self.key(sentence) in seen:
                    continue
                seen.add(self.key(sentence))
                # Reading sentences belong to the last phase; dialogue and
                # example sentences first serve guided practice.
                practice = "reuse" if source == "reading" else "guided"
                for family, build, phase in (
                    ("listen", self.sentence_listening, practice), ("order", self.word_order, practice),
                    ("fill", self.fill_blank, practice), ("read", self.sentence_meaning, "reuse"),
                    ("speak", self.speaking, "reuse"), ("translate", self.translation, "guided"),
                    ("dict-sent", self.dictation_sentence, "discover"),
                ):
                    exercise = build(phase, f"{family}-{source[:3]}-{index}", sentence)
                    if exercise is not None:
                        result.append(self.candidate(exercise, family, self._origin_of(sentence)))
        for index in range(len(self.turns) - 1):
            exercise = self.conversation_choice("guided", f"talk-{index + 1}", index)
            if exercise is not None:
                result.append(self.candidate(exercise, "talk", self._origin_of(self.turns[index])))
        for size in (3, 4):
            for start in range(len(self.turns) - size + 1):
                exercise = self.dialogue_order("reuse", f"dialogue-{start + 1}-{size}", start, size)
                if exercise is not None:
                    result.append(self.candidate(exercise, "dialogue", self._origin_of(self.turns[start])))
        return result

    def reposition(self, exercises: list[Exercise]) -> None:
        """Place each correct answer by the walk of `_choice_position`, in session order."""
        self.serial = 0
        for exercise in exercises:
            spec = exercise.spec
            if spec["kind"] == "conversationChoice":
                correct = next(reply for reply in spec["replies"] if reply["id"] == spec["correctReplyID"])
                replies = [reply for reply in spec["replies"] if reply is not correct]
                position = self._choice_position(len(replies) + 1)
                replies.insert(position, correct)
                spec["replies"] = [{**reply, "id": _LETTERS[index]} for index, reply in enumerate(replies)]
                spec["correctReplyID"] = _LETTERS[position]
                continue
            # Tone choices keep their natural order (tone 1 to 4).
            if spec["kind"] not in {"choice", "listeningChoice", "dictation"}:
                continue
            labels = {choice["id"]: _fr(choice["label"]) for choice in spec["choices"]}
            correct = labels.pop(spec["correctChoiceID"])
            spec["choices"], spec["correctChoiceID"] = self._choices(correct, list(labels.values()))


class _Planner:
    """Choose the session's exercises so that every new word is practised enough."""

    def __init__(self, builder: "SessionBuilder", authored: list[Candidate], pool: list[Candidate]) -> None:
        self.builder = builder
        self.chosen = list(authored)
        self.pool = pool
        self.counts = {word_id: 0 for word_id in builder.hanzi}
        self.kinds: dict[str, set[str]] = {word_id: set() for word_id in builder.hanzi}
        for candidate in authored:
            self._record(candidate)

    def _record(self, candidate: Candidate) -> None:
        for word_id in candidate.words:
            self.counts[word_id] += 1
            self.kinds[word_id].add(candidate.kind)

    def _gain(self, candidate: Candidate) -> int:
        return sum(
            (self.counts[word_id] < MIN_EXPOSURES)
            + (candidate.kind not in self.kinds[word_id] and len(self.kinds[word_id]) < MIN_EXPOSURE_KINDS)
            for word_id in candidate.words
        )

    def _load(self, phase: str) -> int:
        # The grammar exercises of a lesson come on top of the phase's own share.
        return sum(1 for item in self.chosen if item.exercise.phase == phase and item.family != GRAMMAR_FAMILY)

    def _allowed(self, candidate: Candidate) -> bool:
        if len(self.chosen) >= EXERCISE_BUDGET[1] or self._load(candidate.exercise.phase) >= _PHASE_CAPS[candidate.exercise.phase]:
            return False
        cap = _MAX_PER_KIND.get(candidate.kind)
        if cap is not None and sum(1 for item in self.chosen if item.kind == candidate.kind) >= cap:
            return False
        if candidate.kind in _VARIED_KINDS and any(item.kind == candidate.kind and item.family == candidate.family for item in self.chosen):
            return False
        # One sentence never carries two exercises of the same kind.
        return not any(
            item.sentence is not None and item.sentence == candidate.sentence and item.kind == candidate.kind
            for item in self.chosen
        )

    def _take(self, candidate: Candidate) -> None:
        self.chosen.append(candidate)
        self.pool.remove(candidate)
        self._record(candidate)

    def _priority(self, candidate: Candidate) -> tuple[bool, int, int, int, int]:
        """Prefer other kinds to speaking, sentences met once, then rarer phases and kinds."""
        sentence_uses = sum(1 for item in self.chosen if item.sentence is not None and item.sentence == candidate.sentence)
        kind_uses = sum(1 for item in self.chosen if item.kind == candidate.kind)
        return (candidate.kind == "speaking", sentence_uses, self._load(candidate.exercise.phase), kind_uses, -len(candidate.words))

    def cover(self) -> None:
        while True:
            options = [candidate for candidate in self.pool if self._allowed(candidate) and self._gain(candidate) > 0]
            if not options:
                return
            self._take(max(options, key=lambda candidate: (self._gain(candidate), tuple(-int(value) for value in self._priority(candidate)))))

    def require_new_kinds(self) -> None:
        """Give the session one exercise of each newer kind the lesson's material can build."""
        for kind in NEW_KINDS:
            options = [candidate for candidate in self.pool if candidate.kind == kind and self._allowed(candidate)]
            if kind == "dictation":
                # The first dictation asks for the pinyin; a second one asks for the Hanzi.
                options = [candidate for candidate in options if candidate.exercise.spec["script"] == "pinyin"] or options
            if options:
                self._take(max(options, key=lambda candidate: (self._gain(candidate), tuple(-int(value) for value in self._priority(candidate)))))

    def fill(self) -> None:
        """Bring every phase to its minimum, then the session to its target length."""
        while len(self.chosen) < EXERCISE_TARGET or any(self._load(phase) < _PHASE_MINIMUM for phase in PHASES):
            starved = [phase for phase in PHASES if self._load(phase) < _PHASE_MINIMUM]
            options = [
                candidate for candidate in self.pool
                if self._allowed(candidate) and (not starved or candidate.exercise.phase in starved)
            ]
            if not options:
                return
            self._take(min(options, key=lambda candidate: (self._priority(candidate), candidate.exercise.spec["header"]["id"])))

    def shortfalls(self) -> dict[str, tuple[int, int]]:
        return exposure_shortfalls({word_id: (self.counts[word_id], self.kinds[word_id]) for word_id in self.counts})


def expand_lesson_exercises(
    lesson: dict[str, Any],
    new_vocabulary_ids: set[str],
    earlier_vocabulary: list[dict[str, Any]],
    lexicon: set[str],
) -> None:
    """Replace the lesson's exercise blocks by the ordered three-phase session."""
    blocks = lesson["blocks"]
    exercise_blocks = [block for block in blocks if block.get("kind") == "exercise"]
    if not exercise_blocks:
        raise ExpansionError(f"{lesson['id']}: no authored exercises to extend")
    reading = next((block for block in blocks if block.get("kind") == "reading"), {})
    reading_ids = set(reading.get("comprehensionExerciseIDs", []))
    authored = {block["spec"]["header"]["id"]: block for block in exercise_blocks}
    lesson_no = lesson_number(lesson)

    def authored_block(suffix: str) -> dict[str, Any]:
        block = authored.get(f"ex-l{lesson_no}-{suffix}")
        if block is None:
            raise ExpansionError(f"{lesson['id']}: missing authored exercise '{suffix}'")
        return block

    builder = SessionBuilder(lesson, new_vocabulary_ids, earlier_vocabulary, lexicon)
    if len(new_vocabulary_ids) > MAX_NEW_WORDS:
        raise ExpansionError(f"{lesson['id']}: {len(new_vocabulary_ids)} new words, expected at most {MAX_NEW_WORDS}")
    reading_authored = next((block for exercise_id, block in authored.items() if exercise_id in reading_ids), None)
    if reading_authored is None:
        raise ExpansionError(f"{lesson['id']}: reading comprehension exercise is not referenced by the reading")
    fixed = [
        ("discover", authored_block("meaning")), ("guided", authored_block("order")), ("guided", authored_block("fill")),
        ("reuse", authored_block("listen")), ("reuse", authored_block("speak")), ("reuse", reading_authored),
    ]
    # The lesson's grammar note comes with exercises that manipulate its structure; they lead guided practice.
    grammar_blocks = [block for block in exercise_blocks if block.get("metadata", {}).get("grammarPointID")]
    planner = _Planner(
        builder,
        [builder.candidate(Exercise(phase, block["spec"]), "authored") for phase, block in fixed]
        + [builder.candidate(Exercise("guided", block["spec"]), GRAMMAR_FAMILY) for block in grammar_blocks],
        builder.candidates(),
    )
    planner.require_new_kinds()
    planner.cover()
    planner.fill()
    shortfalls = planner.shortfalls()
    if shortfalls:
        detail = ", ".join(f"{builder.hanzi[word_id]} ({count} exercises, {kinds} kinds)" for word_id, (count, kinds) in sorted(shortfalls.items()))
        raise ExpansionError(f"{lesson['id']}: new words are under-practised: {detail}")
    if not EXERCISE_BUDGET[0] <= len(planner.chosen) <= EXERCISE_BUDGET[1]:
        raise ExpansionError(f"{lesson['id']}: {len(planner.chosen)} exercises, expected {EXERCISE_BUDGET[0]}–{EXERCISE_BUDGET[1]}")
    present = {item.kind for item in planner.chosen}.intersection(NEW_KINDS)
    if len(present) < MIN_NEW_KINDS:
        raise ExpansionError(f"{lesson['id']}: only {len(present)} of the newer exercise kinds ({', '.join(sorted(present)) or 'none'}), expected {MIN_NEW_KINDS}")

    # The authored listening, oral and reading exercises close every session.
    closing_specs = [authored_block("listen")["spec"], authored_block("speak")["spec"], reading_authored["spec"]]
    ordered: list[Candidate] = []
    for phase in PHASES:
        session = [item for item in planner.chosen if item.exercise.phase == phase and not any(item.exercise.spec is spec for spec in closing_specs)]
        grammar = [item for item in session if item.family == GRAMMAR_FAMILY]
        ordered.extend(grammar + _spread_kinds([item for item in session if item.family != GRAMMAR_FAMILY]))
    for spec in closing_specs:
        ordered.append(next(item for item in planner.chosen if item.exercise.spec is spec))
    builder.reposition([item.exercise for item in ordered if item.family not in {"authored", GRAMMAR_FAMILY}])

    new_blocks = [
        {
            "kind": "exercise",
            "id": f"block-{item.exercise.spec['header']['id']}",
            "spec": item.exercise.spec,
            "metadata": {**authored.get(item.exercise.spec["header"]["id"], {}).get("metadata", {}), "stage": item.exercise.phase},
        }
        for item in ordered
    ]
    first = blocks.index(exercise_blocks[0])
    remaining = [block for block in blocks if block.get("kind") != "exercise"]
    insert_at = sum(1 for block in blocks[:first] if block.get("kind") != "exercise")
    lesson["blocks"] = remaining[:insert_at] + new_blocks + remaining[insert_at:]
