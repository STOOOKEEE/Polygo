#!/usr/bin/env python3
"""Build the editorial allocation for the 90-session classic HSK 1–2 course.

This tool writes a reviewable plan only. It does not invent dialogue,
readings, exercises, pinyin, translations, or lesson prose. Those texts are
authored in separate, range-specific files and are assembled by the release
editor.

Run order: this allocation, then the range builders, then the assembler. The
allocation reads the authored texts of the fragments (never their vocabulary
lists), and the builders and the assembler read the allocation back.
"""
from __future__ import annotations

import bisect
import json
import re
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
AUTHORING = ROOT / "Content" / "authoring"
CATALOG_PATH = AUTHORING / "hsk-legacy-600.json"
PREVIEW_PATH = AUTHORING / "preview-first-five.json"
DAYS_06_45_PATH = AUTHORING / "90-day-authoring-days-06-45.json"
DAYS_46_66_PATH = AUTHORING / "90-day-authoring-days-46-66.json"
ALLOCATION_PATH = AUTHORING / "90-day-allocation.json"
CONTENT_VERSION = "2026.10.0"

MIN_NEW_PER_LESSON = 3
MAX_NEW_PER_LESSON = 5
# The course teaches the 300 canonical words of ranks 1–300 (HSK classique 1
# and 2). Rank 150 closes HSK 1, and 66 daily lessons at 3–5 new words a day
# introduce the 287 words that the four starter lessons do not.
CANONICAL_TARGET = 300
HSK1_TARGET = 150
MAX_LEXEME = 4

# A unit of at most nine lessons holds a single review, after its fifth lesson,
# and its boss: 66 lessons, 8 reviews and 8 bosses fill 82 sessions, and the 8
# pinyin lessons of module 0 bring the plan to exactly 90 sessions.
UNITS: list[tuple[str, str, int]] = [
    ("unit-02", "Vie pratique", 8),
    ("unit-03", "Temps, études et santé", 8),
    ("unit-04", "Journées bien remplies", 8),
    ("unit-05", "Achats et déplacements", 8),
    ("unit-06", "Études, travail et voyage", 8),
    ("unit-07", "Quartier et communauté", 8),
    ("unit-08", "Travail et habitudes", 9),
    ("unit-09", "Voyages, nature et loisirs", 9),
]
DAYS = sum(size for _, _, size in UNITS)


def _modules() -> list[dict[str, Any]]:
    modules: list[dict[str, Any]] = []
    first = 1
    for order, (unit_id, title, size) in enumerate(UNITS, start=2):
        modules.append({"id": unit_id, "order": order, "title": title, "days": range(first, first + size)})
        first += size
    return modules


MODULES = _modules()
# HSK 1 (ranks 1–150) closes with unit-06: the authored lessons ask for about
# forty HSK 2 words before that day, which leaves no room for ending it sooner
# at 3–5 new words a lesson.
HSK1_LAST_DAY = next(module for module in MODULES if module["id"] == "unit-06")["days"][-1]


# The order is intentional: it is the editorial route through the course.
DAY_THEMES = [
    "food", "home", "family", "time", "shopping", "home", "food", "family", "time", "travel", "routine", "daily-review",
    "study", "routine", "health", "communication", "study", "work", "time", "health", "leisure", "study", "daily-review", "health",
    "shopping", "travel", "food", "shopping", "city", "daily-review", "home", "community", "health", "study", "work", "communication",
    "city", "travel", "shopping", "home", "routine", "community", "study", "work", "communication", "health", "city", "community",
    "work", "study", "routine", "communication", "work", "health", "city", "travel", "shopping", "city", "community", "daily-review",
    "travel", "nature", "leisure", "communication", "city", "travel",
]


def localized(text: str) -> dict[str, str]:
    return {"fr": text}


def module_for_day(day: int) -> dict[str, Any]:
    return next(module for module in MODULES if day in module["days"])


def canonical_ref(ref: str, by_id: dict[str, dict[str, Any]], existing_to_canonical: dict[str, str]) -> str | None:
    candidate = existing_to_canonical.get(ref, ref)
    return candidate if candidate in by_id else None


