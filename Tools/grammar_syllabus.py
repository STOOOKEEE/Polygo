"""The grammar syllabus: a hand-written note every two or three daily lessons, each with two manipulation exercises.

The syllabus is one file, `Content/authoring/grammar-syllabus.json`. `content_tool.py generate` lays each
note on its lesson as the lesson's only grammar introduction block and adds the note's two exercises to the
guided phase; it also drops the assembled `grammar` lists of the pack, which only steered the vocabulary
allocation. `lint` re-checks the notes against the words taught up to their lesson, and the generated lessons
against the notes.

Nothing here invents Mandarin: every hanzi, pinyin and translation comes from the file. The word rules are
checked on hanzi; whether a sentence is natural and its French right stays the writer's and the reviewer's
job (`pinyin_crosscheck` helps).
"""

from __future__ import annotations

import copy
import dataclasses
import json
import random
import re
from pathlib import Path
from typing import Any, Mapping

from exercise_expansion import split_french, split_sentences
from pinyin_format import Lexicon, PinyinError, spell_prose, syllables as split_pinyin
from situations import (
    FIRST_DAILY_LESSON,
    LAST_DAILY_LESSON,
    PINYIN_PUNCTUATION,
    Context,
    SituationError,
    Word,
    analyse_line,
    build_context,
    lesson_number,
    normalize_pinyin,
    pinyin_crosscheck,
    segment,
)

SYLLABUS_FILE = "grammar-syllabus.json"
GRAMMAR_TITLE = "Grammaire — "
NOTE_COUNT = (25, 30)
# Consecutive notes are two or three lessons apart: never more than two lessons in a row without one.
NOTE_GAP = (2, 3)
FIRST_NOTE_BY = FIRST_DAILY_LESSON + 2
LAST_NOTE_FROM = LAST_DAILY_LESSON - 2
EXAMPLE_COUNT = (3, 4)
EXPLANATION_SENTENCES = (2, 6)
MAX_EXPLANATION_CHARS = 600
MAX_MISTAKE_CHARS = 260
MAX_TITLE_CHARS = 48
MAX_FORMULA_CHARS = 60
MAX_LINE_CHARS = 22
ORDER_KINDS = ("wordOrder", "translation")
BLANK_KINDS = ("fillBlank", "choice")
TILE_COUNT = (3, 6)
EXTRA_TILES = (1, 2)
WRONG_CHOICES = (2, 3)
GUIDED = "guided"

_NOTE_KEYS = {"id", "lessonID", "title", "formula", "markers", "explanation", "examples", "mistake", "exercises"}
_EXAMPLE_KEYS = {"hanzi", "pinyin", "translation"}
_ID = re.compile(r"gram-[a-z0-9]+(?:-[a-z0-9]+)*")
_HANZI = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff]")
_HANZI_RUN = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff]+")
_QUOTED = re.compile(r"«[^»]*»")
_SENTENCE_END = re.compile(r"[.?!…](?:\s|$)")
_SENTENCE_HANZI = "。？！"
_LETTERS = "abcdefgh"


class GrammarError(ValueError):
    """The syllabus file or its overlay breaks the authoring contract."""


# -- files ----------------------------------------------------------------------------------


def syllabus_path(root: Path) -> Path:
    return root / "authoring" / SYLLABUS_FILE


def load_notes(path: Path) -> list[dict[str, Any]]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise GrammarError(f"missing grammar syllabus: {path}") from exc
    except json.JSONDecodeError as exc:
        raise GrammarError(f"invalid JSON in {path}: {exc}") from exc
    if not isinstance(value, dict) or set(value) != {"schemaVersion", "notes"} or value["schemaVersion"] != 1:
        raise GrammarError(f"{path}: expected {{schemaVersion: 1, notes: [...]}}")
    if not isinstance(value["notes"], list) or not all(isinstance(note, dict) for note in value["notes"]):
        raise GrammarError(f"{path}.notes: expected an array of objects")
    return value["notes"]


def load_syllabus(root: Path) -> list[dict[str, Any]]:
    return load_notes(syllabus_path(root))


