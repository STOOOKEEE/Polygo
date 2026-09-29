"""Derive a daily lesson's practice exercises from its authored material.

The authoring pack ships six hand-written exercises per lesson. This module
extends them to a three-phase session (discovery, guided practice, re-use)
without inventing any Mandarin, pinyin, or French: every new exercise is a
recombination of vocabulary rows, example sentences, dialogue lines and reading
sentences that already belong to the lesson. Distractors come from other
vocabulary or sentences of the same lesson and of the two preceding lessons.

Only exercise families already decoded by PolygoCore are emitted (`choice`,
`wordOrder`, `fillBlank`, `listeningChoice`, `speaking`). Every exercise block
carries its phase in `metadata.stage`.

The session is planned as a cover: the lesson introduces at most
`MAX_NEW_WORDS` words, and each of them must be presented by at least
`MIN_EXPOSURES` exercises of at least `MIN_EXPOSURE_KINDS` different kinds.
A sentence exercise counts for every new word it presents.
"""
from __future__ import annotations

import random
import re
from dataclasses import dataclass
from typing import Any

PHASES = ("discover", "guided", "reuse")
EXERCISE_BUDGET = (15, 20)
EXERCISE_TARGET = 18
MAX_NEW_WORDS = 8
MIN_EXPOSURES = 3
MIN_EXPOSURE_KINDS = 3
_PHASE_CAPS = {"discover": 8, "guided": 7, "reuse": 7}
_PHASE_MINIMUM = 5
# Speaking is self-rated and quick to build, so it must not crowd out the rest.
_MAX_SPEAKING = 3

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


def _split_sentences(pinyin: str) -> list[str]:
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


def _split_french(text: str) -> list[str]:
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

    @property
    def kind(self) -> str:
        return self.exercise.spec["kind"]


def exercise_text(spec: dict[str, Any]) -> str:
    """The Mandarin an exercise presents: prompt, sentence, tiles, choices and expected answer."""
    answers = spec.get("acceptedAnswers") or [""]
    tokens = {token["id"]: token["hanzi"] for token in spec.get("tokens", [])}
    parts = [
        spec["header"]["prompt"].get("fr", ""),
        spec.get("promptText") or "",
        spec.get("referenceText") or "",
        spec.get("sentence", "").replace("___", answers[0]),
        "".join(tokens[token_id] for token_id in spec.get("correctOrder", [])),
    ]
    parts.extend(_fr(choice.get("label")) for choice in spec.get("choices", []))
    parts.extend(token["hanzi"] for token in spec.get("tokens", []))
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


class _Builder:
    def __init__(
        self,
        lesson: dict[str, Any],
        new_ids: set[str],
        earlier_vocabulary: list[dict[str, Any]],
        lexicon: set[str],
    ) -> None:
        self.lesson = lesson
        self.lesson_no = int(lesson["order"])
        self.new_ids = new_ids
        self.lexicon = lexicon
        self.vocabulary = [entry for entry in lesson["vocabulary"] if _fr(entry.get("meaning"))]
        self.hanzi = {entry["id"]: entry["hanzi"] for entry in self.vocabulary if entry["id"] in new_ids}
        self.earlier = [entry for entry in earlier_vocabulary if _fr(entry.get("meaning"))]
        self.serial = 0
        self.used_prompts: set[tuple[str, str]] = set()
        self.asked: set[str] = set()
        self.objectives = {
            "understand": self._objective("understand", 0),
            "produce": self._objective("produce", -1),
        }
        self.dialogue = self._dialogue_sentences()
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

    def _dialogue_sentences(self) -> list[Sentence]:
        block = self._block("dialogue")
        lines = block.get("lines", []) if block else []
        result = []
        for line in lines:
            sentence = Sentence(
                line.get("hanzi", ""), line.get("pinyin", ""), _fr(line.get("translation")),
                "dialogue", label=line.get("speaker"),
            )
            if sentence.is_clean:
                result.append(sentence)
        return result

    def _reading_sentences(self) -> tuple[list[Sentence], str]:
        block = self._block("reading")
        if not block:
            return [], ""
        result: list[Sentence] = []
        for paragraph in block.get("paragraphs", []):
            hanzi_parts = _split_sentences(paragraph.get("hanzi", ""))
            pinyin_parts = _split_sentences(paragraph.get("pinyin", ""))
            french_parts = _split_french(_fr(paragraph.get("translation")))
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
            "id": f"ex-l{self.lesson_no}-{exercise_id}",
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

    # -- candidate pool --------------------------------------------------

    def candidate(self, exercise: Exercise, family: str) -> Candidate:
        spec = exercise.spec
        text_shown = exercise_text(spec)
        answers = spec.get("acceptedAnswers") or [""]
        tokens = {token["id"]: token["hanzi"] for token in spec.get("tokens", [])}
        text = next((
            value for value in (
                spec.get("promptText"), spec.get("referenceText"), spec.get("sentence", "").replace("___", answers[0]),
                "".join(tokens[token_id] for token_id in spec.get("correctOrder", [])),
            ) if value
        ), None)
        return Candidate(
            exercise,
            frozenset(word_id for word_id, hanzi in self.hanzi.items() if hanzi in text_shown),
            family,
            re.sub(f"[{re.escape(_PUNCTUATION)}]", "", text) if text else None,
        )

    def candidates(self) -> list[Candidate]:
        """Every exercise this lesson's material can produce, new words first."""
        result: list[Candidate] = []
        ordered = sorted(self.vocabulary, key=lambda entry: entry["id"] not in self.new_ids)
        for entry in ordered:
            slug = entry["id"].removeprefix("vocab-").removeprefix("hsk20-")
            builds = [("reverse", self.word_reverse), ("listen-word", self.word_listening), ("pick", self.word_pick)]
            if entry["id"] not in self.asked:
                builds.insert(0, ("meaning", self.word_meaning))
            for family, build in builds:
                exercise = build("discover", f"{family}-{slug}", entry)
                if exercise is not None:
                    result.append(self.candidate(exercise, family))
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
                    ("speak", self.speaking, "reuse"),
                ):
                    exercise = build(phase, f"{family}-{source[:3]}-{index}", sentence)
                    if exercise is not None:
                        result.append(self.candidate(exercise, family))
        return result

    def reposition(self, exercises: list[Exercise]) -> None:
        """Place each correct choice by the walk of `_choice_position`, in session order."""
        self.serial = 0
        for exercise in exercises:
            spec = exercise.spec
            if spec["kind"] not in {"choice", "listeningChoice"}:
                continue
            labels = {choice["id"]: _fr(choice["label"]) for choice in spec["choices"]}
            correct = labels.pop(spec["correctChoiceID"])
            spec["choices"], spec["correctChoiceID"] = self._choices(correct, list(labels.values()))


