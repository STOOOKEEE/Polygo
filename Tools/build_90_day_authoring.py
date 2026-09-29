#!/usr/bin/env python3
"""Build the editorial allocation for the 90-session classic HSK course.

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
DAYS_46_90_PATH = AUTHORING / "90-day-authoring-days-46-90.json"
ALLOCATION_PATH = AUTHORING / "90-day-allocation.json"
CONTENT_VERSION = "2026.10.0"

MIN_NEW_PER_LESSON = 6
MAX_NEW_PER_LESSON = 8
# Ranks 1–300 need 287 new words after the 13 starter words, but eight words
# per lesson only gives 8 × 29 = 232 by day 30. The HSK 1–2 milestone moves to
# the end of unit 5: from there both phases run at about 6.7 words a day.
MILESTONE_DAY = 48
REVIEW_DAYS = (30, 60, 90)
FIXED_PREVIEW_DAYS = 5
MAX_LEXEME = 4


MODULES: list[dict[str, Any]] = [
    {"id": "unit-02", "order": 2, "title": "Vie pratique", "days": range(1, 13)},
    {"id": "unit-03", "order": 3, "title": "Temps, études et santé", "days": range(13, 25)},
    {"id": "unit-04", "order": 4, "title": "Achats et déplacements", "days": range(25, 37)},
    {"id": "unit-05", "order": 5, "title": "Maison et communauté", "days": range(37, 49)},
    {"id": "unit-06", "order": 6, "title": "Études et travail", "days": range(49, 61)},
    {"id": "unit-07", "order": 7, "title": "Ville et voyage", "days": range(61, 73)},
    {"id": "unit-08", "order": 8, "title": "Météo, nature et loisirs", "days": range(73, 83)},
    {"id": "unit-09", "order": 9, "title": "Récits et opinions", "days": range(83, 91)},
]


# The order is intentional: it is the editorial route through the course,
# including the three review days.
DAY_THEMES = [
    "food", "home", "family", "time", "shopping", "home", "food", "family", "time", "travel", "routine", "daily-review",
    "study", "routine", "health", "communication", "study", "work", "time", "health", "leisure", "study", "daily-review", "health",
    "shopping", "travel", "food", "shopping", "city", "classic-checkpoint", "home", "community", "health", "study", "work", "communication",
    "city", "travel", "shopping", "home", "routine", "community", "study", "work", "communication", "health", "city", "community",
    "work", "study", "routine", "communication", "work", "health", "city", "travel", "shopping", "city", "community", "classic-checkpoint",
    "travel", "nature", "leisure", "communication", "city", "travel", "weather", "nature", "leisure", "health", "food", "nature",
    "travel", "leisure", "communication", "nature", "story", "opinion", "problem-solving", "culture", "story", "opinion",
    "communication", "story", "opinion", "problem-solving", "culture", "story", "opinion", "classic-final-checkpoint",
]


GRAMMAR_TARGETS = [
    ("在 + lieu", "在 situe une personne ou un objet dans un lieu."),
    ("也 + verbe", "也 place une information équivalente avant le verbe."),
    ("有 + nom", "有 exprime la possession ou l’existence."),
    ("这/那 + nom", "这 et 那 désignent respectivement ce qui est proche et éloigné."),
    ("几 + classificateur", "几 demande une petite quantité."),
    ("想/要 + verbe", "想 et 要 précèdent l’action souhaitée."),
    ("会/能 + verbe", "会 et 能 précèdent une capacité ou une possibilité."),
    ("正在 + verbe", "正在 indique une action en cours."),
    ("verbe + 了", "了 marque ici une action terminée."),
    ("verbe + 过", "过 indique une expérience passée."),
    ("A 比 B + adjectif", "比 introduit le terme de comparaison."),
    ("因为…所以…", "因为 présente la cause et 所以 la conséquence."),
    ("从 A 到 B", "从 et 到 encadrent un trajet ou une durée."),
    ("先…然后…", "先 présente la première action et 然后 la suivante."),
    ("一边…一边…", "一边 relie deux actions simultanées."),
    ("把 + objet + verbe", "把 place l’objet avant l’action et son résultat."),
    ("被 + agent", "被 introduit ce qui subit l’action."),
    ("虽然…但是…", "虽然 introduit une concession suivie de 但是."),
    ("如果…就…", "如果 pose une condition et 就 sa conséquence."),
    ("越来越 + adjectif", "越来越 décrit une évolution progressive."),
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
    for path in (PREVIEW_PATH, DAYS_06_45_PATH, DAYS_46_90_PATH):
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
    """Give every non-baseline catalogue word one introduction day.

    Each lesson introduces between MIN_NEW_PER_LESSON and MAX_NEW_PER_LESSON
    words, counting the lesson's non-catalogue extras. Ranks 1–300 are all
    introduced by MILESTONE_DAY; a word required by its lesson (grammar anchor,
    meaning question) is introduced no later than that lesson. Within these
    limits the schedule minimises the number of (word, lesson) pairs where an
    authored text uses a word before it is introduced.
    """
    rank = {entry["id"]: entry["rank"] for entry in entries}
    words = sorted((entry["id"] for entry in entries if entry["id"] not in baseline), key=rank.__getitem__)
    limit = {
        word: min(deadlines.get(word, 90), MILESTONE_DAY if rank[word] <= 300 else 90)
        for word in words
    }
    slots = [day for day in range(1, 91) if day not in REVIEW_DAYS]
    phases = [
        [day for day in slots if day <= MILESTONE_DAY],
        [day for day in slots if day > MILESTONE_DAY],
    ]
    pools = [
        {word for word in words if rank[word] <= 300 or deadlines.get(word, 91) <= MILESTONE_DAY},
        {word for word in words if rank[word] > 300 and deadlines.get(word, 91) > MILESTONE_DAY},
    ]

    def first_use(word: str) -> int:
        return uses.get(word, [91])[0]

    def cost(word: str, day: int) -> int:
        return bisect.bisect_left(uses.get(word, []), day)

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


def grammar_target(day: int, anchor: str | None, patterns: list[str] | None = None) -> dict[str, Any]:
    selected = patterns or [GRAMMAR_TARGETS[(day - 6) % len(GRAMMAR_TARGETS)][0]]
    return {"patterns": selected, "anchorCanonicalID": anchor, "reviewable": True}


def build() -> dict[str, Any]:
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    entries = catalog["entries"]
    by_id = {entry["id"]: entry for entry in entries}
    existing_to_canonical = {
        item["existingVocabularyID"]: item["canonicalLexemeID"]
        for item in catalog.get("existingCourseMappings", [])
    }
    themes_by_day = {day: DAY_THEMES[day - 1] for day in range(1, 91)}
    lexicon: dict[str, list[str]] = {}
    for entry in entries:
        lexicon.setdefault(entry["hanzi"], []).append(entry["id"])

    # The authored texts are fixed: they decide which words a lesson needs and
    # where an early introduction costs the least.
    lessons, override_anchors = load_authored_lessons()
    baseline = set(existing_to_canonical.values())
    text_words = {day: set(segment(authored_text(lessons[day]), lexicon)) for day in range(1, 91)}
    uses: dict[str, list[int]] = {}
    for day in range(1, 91):
        for word in text_words[day]:
            uses.setdefault(word, []).append(day)
    required = {day: required_words(lessons[day], lexicon, by_id, existing_to_canonical) for day in range(1, 91)}
    for day, anchor in override_anchors.items():
        required[day].add(anchor)
    deadlines: dict[str, int] = {}
    for day, words in required.items():
        for word in words:
            deadlines[word] = min(deadlines.get(word, day), day)
    extras = {day: len(lessons[day].get("extraVocabulary", [])) for day in range(1, 91)}
    new_by_day = schedule_new_words(entries, baseline, uses, deadlines, extras)

    seen: list[str] = list(existing_to_canonical.values())
    rows: list[dict[str, Any]] = []
    for day in range(1, 91):
        checkpoint = day in REVIEW_DAYS
        new = [] if checkpoint else new_by_day[day]
        # A required word met earlier stays in the lesson as a reused row.
        needed = {word for word in required[day] if word in seen}
        reused = reuse_refs(day, seen, 10 if checkpoint else 3, needed, text_words[day])
        reused = [value for value in reused if value not in new]
        if day <= FIXED_PREVIEW_DAYS:
            patterns = [note["pattern"] for note in lessons[day]["grammar"]]
            anchor = canonical_ref(lessons[day]["grammar"][0]["vocabularyID"], by_id, existing_to_canonical)
        else:
            patterns = ["rappel guidé des structures précédentes"] if checkpoint else None
            anchor = new[0] if new else (reused[0] if reused else (seen[0] if seen else None))
        rows.append({
            "day": day,
            "lessonID": f"lesson-{day + 4:02d}",
            "moduleID": module_for_day(day)["id"],
            "theme": themes_by_day[day],
            "phase": "classic-1-300" if day <= MILESTONE_DAY else "classic-301-600",
            "newVocabularyIDs": new,
            "reusedVocabularyIDs": reused,
            "newCanonicalIDs": new,
            "reusedCanonicalIDs": reused,
            "newCount": len(new),
            "reusedCount": len(reused),
            "grammarTarget": grammar_target(day, anchor, patterns),
            "checkpoint": checkpoint,
        })
        seen.extend(value for value in new if value not in seen)

    covered_milestone = baseline | {value for row in rows[:MILESTONE_DAY] for value in row["newCanonicalIDs"] + row["reusedCanonicalIDs"] if value in by_id}
    covered_day90 = baseline | {value for row in rows for value in row["newCanonicalIDs"] + row["reusedCanonicalIDs"] if value in by_id}
    required_300 = {f"hsk20-{rank:03d}" for rank in range(1, 301)}
    required_600 = {f"hsk20-{rank:03d}" for rank in range(1, 601)}
    if not required_300.issubset(covered_milestone):
        raise ValueError(f"day {MILESTONE_DAY} misses ranks: {sorted(required_300 - covered_milestone)[:8]}")
    if not required_600.issubset(covered_day90):
        raise ValueError(f"day 90 misses ranks: {sorted(required_600 - covered_day90)[:8]}")

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
        "rankRanges": {"day40": [1, 300], "day90": [1, 600]},
    }
    milestones = [
        {
            "id": f"classic-day-{MILESTONE_DAY}", "day": MILESTONE_DAY, "title": localized("Jalon : HSK classique 1–2"), "reference": reference,
            "coverage": {"catalogID": catalog["id"], "catalogVersion": catalog["contentVersion"], "canonicalOnly": True, "vocabularyTarget": 300, "requiredRankRange": [1, 300]},
            "claims": [f"Les rangs 1 à 300 du catalogue sont planifiés au plus tard au jour {MILESTONE_DAY}.", "Un mot rencontré ne constitue pas une preuve de maîtrise."],
        },
        {
            "id": "classic-day-60", "day": 60, "title": localized("Jalon intermédiaire : consolidation"), "reference": reference,
            "claims": ["Le jour 60 est un bilan de réemploi ; aucun nouveau seuil de catalogue n’est revendiqué."],
        },
        {
            "id": "classic-day-90", "day": 90, "title": localized("Jalon : catalogue HSK classique complet"), "reference": reference,
            "coverage": {"catalogID": catalog["id"], "catalogVersion": catalog["contentVersion"], "canonicalOnly": True, "vocabularyTarget": 600, "requiredRankRange": [1, 600]},
            "claims": ["Les 600 lexèmes canoniques du catalogue sont planifiés dans les 90 séances.", "Cette couverture éditoriale ne garantit pas l’acquisition."],
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
        for day in range(1, 91)
    ]
    return {
        "schemaVersion": 1,
        "contentVersion": CONTENT_VERSION,
        "courseID": "mandarin-starter",
        "catalog": catalog_identity,
        "reference": reference,
        "baselineCanonicalIDs": sorted(baseline, key=lambda value: int(value.rsplit("-", 1)[1])),
        "allocationPolicy": {
            "phaseOneDays": [1, MILESTONE_DAY],
            "phaseTwoDays": [MILESTONE_DAY + 1, 90],
            "newPerLesson": [MIN_NEW_PER_LESSON, MAX_NEW_PER_LESSON],
            "checkpointDays": [30, 60, 90],
            "authoringFiles": {"days06to45": "authoring/90-day-authoring-days-06-45.json", "days46to90": "authoring/90-day-authoring-days-46-90.json"},
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
    covered_milestone = set(allocation["baselineCanonicalIDs"]) | {value for row in rows[:MILESTONE_DAY] for value in row["newCanonicalIDs"] + row["reusedCanonicalIDs"]}
    covered90 = set(allocation["baselineCanonicalIDs"]) | {value for row in rows for value in row["newCanonicalIDs"] + row["reusedCanonicalIDs"]}
    print(f"wrote {ALLOCATION_PATH} ({len(rows)} days)")
    print("new counts", [row["newCount"] for row in rows])
    print("coverage", {f"day{MILESTONE_DAY}": len(covered_milestone), "day90": len(covered90)})


if __name__ == "__main__":
    main()