def taught_context(lessons: Mapping[str, dict[str, Any]], catalog: list[dict[str, Any]], lesson_id: str) -> Context:
    """The lesson's context, its taught words completed by the glossed extras of the lessons up to it (the vocabulary blocks show them)."""
    context = build_context(lessons, catalog, lesson_id)
    order = lessons[lesson_id]["order"]
    allowed = dict(context.allowed)
    taught = list(context.taught_order)
    for lesson in sorted(lessons.values(), key=lambda item: item["order"]):
        if lesson["order"] > order or lesson.get("metadata", {}).get("lessonKind"):
            continue
        extras = set(lesson.get("metadata", {}).get("extraVocabularyIDs", []))
        for entry in lesson.get("vocabulary", []):
            if entry["id"] in extras and entry["hanzi"] not in allowed:
                allowed[entry["hanzi"]] = Word(entry["hanzi"], entry["pinyin"], entry["meaning"]["fr"], lesson["id"], False)
                taught.append(allowed[entry["hanzi"]])
    return dataclasses.replace(context, allowed=allowed, taught_order=taught)


def _fr(value: Any) -> str | None:
    text = value.get("fr") if isinstance(value, dict) else None
    return text if isinstance(text, str) and text.strip() else None


def hanzi_only(text: str) -> str:
    return "".join(char for char in text if _HANZI.match(char))


def render_body(note: Mapping[str, Any]) -> str:
    """The text of a note's introduction block: explanation, formula, numbered examples, then the frequent mistake."""
    lines = [note["explanation"]["fr"], f"Formule : {note['formula']}"]
    for number, example in enumerate(note["examples"], start=1):
        lines.extend([f"Exemple {number} : {example['hanzi']}", normalize_pinyin(example["hanzi"], example["pinyin"]), example["translation"]["fr"]])
    lines.append(f"Attention : {note['mistake']['fr']}")
    return "\n".join(lines)


def _tile_pinyin(word: Word) -> list[str] | None:
    """One syllable per hanzi of a taught word, whatever its spelling in the lesson (`xièxie`, `diàn nǎo`)."""
    try:
        parts = [syllable for piece in word.pinyin.split() for syllable in split_pinyin(piece)]
    except PinyinError:
        return None
    return parts if len(parts) == len(word.hanzi) else None


# -- the checks -----------------------------------------------------------------------------


