"""Module 0: pinyin and tones, taught by ear.

The module's lessons are hand-written in `Content/authoring/pinyin-module.json`
and expanded here into the same lesson documents as every other lesson. They
are their own kind of lesson (`metadata.lessonKind == "pinyin"`): not daily
lessons, so no "new word" rule, but listening sessions of 15–20 exercises that
are checked by `check_lesson`.

Every Mandarin text an exercise plays is a *carrier*: a real hanzi or word with
its pinyin, listed once in the file's `carriers` table. Exercises name carriers,
never spell pinyin of their own, so the builder can derive each answer (the tone
pattern of a word, the pinyin of a character) from the table. The lesson keeps
the carriers it uses in `metadata.carriers`, which is all the linter needs to
re-derive every answer without the authoring file.

Minimal pairs are flagged by the author (`contrast`: `initial`, `final` or
`tone`) and verified: each distractor must differ from the answer in that
feature alone. Every distractor syllable must be attested by a carrier, so no
choice offers a syllable that does not exist.
"""
from __future__ import annotations

import copy
import re
import unicodedata
from functools import lru_cache
from typing import Any, Callable

from exercise_expansion import EXERCISE_BUDGET, PHASES
from exercise_kinds import MATCHING_PAIRS, POLYPHONES, pinyin_tones, tone_choice_id, tone_label
from review_lessons import renumber

PINYIN = "pinyin"
SESSION_MINUTES = (12, 3)
LESSON_COUNT = (6, 8)
MAX_WORDS = 8
MIN_KINDS = 4
MIN_LISTENING_SHARE = 0.6
MIN_CONTRASTS = 4
CONTRASTS = ("initial", "final", "tone")
LISTENING_KINDS = ("toneDiscrimination", "dictation", "listeningChoice")
_LETTERS = "abcdefgh"
_TONE_MARKS = {"\u0304", "\u0301", "\u030c", "\u0300"}
_PUNCTUATION = "，。！？、；：,.!?;: "
_INITIALS = ("zh", "ch", "sh", "b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h", "j", "q", "x", "z", "c", "s", "r", "y", "w")
_FINALS = frozenset(
    "a o e ai ei ao ou an en ang eng ong er i ia ie iao iu ian in iang ing iong u ua uo uai ui uan un uang ue ü üe üan ün".split()
)
_TONE_VOWELS = frozenset("āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ")
_HEAR_LABEL = re.compile(r"^(\S+) \((.+)\)$")


class PinyinError(ValueError):
    """Module 0 authoring data or a module 0 lesson breaks its contract."""


def is_pinyin(lesson: dict[str, Any]) -> bool:
    metadata = lesson.get("metadata")
    return isinstance(metadata, dict) and metadata.get("lessonKind") == PINYIN


# -- pinyin ------------------------------------------------------------------


def _plain(char: str) -> str:
    """The letter under a tone mark (`ǚ` gives `ü`)."""
    decomposed = "".join(part for part in unicodedata.normalize("NFD", char) if part not in _TONE_MARKS)
    return unicodedata.normalize("NFC", decomposed)


@lru_cache(maxsize=None)
def _parse(plain: str, start: int) -> tuple[int, ...] | None:
    """Lengths of the syllables that spell `plain[start:]`, or None when it is no pinyin."""
    if start == len(plain):
        return ()
    for initial in [initial for initial in _INITIALS if plain.startswith(initial, start)] + [""]:
        after = start + len(initial)
        for size in range(min(5, len(plain) - after), 0, -1):
            if plain[after:after + size] in _FINALS:
                rest = _parse(plain, after + size)
                if rest is not None:
                    return (len(initial) + size,) + rest
    return None


def syllables(pinyin: str) -> list[str]:
    """The syllables of a pinyin text: apart, or grouped into words (`Hànyǔ`), with or without apostrophes."""
    result: list[str] = []
    for chunk in re.split(r"[ ']+", pinyin.strip()):
        if not chunk:
            continue
        lengths = _parse("".join(_plain(char) for char in chunk.lower()), 0)
        if lengths is None:
            raise PinyinError(f"'{chunk}' is not valid pinyin")
        position = 0
        for length in lengths:
            result.append(chunk[position:position + length])
            position += length
    if not result:
        raise PinyinError("empty pinyin")
    return result


