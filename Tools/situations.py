"""Hand-authored situations: the dialogue, reading and closing exercises of a daily lesson.

A writer produces one JSON file per unit, `Content/authoring/situations/unit-NN.json`,
mapping a lesson ID to a scene: dialogue, reading, one comprehension question, the
sentences the closing listening and speaking exercises use, and the few glossed words
that lie outside the taught vocabulary. `content_tool.py generate` overlays each scene
on its lesson's blueprint in place of the assembled text, and `lint` re-checks the
scene against the words the learner has been taught up to that lesson.

Nothing here invents Mandarin: every hanzi, pinyin and translation comes from the file.
The word rules are checked on hanzi; whether a sentence is natural, or its pinyin and
French are right, stays the writer's and the reviewer's job (`pinyin_crosscheck` helps).
"""

from __future__ import annotations

import copy
import json
import re
import unicodedata
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable, Mapping

from exercise_expansion import split_french, split_sentences
from exercise_kinds import pinyin_tones
from pinyin_module import PinyinError, check_pinyin, syllables as split_pinyin
from review_lessons import is_derived

SITUATIONS_DIR = "situations"
CATALOG_FILE = "hsk-legacy-600.json"
FIRST_DAILY_LESSON = 5
LAST_DAILY_LESSON = 70
LAST_PLAN_RANK = 300

DIALOGUE_LINES = (8, 12)
READING_SENTENCES = (4, 6)
READING_PARAGRAPHS = (1, 3)
MAX_LINE_CHARS = 22
MIN_LISTEN_CHARS = 4
MAX_TITLE_CHARS = 40
MAX_SPEAKERS = 3
# The contract tests accept three to five new words per daily lesson, glossed extras included.
MAX_NEW_WORDS = 5
MIN_READING_NEW_WORDS = 2
EXTRA_SHARE = 0.08
MAX_DIALOGUE_NAME_LINES = 2
MAX_READING_NAME_SENTENCES = 1
CHARACTERS = ("Mina", "Tao", "An", "Lin")
# Lines that a conversation legitimately repeats (two people greeting each other).
GREETINGS = frozenset("你好 您好 早 早上好 晚上好 再见 明天见 谢谢 不客气 对不起 没关系 好 好的 嗯".split())
HANZI_PUNCTUATION = {"，": ",", "、": ",", "；": ";", "：": ":", "。": ".", "？": "?", "！": "!"}
PINYIN_PUNCTUATION = ",.?!;:"
PARTS_OF_SPEECH = (
    "noun", "verb", "adjective", "adverb", "pronoun", "classifier",
    "preposition", "conjunction", "particle", "measureWord", "interjection", "other",
)
LISTEN_PROMPT = "Quelle phrase entends-tu ?"
LISTEN_INSTRUCTION = "Écoute la phrase en mandarin, puis choisis son sens."
SPEAK_INSTRUCTION = "Écoute le modèle, dis la phrase, puis réécoute-toi ou auto-évalue-toi."
READING_INSTRUCTION = "Relis le petit texte avant de répondre."
LISTEN_CHOICES = 3
READING_CHOICES = ("a", "b", "c")

_MAX_WORD = 6
_COST_ALLOWED, _COST_LATER, _COST_UNKNOWN, _COST_UNREACHED = 1, 1_000, 1_000_000, 10**12
_KEYS = {"situation", "title", "dialogue", "reading", "readingQuestion", "listenSentence", "speakSentence", "extraVocabulary"}
_REQUIRED_KEYS = _KEYS - {"extraVocabulary"}
_HANZI = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff]")
_PINYIN_TOKEN = re.compile(r"[^\W\d_]+|[,.?!;:]|\s+|.")
_LESSON_ID = re.compile(r"lesson-(\d+)")


class SituationError(ValueError):
    """A situation file or its overlay breaks the authoring contract."""


# -- files ------------------------------------------------------------------------


def situation_dir(root: Path) -> Path:
    return root / "authoring" / SITUATIONS_DIR


def lesson_number(lesson_id: str) -> int:
    match = _LESSON_ID.fullmatch(lesson_id)
    if match is None:
        raise SituationError(f"'{lesson_id}' is not a daily lesson ID (lesson-NN)")
    return int(match.group(1))


def unit_file_name(module_id: str) -> str:
    """`unit-02` (the first daily unit of the course) is written in `unit-01.json`."""
    match = re.fullmatch(r"unit-(\d+)", module_id)
    if match is None or int(match.group(1)) < 2:
        raise SituationError(f"'{module_id}' is not a daily unit")
    return f"unit-{int(match.group(1)) - 1:02d}.json"


@dataclass
class SituationSet:
    entries: dict[str, dict[str, Any]] = field(default_factory=dict)
    files: dict[str, str] = field(default_factory=dict)