class _Checker:
    def __init__(self, note: dict[str, Any], context: Context) -> None:
        self.note = note
        self.context = context
        self.problems: list[str] = []

    def fail(self, where: str, message: str) -> None:
        self.problems.append(f"{self.note.get('id', '?')} ({self.context.lesson_id}).{where}: {message}")

    def french(self, where: str, value: Any, *, hanzi: bool = False) -> str | None:
        """The French text of `value`; only an explanation may quote the words it explains."""
        text = _fr(value)
        if text is None:
            self.fail(where, 'needs a French text: {"fr": "..."}')
        elif _HANZI.search(text) and not hanzi:
            self.fail(where, "the French text contains hanzi")
        return text

    def taught(self, where: str, text: str) -> bool:
        """Whether every word of the hanzi in `text` has been taught by this lesson."""
        offenders: dict[str, str] = {}
        for run in _HANZI_RUN.findall(text):
            for surface, status in segment(run, self.context.allowed, self.context.later):
                if status == "allowed":
                    continue
                word = self.context.later.get(surface)
                if word is None:
                    offenders[surface] = f"{surface} (unknown word)"
                else:
                    detail = f"taught in {word.lesson}" if word.lesson else "outside the course vocabulary"
                    offenders[surface] = f"{surface} ({word.pinyin}, {word.meaning}; {detail})"
        if offenders:
            self.fail(where, "words the learner has not been taught: " + ", ".join(offenders.values()))
        return not offenders

    def sentence(self, where: str, value: Any, markers: list[str]) -> tuple[str, list[str]] | None:
        """(hanzi, pinyin syllables) of a checked sentence with its French translation; None when it is unsound."""
        if not isinstance(value, dict) or set(value) != _EXAMPLE_KEYS:
            self.fail(where, 'expected {hanzi, pinyin, translation: {"fr": ...}}')
            return None
        self.french(where + ".translation", value["translation"])
        line = analyse_line(value["hanzi"], value["pinyin"])
        for problem in line.problems:
            self.fail(where, problem)
        if line.problems:
            return None
        hanzi = value["hanzi"]
        if line.names:
            self.fail(where, "cannot contain a Latin name: the sentence feeds generated exercises")
        if hanzi[-1] not in _SENTENCE_HANZI:
            self.fail(where, "must end with 。 ？ or ！")
        if line.chars > MAX_LINE_CHARS:
            self.fail(where, f"{line.chars} hanzi, at most {MAX_LINE_CHARS}")
        if any(char in "，、；：" for char in hanzi):
            self.fail(where, "must be one plain sentence, without inner punctuation")
        self.taught(where, hanzi)
        if markers and not any(marker in hanzi for marker in markers):
            self.fail(where, "does not use the structure (none of the markers " + ", ".join(markers) + ")")
        syllables = [token.strip(PINYIN_PUNCTUATION) for token in line.pinyin.split()]
        if len(syllables) != line.chars:
            self.fail(where, "the pinyin has an erhua: choose another sentence")
            return None
        return hanzi, syllables

    def examples(self, value: Any, markers: list[str]) -> list[str]:
        if not isinstance(value, list) or not EXAMPLE_COUNT[0] <= len(value) <= EXAMPLE_COUNT[1]:
            self.fail("examples", f"expected {EXAMPLE_COUNT[0]}–{EXAMPLE_COUNT[1]} examples")
            return []
        found: list[str] = []
        for index, item in enumerate(value, start=1):
            checked = self.sentence(f"examples[{index}]", item, markers)
            if checked is not None:
                found.append(checked[0])
        if len(set(found)) != len(found):
            self.fail("examples", "two examples are the same sentence")
        used = "".join(found)
        unused = [marker for marker in markers if marker not in used]
        if unused:
            self.fail("examples", "no example uses the marker(s) " + ", ".join(unused))
        return found

    def _exercise_keys(self, where: str, exercise: dict[str, Any], required: set[str], optional: set[str]) -> bool:
        missing = sorted(required - set(exercise))
        unknown = sorted(set(exercise) - required - optional)
        if missing or unknown:
            self.fail(where, "; ".join(part for part in (f"missing {', '.join(missing)}" if missing else "", f"unknown {', '.join(unknown)}" if unknown else "") if part))
        return not (missing or unknown)

    def _tiles(self, where: str, exercise: dict[str, Any], hanzi: str, examples: list[str]) -> None:
        kind = exercise["kind"]
        tiles = exercise["tiles"]
        if not isinstance(tiles, list) or not all(isinstance(tile, str) and tile for tile in tiles):
            self.fail(where + ".tiles", "expected an array of words")
            return
        if not TILE_COUNT[0] <= len(tiles) <= TILE_COUNT[1] or len(set(tiles)) != len(tiles):
            self.fail(where + ".tiles", f"{TILE_COUNT[0]}–{TILE_COUNT[1]} different tiles expected")
        if "".join(tiles) != hanzi_only(hanzi):
            self.fail(where + ".tiles", "the tiles, in order, must spell the answer")
        for tile in tiles:
            if tile not in self.context.allowed:
                self.fail(where + ".tiles", f"'{tile}' is not a taught word")
        if kind == "wordOrder":
            return
        if hanzi not in examples:
            self.fail(where + ".answer", "a translation exercise assembles one of the note's examples (the lesson must show the sentence)")
        extras = exercise["extraTiles"]
        if not isinstance(extras, list) or not EXTRA_TILES[0] <= len(extras) <= EXTRA_TILES[1] or len(set(extras)) != len(extras):
            self.fail(where + ".extraTiles", f"{EXTRA_TILES[0]}–{EXTRA_TILES[1]} different distractor tiles expected")
            return
        for tile in extras:
            word = self.context.allowed.get(tile)
            if not isinstance(tile, str) or word is None:
                self.fail(where + ".extraTiles", f"'{tile}' is not a taught word")
            elif tile in hanzi or tile in tiles:
                self.fail(where + ".extraTiles", f"'{tile}' is part of the answer")
            elif _tile_pinyin(word) is None:
                self.fail(where + ".extraTiles", f"'{tile}' has no one-syllable-per-hanzi pinyin")
        alternatives = exercise.get("alternatives", [])
        if not isinstance(alternatives, list):
            self.fail(where + ".alternatives", "expected an array of sentences")
            return
        for alternative in alternatives:
            if not isinstance(alternative, str) or alternative == hanzi or order_of(alternative, tiles) is None:
                self.fail(where + ".alternatives", f"'{alternative}' must be another order of the same tiles")

    def _blank(self, where: str, exercise: dict[str, Any], hanzi: str, markers: list[str]) -> None:
        blank = exercise["blank"]
        if blank not in markers:
            self.fail(where + ".blank", "the blank must be one of the note's markers")
        elif hanzi.count(blank) != 1:
            self.fail(where + ".blank", f"'{blank}' must occur exactly once in the answer")
        if exercise["kind"] == "fillBlank":
            alternatives = exercise.get("alternatives", [])
            if not isinstance(alternatives, list) or not all(isinstance(word, str) and word in self.context.allowed for word in alternatives):
                self.fail(where + ".alternatives", "expected other accepted words, all taught")
            return
        wrong = exercise["wrong"]
        if not isinstance(wrong, list) or not WRONG_CHOICES[0] <= len(wrong) <= WRONG_CHOICES[1] or len(set(wrong)) != len(wrong):
            self.fail(where + ".wrong", f"{WRONG_CHOICES[0]}–{WRONG_CHOICES[1]} different wrong choices expected")
            return
        for word in [blank, *wrong]:
            if word not in self.context.allowed:
                self.fail(where + ".wrong", f"'{word}' is not a taught word")
        if blank in wrong:
            self.fail(where + ".wrong", "the answer is among the wrong choices")

    def exercises(self, value: Any, markers: list[str], examples: list[str]) -> None:
        if not isinstance(value, list) or len(value) != len(ORDER_KINDS):
            self.fail("exercises", f"expected exactly {len(ORDER_KINDS)} exercises: one of {', '.join(ORDER_KINDS)}, then one of {', '.join(BLANK_KINDS)}")
            return
        answers: list[str] = []
        for index, (exercise, kinds) in enumerate(zip(value, (ORDER_KINDS, BLANK_KINDS)), start=1):
            where = f"exercises[{index}]"
            if not isinstance(exercise, dict) or exercise.get("kind") not in kinds:
                self.fail(where, f"expected an exercise of kind {' or '.join(kinds)}")
                continue
            kind = exercise["kind"]
            required, optional = {
                "wordOrder": ({"kind", "answer", "tiles"}, set()),
                "translation": ({"kind", "answer", "tiles", "extraTiles"}, {"alternatives"}),
                "fillBlank": ({"kind", "answer", "blank"}, {"alternatives"}),
                "choice": ({"kind", "answer", "blank", "wrong"}, set()),
            }[kind]
            if not self._exercise_keys(where, exercise, required, optional):
                continue
            checked = self.sentence(where + ".answer", exercise["answer"], markers)
            if checked is None:
                continue
            hanzi = checked[0]
            answers.append(hanzi)
            if kind in ORDER_KINDS:
                self._tiles(where, exercise, hanzi, examples)
            else:
                self._blank(where, exercise, hanzi, markers)
        if len(set(answers)) != len(answers):
            self.fail("exercises", "both exercises use the same sentence")


