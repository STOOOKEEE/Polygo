"""Review lessons and unit bosses, derived from the daily lessons they revisit.

Every unit runs its daily lessons in fives: a review follows each run of
`REVIEW_EVERY` lessons, and a boss closes the unit. A boss that ends a run of
five stands in for the review. The reviews and bosses introduce no word: they
are built from the vocabulary, dialogue lines and grammar examples of the
lessons they cover, so they show no Mandarin, pinyin or translation that those
lessons do not already carry.

`derive_layout` and `derive_sessions` place them in the course (the assembler
calls them), `build_derived_lessons` writes their lessons (the generator calls
it), and the lint of `content_tool` checks the outcome.

A review draws on every newer exercise kind. The boss ends on a dialogue
challenge (listening, replies, translation, dialogue order, speaking). Each
exercise records in `metadata.sourceLessonID` the oldest covered lesson it asks
about, and every phase runs the oldest lessons first: with no learner history
at generation time, the lesson's age is the static measure of what is likely
to have faded, and the spaced-review minutes of the day cover the rest.
"""
from __future__ import annotations

import copy
import re
from dataclasses import replace
from typing import Any

from exercise_expansion import (
    PHASES,
    Candidate,
    Exercise,
    ExpansionError,
    Sentence,
    SessionBuilder,
)
from exercise_kinds import MATCHING_PAIRS, NEW_KINDS

REVIEW_EVERY = 5
REVIEW = "review"
BOSS = "boss"
DERIVED_KINDS = (REVIEW, BOSS)
# Minutes of the lesson and of spaced review in the day's 15-minute plan.
SESSION_MINUTES = {REVIEW: (12, 3), BOSS: (13, 2)}
DERIVED_BUDGET = {REVIEW: (15, 20), BOSS: (18, 20)}
# The dialogue challenge that a boss must run.
BOSS_KINDS = ("listeningChoice", "conversationChoice", "translation", "dialogueOrder", "speaking")

_TARGET = {REVIEW: 18, BOSS: 20}
_PHASE_QUOTA = {
    REVIEW: {"discover": 6, "guided": 6, "reuse": 6},
    BOSS: {"discover": 6, "guided": 5, "reuse": 9},
}
_KIND_CAP = {
    REVIEW: {
        "choice": 4, "listeningChoice": 4, "wordOrder": 2, "fillBlank": 2, "speaking": 2, "matching": 2,
        "dictation": 3, "toneDiscrimination": 2, "translation": 2, "conversationChoice": 2, "dialogueOrder": 2,
    },
    BOSS: {
        "choice": 3, "listeningChoice": 4, "wordOrder": 2, "fillBlank": 2, "speaking": 2, "matching": 2,
        "dictation": 2, "toneDiscrimination": 2, "translation": 3, "conversationChoice": 4, "dialogueOrder": 2,
    },
}
_REQUIRED_KINDS = {REVIEW: NEW_KINDS + ("speaking",), BOSS: BOSS_KINDS}
# Matching and dictation are offered in several shapes; a session takes each shape once.
_VARIED_KINDS = {"matching", "dictation"}
_WORDS_PER_LESSON = {REVIEW: None, BOSS: 5}
# A boss reads its dialogue and structures from this many lessons of the unit,
# spread over it, and from the lessons that teach no word.
_SPREAD_LESSONS = {REVIEW: REVIEW_EVERY, BOSS: 6}
_STRUCTURES_PER_LESSON = {REVIEW: 2, BOSS: 1}
_SEGMENT_LINES = 3
_GRAMMAR_TITLE = "Grammaire — "
_EXAMPLE = re.compile(r"Exemple \d+ : (.+)")


def is_derived(lesson: dict[str, Any]) -> bool:
    metadata = lesson.get("metadata")
    return isinstance(metadata, dict) and metadata.get("lessonKind") in DERIVED_KINDS


# -- placement in the course ---------------------------------------------------