def load_authored_lessons() -> tuple[dict[int, dict[str, Any]], dict[int, str]]:
    """Return the authored lesson fragments and late-course grammar anchors, keyed by course day."""
    lessons: dict[int, dict[str, Any]] = {}
    anchors: dict[int, str] = {}
    for path in (PREVIEW_PATH, DAYS_06_45_PATH, DAYS_46_66_PATH):
        document = json.loads(path.read_text(encoding="utf-8"))
        for lesson in document["lessons"]:
            lessons[lesson["order"] - 4] = lesson
        for day, override in document.get("allocationOverrides", {}).items():
            anchors[int(day)] = override["grammarTarget"]["anchorCanonicalID"]
    return lessons, anchors


def segment(text: str, lexicon: dict[str, list[str]]) -> list[str]:
    """Greedy longest-match catalogue segmentation of every Hanzi run."""
    found: list[str] = []
    for run in re.findall(r"[\u3400-\u4dbf\u4e00-\u9fff]+", text):
        index = 0
        while index < len(run):
            for size in range(min(MAX_LEXEME, len(run) - index), 0, -1):
                word = run[index:index + size]
                if word in lexicon:
                    found.extend(lexicon[word])
                    index += size
                    break
            else:
                index += 1
    return found


def authored_text(lesson: dict[str, Any]) -> str:
    """Every Mandarin string a learner meets in an authored lesson."""
    parts = [line["hanzi"] for line in lesson["dialogue"]["lines"]]
    parts += [paragraph["hanzi"] for paragraph in lesson["reading"]["paragraphs"]]
    parts += [example["hanzi"] for note in lesson["grammar"] for example in note["examples"]]
    for exercise in lesson["exercises"]:
        parts.append(exercise["prompt"]["fr"])
        parts += [exercise.get(key, "") for key in ("promptText", "sentence", "referenceText")]
        parts += [token["hanzi"] for token in exercise.get("tokens", [])]
    return "\n".join(parts)


def required_words(lesson: dict[str, Any], lexicon: dict[str, list[str]], by_id: dict[str, dict[str, Any]], existing_to_canonical: dict[str, str]) -> set[str]:
    """Words the authored lesson names as its focus: grammar anchors and the meaning question."""
    words = {
        canonical
        for note in lesson["grammar"]
        if (canonical := canonical_ref(note["vocabularyID"], by_id, existing_to_canonical)) is not None
    }
    meaning = next(exercise for exercise in lesson["exercises"] if exercise["id"].endswith("-meaning"))
    words.update(segment(meaning["prompt"]["fr"], lexicon))
    return words