def order_of(text: str, tiles: list[str]) -> list[str] | None:
    """The tiles, in the order that spells `text` (punctuation apart), or None when they cannot."""
    remaining = hanzi_only(text)
    order: list[str] = []
    while remaining:
        match = [tile for tile in tiles if tile not in order and remaining.startswith(tile)]
        if len(match) != 1:
            return None
        order.append(match[0])
        remaining = remaining[len(match[0]):]
    return order if len(order) == len(tiles) else None


def check_note(note: dict[str, Any], context: Context) -> list[str]:
    """Every way `note` breaks the rules for its lesson; empty when it is sound."""
    checker = _Checker(note, context)
    missing, unknown = sorted(_NOTE_KEYS - set(note)), sorted(set(note) - _NOTE_KEYS)
    if missing or unknown:
        checker.fail("keys", "; ".join(part for part in (f"missing {', '.join(missing)}" if missing else "", f"unknown {', '.join(unknown)}" if unknown else "") if part))
    if missing:
        return checker.problems
    if not isinstance(note["id"], str) or not _ID.fullmatch(note["id"]):
        checker.fail("id", "expected a stable ID such as gram-ma-question")
    for key, limit in (("title", MAX_TITLE_CHARS), ("formula", MAX_FORMULA_CHARS)):
        text = note[key]
        if not isinstance(text, str) or not text.strip() or "\n" in text:
            checker.fail(key, "expected one line of text")
        elif len(text) > limit:
            checker.fail(key, f"{len(text)} characters, at most {limit}")
        else:
            checker.taught(key, text)
    markers = note["markers"]
    if not isinstance(markers, list) or not markers or not all(isinstance(marker, str) and marker for marker in markers) or len(set(markers)) != len(markers):
        checker.fail("markers", "expected the different taught words that carry the structure")
        markers = []
    else:
        for marker in markers:
            if marker not in context.allowed:
                checker.fail("markers", f"'{marker}' has not been taught by this lesson")
    explanation = checker.french("explanation", note["explanation"], hanzi=True)
    if explanation is not None:
        sentences = len(_SENTENCE_END.findall(_QUOTED.sub("", explanation)))
        if len(explanation) > MAX_EXPLANATION_CHARS or "\n" in explanation:
            checker.fail("explanation", f"{len(explanation)} characters on one line, at most {MAX_EXPLANATION_CHARS}")
        if not EXPLANATION_SENTENCES[0] <= sentences <= EXPLANATION_SENTENCES[1]:
            checker.fail("explanation", f"{sentences} sentences, expected {EXPLANATION_SENTENCES[0]}–{EXPLANATION_SENTENCES[1]}")
        checker.taught("explanation", explanation)
    mistake = checker.french("mistake", note["mistake"], hanzi=True)
    if mistake is not None:
        if len(mistake) > MAX_MISTAKE_CHARS or "\n" in mistake:
            checker.fail("mistake", f"{len(mistake)} characters on one line, at most {MAX_MISTAKE_CHARS}")
        checker.taught("mistake", mistake)
    examples = checker.examples(note["examples"], markers)
    checker.exercises(note["exercises"], markers, examples)
    return checker.problems