def split_syllable(syllable: str) -> tuple[str, str, int]:
    """(initial, final, tone) of one syllable; the final and initial are spelled without tone marks."""
    plain = "".join(_plain(char) for char in syllable.lower())
    for initial in [initial for initial in _INITIALS if plain.startswith(initial)] + [""]:
        if plain[len(initial):] in _FINALS:
            return initial, plain[len(initial):], pinyin_tones([syllable])[0]
    raise PinyinError(f"'{syllable}' is not one pinyin syllable")


def _mark_is_placed_right(syllable: str) -> bool:
    """The tone mark sits on a, else on e or o, else on the last letter of iu and ui."""
    marked = [char for char in syllable.lower() if char in _TONE_VOWELS]
    if len(marked) > 1:
        return False
    if not marked:
        return True
    _, final, _ = split_syllable(syllable)
    if "a" in final:
        target = "a"
    elif "e" in final:
        target = "e"
    elif "o" in final:
        target = "o"
    elif final in ("iu", "ui"):
        target = final[-1]
    else:
        target = final[-1] if len(final) == 1 else final[0]
    return _plain(marked[0]) == target


def check_pinyin(pinyin: Any, where: str) -> list[str]:
    """The syllables of a pinyin text that is NFC, well spelled and correctly marked."""
    if not isinstance(pinyin, str) or not pinyin.strip() or not unicodedata.is_normalized("NFC", pinyin):
        raise PinyinError(f"{where}: pinyin '{pinyin}' must be non-empty NFC text")
    parts = syllables(pinyin)
    for part in parts:
        if not _mark_is_placed_right(part):
            raise PinyinError(f"{where}: the tone mark of '{part}' is misplaced")
    return parts


def spoken_tones(tones: list[int]) -> list[int]:
    """What is said, when it differs from what is written: 3-3 is spoken 2-3."""
    if any(left == right == 3 for left, right in zip(tones, tones[1:])) and tones != [3, 3]:
        raise PinyinError(f"tones {tones} chain several third tones, whose sandhi depends on the phrasing")
    return [2, 3] if tones == [3, 3] else tones


def _hanzi_runs(text: str) -> list[str]:
    return [run for run in re.split(f"[{re.escape(_PUNCTUATION)}]+", text) if run]


def split_carriers(text: str, known: Any, where: str) -> list[str]:
    """The longest carriers, left to right, that spell `text` (punctuation apart)."""
    pieces: list[str] = []
    for run in _hanzi_runs(text):
        start = 0
        while start < len(run):
            end = next((end for end in range(len(run), start, -1) if run[start:end] in known), None)
            if end is None:
                raise PinyinError(f"{where}: '{run[start:]}' is not made of carriers")
            pieces.append(run[start:end])
            start = end
    return pieces


# -- building ---------------------------------------------------------------


class _Carriers:
    """The carriers of the file, and the ones a lesson uses."""

    def __init__(self, table: dict[str, str], vocabulary: list[dict[str, Any]]) -> None:
        self.table = table
        self.vocabulary = {entry["hanzi"]: entry for entry in vocabulary}
        self.used: dict[str, str] = {}

    def pinyin(self, hanzi: str) -> str:
        found = self.table.get(hanzi)
        if found is None:
            entry = self.vocabulary.get(hanzi)
            found = entry["pinyin"] if entry else None
        if found is None:
            raise PinyinError(f"'{hanzi}' is not a carrier")
        self.used[hanzi] = found
        return found

    def spell(self, hanzi: str, where: str) -> str:
        """The carrier's pinyin, checked."""
        check_pinyin(self.pinyin(hanzi), where)
        return self.pinyin(hanzi)

    def attest(self, syllable: str) -> None:
        """Record a carrier that spells `syllable`, preferring a single character."""
        for hanzi, pinyin in sorted(self.table.items(), key=lambda item: len(item[0])):
            if syllable in syllables(pinyin):
                self.used.setdefault(hanzi, pinyin)
                return
        raise PinyinError(f"no carrier attests the syllable '{syllable}'")


def _label(text: str) -> dict[str, str]:
    return {"fr": text}