class _Planner:
    """Choose the session's exercises so that every new word is practised enough."""

    def __init__(self, builder: "_Builder", authored: list[Candidate], pool: list[Candidate]) -> None:
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
        return sum(1 for item in self.chosen if item.exercise.phase == phase)

    def _allowed(self, candidate: Candidate) -> bool:
        if len(self.chosen) >= EXERCISE_BUDGET[1] or self._load(candidate.exercise.phase) >= _PHASE_CAPS[candidate.exercise.phase]:
            return False
        if candidate.kind == "speaking" and sum(1 for item in self.chosen if item.kind == "speaking") >= _MAX_SPEAKING:
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
    lesson_no = int(lesson["order"])

    def authored_block(suffix: str) -> dict[str, Any]:
        block = authored.get(f"ex-l{lesson_no}-{suffix}")
        if block is None:
            raise ExpansionError(f"{lesson['id']}: missing authored exercise '{suffix}'")
        return block

    builder = _Builder(lesson, new_vocabulary_ids, earlier_vocabulary, lexicon)
    if len(new_vocabulary_ids) > MAX_NEW_WORDS:
        raise ExpansionError(f"{lesson['id']}: {len(new_vocabulary_ids)} new words, expected at most {MAX_NEW_WORDS}")
    reading_authored = next((block for exercise_id, block in authored.items() if exercise_id in reading_ids), None)
    if reading_authored is None:
        raise ExpansionError(f"{lesson['id']}: reading comprehension exercise is not referenced by the reading")
    fixed = [
        ("discover", authored_block("meaning")), ("guided", authored_block("order")), ("guided", authored_block("fill")),
        ("reuse", authored_block("listen")), ("reuse", authored_block("speak")), ("reuse", reading_authored),
    ]
    planner = _Planner(
        builder,
        [builder.candidate(Exercise(phase, block["spec"]), "authored") for phase, block in fixed],
        builder.candidates(),
    )
    planner.cover()
    planner.fill()
    shortfalls = planner.shortfalls()
    if shortfalls:
        detail = ", ".join(f"{builder.hanzi[word_id]} ({count} exercises, {kinds} kinds)" for word_id, (count, kinds) in sorted(shortfalls.items()))
        raise ExpansionError(f"{lesson['id']}: new words are under-practised: {detail}")
    if not EXERCISE_BUDGET[0] <= len(planner.chosen) <= EXERCISE_BUDGET[1]:
        raise ExpansionError(f"{lesson['id']}: {len(planner.chosen)} exercises, expected {EXERCISE_BUDGET[0]}–{EXERCISE_BUDGET[1]}")

    # The authored listening, oral and reading exercises close every session.
    closing_specs = [authored_block("listen")["spec"], authored_block("speak")["spec"], reading_authored["spec"]]
    ordered: list[Candidate] = []
    for phase in PHASES:
        session = [item for item in planner.chosen if item.exercise.phase == phase and not any(item.exercise.spec is spec for spec in closing_specs)]
        ordered.extend(_spread_kinds(session))
    for spec in closing_specs:
        ordered.append(next(item for item in planner.chosen if item.exercise.spec is spec))
    builder.reposition([item.exercise for item in ordered if item.family != "authored"])

    new_blocks = [
        {
            "kind": "exercise",
            "id": f"block-{item.exercise.spec['header']['id']}",
            "spec": item.exercise.spec,
            "metadata": {"stage": item.exercise.phase},
        }
        for item in ordered
    ]
    first = blocks.index(exercise_blocks[0])
    remaining = [block for block in blocks if block.get("kind") != "exercise"]
    insert_at = sum(1 for block in blocks[:first] if block.get("kind") != "exercise")
    lesson["blocks"] = remaining[:insert_at] + new_blocks + remaining[insert_at:]