def check_syllabus(
    notes: list[dict[str, Any]],
    lessons: Mapping[str, dict[str, Any]],
    catalog: list[dict[str, Any]],
    *,
    complete: bool = True,
) -> list[str]:
    """Every problem of the notes; `complete` also requires the whole syllabus (cadence, count, every lesson)."""
    problems: list[str] = []
    ids = [note.get("id") for note in notes]
    for identifier in sorted({value for value in ids if ids.count(value) > 1}, key=str):
        problems.append(f"note ID {identifier} is used twice")
    daily: list[int] = []
    for note in notes:
        lesson_id = note.get("lessonID")
        try:
            number = lesson_number(lesson_id) if isinstance(lesson_id, str) else -1
            context = taught_context(lessons, catalog, lesson_id)
        except (SituationError, TypeError) as exc:
            problems.append(f"{note.get('id', '?')}: {exc}")
            continue
        daily.append(number)
        problems.extend(check_note(note, context))
    for number in sorted({value for value in daily if daily.count(value) > 1}):
        problems.append(f"lesson-{number:02d} has two grammar notes")
    if complete and len(daily) == len(notes):
        if not NOTE_COUNT[0] <= len(notes) <= NOTE_COUNT[1]:
            problems.append(f"{len(notes)} notes, expected {NOTE_COUNT[0]}–{NOTE_COUNT[1]}")
        if daily != sorted(daily):
            problems.append("the notes must follow the order of the lessons")
        elif daily:
            if daily[0] > FIRST_NOTE_BY:
                problems.append(f"the first note comes at lesson-{daily[0]:02d}, at the latest lesson-{FIRST_NOTE_BY:02d}")
            if daily[-1] < LAST_NOTE_FROM:
                problems.append(f"the last note comes at lesson-{daily[-1]:02d}, at the earliest lesson-{LAST_NOTE_FROM:02d}")
            for before, after in zip(daily, daily[1:]):
                if not NOTE_GAP[0] <= after - before <= NOTE_GAP[1]:
                    problems.append(f"lesson-{before:02d} and lesson-{after:02d} are {after - before} lessons apart, expected {NOTE_GAP[0]}–{NOTE_GAP[1]}")
    return problems


def pinyin_problems(notes: list[dict[str, Any]]) -> tuple[list[str], str | None]:
    """The pypinyin disagreements of the notes' examples and answers (optional; None note when pypinyin runs)."""
    problems: list[str] = []
    for note in notes:
        sentences = [*note.get("examples", []), *(exercise.get("answer") for exercise in note.get("exercises", []))]
        found, message = pinyin_crosscheck({"dialogue": [item for item in sentences if isinstance(item, dict)]})
        if message:
            return [], message
        problems.extend(f"{note.get('id', '?')}.{problem}" for problem in found)
    return problems, None