def spread(total: int, slots: int) -> list[int]:
    """Split `total` over `slots` as evenly as possible, larger shares last."""
    return [total * (index + 1) // slots - total * index // slots for index in range(slots)]


def schedule_new_words(
    entries: list[dict[str, Any]],
    baseline: set[str],
    uses: dict[str, list[int]],
    deadlines: dict[str, int],
    extras: dict[int, int],
) -> dict[int, list[str]]:
    """Give every canonical word (rank 1–300) that is not a starter word one introduction day.

    Each lesson introduces between MIN_NEW_PER_LESSON and MAX_NEW_PER_LESSON
    words, counting the lesson's non-catalogue extras. The HSK 1 words (ranks
    1–150) are all introduced by HSK1_LAST_DAY; a word required by its lesson
    (grammar anchor, meaning question) is introduced no later than that lesson.
    Words of rank above 300 are never scheduled: they are outside the course's
    vocabulary. Within these limits the schedule minimises the (word, lesson)
    pairs where an authored text uses a word before it is introduced, and
    prefers to introduce a word in a lesson whose own text uses it.
    """
    rank = {entry["id"]: entry["rank"] for entry in entries}
    words = sorted(
        (entry["id"] for entry in entries if entry["id"] not in baseline and entry["rank"] <= CANONICAL_TARGET),
        key=rank.__getitem__,
    )
    limit = {
        word: min(deadlines.get(word, DAYS), HSK1_LAST_DAY if rank[word] <= HSK1_TARGET else DAYS)
        for word in words
    }
    phases = [
        list(range(1, HSK1_LAST_DAY + 1)),
        list(range(HSK1_LAST_DAY + 1, DAYS + 1)),
    ]
    pools = [
        {word for word in words if rank[word] <= HSK1_TARGET or deadlines.get(word, DAYS + 1) <= HSK1_LAST_DAY},
        {word for word in words if rank[word] > HSK1_TARGET and deadlines.get(word, DAYS + 1) > HSK1_LAST_DAY},
    ]

    def first_use(word: str) -> int:
        return uses.get(word, [DAYS + 1])[0]

    def cost(word: str, day: int) -> int:
        """Twice the earlier uses of the word, plus one when the day's own text never uses it."""
        days = uses.get(word, [])
        return 2 * bisect.bisect_left(days, day) + (0 if day in days else 1)

    day_of: dict[str, int] = {}
    by_day: dict[int, list[str]] = {}
    for days, pool in zip(phases, pools):
        totals = spread(len(pool) + sum(extras.get(day, 0) for day in days), len(days))
        for day, total in zip(days, totals):
            count = total - extras.get(day, 0)
            if not MIN_NEW_PER_LESSON <= total <= MAX_NEW_PER_LESSON or count < 0:
                raise ValueError(f"day {day} would introduce {total} words; expected {MIN_NEW_PER_LESSON}–{MAX_NEW_PER_LESSON}")
            chosen = sorted(pool, key=lambda word: (limit[word], first_use(word), rank[word]))[:count]
            for word in chosen:
                if limit[word] < day:
                    raise ValueError(f"{word} must be introduced by day {limit[word]} but the schedule reaches it on day {day}")
                day_of[word] = day
                pool.discard(word)
            by_day[day] = chosen

    # Swap words between days of one phase while that lowers the forward-use
    # count. Swaps keep every day's size, so the limits above stay satisfied.
    improved = True
    while improved:
        improved = False
        for days in phases:
            for word in sorted(day_of, key=lambda value: (rank[value], value)):
                if day_of[word] not in days:
                    continue
                here = day_of[word]
                best: tuple[tuple[int, int, str], str] | None = None
                for day in days:
                    if day == here or limit[word] < day:
                        continue
                    for other in by_day[day]:
                        if limit[other] < here:
                            continue
                        delta = cost(word, day) + cost(other, here) - cost(word, here) - cost(other, day)
                        if delta < 0 and (best is None or (delta, day, other) < best[0]):
                            best = ((delta, day, other), other)
                if best is not None:
                    (_, day, other), _ = best
                    by_day[here][by_day[here].index(word)] = other
                    by_day[day][by_day[day].index(other)] = word
                    day_of[word], day_of[other] = day, here
                    improved = True
    return {day: sorted(chosen, key=rank.__getitem__) for day, chosen in by_day.items()}


def reuse_refs(day: int, seen: list[str], count: int, required: set[str], attested: set[str]) -> list[str]:
    """Choose explicit retrieval IDs from already encountered canonical rows.

    Words the lesson requires come first, then words its own texts already
    use, then a stride through the earlier words.
    """
    ordered = sorted(set(seen), key=lambda value: int(value.rsplit("-", 1)[1]))
    picked = [value for value in ordered if value in required]
    target = max(count, len(picked))
    used = [value for value in ordered if value in attested and value not in required]
    if used:
        start = day % len(used)
        picked += (used[start:] + used[:start])[:target - len(picked)]
    stride = 11 if day % 2 else 7
    start = (day * stride) % len(ordered) if ordered else 0
    for offset in range(len(ordered)):
        if len(picked) >= target:
            break
        value = ordered[(start + offset * stride) % len(ordered)]
        if value not in picked:
            picked.append(value)
    return picked


def grammar_anchor(note: dict[str, Any], vocabulary: list[str], lexicon: dict[str, list[str]]) -> str:
    """The lesson word a grammar note is filed under: one its own examples use, else the lesson's first word."""
    used = {word for example in note["examples"] for word in segment(example["hanzi"], lexicon)}
    return next((word for word in vocabulary if word in used), vocabulary[0])


def build() -> dict[str, Any]:
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    entries = catalog["entries"]
    by_id = {entry["id"]: entry for entry in entries}
    existing_to_canonical = {
        item["existingVocabularyID"]: item["canonicalLexemeID"]
        for item in catalog.get("existingCourseMappings", [])
    }
    if len(DAY_THEMES) != DAYS:
        raise ValueError(f"{len(DAY_THEMES)} themes for {DAYS} lessons")
    themes_by_day = {day: DAY_THEMES[day - 1] for day in range(1, DAYS + 1)}
    lexicon: dict[str, list[str]] = {}
    for entry in entries:
        lexicon.setdefault(entry["hanzi"], []).append(entry["id"])

    # The authored texts are fixed: they decide which words a lesson needs and
    # where an early introduction costs the least.
    lessons, override_anchors = load_authored_lessons()
    baseline = set(existing_to_canonical.values())
    text_words = {day: set(segment(authored_text(lessons[day]), lexicon)) for day in range(1, DAYS + 1)}
    uses: dict[str, list[int]] = {}
    for day in range(1, DAYS + 1):
        for word in text_words[day]:
            uses.setdefault(word, []).append(day)
    required = {day: required_words(lessons[day], lexicon, by_id, existing_to_canonical) for day in range(1, DAYS + 1)}
    for day, anchor in override_anchors.items():
        required[day].add(anchor)
    deadlines: dict[str, int] = {}
    for day, words in required.items():
        for word in words:
            deadlines[word] = min(deadlines.get(word, day), day)
    extras = {day: len(lessons[day].get("extraVocabulary", [])) for day in range(1, DAYS + 1)}
    new_by_day = schedule_new_words(entries, baseline, uses, deadlines, extras)

    seen: list[str] = list(existing_to_canonical.values())
    rows: list[dict[str, Any]] = []
    for day in range(1, DAYS + 1):
        new = new_by_day[day]
        # A required word met earlier stays in the lesson as a reused row.
        needed = {word for word in required[day] if word in seen}
        reused = reuse_refs(day, seen, 3, needed, text_words[day])
        reused = [value for value in reused if value not in new]
        notes = lessons[day]["grammar"]
        vocabulary = list(dict.fromkeys(new + reused))
        authored = override_anchors.get(day) or canonical_ref(notes[0]["vocabularyID"], by_id, existing_to_canonical)
        anchor = authored if authored in vocabulary else grammar_anchor(notes[0], vocabulary, lexicon)
        rows.append({
            "day": day,
            "lessonID": f"lesson-{day + 4:02d}",
            "moduleID": module_for_day(day)["id"],
            "theme": themes_by_day[day],
            "phase": "classic-1-150" if day <= HSK1_LAST_DAY else "classic-151-300",
            "newVocabularyIDs": new,
            "reusedVocabularyIDs": reused,
            "newCanonicalIDs": new,
            "reusedCanonicalIDs": reused,
            "newCount": len(new),
            "reusedCount": len(reused),
            "grammarTarget": {"patterns": [note["pattern"] for note in notes], "anchorCanonicalID": anchor, "reviewable": True},
        })
        seen.extend(value for value in new if value not in seen)

    covered_hsk1 = baseline | {value for row in rows[:HSK1_LAST_DAY] for value in row["newCanonicalIDs"] + row["reusedCanonicalIDs"] if value in by_id}
    covered_course = baseline | {value for row in rows for value in row["newCanonicalIDs"] + row["reusedCanonicalIDs"] if value in by_id}
    required_hsk1 = {f"hsk20-{rank:03d}" for rank in range(1, HSK1_TARGET + 1)}
    required_course = {f"hsk20-{rank:03d}" for rank in range(1, CANONICAL_TARGET + 1)}
    if not required_hsk1.issubset(covered_hsk1):
        raise ValueError(f"day {HSK1_LAST_DAY} misses ranks: {sorted(required_hsk1 - covered_hsk1)[:8]}")
    if not required_course.issubset(covered_course):
        raise ValueError(f"day {DAYS} misses ranks: {sorted(required_course - covered_course)[:8]}")

    module_payload = [
        {"id": module["id"], "order": module["order"], "title": localized(module["title"]), "lessonIDs": [f"lesson-{day + 4:02d}" for day in module["days"]]}
        for module in MODULES
    ]
    reference = {"framework": "HSK", "level": "classic 2.0 / legacy", "standardID": "HSK-legacy-2.0", "standardVersion": "2.0"}
    catalog_identity = {
        "id": catalog["id"],
        "contentVersion": catalog["contentVersion"],
        "standardID": catalog["standard"]["id"],
        "standardVersion": catalog["standard"]["version"],
        "rankRanges": {"hsk1": [1, HSK1_TARGET], "course": [1, CANONICAL_TARGET]},
    }
    milestones = [
        {
            "id": f"classic-day-{HSK1_LAST_DAY}", "day": HSK1_LAST_DAY, "title": localized("Jalon : HSK classique 1"), "reference": reference,
            "coverage": {"catalogID": catalog["id"], "catalogVersion": catalog["contentVersion"], "canonicalOnly": True, "vocabularyTarget": HSK1_TARGET, "requiredRankRange": [1, HSK1_TARGET]},
            "claims": [f"Les rangs 1 à {HSK1_TARGET} du catalogue sont planifiés au plus tard au jour {HSK1_LAST_DAY}.", "Un mot rencontré ne constitue pas une preuve de maîtrise."],
        },
        {
            "id": f"classic-day-{DAYS}", "day": DAYS, "title": localized("Jalon : HSK classique 1–2"), "reference": reference,
            "coverage": {"catalogID": catalog["id"], "catalogVersion": catalog["contentVersion"], "canonicalOnly": True, "vocabularyTarget": CANONICAL_TARGET, "requiredRankRange": [1, CANONICAL_TARGET]},
            "claims": [f"Les {CANONICAL_TARGET} lexèmes canoniques des rangs 1 à {CANONICAL_TARGET} sont planifiés au plus tard au jour {DAYS}.", "Cette couverture éditoriale ne garantit pas l’acquisition."],
        },
    ]
    sessions = [
        {
            "day": day,
            "lessonID": f"lesson-{day + 4:02d}",
            # Every authored lesson is estimated at twelve minutes; reserve
            # the remaining three minutes for the due SRS review.
            "courseMinutes": 12,
            "reviewMinutes": 3,
        }
        for day in range(1, DAYS + 1)
    ]
    return {
        "schemaVersion": 1,
        "contentVersion": CONTENT_VERSION,
        "courseID": "mandarin-starter",
        "catalog": catalog_identity,
        "reference": reference,
        "baselineCanonicalIDs": sorted(baseline, key=lambda value: int(value.rsplit("-", 1)[1])),
        "allocationPolicy": {
            "phaseOneDays": [1, HSK1_LAST_DAY],
            "phaseTwoDays": [HSK1_LAST_DAY + 1, DAYS],
            "newPerLesson": [MIN_NEW_PER_LESSON, MAX_NEW_PER_LESSON],
            "authoringFiles": {"days06to45": "authoring/90-day-authoring-days-06-45.json", "days46to66": "authoring/90-day-authoring-days-46-66.json"},
        },
        "modules": module_payload,
        "milestones": milestones,
        "plan": {"targetMinutes": 15, "catalogID": catalog["id"], "catalogVersion": catalog["contentVersion"], "sessions": sessions, "milestones": milestones},
        "lessons": rows,
    }


def main() -> None:
    allocation = build()
    ALLOCATION_PATH.write_text(json.dumps(allocation, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    rows = allocation["lessons"]
    covered_hsk1 = set(allocation["baselineCanonicalIDs"]) | {value for row in rows[:HSK1_LAST_DAY] for value in row["newCanonicalIDs"] + row["reusedCanonicalIDs"]}
    covered_course = set(allocation["baselineCanonicalIDs"]) | {value for row in rows for value in row["newCanonicalIDs"] + row["reusedCanonicalIDs"]}
    print(f"wrote {ALLOCATION_PATH} ({len(rows)} days)")
    print("new counts", [row["newCount"] for row in rows])
    print("coverage", {f"day{HSK1_LAST_DAY}": len(covered_hsk1), f"day{DAYS}": len(covered_course)})


if __name__ == "__main__":
    main()