def _rotate(items: list[Any], lesson_number: int, index: int) -> list[Any]:
    """Spread the answer's position across a lesson, whatever the authored order."""
    shift = (lesson_number + index) % len(items)
    return items[shift:] + items[:shift]


def _check_unique(values: list[str], where: str) -> None:
    if len(set(values)) != len(values):
        raise PinyinError(f"{where}: duplicate values")


def _exercise(lesson_id: str, number: int, lesson_number: int, objectives: list[str], carriers: _Carriers, item: dict[str, Any], meanings: dict[str, tuple[str, str]]) -> dict[str, Any]:
    """One authored exercise as an exercise block."""
    where = f"{lesson_id} exercise {number}"
    kind = item.get("kind")
    stage = item.get("stage")
    if stage not in PHASES:
        raise PinyinError(f"{where}: stage must be one of {', '.join(PHASES)}")
    exercise_id = f"ex-{lesson_id}-{number:02d}"
    contrast = item.get("contrast")
    if contrast is not None and (contrast not in CONTRASTS or kind not in ("pinyin", "hear")):
        raise PinyinError(f"{where}: contrast {contrast!r} needs a pinyin or hear exercise and one of {', '.join(CONTRASTS)}")
    objective = item.get("objective")
    if objective is None:
        objective = objectives[0] if kind in ("tone", "pinyin", "hear") else objectives[-1]
    if objective not in objectives:
        raise PinyinError(f"{where}: unknown objective '{objective}'")
    header = {"id": exercise_id, "prompt": _label(""), "instruction": _label(""), "objectiveIDs": [objective], "required": True}

    def texts(prompt: str, instruction: str) -> None:
        header["prompt"] = _label(item.get("prompt", prompt))
        header["instruction"] = _label(item.get("instruction", instruction))

    listen = "Appuie sur l’écoute, puis choisis ce que tu as entendu."
    if kind == "tone":
        say = item["say"]
        tones = spoken_tones(pinyin_tones(syllables(carriers.spell(say, where))))
        if len(tones) not in (1, 2):
            raise PinyinError(f"{where}: tones are asked of one or two syllables")
        options = item["options"]
        _check_unique(options, where)
        answer = "".join(str(tone) for tone in tones)
        if answer not in options or any(len(option) != len(tones) or not option.isdigit() for option in options):
            raise PinyinError(f"{where}: options must all have {len(tones)} tones and offer {answer}")
        texts(
            "Écoute la syllabe, puis choisis son ton." if len(tones) == 1 else "Écoute le mot, puis choisis ses deux tons.",
            "Appuie sur l’écoute, puis choisis la mélodie que tu entends.",
        )
        spec: dict[str, Any] = {
            "kind": "toneDiscrimination", "header": header, "promptText": say,
            "choices": [
                {"id": tone_choice_id([int(digit) for digit in option]), "label": _label(tone_label([int(digit) for digit in option])), "audio": None}
                for option in sorted(options)
            ],
            "correctChoiceID": tone_choice_id(tones),
        }
    elif kind == "pinyin":
        say = item["say"]
        answer_pinyin = carriers.spell(say, where)
        choices = item["choices"]
        _check_unique(choices, where)
        if answer_pinyin not in choices:
            raise PinyinError(f"{where}: the choices must offer '{answer_pinyin}'")
        for choice in choices:
            for syllable in check_pinyin(choice, where):
                carriers.attest(syllable)
        texts("Écoute, puis choisis le pinyin.", listen)
        entries = [{"id": _LETTERS[position], "label": _label(choice), "audio": None} for position, choice in enumerate(choices)]
        spec = {
            "kind": "dictation", "header": header, "script": "pinyin", "promptText": say,
            "choices": _rotate(entries, lesson_number, number), "correctChoiceID": _LETTERS[choices.index(answer_pinyin)],
        }
    elif kind == "hear":
        say = item["say"]
        choices = item["choices"]
        _check_unique(choices, where)
        if say not in choices:
            raise PinyinError(f"{where}: the choices must offer '{say}'")
        entries = [
            {"id": _LETTERS[position], "label": _label(f"{hanzi} ({carriers.spell(hanzi, where)})"), "audio": None}
            for position, hanzi in enumerate(choices)
        ]
        texts("Écoute, puis choisis le caractère que tu entends.", listen)
        spec = {
            "kind": "listeningChoice", "header": header, "promptText": say,
            "choices": _rotate(entries, lesson_number, number), "correctChoiceID": _LETTERS[choices.index(say)],
        }
    elif kind == "match":
        hanzi_list = item["pairs"]
        _check_unique(hanzi_list, where)
        if item.get("mode", "pinyin") == "pinyin":
            pairs = [{"id": _LETTERS[position], "left": hanzi, "pinyin": None, "right": _label(carriers.spell(hanzi, where))} for position, hanzi in enumerate(hanzi_list)]
            texts("Écoute chaque caractère et associe-le à son pinyin.", "Touche un caractère (il se prononce), puis touche son pinyin.")
        else:
            if any(hanzi not in meanings for hanzi in hanzi_list):
                raise PinyinError(f"{where}: meanings are asked of the lesson's vocabulary only")
            pairs = [{"id": _LETTERS[position], "left": hanzi, "pinyin": meanings[hanzi][0], "right": _label(meanings[hanzi][1])} for position, hanzi in enumerate(hanzi_list)]
            texts("Associe chaque mot à son sens.", "Touche un mot, puis touche ce qui lui correspond.")
        spec = {"kind": "matching", "header": header, "pairs": pairs}
    elif kind == "choice":
        choices = item["choices"]
        _check_unique(choices, where)
        header["prompt"] = _label(item["prompt"])
        header["instruction"] = _label(item.get("instruction", "Choisis la bonne réponse."))
        entries = [{"id": _LETTERS[position], "label": _label(choice), "audio": None} for position, choice in enumerate(choices)]
        spec = {
            "kind": "choice", "header": header, "choices": _rotate(entries, lesson_number, number),
            "correctChoiceID": _LETTERS[item["answer"]],
        }
    elif kind == "speak":
        say = item["say"]
        pieces = split_carriers(say, {**carriers.vocabulary, **carriers.table}, where)
        pinyin = item.get("pinyin") or " ".join(carriers.spell(piece, where) for piece in pieces)
        for piece in pieces:
            carriers.pinyin(piece)
        header["required"] = False
        texts(f"Dis à voix haute : {pinyin}.", "Écoute le modèle, dis-le, puis auto-évalue-toi.")
        spec = {
            "kind": "speaking", "header": header, "referenceText": say, "referencePinyin": pinyin, "referenceAudio": None,
            "acceptedTranscripts": [say], "allowSelfRating": True,
        }
    else:
        raise PinyinError(f"{where}: unknown kind {kind!r}")
    metadata: dict[str, Any] = {"stage": stage}
    if contrast is not None:
        metadata["contrast"] = contrast
    return {"kind": "exercise", "id": f"block-{exercise_id}", "spec": spec, "metadata": metadata}