# -- the overlay ----------------------------------------------------------------------------


def _is_daily(lesson_id: Any) -> bool:
    try:
        return isinstance(lesson_id, str) and FIRST_DAILY_LESSON <= lesson_number(lesson_id) <= LAST_DAILY_LESSON
    except SituationError:
        return False


def _blanked(hanzi: str, blank: str) -> str:
    return hanzi.replace(blank, "___", 1)


def _tokens(hanzi: str, syllables: list[str], tiles: list[str]) -> list[dict[str, Any]]:
    result = []
    cursor = 0
    for index, tile in enumerate(tiles):
        result.append({"id": _LETTERS[index], "hanzi": tile, "pinyin": " ".join(syllables[cursor:cursor + len(tile)]), "audio": None})
        cursor += len(tile)
    return result


def build_exercises(note: dict[str, Any], lesson_id: str, produce: str, context: Context) -> list[dict[str, Any]]:
    """The note's two exercises as pack exercises: generated prompts, tiles in a fixed shuffle, choices answer first."""
    number = lesson_number(lesson_id)
    built: list[dict[str, Any]] = []
    for index, exercise in enumerate(note["exercises"], start=1):
        kind = exercise["kind"]
        answer = exercise["answer"]
        hanzi = answer["hanzi"]
        french = answer["translation"]["fr"].rstrip(". ")
        syllables = [token.strip(PINYIN_PUNCTUATION) for token in normalize_pinyin(hanzi, answer["pinyin"]).split()]
        rng = random.Random(f"{note['id']}:{index}")
        spec: dict[str, Any] = {"kind": kind}
        if kind in ORDER_KINDS:
            tokens = _tokens(hanzi, syllables, exercise["tiles"])
            correct = [token["id"] for token in tokens]
            tiles = list(tokens)
            if kind == "translation":
                for extra in exercise["extraTiles"]:
                    pinyin = " ".join(_tile_pinyin(context.allowed[extra]) or [])
                    tiles.append({"id": _LETTERS[len(tiles)], "hanzi": extra, "pinyin": pinyin, "audio": None})
            shuffled = list(tiles)
            while [token["id"] for token in shuffled if token["id"] in correct] == correct:
                rng.shuffle(shuffled)
            spec["tokens"] = shuffled
            spec["correctOrder"] = correct
            if kind == "translation":
                by_hanzi = {token["hanzi"]: token["id"] for token in tokens}
                spec["acceptedOrders"] = [[by_hanzi[tile] for tile in order_of(item, exercise["tiles"]) or []] for item in exercise.get("alternatives", [])]
                prompt, instruction = (
                    f"Traduis en chinois : « {french} »",
                    "Assemble la phrase avec les tuiles. Attention : certaines tuiles sont en trop.",
                )
            else:
                body = hanzi.rstrip(_SENTENCE_HANZI)
                spec["acceptedVariants"] = [hanzi] if body == hanzi else [hanzi, body]
                prompt, instruction = f"Construis « {french} ».", "Replace chaque groupe dans l’ordre, puis relis la phrase complète."
        else:
            blank = exercise["blank"]
            blanked = _blanked(hanzi, blank)
            if kind == "fillBlank":
                spec["sentence"] = blanked
                spec["acceptedAnswers"] = [blank, *exercise.get("alternatives", [])]
                spec["caseSensitive"] = False
                prompt, instruction = f"Complète : {blanked} (« {french} »)", "Écris le mot manquant en caractères chinois."
            else:
                words = [blank, *exercise["wrong"]]
                spec["choices"] = [
                    {"id": _LETTERS[position], "label": {"fr": f"{word} ({context.allowed[word].pinyin})"}, "audio": None}
                    for position, word in enumerate(words)
                ]
                spec["correctChoiceID"] = _LETTERS[0]
                prompt = f"Quel mot complète la phrase : {blanked} (« {french} ») ?"
                instruction = "Choisis le mot qui convient."
        built.append({
            "id": f"ex-l{number}-gram-{index}", "prompt": {"fr": prompt}, "instruction": {"fr": instruction},
            "objectiveIDs": [produce], "required": True, "grammarPointID": note["id"], **spec,
        })
    return built


