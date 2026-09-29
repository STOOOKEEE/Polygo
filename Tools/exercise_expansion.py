"""Derive a daily lesson's practice exercises from its authored material.

The authoring pack ships six hand-written exercises per lesson. This module
extends them to a three-phase session (discovery, guided practice, re-use)
without inventing any Mandarin, pinyin, or French: every new exercise is a
recombination of vocabulary rows, example sentences, dialogue lines and reading
sentences that already belong to the lesson. Distractors come from other
vocabulary or sentences of the same lesson and of the two preceding lessons.

Only exercise families already decoded by PolygoCore are emitted (`choice`,
`wordOrder`, `fillBlank`, `listeningChoice`). Every exercise block carries its
phase in `metadata.stage`.
"""
from __future__ import annotations

import random
import re
from dataclasses import dataclass
from typing import Any, Callable

PHASES = ("discover", "guided", "reuse")
EXERCISE_BUDGET = (15, 20)

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
        """Pure Mandarin text whose pinyin aligns one syllable per Hanzi."""
        stripped = self.hanzi.strip()
        if not stripped or not all(_is_hanzi(char) or char in _PUNCTUATION for char in stripped):
            return False
        return len(self.chars) == len(self.syllables) and bool(self.fr.strip())

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
        self.earlier = [entry for entry in earlier_vocabulary if _fr(entry.get("meaning"))]
        self.serial = 0
        self.used_words: set[str] = set()
        self.used_sentences: set[str] = set()
        self.used_prompts: set[tuple[str, str]] = set()
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
        """Keep authored words, sentences and prompts out of the new exercises."""
        by_hanzi = {entry["hanzi"]: entry["id"] for entry in self.vocabulary}
        for block in self.lesson["blocks"]:
            spec = block.get("spec") if block.get("kind") == "exercise" else None
            if not isinstance(spec, dict):
                continue
            prompt = _fr(spec["header"].get("prompt"))
            self.used_prompts.add((prompt, spec.get("promptText") or ""))
            if prompt.startswith("Que signifie"):
                self.used_words.update(vocabulary_id for hanzi, vocabulary_id in by_hanzi.items() if hanzi in prompt)
            tokens = {token["id"]: token["hanzi"] for token in spec.get("tokens", [])}
            answers = spec.get("acceptedAnswers") or [""]
            for text in (
                spec.get("promptText"), spec.get("sentence", "").replace("___", answers[0]),
                spec.get("referenceText"),
                "".join(tokens[token_id] for token_id in spec.get("correctOrder", [])),
            ):
                if text:
                    self.used_sentences.add(re.sub(f"[{re.escape(_PUNCTUATION)}]", "", text))

    # -- helpers ---------------------------------------------------------

    def _rng(self, name: str) -> random.Random:
        return random.Random(f"{self.lesson['id']}:{name}")

    @staticmethod
    def key(sentence: Sentence) -> str:
        return re.sub(f"[{re.escape(_PUNCTUATION)}]", "", sentence.hanzi)

    def _fresh_words(self, count: int) -> list[dict[str, Any]]:
        ordered = sorted(self.vocabulary, key=lambda entry: entry["id"] not in self.new_ids)
        words = [entry for entry in ordered if entry["id"] not in self.used_words][:count]
        self.used_words.update(entry["id"] for entry in words)
        return words

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
            candidates.sort(key=lambda entry: abs(len(entry["hanzi"]) - len(target["hanzi"])))
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
        self.used_sentences.add(self.key(sentence))
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
        self.used_sentences.add(self.key(sentence))
        return Exercise(phase, {"kind": "choice", "header": header, "choices": choices, "correctChoiceID": correct})

    def word_order(self, phase: str, name: str, sentence: Sentence) -> Exercise | None:
        if sentence.has_inner_punctuation:
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
        self.used_sentences.add(self.key(sentence))
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
        candidates.sort(key=lambda item: (by_hanzi[item[1]]["id"] not in self.new_ids, item[1] in self.used_words))
        if not candidates:
            return None
        start, word = candidates[0]
        self.used_words.add(by_hanzi[word]["id"])
        blanked = sentence.hanzi[:start] + "___" + sentence.hanzi[start + len(word):]
        header = self._header(
            name, f"Complète : {blanked} (« {sentence.fr.rstrip('. ')} »)",
            "Choisis le mot manquant.", "produce",
        )
        if header is None:
            return None
        self.used_sentences.add(self.key(sentence))
        return Exercise(phase, {
            "kind": "fillBlank", "header": header, "sentence": blanked,
            "acceptedAnswers": [word], "caseSensitive": False,
        })


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
    words = builder._fresh_words(5)
    if len(words) < 5:
        raise ExpansionError(f"{lesson['id']}: needs five words for the discovery phase")

    def sentence_for(name: str, pools: list[list[Sentence]], build: Callable[[str, str, Sentence], Exercise | None], phase: str) -> Exercise | None:
        for pool in pools:
            for sentence in pool:
                if builder.key(sentence) in builder.used_sentences:
                    continue
                exercise = build(phase, name, sentence)
                if exercise is not None:
                    return exercise
        return None

    dialogue_first = sorted(builder.dialogue, key=lambda item: not any(
        entry["hanzi"] in item.hanzi and entry["id"] in new_vocabulary_ids for entry in builder.vocabulary))

    discover = [
        builder.word_listening("discover", "listen-word-1", words[0]),
        builder.word_meaning("discover", "meaning-2", words[1]),
        builder.word_reverse("discover", "reverse-1", words[2]),
        builder.word_listening("discover", "listen-word-2", words[3]),
        builder.word_meaning("discover", "meaning-3", words[4]),
    ]
    guided = [
        sentence_for("listen-dialogue-1", [dialogue_first, builder.examples], builder.sentence_listening, "guided"),
        sentence_for("order-2", [builder.examples, dialogue_first], builder.word_order, "guided"),
        sentence_for("fill-2", [builder.examples, dialogue_first], builder.fill_blank, "guided"),
        sentence_for("listen-dialogue-2", [dialogue_first, builder.examples], builder.sentence_listening, "guided"),
    ]
    reuse = [
        sentence_for("order-3", [builder.reading, dialogue_first, builder.examples], builder.word_order, "reuse"),
        sentence_for("fill-3", [builder.reading, dialogue_first, builder.examples], builder.fill_blank, "reuse"),
        sentence_for("read-sentence-1", [builder.reading, dialogue_first, builder.examples], builder.sentence_meaning, "reuse"),
    ]

    def wrap(phase: str, block: dict[str, Any]) -> Exercise:
        return Exercise(phase, block["spec"])

    listen_authored = authored_block("listen")
    speak_authored = authored_block("speak")
    reading_authored = next((block for exercise_id, block in authored.items() if exercise_id in reading_ids), None)
    if reading_authored is None:
        raise ExpansionError(f"{lesson['id']}: reading comprehension exercise is not referenced by the reading")
    meaning_authored = authored_block("meaning")
    order_authored = authored_block("order")
    fill_authored = authored_block("fill")

    ordered = (
        [wrap("discover", meaning_authored), discover[0], discover[1], discover[2], discover[3], discover[4]]
        + [wrap("guided", order_authored), guided[0], wrap("guided", fill_authored), guided[1], guided[3], guided[2]]
        + [reuse[0], reuse[1], reuse[2], wrap("reuse", listen_authored), wrap("reuse", speak_authored), wrap("reuse", reading_authored)]
    )
    ordered = [exercise for exercise in ordered if exercise is not None]
    if not EXERCISE_BUDGET[0] <= len(ordered) <= EXERCISE_BUDGET[1]:
        raise ExpansionError(f"{lesson['id']}: {len(ordered)} exercises, expected {EXERCISE_BUDGET[0]}–{EXERCISE_BUDGET[1]}")

    new_blocks = [
        {
            "kind": "exercise",
            "id": f"block-{exercise.spec['header']['id']}",
            "spec": exercise.spec,
            "metadata": {"stage": exercise.phase},
        }
        for exercise in ordered
    ]
    first = blocks.index(exercise_blocks[0])
    remaining = [block for block in blocks if block.get("kind") != "exercise"]
    insert_at = sum(1 for block in blocks[:first] if block.get("kind") != "exercise")
    lesson["blocks"] = remaining[:insert_at] + new_blocks + remaining[insert_at:]