def build_lessons(
    data: dict[str, Any],
    content_version: str,
    resolve_vocab: Callable[[str], tuple[str, dict[str, Any]] | None],
    make_card: Callable[[str, dict[str, Any]], dict[str, Any]],
) -> list[dict[str, Any]]:
    """The module's lessons, ready to be written; the order is the one of the file, from 1."""
    module = data["module"]
    table = data["carriers"]
    if not isinstance(table, dict) or not table:
        raise PinyinError("carriers: expected a non-empty object")
    for hanzi, pinyin in table.items():
        if len(check_pinyin(pinyin, f"carrier '{hanzi}'")) != len(hanzi):
            raise PinyinError(f"carrier '{hanzi}' does not have one syllable per character")
    sources = data["lessons"]
    if not isinstance(sources, list) or not LESSON_COUNT[0] <= len(sources) <= LESSON_COUNT[1]:
        raise PinyinError(f"lessons: {LESSON_COUNT[0]} to {LESSON_COUNT[1]} lessons expected")
    lessons: list[dict[str, Any]] = []
    for number, source in enumerate(sources, start=1):
        lesson_id = source["id"]
        if lesson_id != f"{PINYIN}-{number:02d}":
            raise PinyinError(f"lesson {number}: the ID must be {PINYIN}-{number:02d}")
        vocabulary: list[dict[str, Any]] = []
        for ref in source["vocabulary"]:
            resolved = resolve_vocab(ref)
            if resolved is None:
                raise PinyinError(f"{lesson_id}: unknown vocabulary reference '{ref}'")
            vocabulary.append(resolved[1])
        vocabulary_ids = [entry["id"] for entry in vocabulary]
        _check_unique(vocabulary_ids, f"{lesson_id} vocabulary")
        for entry in vocabulary:
            if table.get(entry["hanzi"], entry["pinyin"]) != entry["pinyin"]:
                raise PinyinError(f"{lesson_id}: carrier '{entry['hanzi']}' disagrees with the vocabulary's pinyin")
        carriers = _Carriers(table, vocabulary)
        meanings = {entry["hanzi"]: (entry["pinyin"], entry["meaning"]["fr"]) for entry in vocabulary}
        objectives = [
            {"id": objective["id"], "required": True, "statement": _label(objective["statement"])} for objective in source["objectives"]
        ]
        objective_ids = [objective["id"] for objective in objectives]
        blocks: list[dict[str, Any]] = [
            {"kind": "introduction", "id": f"block-{lesson_id}-intro-{position}", "title": _label(text["title"]), "body": _label(text["body"])}
            for position, text in enumerate(source["introduction"], start=1)
        ]
        blocks.append({"kind": "vocabulary", "id": f"block-{lesson_id}-vocabulary", "vocabularyIDs": vocabulary_ids})
        blocks.extend(
            _exercise(lesson_id, position, number, objective_ids, carriers, item, meanings)
            for position, item in enumerate(source["exercises"], start=1)
        )
        blocks.append({"kind": "recap", "id": f"block-{lesson_id}-recap", "objectiveIDs": objective_ids, "vocabularyIDs": vocabulary_ids})
        lesson = {
            "schemaVersion": 1,
            "contentVersion": content_version,
            "id": lesson_id,
            "moduleID": module["id"],
            "order": number,
            "title": _label(source["title"]),
            "summary": _label(source["summary"]),
            "estimatedMinutes": SESSION_MINUTES[0],
            "objectives": objectives,
            "vocabulary": vocabulary,
            "blocks": blocks,
            "cards": [make_card(entry["id"], entry) for entry in vocabulary],
            "metadata": {
                "lessonKind": PINYIN,
                "standardID": "HSK-legacy-2.0",
                "standardVersion": "2.0",
                "legacyStandardID": "HSK-legacy-2.0",
                "legacyStandardVersion": "2.0",
                "levelID": "level-00",
                "sectionID": "section-00",
                "unitID": module["id"],
                # The words are met here and taught, with examples and reviews, by the daily lessons.
                "newVocabularyIDs": [],
                "reusedVocabularyIDs": [],
                "newVocabularyCount": 0,
                "extraVocabularyIDs": [],
                "previewVocabularyIDs": vocabulary_ids,
                "carriers": dict(sorted(carriers.used.items())),
            },
        }
        check_lesson(lesson)
        lessons.append(lesson)
    return lessons