def lower_note(note: dict[str, Any]) -> dict[str, Any]:
    """The pack's grammar note for a syllabus note."""
    return {
        "id": note["id"],
        "pattern": note["title"],
        "formula": note["formula"],
        "explanation": note["explanation"],
        "examples": [
            {"hanzi": item["hanzi"], "pinyin": normalize_pinyin(item["hanzi"], item["pinyin"]), "translation": item["translation"]}
            for item in note["examples"]
        ],
        "mistake": note["mistake"],
    }


def grammar_point(note: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": note["id"], "pattern": note["formula"], "function": note["title"],
        "markers": list(note["markers"]), "errors": [note["mistake"]["fr"]],
    }


def apply_syllabus(
    blueprints: list[Any],
    notes: list[dict[str, Any]],
    lessons: Mapping[str, dict[str, Any]],
    catalog: list[dict[str, Any]],
) -> list[Any]:
    """The daily blueprints with the syllabus's notes and exercises in place of the assembled grammar.

    A lesson without a note ends up with no grammar block: the pack's own `grammar` lists are dropped.
    """
    by_lesson = {note["lessonID"]: note for note in notes}
    listed = {item["id"] for item in blueprints if isinstance(item, dict) and isinstance(item.get("id"), str)}
    unknown = sorted(set(by_lesson) - listed, key=lesson_number)
    if unknown:
        raise GrammarError(f"grammar notes for lessons the pack does not list: {', '.join(unknown)}")
    result: list[Any] = []
    for item in blueprints:
        if not isinstance(item, dict) or not _is_daily(item.get("id")):
            result.append(item)
            continue
        lesson = copy.deepcopy(item)
        lesson["grammar"] = []
        note = by_lesson.get(lesson["id"])
        if note is not None:
            context = taught_context(lessons, catalog, lesson["id"])
            produce = next((objective["id"] for objective in lesson["objectives"] if objective["id"].endswith("-produce")), lesson["objectives"][-1]["id"])
            lesson["grammar"] = [lower_note(note)]
            lesson["grammarPoints"] = [grammar_point(note)]
            lesson["exercises"] = [*lesson["exercises"], *build_exercises(note, lesson["id"], produce, context)]
        result.append(lesson)
    return result


# -- what a generated bundle owes the syllabus ------------------------------------------------


def _answer_problems(block: dict[str, Any], expected: dict[str, Any]) -> list[str]:
    """Whether a generated exercise still assembles or completes the note's answer with its marker."""
    spec = block["spec"]
    answer = hanzi_only(expected["answer"]["hanzi"])
    kind = spec["kind"]
    if kind != expected["kind"]:
        return [f"is a {kind}, the note asks for a {expected['kind']}"]
    if kind in ORDER_KINDS:
        pieces = {token["id"]: token["hanzi"] for token in spec["tokens"]}
        built = "".join(pieces[token_id] for token_id in spec["correctOrder"])
        marked = any(pieces[token_id] in expected["_markers"] for token_id in spec["correctOrder"])
    elif kind == "fillBlank":
        built = hanzi_only(spec["sentence"].replace("___", spec["acceptedAnswers"][0]))
        marked = spec["acceptedAnswers"][0] in expected["_markers"]
    else:
        label = next(choice["label"]["fr"] for choice in spec["choices"] if choice["id"] == spec["correctChoiceID"])
        word = label.split(" ")[0]
        built = hanzi_only(expected["answer"]["hanzi"].replace(expected["blank"], word, 1))
        marked = word in expected["_markers"]
    problems = []
    if built != answer:
        problems.append(f"builds '{built}', the note answers '{answer}'")
    if not marked:
        problems.append("does not manipulate one of the note's markers")
    return problems


