#!/usr/bin/env python3
"""Assemble the reviewed 90-session Mandarin authoring pack.

The course is authored in three independently reviewable lesson fragments:
the fixed five-session preview, days 6–45, and days 46–90.  This script only
joins those documents and copies the allocation's modules and day plan.  It
does not derive or rewrite any Mandarin, pinyin, translation, answer, or
example sentence.
"""
from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
AUTHORING = ROOT / "Content" / "authoring"
PREVIEW_PATH = AUTHORING / "preview-first-five.json"
DAYS_06_45_PATH = AUTHORING / "90-day-authoring-days-06-45.json"
DAYS_46_90_PATH = AUTHORING / "90-day-authoring-days-46-90.json"
ALLOCATION_PATH = AUTHORING / "90-day-allocation.json"
OUTPUT_PATH = AUTHORING / "90-day-authoring.json"
CONTENT_VERSION = "2026.10.0"
COURSE_ID = "mandarin-starter"


class AssemblyError(ValueError):
    """A source fragment does not match the release allocation."""


def load(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise AssemblyError(f"missing source fragment: {path}") from exc
    except json.JSONDecodeError as exc:
        raise AssemblyError(f"invalid JSON in {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise AssemblyError(f"{path}: expected an object")
    return value


def non_empty_string(value: Any, context: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise AssemblyError(f"{context}: expected a non-empty string")
    return value


def check_version(document: dict[str, Any], path: Path) -> None:
    if document.get("schemaVersion") != 1:
        raise AssemblyError(f"{path}.schemaVersion: expected 1")
    if document.get("contentVersion") != CONTENT_VERSION:
        raise AssemblyError(f"{path}.contentVersion: expected {CONTENT_VERSION}")


def lesson_map(document: dict[str, Any], path: Path) -> dict[str, dict[str, Any]]:
    lessons = document.get("lessons")
    if not isinstance(lessons, list) or not lessons:
        raise AssemblyError(f"{path}.lessons: expected a non-empty array")
    result: dict[str, dict[str, Any]] = {}
    for index, lesson in enumerate(lessons):
        if not isinstance(lesson, dict):
            raise AssemblyError(f"{path}.lessons[{index}]: expected an object")
        lesson_id = non_empty_string(lesson.get("id"), f"{path}.lessons[{index}].id")
        if lesson_id in result:
            raise AssemblyError(f"{path}.lessons: duplicate lesson '{lesson_id}'")
        result[lesson_id] = lesson
    return result


def expected_lesson_id(day: int) -> str:
    return f"lesson-{day + 4:02d}"


def assemble() -> dict[str, Any]:
    preview = load(PREVIEW_PATH)
    days_06_45 = load(DAYS_06_45_PATH)
    days_46_90 = load(DAYS_46_90_PATH)
    allocation = load(ALLOCATION_PATH)
    for document, path in (
        (preview, PREVIEW_PATH),
        (days_06_45, DAYS_06_45_PATH),
        (days_46_90, DAYS_46_90_PATH),
        (allocation, ALLOCATION_PATH),
    ):
        check_version(document, path)

    if preview.get("course", {}).get("id") != COURSE_ID:
        raise AssemblyError(f"{PREVIEW_PATH}.course.id: expected {COURSE_ID}")
    if days_46_90.get("courseID") != COURSE_ID:
        raise AssemblyError(f"{DAYS_46_90_PATH}.courseID: expected {COURSE_ID}")
    if allocation.get("courseID") != COURSE_ID:
        raise AssemblyError(f"{ALLOCATION_PATH}.courseID: expected {COURSE_ID}")

    allocation_rows = allocation.get("lessons")
    if not isinstance(allocation_rows, list) or len(allocation_rows) != 90:
        raise AssemblyError(f"{ALLOCATION_PATH}.lessons: expected 90 day rows")
    rows_by_day: dict[int, dict[str, Any]] = {}
    for index, row in enumerate(allocation_rows):
        if not isinstance(row, dict) or not isinstance(row.get("day"), int):
            raise AssemblyError(f"{ALLOCATION_PATH}.lessons[{index}]: expected a day row")
        day = row["day"]
        if day in rows_by_day:
            raise AssemblyError(f"{ALLOCATION_PATH}.lessons: duplicate day {day}")
        rows_by_day[day] = row
    if set(rows_by_day) != set(range(1, 91)):
        raise AssemblyError(f"{ALLOCATION_PATH}.lessons: expected contiguous days 1–90")

    fragments = (
        (1, 5, lesson_map(preview, PREVIEW_PATH)),
        (6, 45, lesson_map(days_06_45, DAYS_06_45_PATH)),
        (46, 90, lesson_map(days_46_90, DAYS_46_90_PATH)),
    )
    lessons: list[dict[str, Any]] = []
    seen_lesson_ids: set[str] = set()
    for start, end, fragment_lessons in fragments:
        expected_ids = {expected_lesson_id(day) for day in range(start, end + 1)}
        if set(fragment_lessons) != expected_ids:
            missing = sorted(expected_ids - set(fragment_lessons))
            extra = sorted(set(fragment_lessons) - expected_ids)
            raise AssemblyError(
                f"lesson fragment days {start}–{end}: IDs differ; missing={missing}, extra={extra}"
            )
        for day in range(start, end + 1):
            lesson_id = expected_lesson_id(day)
            lesson = copy.deepcopy(fragment_lessons[lesson_id])
            row = rows_by_day[day]
            if lesson.get("moduleID") != row.get("moduleID"):
                raise AssemblyError(f"day {day}: lesson moduleID differs from allocation")
            if lesson.get("order") != day + 4:
                raise AssemblyError(f"day {day}: lesson order differs from allocation")
            if lesson_id in seen_lesson_ids:
                raise AssemblyError(f"duplicate assembled lesson '{lesson_id}'")
            seen_lesson_ids.add(lesson_id)
            lessons.append(lesson)
    if len(lessons) != 90:
        raise AssemblyError(f"assembled lessons: expected 90, got {len(lessons)}")

    modules = allocation.get("modules")
    if not isinstance(modules, list) or not modules:
        raise AssemblyError(f"{ALLOCATION_PATH}.modules: expected a non-empty array")
    module_ids: set[str] = set()
    listed_ids: list[str] = []
    for index, module in enumerate(modules):
        if not isinstance(module, dict):
            raise AssemblyError(f"{ALLOCATION_PATH}.modules[{index}]: expected an object")
        module_id = non_empty_string(module.get("id"), f"{ALLOCATION_PATH}.modules[{index}].id")
        if module_id in module_ids:
            raise AssemblyError(f"{ALLOCATION_PATH}.modules: duplicate module '{module_id}'")
        module_ids.add(module_id)
        module_lessons = module.get("lessonIDs")
        if not isinstance(module_lessons, list) or not module_lessons:
            raise AssemblyError(f"{ALLOCATION_PATH}.modules[{index}].lessonIDs: expected a non-empty array")
        listed_ids.extend(non_empty_string(value, f"{ALLOCATION_PATH}.modules[{index}].lessonIDs") for value in module_lessons)
    if set(listed_ids) != seen_lesson_ids or len(listed_ids) != len(seen_lesson_ids):
        raise AssemblyError(f"{ALLOCATION_PATH}.modules.lessonIDs: must list each assembled lesson exactly once")

    plan = allocation.get("plan")
    if not isinstance(plan, dict):
        raise AssemblyError(f"{ALLOCATION_PATH}.plan: expected an object")
    sessions = plan.get("sessions")
    if not isinstance(sessions, list) or len(sessions) != 90:
        raise AssemblyError(f"{ALLOCATION_PATH}.plan.sessions: expected 90 sessions")
    for index, session in enumerate(sessions):
        if not isinstance(session, dict):
            raise AssemblyError(f"{ALLOCATION_PATH}.plan.sessions[{index}]: expected an object")
        day = session.get("day")
        lesson_id = session.get("lessonID")
        if day != index + 1 or lesson_id != expected_lesson_id(index + 1):
            raise AssemblyError(f"{ALLOCATION_PATH}.plan.sessions[{index}]: day and lessonID are out of sequence")
        if session.get("courseMinutes", 0) + session.get("reviewMinutes", 0) != plan.get("targetMinutes"):
            raise AssemblyError(f"{ALLOCATION_PATH}.plan.sessions[{index}]: budget does not total targetMinutes")
        lesson = next(item for item in lessons if item["id"] == lesson_id)
        if session.get("courseMinutes") != lesson.get("estimatedMinutes"):
            raise AssemblyError(f"day {index + 1}: courseMinutes must match lesson.estimatedMinutes")
        if session.get("reviewMinutes") != plan.get("targetMinutes") - lesson.get("estimatedMinutes"):
            raise AssemblyError(f"day {index + 1}: reviewMinutes must fill the target budget")

    source_course = copy.deepcopy(preview["course"])
    source_course.update(
        {
            "id": COURSE_ID,
            "slug": COURSE_ID,
            "title": {"fr": "Mandarin au quotidien — parcours de 90 jours"},
            "description": {
                "fr": "Un parcours de 90 séances pour comprendre, produire et réemployer le mandarin du quotidien. Repère HSK classique 2.0 / legacy ; la couverture décrit les lexèmes rencontrés et ne garantit ni maîtrise ni score d’examen."
            },
            # Keep the transition reference explicit: this release's plan is
            # aligned to the versioned classic HSK list only.
            "alignment": [
                {
                    "framework": "HSK",
                    "level": "classic 2.0 / legacy",
                    "standardID": "HSK-legacy-2.0",
                    "standardVersion": "2.0",
                    "status": "reference-transition",
                }
            ],
            # The learner-facing course follows the versioned classic HSK
            # list. Keep the newer HSK reference in a separate, explicitly
            # non-alignment field for the migration audit.
            "metadata": {
                "standardID": "HSK-legacy-2.0",
                "standardVersion": "2.0",
                "legacyStandardID": "HSK-legacy-2.0",
                "legacyStandardVersion": "2.0",
                "comparisonStandardID": "HSK-3.0",
                "comparisonStandardVersion": "2025-11",
                "comparisonStandardRole": "design-reference-only",
                "transitionStatus": "primary-classic-legacy-2.0",
                "examClaim": "none",
                "scriptPolicy": "simplified-and-traditional",
                "starterLessonCount": 4,
                "plannedSessionCount": 90,
                "availableLessonCount": 94,
                "canonicalVocabularyCount": 600,
            },
            "standardReferences": [
                {
                    "framework": "HSK",
                    "level": "new HSK 3.0",
                    "standardID": "HSK-3.0",
                    "standardVersion": "2025-11",
                    "status": "design-reference-only",
                }
            ],
            "plan": copy.deepcopy(plan),
        }
    )

    catalog = preview.get("catalog")
    if catalog != "authoring/hsk-legacy-600.json":
        raise AssemblyError(f"{PREVIEW_PATH}.catalog: expected authoring/hsk-legacy-600.json")

    return {
        "schemaVersion": 1,
        "contentVersion": CONTENT_VERSION,
        "course": source_course,
        "catalog": catalog,
        "modules": copy.deepcopy(modules),
        "lessons": lessons,
    }


def main() -> None:
    output = assemble()
    OUTPUT_PATH.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {OUTPUT_PATH} ({len(output['lessons'])} lessons, {len(output['modules'])} modules)")


if __name__ == "__main__":
    main()