# -- the course ------------------------------------------------------------------


def add_to_course(course: dict[str, Any], data: dict[str, Any], lessons: list[dict[str, Any]]) -> None:
    """Put the module first in the path and its lessons on the first days of the plan."""
    module = copy.deepcopy(data["module"])
    module["lessonIDs"] = [lesson["id"] for lesson in lessons]
    count = len(lessons)
    plan = course["plan"]
    plan["sessions"] = [
        {"day": position, "lessonID": lesson["id"], "courseMinutes": SESSION_MINUTES[0], "reviewMinutes": SESSION_MINUTES[1]}
        for position, lesson in enumerate(lessons, start=1)
    ] + [{**session, "day": session["day"] + count} for session in plan["sessions"]]
    milestones = []
    for milestone in plan.get("milestones", []):
        moved = copy.deepcopy(milestone)
        moved["day"] = milestone["day"] + count
        moved["id"] = renumber(milestone["id"], milestone["day"], moved["day"])
        if "claims" in moved:
            moved["claims"] = [renumber(claim, milestone["day"], moved["day"]) for claim in moved["claims"]]
        milestones.append(moved)
    plan["milestones"] = milestones
    course["modules"].insert(0, module)
    sessions = [session["lessonID"] for session in plan["sessions"]]
    counts = {
        "total": len(sessions),
        "pinyin": count,
        "daily": sum(lesson_id.startswith("lesson-") for lesson_id in sessions),
        "reviews": sum(lesson_id.startswith("review-") for lesson_id in sessions),
        "bosses": sum(lesson_id.startswith("boss-") for lesson_id in sessions),
        "words": course["metadata"]["canonicalVocabularyCount"],
    }
    course["title"] = {"fr": data["course"]["title"]["fr"].format(**counts)}
    course["description"] = {"fr": data["course"]["description"]["fr"].format(**counts)}
    metadata = course["metadata"]
    metadata["plannedSessionCount"] = len(sessions)
    metadata["availableLessonCount"] = metadata["starterLessonCount"] + len(sessions)