def bundle_problems(notes: list[dict[str, Any]], lessons: Mapping[str, dict[str, Any]], lexicon: Lexicon) -> list[str]:
    """What a generated bundle owes the syllabus: each note's block (its pinyin written by words) and exercises where
    designed, no grammar elsewhere."""
    by_lesson = {note["lessonID"]: note for note in notes}
    problems: list[str] = []
    for lesson_id, lesson in sorted(lessons.items(), key=lambda item: item[1]["order"]):
        if not _is_daily(lesson_id) or lesson.get("metadata", {}).get("lessonKind"):
            continue
        number = lesson_number(lesson_id)
        blocks = lesson.get("blocks", [])
        grammar = [block for block in blocks if block.get("kind") == "introduction" and "-grammar-" in block.get("id", "")]
        gram_exercises = [block for block in blocks if block.get("kind") == "exercise" and "-gram-" in block["spec"]["header"]["id"]]
        note = by_lesson.get(lesson_id)
        if note is None:
            if grammar or gram_exercises or lesson.get("grammarPoints"):
                problems.append(f"{lesson_id}: has grammar but the syllabus designs no note here; run `content_tool.py generate` again")
            continue
        if len(grammar) != 1 or grammar[0]["id"] != f"block-{lesson_id}-grammar-01":
            problems.append(f"{lesson_id}: expected the single grammar block block-{lesson_id}-grammar-01; run `content_tool.py generate` again")
            continue
        block = grammar[0]
        if block["title"].get("fr") != GRAMMAR_TITLE + note["title"] or block["body"].get("fr") != spell_prose(render_body(note), lexicon) or block.get("metadata", {}).get("grammarPointID") != note["id"]:
            problems.append(f"{lesson_id}: the grammar block differs from note {note['id']}; run `content_tool.py generate` again")
        if [point.get("id") for point in lesson.get("grammarPoints", [])] != [note["id"]]:
            problems.append(f"{lesson_id}: grammarPoints must list {note['id']} alone")
        expected_ids = [f"ex-l{number}-gram-{index}" for index in range(1, len(note["exercises"]) + 1)]
        if [block["spec"]["header"]["id"] for block in gram_exercises] != expected_ids:
            problems.append(f"{lesson_id}: expected the exercises {', '.join(expected_ids)}; run `content_tool.py generate` again")
            continue
        for block, exercise in zip(gram_exercises, note["exercises"]):
            where = f"{lesson_id}: exercise {block['spec']['header']['id']}"
            metadata = block.get("metadata", {})
            if metadata.get("grammarPointID") != note["id"] or metadata.get("stage") != GUIDED:
                problems.append(f"{where} must be linked to {note['id']} in the {GUIDED} phase")
            problems.extend(f"{where} {problem}" for problem in _answer_problems(block, {**exercise, "_markers": note["markers"]}))
    return problems


# -- writer tooling -------------------------------------------------------------------------


def brief(context: Context, lesson: dict[str, Any], notes: list[dict[str, Any]]) -> str:
    """What a writer needs to author one lesson's note: the taught words, the lesson's own sentences, the note so far."""
    dialogue = next((block for block in lesson["blocks"] if block.get("kind") == "dialogue"), {})
    reading = next((block for block in lesson["blocks"] if block.get("kind") == "reading"), {})
    sentences = [(line["hanzi"], line["pinyin"], line["translation"]["fr"]) for line in dialogue.get("lines", [])]
    for item in reading.get("paragraphs", []):
        parts = [split_sentences(item["hanzi"]), split_sentences(item["pinyin"]), split_french(item["translation"]["fr"])]
        rows = list(zip(*parts)) if len({len(part) for part in parts}) == 1 else [(item["hanzi"], item["pinyin"], item["translation"]["fr"])]
        sentences.extend((hanzi.strip(), pinyin.strip(), french.strip()) for hanzi, pinyin, french in rows)
    clean = [
        (hanzi, pinyin, french) for hanzi, pinyin, french in sentences
        if not any(status != "allowed" for run in _HANZI_RUN.findall(hanzi) for _, status in segment(run, context.allowed, context.later))
        and not re.search("[A-Za-z]", hanzi)
    ]
    note = next((note for note in notes if note.get("lessonID") == context.lesson_id), None)
    words = "\n".join(f"  {word.lesson}: {word.hanzi} {word.pinyin} — {word.meaning}" for word in context.taught_order)
    return "\n".join([
        f"# {context.lesson_id} — {context.title}",
        f"Note prévue : {note['id']} ({note['title']})" if note else "Note prévue : aucune",
        "",
        "## Phrases du dialogue et de la lecture qui n'emploient que des mots enseignés (à réutiliser comme exemples)",
        *[f"  {hanzi} | {pinyin} | {french}" for hanzi, pinyin, french in clean],
        "",
        f"## Vocabulaire enseigné ({len(context.taught_order)} mots)",
        words,
    ])