def load_file(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise SituationError(f"missing situation file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise SituationError(f"invalid JSON in {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise SituationError(f"{path}: expected an object mapping lesson IDs to situations")
    return value


def load_situations(root: Path) -> SituationSet:
    result = SituationSet()
    for path in sorted(situation_dir(root).glob("unit-*.json")):
        for lesson_id, entry in load_file(path).items():
            if lesson_id in result.entries:
                raise SituationError(f"{lesson_id} is written in both {result.files[lesson_id]} and {path.name}")
            result.entries[lesson_id] = entry
            result.files[lesson_id] = path.name
    return result


# -- vocabulary the learner has met --------------------------------------------------


@dataclass(frozen=True)
class Word:
    hanzi: str
    pinyin: str
    meaning: str
    # The lesson that first lists the word; empty for a catalogue word the plan never teaches.
    lesson: str
    canonical: bool = True


@dataclass
class Context:
    """What a lesson's texts may use, and must use, derived from the generated bundle."""

    lesson_id: str
    module_id: str
    theme: str
    title: str
    summary: str
    allowed: dict[str, Word]
    later: dict[str, Word]
    new: list[Word]
    reused: list[Word]
    taught_order: list[Word]
    speakers: Counter[str]
    grammar: list[tuple[str, str]]

    @property
    def unit_file(self) -> str:
        return unit_file_name(self.module_id)


def _text(value: Any) -> str | None:
    return value if isinstance(value, str) and value.strip() else None


def _fr(value: Any) -> str | None:
    return _text(value.get("fr")) if isinstance(value, dict) else None


def _meaning(entry: Mapping[str, Any]) -> str:
    meaning = entry.get("meaning")
    if isinstance(meaning, dict) and isinstance(meaning.get("fr"), str):
        return meaning["fr"]
    return str(entry.get("meaningFr", ""))


def _forms(hanzi: str, catalog_forms: Mapping[str, list[str]]) -> list[str]:
    return [hanzi, *catalog_forms.get(hanzi, [])]


def build_context(lessons: Mapping[str, dict[str, Any]], catalog: list[dict[str, Any]], lesson_id: str) -> Context:
    number = lesson_number(lesson_id)
    if not FIRST_DAILY_LESSON <= number <= LAST_DAILY_LESSON or lesson_id not in lessons:
        raise SituationError(f"{lesson_id}: not a daily lesson of this course (lesson-{FIRST_DAILY_LESSON:02d} to lesson-{LAST_DAILY_LESSON})")
    target = lessons[lesson_id]
    catalog_forms = {entry["hanzi"]: list(entry.get("aliases", [])) for entry in catalog}
    ordered = sorted((lesson for lesson in lessons.values() if not is_derived(lesson)), key=lambda lesson: (lesson["order"], lesson["id"]))
    allowed: dict[str, Word] = {}
    later: dict[str, Word] = {}
    taught_order: list[Word] = []
    speakers: Counter[str] = Counter()
    for lesson in ordered:
        extras = set(lesson.get("metadata", {}).get("extraVocabularyIDs", []))
        earlier = lesson["order"] <= target["order"]
        for entry in lesson.get("vocabulary", []):
            if entry["id"] in extras:
                continue
            word = Word(entry["hanzi"], entry["pinyin"], _meaning(entry), lesson["id"])
            if earlier:
                if entry["hanzi"] not in allowed:
                    taught_order.append(word)
                for form in _forms(word.hanzi, catalog_forms):
                    allowed.setdefault(form, word)
            else:
                for form in _forms(word.hanzi, catalog_forms):
                    later.setdefault(form, word)
        if lesson["order"] < target["order"]:
            for block in lesson.get("blocks", []):
                if block.get("kind") == "dialogue":
                    speakers.update(line["speaker"] for line in block.get("lines", []))
    for entry in catalog:
        canonical = entry["rank"] <= LAST_PLAN_RANK
        word = Word(entry["hanzi"], entry["pinyin"], _meaning(entry), "", canonical)
        for form in _forms(word.hanzi, catalog_forms):
            if form not in allowed:
                later.setdefault(form, word)
    metadata = target.get("metadata", {})
    extras = set(metadata.get("extraVocabularyIDs", []))
    by_id = {entry["id"]: entry for entry in target.get("vocabulary", [])}
    new_ids = [vocab_id for vocab_id in metadata.get("newVocabularyIDs", []) if vocab_id not in extras]
    new = [Word(by_id[i]["hanzi"], by_id[i]["pinyin"], _meaning(by_id[i]), lesson_id) for i in new_ids]
    reused = [
        Word(entry["hanzi"], entry["pinyin"], _meaning(entry), lesson_id)
        for entry in target.get("vocabulary", []) if entry["id"] not in extras and entry["id"] not in new_ids
    ]
    grammar = [
        ((_fr(block.get("title")) or "").removeprefix("Grammaire — "), _fr(block.get("body")) or "")
        for block in target.get("blocks", []) if block.get("kind") == "introduction" and "-grammar-" in block.get("id", "")
    ]
    return Context(
        lesson_id, target["moduleID"], str(metadata.get("theme", "")), target["title"]["fr"], target["summary"]["fr"],
        allowed, later, new, reused, taught_order, speakers, grammar,
    )


def load_catalog(root: Path) -> list[dict[str, Any]]:
    path = root / "authoring" / CATALOG_FILE
    try:
        return json.loads(path.read_text(encoding="utf-8"))["entries"]
    except FileNotFoundError as exc:
        raise SituationError(f"missing catalogue: {path}") from exc


def load_lessons(root: Path) -> dict[str, dict[str, Any]]:
    lessons: dict[str, dict[str, Any]] = {}
    for path in sorted((root / "lessons").glob("*.json")):
        lesson = json.loads(path.read_text(encoding="utf-8"))
        lessons[lesson["id"]] = lesson
    return lessons


# -- pinyin and hanzi lines -------------------------------------------------------------


@dataclass
class Line:
    """One checked hanzi/pinyin pair."""

    problems: list[str] = field(default_factory=list)
    pinyin: str = ""
    runs: list[str] = field(default_factory=list)
    chars: int = 0
    names: int = 0


def _parse_hanzi(text: str, problems: list[str]) -> list[tuple[str, str]]:
    items: list[tuple[str, str]] = []
    index = 0
    while index < len(text):
        char = text[index]
        if _HANZI.match(char):
            items.append(("h", char))
        elif char in HANZI_PUNCTUATION:
            items.append(("p", char))
        elif char.isascii() and char.isalpha():
            end = index
            while end < len(text) and text[end].isascii() and text[end].isalpha():
                end += 1
            run = text[index:end]
            if run not in CHARACTERS:
                problems.append(f"letters '{run}' in the hanzi are not a recurring character ({', '.join(CHARACTERS)})")
            items.append(("n", run))
            index += len(run)
            continue
        else:
            problems.append("a space in the hanzi" if char.isspace() else f"character {char!r} is not allowed in the hanzi (hanzi and ， 。 ？ ！ 、 ； ： only)")
        index += 1
    return items


def _pinyin_syllables(run: str) -> tuple[list[str], bool]:
    """The syllables of a letter run; True when its last one is an erhua (`nǎr`)."""
    try:
        return split_pinyin(run), False
    except PinyinError:
        if len(run) > 1 and run.endswith("r"):
            try:
                return split_pinyin(run[:-1]), True
            except PinyinError:
                pass
        raise


def _parse_pinyin(text: str, problems: list[str]) -> list[tuple[str, str, bool]]:
    """(kind, text, erhua) for each syllable `s`, name `n` and punctuation mark `p`."""
    tokens: list[tuple[str, str, bool]] = []
    for match in _PINYIN_TOKEN.finditer(text):
        piece = match.group()
        if piece.isspace():
            continue
        if piece in PINYIN_PUNCTUATION and len(piece) == 1:
            tokens.append(("p", piece, False))
        elif piece[0].isalpha():
            if piece in CHARACTERS:
                tokens.append(("n", piece, False))
                continue
            if piece != piece.lower():
                problems.append(f"pinyin '{piece}' must be lowercase (only {', '.join(CHARACTERS)} take a capital)")
                continue
            try:
                parts, erhua = _pinyin_syllables(piece)
                for part in parts:
                    check_pinyin(part, "pinyin")
            except PinyinError as exc:
                problems.append(f"pinyin '{piece}': {str(exc).removeprefix('pinyin: ')}")
                continue
            tokens.extend(("s", part, erhua and position == len(parts) - 1) for position, part in enumerate(parts))
        else:
            hint = ": use the ASCII marks , . ? ! ; :" if piece in "，。？！、；：" else ""
            problems.append(f"character {piece!r} is not allowed in the pinyin{hint}")
    return tokens


def analyse_line(hanzi: Any, pinyin: Any) -> Line:
    """Check that a hanzi line and its pinyin correspond, and return the pinyin in the bundle's spelling."""
    line = Line()
    if not isinstance(hanzi, str) or not hanzi.strip() or not isinstance(pinyin, str) or not pinyin.strip():
        line.problems.append("hanzi and pinyin must be non-empty text")
        return line
    if not unicodedata.is_normalized("NFC", pinyin):
        line.problems.append("the pinyin must be NFC text (precomposed tone marks)")
        return line
    items = _parse_hanzi(hanzi, line.problems)
    tokens = _parse_pinyin(pinyin, line.problems)
    if line.problems:
        return line
    if items[0][0] == "p":
        line.problems.append("a line cannot start with punctuation")
        return line
    position = 0
    for kind, text, erhua in tokens:
        expected = items[position] if position < len(items) else None
        if kind == "p":
            ok = expected is not None and expected[0] == "p" and HANZI_PUNCTUATION[expected[1]] == text
        elif kind == "n":
            ok = expected == ("n", text)
        else:
            ok = expected is not None and expected[0] == "h"
        if not ok:
            line.problems.append(_misaligned(items, tokens, position, kind, text))
            return line
        position += 1
        if erhua:
            if position >= len(items) or items[position] != ("h", "儿"):
                line.problems.append(f"the erhua '{text}' must match 儿 in the hanzi")
                return line
            position += 1
    if position != len(items):
        line.problems.append(_misaligned(items, tokens, position, "end", ""))
        return line
    parts: list[str] = []
    for kind, text, _ in tokens:
        if kind == "p":
            parts[-1] += text
        else:
            parts.append(text)
    line.pinyin = " ".join(parts)
    line.chars = sum(1 for kind, _ in items if kind == "h")
    line.names = sum(1 for kind, _ in items if kind == "n")
    run = ""
    for kind, char in items:
        if kind == "h":
            run += char
            continue
        if run:
            line.runs.append(run)
        run = ""
    if run:
        line.runs.append(run)
    return line


def _misaligned(items: list[tuple[str, str]], tokens: list[tuple[str, str, bool]], position: int, kind: str, text: str) -> str:
    syllables = sum(1 for token in tokens if token[0] in "sn")
    chars = sum(1 for item in items if item[0] in "hn")
    around = "".join(char for _, char in items[max(0, position - 1):position + 2])
    return (
        f"the pinyin does not follow the hanzi (near '{around}': {chars} hanzi/names, {syllables} syllables/names; "
        "one syllable per hanzi, one ASCII mark per ， 。 ？ ！ 、 ； ： at the same place)"
    )


def normalize_pinyin(hanzi: str, pinyin: str) -> str:
    line = analyse_line(hanzi, pinyin)
    if line.problems:
        raise SituationError(f"'{hanzi}': {line.problems[0]}")
    return line.pinyin


# -- words -----------------------------------------------------------------------------


def segment(run: str, allowed: Mapping[str, Any], known: Mapping[str, Any]) -> list[tuple[str, str]]:
    """Cut a hanzi run into words, preferring taught ones: (surface, `allowed` | `later` | `unknown`)."""
    size = len(run)
    total = [_COST_UNREACHED] * (size + 1)
    total[0] = 0
    back = [(0, "")] * (size + 1)
    for start in range(size):
        if total[start] == _COST_UNREACHED:
            continue
        for length in range(min(_MAX_WORD, size - start), 0, -1):
            piece = run[start:start + length]
            if piece in allowed:
                cost, status = _COST_ALLOWED, "allowed"
            elif piece in known:
                cost, status = _COST_LATER, "later"
            elif length == 1:
                cost, status = _COST_UNKNOWN, "unknown"
            else:
                continue
            if total[start] + cost < total[start + length]:
                total[start + length] = total[start] + cost
                back[start + length] = (start, status)
    tokens: list[tuple[str, str]] = []
    end = size
    while end > 0:
        start, status = back[end]
        tokens.append((run[start:end], status))
        end = start
    return tokens[::-1]


def extra_id(hanzi: str) -> str:
    """A stable vocabulary ID for a word outside the catalogue: `vocab-x-4f46` for 但."""
    return "vocab-x-" + "-".join(f"{ord(char):x}" for char in hanzi)


def extra_entry(extra: dict[str, Any]) -> dict[str, Any]:
    """The lesson vocabulary row of a glossed extra word."""
    hanzi, vocab_id = extra["hanzi"], extra_id(extra["hanzi"])
    return {
        "id": vocab_id,
        "hanzi": hanzi,
        "traditionalHanzi": extra["traditionalHanzi"],
        "pinyin": extra["pinyin"],
        "toneNumbers": pinyin_tones(extra["pinyin"].split()),
        "segmentation": [{"surface": hanzi, "vocabularyID": vocab_id, "pinyin": extra["pinyin"], "partOfSpeech": extra["partOfSpeech"]}],
        "partOfSpeech": extra["partOfSpeech"],
        "grammarNotes": [],
        "meaning": {"fr": extra["meaning"]["fr"]},
        "audio": None,
        "example": None,
        "memoryStory": None,
    }


# -- the checks ----------------------------------------------------------------------------


def _cap(words: int) -> int:
    return max(1, int(EXTRA_SHARE * words + 0.5))


class _Checker:
    def __init__(self, context: Context, earlier_extras: Mapping[str, Mapping[str, Any]]) -> None:
        self.context = context
        self.earlier_extras = earlier_extras
        self.problems: list[str] = []
        self.extras: dict[str, dict[str, Any]] = {}
        self.forms: dict[str, Any] = dict(context.allowed)

    def fail(self, where: str, message: str) -> None:
        self.problems.append(f"{self.context.lesson_id}.{where}: {message}")

    # translation and pinyin text
    def french(self, where: str, value: Any) -> str | None:
        text = _fr(value)
        if text is None:
            self.fail(where, "needs a French text: {\"fr\": \"...\"}")
        elif _HANZI.search(text):
            self.fail(where, "the French text contains hanzi")
        return text

    def line(self, where: str, hanzi: Any, pinyin: Any) -> Line:
        line = analyse_line(hanzi, pinyin)
        for problem in line.problems:
            self.fail(where, problem)
        return line

    # words
    def words(self, where: str, runs: list[str]) -> tuple[list[str], int, int]:
        """(tokens, word count, extra-word count) of a text; offending words are reported."""
        tokens: list[str] = []
        offenders: dict[str, str] = {}
        known = self.context.later
        for run in runs:
            for surface, status in segment(run, self.forms, known):
                if status == "allowed":
                    tokens.append(surface)
                elif status == "later":
                    word = known[surface]
                    detail = f"{word.pinyin}, {word.meaning}; " + (f"taught in {word.lesson}" if word.lesson else "outside the course vocabulary")
                    offenders[surface] = f"{surface} ({detail})"
                else:
                    offenders[surface] = f"{surface} (unknown word)"
        if offenders:
            self.fail(where, "words the learner has not been taught: " + ", ".join(offenders.values()))
        extra_count = sum(1 for token in tokens if token in self.extras)
        return tokens, len(tokens), extra_count

    def check_extras(self, value: Any) -> None:
        if value is None:
            return
        if not isinstance(value, list):
            self.fail("extraVocabulary", "expected an array")
            return
        for index, extra in enumerate(value):
            where = f"extraVocabulary[{index}]"
            if not isinstance(extra, dict) or set(extra) != {"hanzi", "traditionalHanzi", "pinyin", "meaning", "partOfSpeech"}:
                self.fail(where, "expected {hanzi, traditionalHanzi, pinyin, meaning: {fr}, partOfSpeech}")
                continue
            hanzi, pinyin = extra.get("hanzi"), extra.get("pinyin")
            if not isinstance(hanzi, str) or not hanzi or not all(_HANZI.match(char) for char in hanzi):
                self.fail(where, "hanzi must be one word written with hanzi only")
                continue
            if hanzi in self.extras:
                self.fail(where, f"{hanzi} is listed twice")
            if self.french(where + ".meaning", extra.get("meaning")) is None:
                continue
            if extra["partOfSpeech"] not in PARTS_OF_SPEECH:
                self.fail(where, f"partOfSpeech must be one of {', '.join(PARTS_OF_SPEECH)}")
            traditional = extra["traditionalHanzi"]
            if not isinstance(traditional, str) or len(traditional) != len(hanzi) or not all(_HANZI.match(char) for char in traditional):
                self.fail(where, "traditionalHanzi must write the word in traditional characters, one per hanzi (the same character when it does not change)")
            parsed = analyse_line(hanzi, pinyin)
            if parsed.problems:
                for problem in parsed.problems:
                    self.fail(where, problem)
                continue
            if parsed.pinyin != " ".join(pinyin.split()):
                self.fail(where, f"write the pinyin one syllable at a time: '{parsed.pinyin}'")
            if hanzi in self.context.allowed:
                self.fail(where, f"{hanzi} is already taught: it is not an extra")
            later = self.context.later.get(hanzi)
            if later is not None and later.canonical and later.lesson:
                self.fail(where, f"{hanzi} is a course word taught in {later.lesson}: use only what has been taught, not an extra")
            previous = self.earlier_extras.get(hanzi)
            if previous is not None and (previous.get("pinyin") != pinyin or _fr(previous.get("meaning")) != _fr(extra.get("meaning"))):
                self.fail(where, f"{hanzi} is glossed differently in an earlier lesson ({previous.get('pinyin')}, {_fr(previous.get('meaning'))}): use the same gloss")
            self.extras[hanzi] = extra
            self.forms[hanzi] = extra
        fresh = [hanzi for hanzi in self.extras if hanzi not in self.earlier_extras]
        limit = MAX_NEW_WORDS - len(self.context.new)
        if len(fresh) > limit:
            self.fail(
                "extraVocabulary",
                f"{len(self.context.new)} new course words plus {len(fresh)} new extras exceed {MAX_NEW_WORDS} new words per lesson "
                f"(at most {max(limit, 0)} new extra{'s' if limit > 1 else ''} here)",
            )

    def check_dialogue(self, value: Any) -> tuple[list[str], list[Line]]:
        if not isinstance(value, list):
            self.fail("dialogue", "expected an array of lines")
            return [], []
        low, high = DIALOGUE_LINES
        if not low <= len(value) <= high:
            self.fail("dialogue", f"{len(value)} lines, expected {low}–{high}")
        speakers: list[str] = []
        lines: list[Line] = []
        runs: list[str] = []
        previous = ""
        named = 0
        for index, item in enumerate(value, start=1):
            where = f"dialogue[{index}]"
            if not isinstance(item, dict) or set(item) != {"speaker", "hanzi", "pinyin", "translation"}:
                self.fail(where, "expected {speaker, hanzi, pinyin, translation: {fr}}")
                continue
            speaker = _text(item["speaker"])
            if speaker is None:
                self.fail(where, "speaker is empty")
            else:
                speakers.append(speaker)
            self.french(where + ".translation", item["translation"])
            line = self.line(where, item["hanzi"], item["pinyin"])
            lines.append(line)
            runs.extend(line.runs)
            if line.names:
                named += 1
            if line.chars > MAX_LINE_CHARS:
                self.fail(where, f"{line.chars} hanzi, at most {MAX_LINE_CHARS}: split the line")
            hanzi = item["hanzi"] if isinstance(item["hanzi"], str) else ""
            if hanzi and hanzi == previous and hanzi.rstrip("，。！？、；：") not in GREETINGS:
                self.fail(where, "repeats the previous line")
            previous = hanzi
        if len(set(speakers)) < 2:
            self.fail("dialogue", "needs at least two speakers")
        if len(set(speakers)) > MAX_SPEAKERS:
            self.fail("dialogue", f"{len(set(speakers))} speakers, at most {MAX_SPEAKERS}")
        if named > MAX_DIALOGUE_NAME_LINES:
            self.fail("dialogue", f"{named} lines contain a Latin name, at most {MAX_DIALOGUE_NAME_LINES} (such lines cannot feed the generated exercises)")
        return runs, lines

    def check_reading(self, value: Any) -> tuple[list[str], int]:
        if not isinstance(value, dict) or set(value) != {"title", "paragraphs"}:
            self.fail("reading", "expected {title: {fr}, paragraphs: [...]}")
            return [], 0
        self.french("reading.title", value["title"])
        paragraphs = value["paragraphs"]
        if not isinstance(paragraphs, list):
            self.fail("reading.paragraphs", "expected an array")
            return [], 0
        low, high = READING_PARAGRAPHS
        if not low <= len(paragraphs) <= high:
            self.fail("reading.paragraphs", f"{len(paragraphs)} paragraphs, expected {low}–{high}")
        runs: list[str] = []
        sentences = 0
        named = 0
        for index, item in enumerate(paragraphs, start=1):
            where = f"reading.paragraphs[{index}]"
            if not isinstance(item, dict) or set(item) != {"hanzi", "pinyin", "translation"}:
                self.fail(where, "expected {hanzi, pinyin, translation: {fr}}")
                continue
            french = self.french(where + ".translation", item["translation"])
            line = self.line(where, item["hanzi"], item["pinyin"])
            runs.extend(line.runs)
            if line.problems:
                continue
            hanzi = item["hanzi"]
            if hanzi[-1] not in "。！？":
                self.fail(where, "must end with 。 ！ or ？")
            parts = split_sentences(hanzi)
            sentences += len(parts)
            french_parts = split_french(french or "")
            if not len(parts) == len(split_sentences(line.pinyin)) == len(french_parts):
                self.fail(
                    where,
                    f"{len(parts)} hanzi sentences, {len(split_sentences(line.pinyin))} pinyin sentences and {len(french_parts)} French sentences: "
                    "each sentence needs its own pinyin and French sentence (French ends with . ? ! and has no other full stop followed by a space)",
                )
            if line.names:
                named += len(parts)
        low, high = READING_SENTENCES
        if not low <= sentences <= high:
            self.fail("reading", f"{sentences} sentences, expected {low}–{high}")
        if named > MAX_READING_NAME_SENTENCES:
            self.fail("reading", f"a Latin name in {named} sentences, at most {MAX_READING_NAME_SENTENCES}")
        return runs, sentences

    def check_question(self, value: Any) -> None:
        if not isinstance(value, dict) or set(value) != {"prompt", "choices", "correctChoiceID"}:
            self.fail("readingQuestion", "expected {prompt: {fr}, choices: [{id, label: {fr}}] x3, correctChoiceID}")
            return
        self.french("readingQuestion.prompt", value["prompt"])
        choices = value["choices"]
        if not isinstance(choices, list) or len(choices) != len(READING_CHOICES):
            self.fail("readingQuestion.choices", f"expected exactly {len(READING_CHOICES)} choices")
            return
        labels: list[str] = []
        for index, choice in enumerate(choices):
            where = f"readingQuestion.choices[{index}]"
            if not isinstance(choice, dict) or set(choice) != {"id", "label"} or choice["id"] != READING_CHOICES[index]:
                self.fail(where, f"expected {{id: '{READING_CHOICES[index]}', label: {{fr}}}}")
                continue
            label = self.french(where + ".label", choice["label"])
            if label is not None:
                labels.append(label)
        if len(set(labels)) != len(labels):
            self.fail("readingQuestion.choices", "two choices have the same label")
        if value["correctChoiceID"] not in READING_CHOICES:
            self.fail("readingQuestion.correctChoiceID", f"must be one of {', '.join(READING_CHOICES)}")

    def check_sentence(self, key: str, value: Any, lines: list[dict[str, Any]]) -> None:
        if not isinstance(value, dict) or set(value) != {"hanzi", "pinyin", "translation"}:
            self.fail(key, "expected {hanzi, pinyin, translation: {fr}}")
            return
        self.french(key + ".translation", value["translation"])
        line = self.line(key, value["hanzi"], value["pinyin"])
        if line.problems:
            return
        if line.names:
            self.fail(key, "cannot contain a Latin name: the sentence is read aloud in Mandarin")
        if line.chars < MIN_LISTEN_CHARS:
            self.fail(key, f"{line.chars} hanzi, at least {MIN_LISTEN_CHARS}")
        for source in lines:
            source_line = analyse_line(source.get("hanzi"), source.get("pinyin"))
            if source_line.problems:
                continue
            whole = (source["hanzi"], source_line.pinyin)
            hanzi_parts, pinyin_parts = split_sentences(source["hanzi"]), split_sentences(source_line.pinyin)
            pieces = [whole] + (list(zip(hanzi_parts, pinyin_parts)) if len(hanzi_parts) == len(pinyin_parts) else [])
            if (value["hanzi"], line.pinyin) in [(hanzi.strip(), pinyin.strip()) for hanzi, pinyin in pieces]:
                return
        self.fail(key, "must be a line of the dialogue, or one sentence of a line, copied with its pinyin")

    def check_coverage(self, dialogue: list[str], reading: list[str]) -> None:
        used = set(dialogue) | set(reading)
        missing = [word.hanzi for word in self.context.new if word.hanzi not in used]
        if missing:
            self.fail("dialogue", "new words missing from the dialogue and the reading: " + ", ".join(missing))
        in_reading = [word.hanzi for word in self.context.new if word.hanzi in set(reading)]
        wanted = min(MIN_READING_NEW_WORDS, len(self.context.new))
        if len(in_reading) < wanted:
            self.fail("reading", f"{len(in_reading)} new words in the reading, at least {wanted} (new words: {', '.join(word.hanzi for word in self.context.new)})")
        unused = [hanzi for hanzi in self.extras if hanzi not in used]
        if unused:
            self.fail("extraVocabulary", "listed but used in no text: " + ", ".join(unused))


def check_situation(
    situation: Any,
    context: Context,
    earlier_extras: Mapping[str, Mapping[str, Any]] | None = None,
) -> list[str]:
    """Every way `situation` breaks the rules for `context`'s lesson; empty when it is sound."""
    checker = _Checker(context, earlier_extras or {})
    if not isinstance(situation, dict):
        return [f"{context.lesson_id}: expected an object"]
    missing = sorted(_REQUIRED_KEYS - set(situation))
    unknown = sorted(set(situation) - _KEYS)
    if missing:
        checker.fail("keys", "missing " + ", ".join(missing))
    if unknown:
        checker.fail("keys", "unknown " + ", ".join(unknown))
    if missing:
        return checker.problems
    title = checker.french("title", situation["title"])
    if title is not None and len(title) > MAX_TITLE_CHARS:
        checker.fail("title", f"{len(title)} characters, at most {MAX_TITLE_CHARS}")
    checker.french("situation", situation["situation"])
    checker.check_extras(situation.get("extraVocabulary"))
    dialogue_runs, _ = checker.check_dialogue(situation["dialogue"])
    reading_runs, _ = checker.check_reading(situation["reading"])
    dialogue_tokens, dialogue_words, dialogue_extras = checker.words("dialogue", dialogue_runs)
    reading_tokens, reading_words, reading_extras = checker.words("reading", reading_runs)
    for where, words, extras in (("dialogue", dialogue_words, dialogue_extras), ("reading", reading_words, reading_extras)):
        if extras > _cap(words):
            checker.fail(where, f"{extras} extra words out of {words}, at most {_cap(words)} ({int(EXTRA_SHARE * 100)} %, at least one allowed)")
    checker.check_question(situation["readingQuestion"])
    dialogue = situation["dialogue"] if isinstance(situation["dialogue"], list) else []
    lines = [item for item in dialogue if isinstance(item, dict)]
    checker.check_sentence("listenSentence", situation["listenSentence"], lines)
    checker.check_sentence("speakSentence", situation["speakSentence"], lines)
    listen, speak = situation["listenSentence"], situation["speakSentence"]
    if isinstance(listen, dict) and isinstance(speak, dict) and listen.get("hanzi") == speak.get("hanzi"):
        checker.fail("speakSentence", "must differ from listenSentence")
    checker.check_coverage(dialogue_tokens, reading_tokens)
    return checker.problems


def lint_set(
    situations: SituationSet,
    lessons: Mapping[str, dict[str, Any]],
    catalog: list[dict[str, Any]],
    *,
    only: str | None = None,
) -> list[str]:
    """Check every situation (or those of file `only`); a whole-set check also requires every daily lesson to have one."""
    problems: list[str] = []
    by_number = sorted(situations.entries, key=lesson_number)
    for lesson_id in by_number:
        if only is not None and situations.files[lesson_id] != only:
            continue
        try:
            context = build_context(lessons, catalog, lesson_id)
            expected = context.unit_file
        except SituationError as exc:
            problems.append(str(exc))
            continue
        if situations.files[lesson_id] != expected:
            problems.append(f"{lesson_id}: belongs to {expected}, not {situations.files[lesson_id]}")
        earlier = {
            extra["hanzi"]: extra
            for other in by_number if lesson_number(other) < lesson_number(lesson_id)
            for extra in _extras_of(situations.entries[other])
        }
        problems.extend(check_situation(situations.entries[lesson_id], context, earlier))
    if only is None:
        missing = missing_situations(lessons, situations)
        if missing:
            problems.append(f"situations missing for {len(missing)} daily lessons: {', '.join(missing[:6])}{'…' if len(missing) > 6 else ''}")
    return problems


def missing_situations(lesson_ids: Iterable[str], situations: SituationSet) -> list[str]:
    """The daily lessons among `lesson_ids` that no situation file writes."""
    daily = {
        lesson_id for lesson_id in lesson_ids
        if _LESSON_ID.fullmatch(lesson_id) and FIRST_DAILY_LESSON <= lesson_number(lesson_id) <= LAST_DAILY_LESSON
    }
    return sorted(daily - set(situations.entries), key=lesson_number)


def _extras_of(situation: Any) -> list[dict[str, Any]]:
    extras = situation.get("extraVocabulary") if isinstance(situation, dict) else None
    return [extra for extra in extras if isinstance(extra, dict) and isinstance(extra.get("hanzi"), str)] if isinstance(extras, list) else []


# -- overlay ---------------------------------------------------------------------------------


def _exercise(blueprint: dict[str, Any], exercise_id: str) -> dict[str, Any]:
    for exercise in blueprint["exercises"]:
        if exercise["id"] == exercise_id:
            return exercise
    raise SituationError(f"{blueprint['id']}: the pack has no exercise '{exercise_id}' to replace")


def _label(text: str) -> dict[str, Any]:
    return {"fr": text}


def _choice(choice_id: str, text: str) -> dict[str, Any]:
    return {"id": choice_id, "label": _label(text), "audio": None}


def _listen_distractors(situation: dict[str, Any]) -> list[str]:
    """The other dialogue lines' translations that resemble the answer most in length."""
    answer = situation["listenSentence"]["translation"]["fr"]
    heard = situation["listenSentence"]["hanzi"]
    candidates = [
        line["translation"]["fr"] for line in situation["dialogue"]
        if line["translation"]["fr"] != answer and heard not in line["hanzi"] and heard != line["hanzi"]
    ]
    unique = list(dict.fromkeys(candidates))
    ranked = sorted(range(len(unique)), key=lambda index: (abs(len(unique[index]) - len(answer)), index))
    return [unique[index] for index in ranked[:LISTEN_CHOICES - 1]]


def apply_situation(blueprint: dict[str, Any], situation: dict[str, Any]) -> dict[str, Any]:
    """The lesson blueprint with the scene's texts and closing exercises in place of the assembled ones."""
    lesson = copy.deepcopy(blueprint)
    lesson_id = lesson["id"]
    number = lesson_number(lesson_id)
    lesson["title"] = _label(situation["title"]["fr"])
    lesson["summary"] = _label(situation["situation"]["fr"])
    lesson["dialogue"]["lines"] = [
        {
            "speaker": item["speaker"], "hanzi": item["hanzi"], "pinyin": normalize_pinyin(item["hanzi"], item["pinyin"]),
            "translation": _label(item["translation"]["fr"]), "audio": None,
        }
        for item in situation["dialogue"]
    ]
    lesson["reading"]["title"] = _label(situation["reading"]["title"]["fr"])
    lesson["reading"]["paragraphs"] = [
        {
            "id": f"p{index}", "hanzi": item["hanzi"], "pinyin": normalize_pinyin(item["hanzi"], item["pinyin"]),
            "translation": _label(item["translation"]["fr"]), "segmentation": [], "audio": None,
        }
        for index, item in enumerate(situation["reading"]["paragraphs"], start=1)
    ]
    lesson["extraVocabulary"] = [extra_entry(extra) for extra in situation.get("extraVocabulary", [])]
    metadata = lesson.setdefault("metadata", {})
    metadata["situationAuthored"] = True

    listen = situation["listenSentence"]
    listen_exercise = _exercise(lesson, f"ex-l{number}-listen")
    wrong = _listen_distractors(situation)
    if len(wrong) < LISTEN_CHOICES - 1:
        raise SituationError(f"{lesson_id}: the dialogue offers too few different translations for the listening exercise")
    # The answer comes first, like every pack exercise: `normalize_lesson` then rotates the choices by
    # lesson, so the correct position varies without a second shuffle that would cancel that rotation.
    texts = [listen["translation"]["fr"], *wrong]
    listen_exercise.update({
        "prompt": _label(LISTEN_PROMPT), "instruction": _label(LISTEN_INSTRUCTION), "promptText": listen["hanzi"],
        "choices": [_choice(READING_CHOICES[index], text) for index, text in enumerate(texts)],
        "correctChoiceID": READING_CHOICES[0],
    })

    speak = situation["speakSentence"]
    speak_exercise = _exercise(lesson, f"ex-l{number}-speak")
    said = speak["translation"]["fr"].rstrip(". ")
    speak_exercise.update({
        "prompt": _label(f"Dis « {said} »."), "instruction": _label(SPEAK_INSTRUCTION), "referenceText": speak["hanzi"],
        "referencePinyin": normalize_pinyin(speak["hanzi"], speak["pinyin"]), "referenceAudio": None,
        "acceptedTranscripts": [speak["hanzi"]], "allowSelfRating": True,
    })

    question = situation["readingQuestion"]
    reading_ids = lesson["reading"].get("comprehensionExerciseIDs", [])
    if len(reading_ids) != 1:
        raise SituationError(f"{lesson_id}: the pack's reading must name one comprehension exercise")
    answer_first = sorted(question["choices"], key=lambda choice: choice["id"] != question["correctChoiceID"])
    _exercise(lesson, reading_ids[0]).update({
        "prompt": _label(question["prompt"]["fr"]), "instruction": _label(READING_INSTRUCTION),
        "choices": [_choice(choice["id"], choice["label"]["fr"]) for choice in answer_first],
        "correctChoiceID": question["correctChoiceID"],
    })
    return lesson


def lesson_drift(situation: dict[str, Any], lesson: dict[str, Any]) -> list[str]:
    """Where a generated lesson differs from its situation file (the file was edited after generation)."""
    problems: list[str] = []
    dialogue = next((block for block in lesson["blocks"] if block.get("kind") == "dialogue"), {})
    reading = next((block for block in lesson["blocks"] if block.get("kind") == "reading"), {})
    expected_lines = [
        (item["speaker"], item["hanzi"], normalize_pinyin(item["hanzi"], item["pinyin"]), item["translation"]["fr"])
        for item in situation["dialogue"]
    ]
    lines = [(line["speaker"], line["hanzi"], line["pinyin"], line["translation"]["fr"]) for line in dialogue.get("lines", [])]
    if lines != expected_lines:
        problems.append("the dialogue differs from its situation file")
    expected_paragraphs = [
        (item["hanzi"], normalize_pinyin(item["hanzi"], item["pinyin"]), item["translation"]["fr"]) for item in situation["reading"]["paragraphs"]
    ]
    paragraphs = [(item["hanzi"], item["pinyin"], item["translation"]["fr"]) for item in reading.get("paragraphs", [])]
    if paragraphs != expected_paragraphs or reading.get("title", {}).get("fr") != situation["reading"]["title"]["fr"]:
        problems.append("the reading differs from its situation file")
    if lesson["title"]["fr"] != situation["title"]["fr"] or lesson["summary"]["fr"] != situation["situation"]["fr"]:
        problems.append("the title or summary differs from its situation file")
    return [f"{lesson['id']}: {problem}; run `content_tool.py generate` again" for problem in problems]


def bundle_problems(
    situations: SituationSet,
    lessons: Mapping[str, dict[str, Any]],
    catalog: list[dict[str, Any]],
) -> list[str]:
    """What a generated bundle owes its situation files: a scene per daily lesson, sound scenes, flagged lessons, texts that match."""
    problems = lint_set(situations, lessons, catalog)
    for lesson_id, lesson in lessons.items():
        flagged = lesson.get("metadata", {}).get("situationAuthored") is True
        if flagged and lesson_id not in situations.entries:
            problems.append(f"{lesson_id}: flagged situationAuthored but no situation file writes it")
        elif lesson_id in situations.entries and not flagged:
            problems.append(f"{lesson_id}: has a situation file but the generated lesson is not flagged; run `content_tool.py generate` again")
    if not problems:
        for lesson_id in sorted(situations.entries, key=lesson_number):
            problems.extend(lesson_drift(situations.entries[lesson_id], lessons[lesson_id]))
    return problems


# -- writer tooling -----------------------------------------------------------------------------


def skeleton(context: Context) -> dict[str, Any]:
    speakers = ["Mina", "Tao"]
    sentence = {"hanzi": "", "pinyin": "", "translation": {"fr": ""}}
    return {
        context.lesson_id: {
            "situation": {"fr": ""},
            "title": {"fr": ""},
            "dialogue": [
                {"speaker": speakers[index % 2], "hanzi": "", "pinyin": "", "translation": {"fr": ""}}
                for index in range(DIALOGUE_LINES[0])
            ],
            "reading": {"title": {"fr": ""}, "paragraphs": [copy.deepcopy(sentence), copy.deepcopy(sentence)]},
            "readingQuestion": {
                "prompt": {"fr": ""},
                "choices": [{"id": choice, "label": {"fr": ""}} for choice in READING_CHOICES],
                "correctChoiceID": "a",
            },
            "listenSentence": copy.deepcopy(sentence),
            "speakSentence": copy.deepcopy(sentence),
            "extraVocabulary": [],
        }
    }


def _dump(value: Any, depth: int) -> str:
    """JSON with short objects on one line, so that a skeleton reads as a form."""
    inline = json.dumps(value, ensure_ascii=False)
    if len(inline) <= 100 or not isinstance(value, (dict, list)):
        return inline
    pad, inner = "  " * depth, "  " * (depth + 1)
    if isinstance(value, dict):
        rows = [f"{inner}{json.dumps(key, ensure_ascii=False)}: {_dump(item, depth + 1)}" for key, item in value.items()]
        return "{\n" + ",\n".join(rows) + f"\n{pad}}}"
    return "[\n" + ",\n".join(inner + _dump(item, depth + 1) for item in value) + f"\n{pad}]"


def _table(words: list[Word]) -> str:
    rows: dict[str, list[str]] = {}
    for word in words:
        rows.setdefault(word.lesson, []).append(f"{word.hanzi} {word.pinyin} {word.meaning}")
    return "\n".join(f"  {lesson}: " + " | ".join(row) for lesson, row in rows.items())


def brief(context: Context, situations: SituationSet, lessons: Mapping[str, dict[str, Any]]) -> str:
    number = lesson_number(context.lesson_id)
    words = context.taught_order
    written = [
        f"  {lesson_id}: {situations.entries[lesson_id]['title']['fr']} — {situations.entries[lesson_id]['situation']['fr']}"
        for lesson_id in sorted(situations.entries, key=lesson_number)
        if lesson_number(lesson_id) < number and isinstance(situations.entries[lesson_id], dict)
        and _fr(situations.entries[lesson_id].get("title")) and _fr(situations.entries[lesson_id].get("situation"))
    ][-5:]
    previous = [
        f"  {lesson_id}: {lesson['title']['fr']} — {lesson['summary']['fr']}"
        for lesson_id, lesson in sorted(lessons.items(), key=lambda item: item[1]["order"])
        if _LESSON_ID.fullmatch(lesson_id) and FIRST_DAILY_LESSON <= lesson_number(lesson_id) < number and lesson_id not in situations.entries
    ][-3:]
    cap = MAX_NEW_WORDS - len(context.new)
    speakers = ", ".join(f"{name} ({count} lignes)" for name, count in context.speakers.most_common()) or "aucun"
    lines = [
        f"# {context.lesson_id} — {context.title}",
        f"Unité : {context.module_id} (fichier Content/authoring/situations/{context.unit_file}) · thème : {context.theme or 'n/a'}",
        f"Résumé actuel : {context.summary}",
        "",
        "## Mots nouveaux (tous à employer dans le dialogue et la lecture ; au moins "
        f"{min(MIN_READING_NEW_WORDS, len(context.new))} dans la lecture)",
        *[f"  {word.hanzi} {word.pinyin} — {word.meaning}" for word in context.new],
        "",
        "## Mots repris (déjà vus, à réemployer)",
        *([f"  {word.hanzi} {word.pinyin} — {word.meaning}" for word in context.reused] or ["  aucun"]),
        "",
        "## Ancre de grammaire",
        *([f"  {title}\n" + "\n".join(f"    {row}" for row in body.splitlines()) for title, body in context.grammar] or ["  aucune note pour cette leçon"]),
        "",
        "## Personnages",
        f"  Récurrents : {', '.join(CHARACTERS)} (Mina et Tao mènent la plupart des dialogues). Jusqu'ici : {speakers}.",
        "  Séances précédentes déjà écrites :",
        *(written or ["  (aucune)"]),
        "  Séances précédentes encore au texte assemblé (titre — résumé) :",
        *(previous or ["  (aucune)"]),
        "",
        "## Règles",
        f"  Dialogue {DIALOGUE_LINES[0]}–{DIALOGUE_LINES[1]} répliques, {MAX_LINE_CHARS} hanzi au plus par réplique ; lecture {READING_SENTENCES[0]}–{READING_SENTENCES[1]} phrases en 1–{READING_PARAGRAPHS[1]} paragraphes.",
        f"  Mots autorisés : ceux du tableau ci-dessous (+ prénoms {', '.join(CHARACTERS)}, + extras glosses). "
        f"Mots nouveaux au total (canoniques + extras) : {MAX_NEW_WORDS} au plus, donc {max(cap, 0)} extra(s) nouveau(x) possible(s) ici ; "
        f"un extra ne pèse pas plus de {int(EXTRA_SHARE * 100)} % des mots d'un texte (1 au minimum).",
        "  Hanzi : ponctuation pleine largeur (， 。 ？ ！). Pinyin : une syllabe par hanzi, séparées par des espaces, ponctuation ASCII (, . ? !).",
        "",
        f"## Vocabulaire autorisé ({len(words)} mots, dans l'ordre où ils ont été vus ; l'aperçu du module 0 est en tête)",
        _table(words),
        "",
        "## Squelette JSON",
        _dump(skeleton(context), 0),
        "",
        f"Contrôle : python3 Tools/content_tool.py situations-lint --file Content/authoring/situations/{context.unit_file}",
    ]
    return "\n".join(lines)


# -- optional pinyin cross-check ---------------------------------------------------------------------


_SANDHI = {"不": {"bù", "bú"}, "一": {"yī", "yí", "yì"}}
_TONE_MARKS = str.maketrans("āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ", "aaaaeeeeiiiioooouuuuüüüü")


def _base(syllable: str) -> str:
    return syllable.translate(_TONE_MARKS)


def pinyin_crosscheck(situation: dict[str, Any]) -> tuple[list[str], str | None]:
    """Compare each syllable with pypinyin's readings of the hanzi (writers and reviewers; optional).

    Returns the disagreements and a note when pypinyin is not installed. A syllable passes when it is one
    of the character's readings, a neutral-tone form of one, or a known sandhi form of 不 and 一.
    """
    try:
        from pypinyin import Style, pinyin as read  # type: ignore[import-not-found]
    except ImportError:
        return [], "pypinyin is not installed: pinyin cross-check skipped (python3 -m venv /tmp/py && /tmp/py/bin/pip install pypinyin)"
    texts: list[tuple[str, str, str]] = []
    for index, item in enumerate(situation.get("dialogue", []), start=1):
        texts.append((f"dialogue[{index}]", item["hanzi"], item["pinyin"]))
    for index, item in enumerate(situation.get("reading", {}).get("paragraphs", []), start=1):
        texts.append((f"reading.paragraphs[{index}]", item["hanzi"], item["pinyin"]))
    for key in ("listenSentence", "speakSentence"):
        if key in situation:
            texts.append((key, situation[key]["hanzi"], situation[key]["pinyin"]))
    problems: list[str] = []
    for where, hanzi, spelled in texts:
        line = analyse_line(hanzi, spelled)
        if line.problems:
            continue
        given = [token.strip(PINYIN_PUNCTUATION) for token in line.pinyin.split()]
        given = [token for token in given if token not in CHARACTERS]
        chars = [char for char in hanzi if _HANZI.match(char)]
        if len(given) != len(chars):
            continue  # erhua: the syllable count differs from the hanzi count
        for position, (char, syllable) in enumerate(zip(chars, given)):
            readings = {reading for candidates in read(char, style=Style.TONE, heteronym=True) for reading in candidates}
            plain = {_base(reading) for reading in readings}
            if syllable in readings or syllable in _SANDHI.get(char, set()):
                continue
            if _base(syllable) == syllable and syllable in plain:
                continue  # neutral tone
            problems.append(f"{where}: {char} written '{syllable}', pypinyin reads {'/'.join(sorted(readings))} (syllable {position + 1})")
    return problems, None