# -- linting --------------------------------------------------------------------


def _fail(where: str, message: str) -> None:
    raise PinyinError(f"{where}: {message}")


def _features(pinyin: str, where: str) -> list[tuple[str, str, int]]:
    return [split_syllable(part) for part in check_pinyin(pinyin, where)]


def _check_minimal_pair(correct: str, others: list[str], contrast: str, where: str) -> None:
    """Each other choice differs from the answer in the `contrast` feature alone."""
    wanted = _features(correct, where)
    index = {"initial": 0, "final": 1, "tone": 2}[contrast]
    for other in others:
        found = _features(other, where)
        if len(found) != len(wanted):
            _fail(where, f"'{other}' does not have as many syllables as '{correct}'")
        same_elsewhere = all(
            tuple(part for position, part in enumerate(left) if position != index) == tuple(part for position, part in enumerate(right) if position != index)
            for left, right in zip(wanted, found)
        )
        differs = any(left[index] != right[index] for left, right in zip(wanted, found))
        if not same_elsewhere or not differs:
            _fail(where, f"'{other}' is not a {contrast} minimal pair of '{correct}'")


def _choice_ids(spec: dict[str, Any], where: str) -> dict[str, str]:
    choices = spec.get("choices")
    if not isinstance(choices, list) or len(choices) < 2:
        _fail(where, "needs at least two choices")
    ids = [choice["id"] for choice in choices]
    labels = [choice["label"]["fr"] for choice in choices]
    if len(set(ids)) != len(ids) or len(set(labels)) != len(labels) or spec.get("correctChoiceID") not in ids:
        _fail(where, "has duplicate choices or no correct choice")
    return dict(zip(ids, labels))