def derive_layout(modules: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Insert the reviews and the boss into each module's lesson list.

    Returns the modules with their new `lessonIDs` and the blueprints of the
    derived lessons, in course order. Each blueprint names the daily lessons it
    covers; the assembler adds the `order`.
    """
    orders = [module["order"] for module in modules]
    if orders != sorted(orders):
        raise ValueError("modules must be listed in course order")
    layout: list[dict[str, Any]] = []
    blueprints: list[dict[str, Any]] = []
    reviews = 0
    for module in modules:
        lesson_ids = list(module["lessonIDs"])
        ids: list[str] = []
        run: list[str] = []
        for position, lesson_id in enumerate(lesson_ids):
            ids.append(lesson_id)
            run.append(lesson_id)
            if len(run) == REVIEW_EVERY and position < len(lesson_ids) - 1:
                reviews += 1
                blueprints.append({"id": f"review-{reviews:02d}", "kind": REVIEW, "moduleID": module["id"], "number": reviews, "covers": run})
                ids.append(blueprints[-1]["id"])
                run = []
        blueprints.append({"id": f"boss-{module['id']}", "kind": BOSS, "moduleID": module["id"], "covers": lesson_ids})
        ids.append(blueprints[-1]["id"])
        layout.append({**module, "lessonIDs": ids})
    return layout, blueprints


def derive_sessions(
    layout: list[dict[str, Any]], base_sessions: list[dict[str, Any]], blueprints: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """The plan's sessions in the layout's order, with the derived lessons' minutes."""
    by_lesson = {session["lessonID"]: session for session in base_sessions}
    kinds = {blueprint["id"]: blueprint["kind"] for blueprint in blueprints}
    sessions: list[dict[str, Any]] = []
    for module in layout:
        for lesson_id in module["lessonIDs"]:
            course, review = SESSION_MINUTES[kinds[lesson_id]] if lesson_id in kinds else (
                by_lesson[lesson_id]["courseMinutes"], by_lesson[lesson_id]["reviewMinutes"],
            )
            sessions.append({"day": len(sessions) + 1, "lessonID": lesson_id, "courseMinutes": course, "reviewMinutes": review})
    return sessions


def remap_milestones(
    milestones: list[dict[str, Any]],
    base_sessions: list[dict[str, Any]],
    sessions: list[dict[str, Any]],
    layout: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Move each milestone to its lesson's new day, or to the boss when its lesson ends a unit.

    Reviews and bosses add no word, so the coverage a milestone claims is the
    one of its lesson. The day figures in the ID and the claims follow the move.
    """
    day_of = {session["lessonID"]: session["day"] for session in sessions}
    unit_of = {lesson_id: module for module in layout for lesson_id in module["lessonIDs"]}
    result: list[dict[str, Any]] = []
    for milestone in milestones:
        old = milestone["day"]
        lesson_id = base_sessions[old - 1]["lessonID"]
        module = unit_of[lesson_id]
        daily = [lesson for lesson in module["lessonIDs"] if not lesson.startswith(DERIVED_KINDS)]
        new = day_of[f"boss-{module['id']}"] if lesson_id == daily[-1] else day_of[lesson_id]
        moved = copy.deepcopy(milestone)
        moved["day"] = new
        moved["id"] = _renumber(milestone["id"], old, new)
        if "claims" in moved:
            moved["claims"] = [_renumber(claim, old, new) for claim in moved["claims"]]
        result.append(moved)
    return result


def _renumber(text: str, old: int, new: int) -> str:
    return re.sub(rf"(?<!\d){old}(?!\d)", str(new), text)


# -- the derived lessons -------------------------------------------------------


def _fr(value: Any) -> str:
    return value["fr"].strip() if isinstance(value, dict) and isinstance(value.get("fr"), str) else ""


def introduction_examples(block: dict[str, Any]) -> list[tuple[str, str, str]]:
    """The (Hanzi, pinyin, French) examples an introduction block spells out as `Exemple N : …`."""
    lines = _fr(block.get("body")).split("\n")
    return [
        (match.group(1), lines[position + 1], lines[position + 2])
        for position, line in enumerate(lines)
        if (match := _EXAMPLE.fullmatch(line)) and position + 2 < len(lines)
    ]


def _spread(count: int, wanted: int) -> list[int]:
    """`wanted` positions spread over `count`, all of them when there are few."""
    if count <= wanted:
        return list(range(count))
    return sorted({round(index * (count - 1) / (wanted - 1)) for index in range(wanted)})


def _segment(lesson: dict[str, Any]) -> list[dict[str, Any]]:
    """Consecutive clean dialogue lines, preferring runs where a question is answered."""
    block = next((item for item in lesson["blocks"] if item.get("kind") == "dialogue"), None)
    lines = block.get("lines", []) if block else []
    clean = [
        Sentence(line["hanzi"], line["pinyin"], _fr(line["translation"]), "dialogue", label=line["speaker"]).is_clean
        for line in lines
    ]
    for size in range(_SEGMENT_LINES, 1, -1):
        windows = [
            start for start in range(len(lines) - size + 1)
            if all(clean[start:start + size]) and len({line["hanzi"] for line in lines[start:start + size]}) == size
        ]
        if windows:
            def answered(start: int) -> int:
                return sum(lines[at]["hanzi"].rstrip().endswith("？") for at in range(start, start + size - 1))
            best = max(windows, key=lambda start: (answered(start), -start))
            return copy.deepcopy(lines[best:best + size])
    return []


def _structures(lesson: dict[str, Any], limit: int) -> list[tuple[str, tuple[str, str, str]]]:
    """(pattern, first clean example) of the lesson's grammar notes."""
    found: list[tuple[str, tuple[str, str, str]]] = []
    for block in lesson["blocks"]:
        if block.get("kind") != "introduction" or "-grammar-" not in block["id"]:
            continue
        examples = [
            example for example in introduction_examples(block)
            if Sentence(example[0], example[1], example[2], "example").is_clean
        ]
        if examples:
            found.append((_fr(block["title"]).removeprefix(_GRAMMAR_TITLE), examples[0]))
    return found[:limit]


class _ReviewBuilder(SessionBuilder):
    """The builder of a lesson whose material is drawn from several lessons.

    The dialogue block strings together short extracts of the covered lessons:
    the extracts are separated for the dialogue exercises, so that no line is
    ever asked to follow one from another lesson.
    """

    def __init__(
        self,
        lesson: dict[str, Any],
        lexicon: set[str],
        identity: tuple[int, str],
        segment_sizes: list[int],
        segment_owners: list[int],
        word_origin: dict[str, int],
        structures: list[tuple[int, Sentence]],
    ) -> None:
        self.segment_sizes = segment_sizes
        self.word_origin = word_origin
        self.structures = [sentence for _, sentence in structures]
        self.lesson_count = 1 + max(word_origin.values())
        self.sentence_origin: dict[str, int] = {}
        lines = next(block for block in lesson["blocks"] if block["kind"] == "dialogue")["lines"]
        cursor = 0
        for size, owner in zip(segment_sizes, segment_owners):
            for line in lines[cursor:cursor + size]:
                self._note_origin(line["hanzi"], owner)
            cursor += size
        for owner, sentence in structures:
            self._note_origin(sentence.hanzi, owner)
        for entry in lesson["vocabulary"]:
            if isinstance(entry.get("example"), dict):
                self._note_origin(entry["example"].get("hanzi", ""), word_origin[entry["id"]])
        super().__init__(lesson, set(), [], lexicon, identity)

    def _note_origin(self, hanzi: str, origin: int) -> None:
        self.sentence_origin[hanzi] = min(origin, self.sentence_origin.get(hanzi, origin))

    def _dialogue_turns(self) -> list[Sentence | None]:
        turns = super()._dialogue_turns()
        result: list[Sentence | None] = []
        cursor = 0
        for size in self.segment_sizes:
            result.extend(turns[cursor:cursor + size])
            result.append(None)
            cursor += size
        return result[:-1]

    def _example_sentences(self) -> list[Sentence]:
        return super()._example_sentences() + self.structures

    def _origin_of(self, item: dict[str, Any] | Sentence | None) -> int:
        if isinstance(item, Sentence):
            return self.sentence_origin.get(item.hanzi, 0)
        return self.word_origin[item["id"]] if item else 0

    def _matching_groups(self, ordered: list[dict[str, Any]]) -> list[tuple[str, str, list[dict[str, Any]]]]:
        """Matchings within one lesson's words, so that each one asks about one lesson."""
        groups: list[tuple[str, str, list[dict[str, Any]]]] = []
        for origin in range(self.lesson_count):
            pool = [entry for entry in ordered if self.word_origin[entry["id"]] == origin]
            for mode in ("meaning", "pinyin"):
                group = self._matching_group(pool, mode)
                if len(group) >= MATCHING_PAIRS[0]:
                    groups.append((f"match-{mode}-{origin + 1}", mode, group))
        return groups


class _Selection:
    """The exercises of one derived lesson: balanced over the covered lessons, varied in kind."""

    def __init__(self, kind: str, pool: list[Candidate]) -> None:
        self.kind = kind
        self.pool = pool
        self.chosen: list[Candidate] = []

    def _uses(self, attribute: str, value: Any) -> int:
        return sum(1 for item in self.chosen if getattr(item, attribute) == value)

    def _phase_load(self, candidate: Candidate) -> int:
        return sum(1 for item in self.chosen if item.exercise.phase == candidate.exercise.phase)

    def _allowed(self, candidate: Candidate) -> bool:
        if len(self.chosen) >= _TARGET[self.kind] or self._phase_load(candidate) >= _PHASE_QUOTA[self.kind][candidate.exercise.phase]:
            return False
        if self._uses("kind", candidate.kind) >= _KIND_CAP[self.kind][candidate.kind]:
            return False
        if candidate.kind in _VARIED_KINDS and any(item.kind == candidate.kind and item.family == candidate.family for item in self.chosen):
            return False
        return not any(
            item.sentence is not None and item.sentence == candidate.sentence and item.kind == candidate.kind
            for item in self.chosen
        )

    def _score(self, candidate: Candidate) -> tuple[int, int, bool, int, int, str]:
        """Prefer the least covered lesson, then the rarest kind; speaking, the quickest to build, comes last."""
        sentence_uses = sum(1 for item in self.chosen if item.sentence is not None and item.sentence == candidate.sentence)
        return (
            self._uses("origin", candidate.origin), self._uses("kind", candidate.kind), candidate.kind == "speaking",
            self._phase_load(candidate), sentence_uses, candidate.exercise.spec["header"]["id"],
        )

    def _take(self, candidate: Candidate) -> None:
        self.chosen.append(candidate)
        self.pool.remove(candidate)

    def run(self) -> list[Candidate]:
        for kind in _REQUIRED_KINDS[self.kind]:
            options = [item for item in self.pool if item.kind == kind and self._allowed(item)]
            if kind == "listeningChoice":
                # A boss listens to whole lines; a review may also listen to words.
                options = [item for item in options if item.family == "listen"] or options
            if options:
                self._take(min(options, key=self._score))
        # Every covered lesson is asked about once, those with the least material first.
        supply = {origin: sum(1 for item in self.pool if item.origin == origin) for origin in {item.origin for item in self.pool}}
        for origin in sorted(supply, key=lambda origin: (supply[origin], origin)):
            options = [item for item in self.pool if item.origin == origin and self._allowed(item)]
            if options and self._uses("origin", origin) == 0:
                self._take(min(options, key=self._score))
        while len(self.chosen) < _TARGET[self.kind]:
            options = [item for item in self.pool if self._allowed(item)]
            if not options:
                break
            self._take(min(options, key=self._score))
        return self.chosen


def _boss_phases(pool: list[Candidate]) -> list[Candidate]:
    """A boss ends on the dialogue challenge: whole-line listening, replies, translation, ordering, speaking."""
    challenge = set(BOSS_KINDS) - {"listeningChoice"}
    result: list[Candidate] = []
    for item in pool:
        phase = item.exercise.phase
        if item.kind in challenge or item.family == "listen":
            phase = "reuse"
        elif item.family == "read":
            phase = "guided"
        result.append(replace(item, exercise=Exercise(phase, item.exercise.spec)) if phase != item.exercise.phase else item)
    return result


def _join(titles: list[str]) -> str:
    quoted = [f"« {title} »" for title in titles]
    return quoted[0] if len(quoted) == 1 else ", ".join(quoted[:-1]) + " et " + quoted[-1]


def _objectives(lesson_id: str, kind: str) -> list[dict[str, Any]]:
    statements = {
        REVIEW: ("Retrouver le sens des mots, des phrases et des dialogues des cinq dernières leçons.", "Réemployer leurs structures sans aucun mot nouveau."),
        BOSS: ("Comprendre et suivre un dialogue qui reprend toute l’unité.", "Répondre et construire des phrases de l’unité sans aucun mot nouveau."),
    }[kind]
    return [
        {"id": f"{lesson_id}-{suffix}", "required": True, "statement": {"fr": statement}}
        for suffix, statement in zip(("understand", "produce"), statements)
    ]


def _build(
    blueprint: dict[str, Any],
    lessons: dict[str, dict[str, Any]],
    unit_title: str,
    content_version: str,
    lexicon: set[str],
) -> dict[str, Any]:
    kind, lesson_id = blueprint["kind"], blueprint["id"]
    covers = [lessons[cover_id] for cover_id in blueprint["covers"]]
    limit = _WORDS_PER_LESSON[kind]

    vocabulary: list[dict[str, Any]] = []
    word_origin: dict[str, int] = {}
    for origin, cover in enumerate(covers):
        new_ids = set(cover["metadata"]["newVocabularyIDs"])
        entries = [entry for entry in cover["vocabulary"] if entry["id"] in new_ids][:limit]
        vocabulary.extend(copy.deepcopy(entry) for entry in entries)
        word_origin.update({entry["id"]: origin for entry in entries})
    cards = [
        copy.deepcopy(next(card for cover in covers for card in cover["cards"] if card["vocabularyID"] == entry["id"]))
        for entry in vocabulary
    ]

    dialogue: list[dict[str, Any]] = []
    segment_sizes: list[int] = []
    segment_owners: list[int] = []
    structures: list[tuple[int, str, tuple[str, str, str]]] = []
    # A lesson that teaches no word is only present through its dialogue and structures.
    wordless = {origin for origin, cover in enumerate(covers) if not cover["metadata"]["newVocabularyIDs"]}
    for origin in sorted(wordless.union(_spread(len(covers), _SPREAD_LESSONS[kind]))):
        segment = _segment(covers[origin])
        if segment:
            dialogue.extend(segment)
            segment_sizes.append(len(segment))
            segment_owners.append(origin)
        structures.extend((origin, pattern, example) for pattern, example in _structures(covers[origin], _STRUCTURES_PER_LESSON[kind]))

    titles = [_fr(cover["title"]) for cover in covers]
    if kind == REVIEW:
        title = f"Révision {blueprint['number']}"
        summary = f"Retrouve, en commençant par les plus anciennes, les mots, les phrases et les structures de {_join(titles)}."
        opening = (
            f"Cette séance ne contient aucun mot nouveau : elle reprend les mots, les phrases et les structures de {_join(titles)}. "
            "Les exercices commencent par les leçons les plus anciennes."
        )
    else:
        title = f"Défi de l’unité : {unit_title}"
        summary = f"Dernière étape de l’unité « {unit_title} » : écoute, réponds et reconstitue des dialogues avec tout ce que tu as appris."
        opening = (
            f"Dernière étape de l’unité « {unit_title} » : aucun mot nouveau, seulement ce que tu as déjà appris dans les {len(covers)} leçons. "
            "Écoute, réponds et reconstitue des dialogues ; les exercices commencent par les leçons les plus anciennes."
        )
    body = [opening, "", "Structures à retrouver :"]
    for number, (_, pattern, (hanzi, pinyin, french)) in enumerate(structures, start=1):
        body.extend([pattern, f"Exemple {number} : {hanzi}", pinyin, french])

    lesson: dict[str, Any] = {
        "schemaVersion": 1,
        "contentVersion": content_version,
        "id": lesson_id,
        "moduleID": blueprint["moduleID"],
        "order": blueprint["order"],
        "level": covers[-1].get("level"),
        "title": {"fr": title},
        "summary": {"fr": summary},
        "estimatedMinutes": SESSION_MINUTES[kind][0],
        "objectives": _objectives(lesson_id, kind),
        "vocabulary": vocabulary,
        "blocks": [
            {"kind": "introduction", "id": f"block-{lesson_id}-intro", "title": {"fr": title}, "body": {"fr": "\n".join(body)}},
            {"kind": "dialogue", "id": f"block-{lesson_id}-dialogue", "lines": dialogue, "comprehensionExerciseIDs": []},
        ],
        "cards": cards,
    }
    builder = _ReviewBuilder(
        lesson, lexicon, (blueprint["order"], f"ex-{lesson_id}"), segment_sizes, segment_owners, word_origin,
        [(origin, Sentence(hanzi, pinyin, french, "example")) for origin, _, (hanzi, pinyin, french) in structures],
    )
    pool = builder.candidates()
    if kind == BOSS:
        pool = _boss_phases(pool)
    chosen = _Selection(kind, pool).run()
    if not DERIVED_BUDGET[kind][0] <= len(chosen) <= DERIVED_BUDGET[kind][1]:
        raise ExpansionError(f"{lesson_id}: {len(chosen)} exercises, expected {DERIVED_BUDGET[kind][0]}–{DERIVED_BUDGET[kind][1]}")
    missing = [name for name in _REQUIRED_KINDS[kind] if all(item.kind != name for item in chosen)]
    if missing:
        raise ExpansionError(f"{lesson_id}: the material builds no {', '.join(missing)} exercise")

    ordered = [
        item
        for phase in PHASES
        for item in sorted((item for item in chosen if item.exercise.phase == phase), key=lambda item: (item.origin, item.exercise.spec["header"]["id"]))
    ]
    builder.reposition([item.exercise for item in ordered])
    exercise_blocks = [
        {
            "kind": "exercise",
            "id": f"block-{item.exercise.spec['header']['id']}",
            "spec": item.exercise.spec,
            "metadata": {"stage": item.exercise.phase, "sourceLessonID": blueprint["covers"][item.origin]},
        }
        for item in ordered
    ]
    first_words: dict[int, str] = {}
    for entry in vocabulary:
        first_words.setdefault(word_origin[entry["id"]], entry["id"])
    lesson["blocks"] += exercise_blocks + [{
        "kind": "recap", "id": f"block-{lesson_id}-recap", "vocabularyIDs": list(first_words.values()),
        "objectiveIDs": [objective["id"] for objective in lesson["objectives"]],
    }]

    last = covers[-1]["metadata"]
    lesson["metadata"] = {
        "lessonKind": kind,
        "reviewedLessonIDs": blueprint["covers"],
        **{key: last[key] for key in ("standardID", "standardVersion", "legacyStandardID", "legacyStandardVersion", "levelID", "sectionID")},
        "unitID": blueprint["moduleID"],
        "newVocabularyIDs": [],
        "reusedVocabularyIDs": [entry["id"] for entry in vocabulary],
        "newVocabularyCount": 0,
        "extraVocabularyIDs": [],
    }
    return lesson


def build_derived_lessons(
    blueprints: list[dict[str, Any]],
    lessons: dict[str, dict[str, Any]],
    unit_titles: dict[str, str],
    content_version: str,
    lexicon: set[str],
) -> list[dict[str, Any]]:
    """The review and boss lessons of `blueprints`, from the generated daily `lessons`."""
    missing = sorted(cover for blueprint in blueprints for cover in blueprint["covers"] if cover not in lessons)
    if missing:
        raise ExpansionError(f"review lessons cover unknown lessons: {', '.join(missing)}")
    return [_build(blueprint, lessons, unit_titles[blueprint["moduleID"]], content_version, lexicon) for blueprint in blueprints]