def check_lesson(lesson: dict[str, Any]) -> None:
    """The contract of a module 0 lesson; raises PinyinError, naming the lesson."""
    lesson_id = lesson["id"]
    metadata = lesson["metadata"]
    if not re.fullmatch(rf"{PINYIN}-\d\d", lesson_id) or not is_pinyin(lesson):
        _fail(lesson_id, f"a module 0 lesson is named {PINYIN}-NN and has lessonKind {PINYIN}")
    if lesson["estimatedMinutes"] != SESSION_MINUTES[0]:
        _fail(lesson_id, f"estimatedMinutes must be {SESSION_MINUTES[0]}")
    carriers = metadata.get("carriers")
    if not isinstance(carriers, dict) or not carriers:
        _fail(lesson_id, "metadata.carriers lists the carriers the exercises use")
    attested: set[str] = set()
    for hanzi, pinyin in carriers.items():
        where = f"{lesson_id} carrier '{hanzi}'"
        parts = check_pinyin(pinyin, where)
        if len(parts) != len(hanzi):
            _fail(where, "needs one syllable per character")
        attested.update(parts)
    vocabulary_ids = [entry["id"] for entry in lesson["vocabulary"]]
    if len(vocabulary_ids) > MAX_WORDS or metadata.get("previewVocabularyIDs") != vocabulary_ids:
        _fail(lesson_id, f"metadata.previewVocabularyIDs must list the lesson's {MAX_WORDS} words at most")
    if metadata.get("newVocabularyIDs") != [] or metadata.get("newVocabularyCount") != 0:
        _fail(lesson_id, "a module 0 lesson introduces no word: the daily lessons teach them")
    if {card["vocabularyID"] for card in lesson["cards"]} != set(vocabulary_ids):
        _fail(lesson_id, "every previewed word needs a review card")
    for entry in lesson["vocabulary"]:
        if carriers.get(entry["hanzi"], entry["pinyin"]) != entry["pinyin"]:
            _fail(lesson_id, f"carrier '{entry['hanzi']}' disagrees with the vocabulary's pinyin")
    if not any(block["kind"] == "introduction" and block["body"]["fr"].strip() for block in lesson["blocks"]):
        _fail(lesson_id, "needs an introduction")

    blocks = [block for block in lesson["blocks"] if block["kind"] == "exercise"]
    if not EXERCISE_BUDGET[0] <= len(blocks) <= EXERCISE_BUDGET[1]:
        _fail(lesson_id, f"{len(blocks)} exercises, expected {EXERCISE_BUDGET[0]}–{EXERCISE_BUDGET[1]}")
    ranks = [PHASES.index(block["metadata"]["stage"]) for block in blocks]
    if ranks != sorted(ranks) or set(ranks) != set(range(len(PHASES))):
        _fail(lesson_id, f"exercises must run through {', '.join(PHASES)} in order")
    specs = [block["spec"] for block in blocks]
    if len({spec["kind"] for spec in specs}) < MIN_KINDS:
        _fail(lesson_id, f"needs at least {MIN_KINDS} exercise kinds")
    if sum(spec["kind"] in LISTENING_KINDS for spec in specs) < MIN_LISTENING_SHARE * len(specs):
        _fail(lesson_id, "a module 0 lesson is mostly listening")
    if sum("contrast" in block["metadata"] for block in blocks) < MIN_CONTRASTS:
        _fail(lesson_id, f"needs at least {MIN_CONTRASTS} minimal-pair exercises")
    used_objectives = {objective for spec in specs for objective in spec["header"]["objectiveIDs"]}
    if used_objectives != {objective["id"] for objective in lesson["objectives"]}:
        _fail(lesson_id, "every objective needs exercise evidence")
    identities: set[tuple[str, str]] = set()

    def spoken(text: str, where: str) -> list[str]:
        """The carrier's syllables; a text that TTS could misread is refused."""
        if text not in carriers:
            _fail(where, f"plays '{text}', which is not a carrier of the lesson")
        if POLYPHONES.intersection(text):
            _fail(where, f"plays '{text}': a character with several readings may be misread by speech synthesis")
        return syllables(carriers[text])

    for block in blocks:
        spec, stage = block["spec"], block["metadata"]
        where = f"{lesson_id}: exercise '{spec['header']['id']}'"
        subject = spec.get("promptText") or " ".join(pair["left"] for pair in spec.get("pairs", [])) or spec.get("referenceText", "")
        identity = (spec["header"]["prompt"]["fr"], subject)
        if identity in identities:
            _fail(where, "repeats an earlier prompt")
        identities.add(identity)
        kind, contrast = spec["kind"], stage.get("contrast")
        if contrast is not None and (contrast not in CONTRASTS or kind not in ("dictation", "listeningChoice")):
            _fail(where, "flags a minimal pair on an exercise that cannot hold one")
        if kind == "toneDiscrimination":
            ids = _choice_ids(spec, where)
            tones = spoken_tones(pinyin_tones(spoken(spec["promptText"], where)))
            if spec["correctChoiceID"] != tone_choice_id(tones):
                _fail(where, "has a correct tone pattern that differs from the carrier's tones")
            for choice_id, label in ids.items():
                offered = [int(digit) for digit in choice_id[1:] if digit.isdigit()]
                if not choice_id.startswith("t") or not choice_id[1:].isdigit() or len(offered) != len(tones) or label != tone_label(offered) or (len(offered) == 2 and offered[0] == offered[1] == 3):
                    _fail(where, f"has a malformed or misleading tone choice '{choice_id}'")
        elif kind == "dictation":
            ids = _choice_ids(spec, where)
            correct = ids[spec["correctChoiceID"]]
            if spec.get("script") != "pinyin" or correct != carriers.get(spec["promptText"]):
                _fail(where, "has a correct pinyin that is not the carrier's")
            spoken(spec["promptText"], where)
            for label in ids.values():
                if not set(check_pinyin(label, where)) <= attested:
                    _fail(where, f"offers '{label}', whose syllables no carrier attests")
            if contrast:
                _check_minimal_pair(correct, [label for choice_id, label in ids.items() if choice_id != spec["correctChoiceID"]], contrast, where)
        elif kind == "listeningChoice":
            ids = _choice_ids(spec, where)
            parsed = {}
            for choice_id, label in ids.items():
                found = _HEAR_LABEL.match(label)
                if found is None or carriers.get(found.group(1)) != found.group(2):
                    _fail(where, f"offers '{label}', which is not a carrier with its pinyin")
                parsed[choice_id] = found.groups()
            if parsed[spec["correctChoiceID"]][0] != spec["promptText"]:
                _fail(where, "has a correct choice that is not the spoken text")
            spoken(spec["promptText"], where)
            if contrast:
                _check_minimal_pair(
                    parsed[spec["correctChoiceID"]][1], [pinyin for choice_id, (_, pinyin) in parsed.items() if choice_id != spec["correctChoiceID"]], contrast, where,
                )
        elif kind == "matching":
            pairs = spec["pairs"]
            if not MATCHING_PAIRS[0] <= len(pairs) <= MATCHING_PAIRS[1]:
                _fail(where, f"needs {MATCHING_PAIRS[0]} to {MATCHING_PAIRS[1]} pairs")
            rights = [pair["right"]["fr"] for pair in pairs]
            if len({pair["left"] for pair in pairs}) != len(pairs) or len(set(rights)) != len(rights):
                _fail(where, "has duplicate pair sides")
            vocabulary = {entry["hanzi"]: entry for entry in lesson["vocabulary"]}
            for pair in pairs:
                if pair["pinyin"] is None:
                    if pair["left"] not in carriers or pair["right"]["fr"] != carriers[pair["left"]]:
                        _fail(where, f"pairs '{pair['left']}' with something else than its pinyin")
                else:
                    entry = vocabulary.get(pair["left"])
                    if entry is None or pair["pinyin"] != entry["pinyin"] or pair["right"]["fr"] != entry["meaning"]["fr"]:
                        _fail(where, f"pairs '{pair['left']}' with something else than its meaning")
        elif kind == "speaking":
            expected = [part for piece in split_carriers(spec["referenceText"], carriers, where) for part in spoken(piece, where)]
            found = syllables(re.sub(f"[{re.escape(_PUNCTUATION)}]+", " ", spec["referencePinyin"]))
            if found != expected or spec["header"]["required"] is not False or spec.get("allowSelfRating") is not True:
                _fail(where, "has a reference pinyin that is not its text's, or an oral activity that blocks progression")
        elif kind == "choice":
            _choice_ids(spec, where)
        else:
            _fail(where, f"uses the kind {kind}, which a module 0 lesson does not")


def check_structure(course: dict[str, Any], lessons: dict[str, dict[str, Any]], context: str) -> None:
    """The module sits first in the path and on the first days of the plan, with its own budget."""
    pinyin_ids = [lesson_id for lesson_id, lesson in lessons.items() if is_pinyin(lesson)]
    if not pinyin_ids:
        return
    modules = sorted(course["modules"], key=lambda module: module["order"])
    first = modules[0]
    if first["lessonIDs"] != sorted(pinyin_ids) or not LESSON_COUNT[0] <= len(pinyin_ids) <= LESSON_COUNT[1]:
        raise PinyinError(f"{context}: the first unit holds exactly the {LESSON_COUNT[0]} to {LESSON_COUNT[1]} pinyin lessons, in order")
    sessions = course.get("plan", {}).get("sessions", [])
    head = sessions[:len(pinyin_ids)]
    if [session["lessonID"] for session in head] != first["lessonIDs"] or any(
        (session["courseMinutes"], session["reviewMinutes"]) != SESSION_MINUTES for session in head
    ):
        raise PinyinError(f"{context}: the pinyin lessons are the first days of the plan, {SESSION_MINUTES[0]} + {SESSION_MINUTES[1]} minutes")
