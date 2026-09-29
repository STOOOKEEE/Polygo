#!/usr/bin/env python3
"""Generate and lint Polygo's JSON content.

Release authors compact lesson blueprints and a shared HSK catalogue. This
tool expands them into the Codable bundle consumed by PolygoCore and checks
cross-document invariants that one Swift decoder cannot see. It never invents
Mandarin text, pinyin, translations, examples, or exercise answers.
"""

from __future__ import annotations

import argparse
import copy
import json
import re
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Any, Iterable

from exercise_expansion import (
    EXERCISE_BUDGET,
    MAX_NEW_WORDS,
    MIN_EXPOSURE_KINDS,
    MIN_EXPOSURES,
    PHASES,
    ExpansionError,
    expand_lesson_exercises,
    exposure_shortfalls,
    lesson_number,
    word_exposures,
)
from exercise_kinds import (
    CONVERSATION_REPLIES,
    DIALOGUE_ORDER_LINES,
    DICTATION_SCRIPTS,
    MATCHING_PAIRS,
    MIN_NEW_KINDS,
    NEW_KINDS,
    entry_tones,
    tone_choice_id,
)
from review_lessons import (
    BOSS,
    BOSS_KINDS,
    DERIVED_KINDS,
    DERIVED_BUDGET,
    REVIEW,
    REVIEW_EVERY,
    SESSION_MINUTES,
    build_derived_lessons,
    introduction_examples,
    is_derived,
)
from pinyin_module import PinyinError, add_to_course, build_lessons, check_lesson, check_structure, is_pinyin


SCHEMA_VERSION = 1
HSK_LEGACY_STANDARD_ID = "HSK-legacy-2.0"
HSK_LEGACY_STANDARD_VERSION = "2.0"
PROTECTED_LEGACY_LESSONS = {"lesson-01", "lesson-02", "lesson-03", "lesson-04"}
PINYIN_MODULE_FILE = "pinyin-module.json"


class ContentError(Exception):
    """An authoring or generated-content contract violation."""


def load_json(path: Path) -> Any:
    try:
        with path.open(encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ContentError(f"missing JSON document: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ContentError(f"invalid JSON in {path}: {exc}") from exc


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(value, ensure_ascii=False, indent=2) + "\n"
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as handle:
        handle.write(payload)
        temporary = Path(handle.name)
    temporary.replace(path)


def require(mapping: dict[str, Any], key: str, context: str) -> Any:
    if key not in mapping:
        raise ContentError(f"{context}: missing '{key}'")
    return mapping[key]


def string(value: Any, context: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ContentError(f"{context}: expected a non-empty string")
    return value


def integer(value: Any, context: str, *, minimum: int | None = None) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise ContentError(f"{context}: expected an integer")
    if minimum is not None and value < minimum:
        raise ContentError(f"{context}: expected an integer >= {minimum}")
    return value


def localized(value: Any, context: str) -> dict[str, str]:
    if not isinstance(value, dict) or not value:
        raise ContentError(f"{context}: expected a non-empty language map")
    for language, text in value.items():
        string(language, f"{context} language")
        string(text, f"{context}.{language}")
    return value


def unique(values: Iterable[str], context: str) -> None:
    seen: set[str] = set()
    for value in values:
        if value in seen:
            raise ContentError(f"{context}: duplicate '{value}'")
        seen.add(value)


def all_lesson_files(root: Path) -> dict[str, dict[str, Any]]:
    lessons: dict[str, dict[str, Any]] = {}
    for path in sorted((root / "lessons").glob("*.json")):
        value = load_json(path)
        if not isinstance(value, dict):
            raise ContentError(f"{path}: expected an object")
        lesson_id = string(require(value, "id", str(path)), str(path) + ".id")
        if lesson_id in lessons:
            raise ContentError(f"duplicate lesson document '{lesson_id}'")
        lessons[lesson_id] = value
    return lessons


def exercise_specs(lesson: dict[str, Any]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for block in lesson.get("blocks", []):
        if isinstance(block, dict) and block.get("kind") == "exercise" and isinstance(block.get("spec"), dict):
            result.append(block["spec"])
    return result


def catalog_entry_key(entry: dict[str, Any], context: str) -> tuple[str, str]:
    entry_id = string(require(entry, "id", context), context + ".id")
    lexeme_key = string(require(entry, "lexemeKey", context), context + ".lexemeKey")
    return entry_id, lexeme_key


def validate_catalog(catalog: dict[str, Any], context: str = "catalog") -> dict[str, Any]:
    standard = require(catalog, "standard", context)
    if not isinstance(standard, dict):
        raise ContentError(f"{context}.standard: expected an object")
    standard_id = string(require(standard, "id", context + ".standard"), context + ".standard.id")
    standard_version = string(require(standard, "version", context + ".standard"), context + ".standard.version")
    if standard_id != HSK_LEGACY_STANDARD_ID or standard_version != HSK_LEGACY_STANDARD_VERSION:
        raise ContentError(f"{context}: expected {HSK_LEGACY_STANDARD_ID}/{HSK_LEGACY_STANDARD_VERSION}")
    entries = require(catalog, "entries", context)
    if not isinstance(entries, list) or not entries:
        raise ContentError(f"{context}.entries: expected a non-empty array")
    by_id: dict[str, dict[str, Any]] = {}
    by_lexeme: dict[str, dict[str, Any]] = {}
    ranks: list[int] = []
    for index, entry in enumerate(entries):
        location = f"{context}.entries[{index}]"
        if not isinstance(entry, dict):
            raise ContentError(f"{location}: expected an object")
        entry_id, lexeme_key = catalog_entry_key(entry, location)
        rank = integer(require(entry, "rank", location), location + ".rank", minimum=1)
        string(require(entry, "hanzi", location), location + ".hanzi")
        string(require(entry, "pinyin", location), location + ".pinyin")
        string(require(entry, "meaningFr", location), location + ".meaningFr")
        if entry.get("example") is not None:
            example_location = location + ".example"
            example = entry["example"]
            if not isinstance(example, dict):
                raise ContentError(f"{example_location}: expected an object")
            string(require(example, "hanzi", example_location), example_location + ".hanzi")
            string(require(example, "pinyin", example_location), example_location + ".pinyin")
            translation = example.get("translationFr")
            if translation is None:
                translation = (example.get("translation") or {}).get("fr") if isinstance(example.get("translation"), dict) else None
            string(translation, example_location + ".translationFr")
        if entry_id in by_id or lexeme_key in by_lexeme:
            raise ContentError(f"{location}: duplicate id or lexemeKey")
        by_id[entry_id] = entry
        by_lexeme[lexeme_key] = entry
        ranks.append(rank)
    if ranks != list(range(1, len(ranks) + 1)):
        raise ContentError(f"{context}.entries.rank: expected contiguous ranks starting at 1")
    if len(entries) < 600:
        raise ContentError(f"{context}.entries: expected at least 600 official entries")
    catalog_id = string(require(catalog, "id", context), context + ".id")
    catalog_version = string(require(catalog, "contentVersion", context), context + ".contentVersion")
    existing_mappings = catalog.get("existingCourseMappings", [])
    if not isinstance(existing_mappings, list):
        raise ContentError(f"{context}.existingCourseMappings: expected an array")
    by_existing_id: dict[str, str] = {}
    by_catalog_id: dict[str, str] = {}
    for index, mapping in enumerate(existing_mappings):
        location = f"{context}.existingCourseMappings[{index}]"
        if not isinstance(mapping, dict):
            raise ContentError(f"{location}: expected an object")
        existing_id = string(require(mapping, "existingVocabularyID", location), location + ".existingVocabularyID")
        mapped_id = string(require(mapping, "canonicalLexemeID", location), location + ".canonicalLexemeID")
        if existing_id in by_existing_id or mapped_id in by_catalog_id:
            raise ContentError(f"{location}: duplicate vocabulary mapping")
        if mapped_id not in by_id:
            raise ContentError(f"{location}: unknown catalog entry '{mapped_id}'")
        by_existing_id[existing_id] = mapped_id
        by_catalog_id[mapped_id] = existing_id
    return {
        "id": catalog_id,
        # `version` identifies this shipped catalog payload. The normative
        # HSK version remains available separately as `standardVersion`.
        "version": catalog_version,
        "standardID": standard_id,
        "standardVersion": standard_version,
        "byID": by_id,
        "byLexeme": by_lexeme,
        "existingByVocabularyID": by_existing_id,
        "existingByCatalogID": by_catalog_id,
    }


def merge_catalog_examples(catalog: dict[str, Any], sidecar: dict[str, Any], context: str) -> dict[str, Any]:
    """Attach explicitly authored example sentences to catalogue entries.

    Examples are kept in a separate editorial file so a large lexical source
    can be reviewed independently.  The merge happens in memory before
    `catalog_vocab` creates lesson-local entries; it never derives a sentence
    from a gloss or from a vocabulary ID.
    """
    examples = sidecar.get("examples")
    if not isinstance(examples, dict):
        raise ContentError(f"{context}.examples: expected an object")
    sidecar_catalog = sidecar.get("catalog")
    if not isinstance(sidecar_catalog, dict):
        raise ContentError(f"{context}.catalog: expected an object")
    catalog_id = string(require(catalog, "id", "catalog"), "catalog.id")
    catalog_version = string(require(catalog, "contentVersion", "catalog"), "catalog.contentVersion")
    if string(require(sidecar_catalog, "id", f"{context}.catalog"), f"{context}.catalog.id") != catalog_id:
        raise ContentError(f"{context}.catalog.id: expected '{catalog_id}'")
    if string(require(sidecar_catalog, "contentVersion", f"{context}.catalog"), f"{context}.catalog.contentVersion") != catalog_version:
        raise ContentError(f"{context}.catalog.contentVersion: expected '{catalog_version}'")
    standard = require(catalog, "standard", "catalog")
    if not isinstance(standard, dict):
        raise ContentError("catalog.standard: expected an object")
    standard_id = string(require(standard, "id", "catalog.standard"), "catalog.standard.id")
    standard_version = string(require(standard, "version", "catalog.standard"), "catalog.standard.version")
    if string(require(sidecar_catalog, "standardID", f"{context}.catalog"), f"{context}.catalog.standardID") != standard_id:
        raise ContentError(f"{context}.catalog.standardID: expected '{standard_id}'")
    if string(require(sidecar_catalog, "standardVersion", f"{context}.catalog"), f"{context}.catalog.standardVersion") != standard_version:
        raise ContentError(f"{context}.catalog.standardVersion: expected '{standard_version}'")
    value_range = sidecar.get("range")
    if not isinstance(value_range, list) or len(value_range) != 2:
        raise ContentError(f"{context}.range: expected [start, end]")
    start = integer(value_range[0], f"{context}.range[0]", minimum=1)
    end = integer(value_range[1], f"{context}.range[1]", minimum=start)
    catalog_entries = {entry.get("id"): entry for entry in catalog.get("entries", []) if isinstance(entry, dict)}
    for reference, authored in examples.items():
        reference = string(reference, f"{context}.examples key")
        target = catalog_entries.get(reference)
        if target is None:
            raise ContentError(f"{context}.examples.{reference}: unknown catalogue entry")
        rank = integer(require(target, "rank", f"{context}.examples.{reference}"), f"{context}.examples.{reference}.rank", minimum=1)
        if not start <= rank <= end:
            raise ContentError(f"{context}.examples.{reference}: rank {rank} is outside {start}–{end}")
        if not isinstance(authored, dict):
            raise ContentError(f"{context}.examples.{reference}: expected an object")
        hanzi = string(require(authored, "hanzi", f"{context}.examples.{reference}"), f"{context}.examples.{reference}.hanzi")
        pinyin = string(require(authored, "pinyin", f"{context}.examples.{reference}"), f"{context}.examples.{reference}.pinyin")
        translation = authored.get("translation")
        if not isinstance(translation, dict) or "fr" not in translation:
            raise ContentError(f"{context}.examples.{reference}.translation: expected a French translation")
        translation = localized(translation, f"{context}.examples.{reference}.translation")
        target["example"] = {
            "hanzi": hanzi,
            "pinyin": pinyin,
            "translation": copy.deepcopy(translation),
            "audio": copy.deepcopy(authored.get("audio")),
        }
    return catalog


def find_catalog(root: Path, source: dict[str, Any] | None = None, source_path: Path | None = None) -> tuple[dict[str, Any], dict[str, Any]] | None:
    """Return (raw catalog, normalized index), if the course has one."""
    raw: Any = source.get("catalog") if isinstance(source, dict) else None
    if raw is None:
        candidate = root / "authoring" / "hsk-legacy-600.json"
        if candidate.exists():
            raw = str(candidate.relative_to(root))
    if raw is None:
        return None
    catalog_path: Path | None = None
    if isinstance(raw, str):
        path = Path(raw)
        if not path.is_absolute():
            root_candidate = root / path
            source_candidate = (source_path.parent / path) if source_path else path
            path = root_candidate if root_candidate.exists() else source_candidate
        catalog_path = path
        catalog = load_json(path)
    elif isinstance(raw, dict) and "path" in raw:
        path = Path(string(raw["path"], "authoring.catalog.path"))
        if not path.is_absolute():
            root_candidate = root / path
            source_candidate = (source_path.parent / path) if source_path else path
            path = root_candidate if root_candidate.exists() else source_candidate
        catalog_path = path
        catalog = load_json(path)
    elif isinstance(raw, dict):
        catalog = raw
    else:
        raise ContentError("authoring.catalog: expected a path or object")
    if not isinstance(catalog, dict):
        raise ContentError("catalog: expected an object")
    # Example sentences are split into reviewable rank ranges beside the
    # shared catalogue. Merge every matching sidecar in deterministic order so
    # both the early and late course vocabulary rows receive their authored
    # examples. Older authoring packs remain valid when no sidecar exists.
    sidecar_candidates: list[Path] = []
    if catalog_path is not None:
        sidecar_candidates.extend(sorted(catalog_path.parent.glob("hsk-legacy-examples-*.json")))
    sidecar_candidates.extend(sorted((root / "authoring").glob("hsk-legacy-examples-*.json")))
    if source_path is not None:
        sidecar_candidates.extend(sorted(source_path.parent.glob("hsk-legacy-examples-*.json")))
    seen_sidecars: set[Path] = set()
    seen_sidecar_names: set[str] = set()
    seen_examples: set[str] = set()
    for candidate in sidecar_candidates:
        sidecar_path = candidate.resolve()
        # A staged generation may receive the authoring input from the
        # original Content tree while the catalogue is copied into a
        # temporary root. Those are different absolute paths containing the
        # same sidecar; the catalogue-adjacent copy wins deterministically.
        if sidecar_path in seen_sidecars or sidecar_path.name in seen_sidecar_names or not sidecar_path.exists():
            continue
        seen_sidecars.add(sidecar_path)
        seen_sidecar_names.add(sidecar_path.name)
        sidecar = load_json(sidecar_path)
        if not isinstance(sidecar, dict):
            raise ContentError(f"{sidecar_path}: expected an object")
        sidecar_examples = sidecar.get("examples")
        if not isinstance(sidecar_examples, dict):
            raise ContentError(f"{sidecar_path}.examples: expected an object")
        duplicate_examples = sorted(set(sidecar_examples) & seen_examples)
        if duplicate_examples:
            raise ContentError(f"{sidecar_path}: duplicate example references: {', '.join(duplicate_examples[:8])}")
        merge_catalog_examples(catalog, sidecar, str(sidecar_path))
        seen_examples.update(sidecar_examples)
    return catalog, validate_catalog(catalog)


def catalog_vocab(entry: dict[str, Any], catalog_info: dict[str, Any]) -> dict[str, Any]:
    """Convert the release catalogue's compact lexical row to a local entry."""
    entry_id, lexeme_key = catalog_entry_key(entry, "catalog entry")
    result: dict[str, Any] = {
        "id": "vocab-" + entry_id,
        "canonicalID": lexeme_key,
        "hanzi": entry["hanzi"],
        "pinyin": entry["pinyin"],
        "toneNumbers": copy.deepcopy(entry.get("toneNumbers", [])),
        # One whole-word segment makes every catalog entry selectable while
        # preserving the authored lexical surface and reading.
        "segmentation": [{
            "surface": entry["hanzi"],
            "vocabularyID": "vocab-" + entry_id,
            "pinyin": entry["pinyin"],
        }],
        "partOfSpeech": entry.get("partOfSpeech"),
        "grammarNotes": [],
        "meaning": {"fr": entry["meaningFr"]},
        "audio": None,
        "example": None,
        "memoryStory": None,
        "metadata": {
            "catalogID": catalog_info["id"],
            "catalogVersion": catalog_info["version"],
            "canonicalID": lexeme_key,
            "standardID": catalog_info["standardID"],
            "standardVersion": catalog_info["standardVersion"],
            "rank": entry["rank"],
            "level": entry.get("level"),
        },
    }
    authored_example = entry.get("example")
    if authored_example is not None:
        if isinstance(authored_example.get("translation"), dict):
            translation = copy.deepcopy(authored_example["translation"])
        else:
            translation = {"fr": authored_example["translationFr"]}
        result["example"] = {
            "hanzi": authored_example["hanzi"],
            "pinyin": authored_example["pinyin"],
            "translation": translation,
            "audio": copy.deepcopy(authored_example.get("audio")),
        }
    if entry.get("traditionalHanzi"):
        result["traditionalHanzi"] = entry["traditionalHanzi"]
    return result


def resolve_catalog_or_existing(ref: str, existing_vocab: dict[str, dict[str, Any]], catalog_info: dict[str, Any] | None) -> tuple[str, dict[str, Any]] | None:
    if ref in existing_vocab:
        return ref, copy.deepcopy(existing_vocab[ref])
    if catalog_info is None:
        return None
    entry = catalog_info["byID"].get(ref) or catalog_info["byLexeme"].get(ref)
    if entry is None and ref.startswith("vocab-"):
        entry = catalog_info["byID"].get(ref.removeprefix("vocab-"))
    if entry is None:
        return None
    # Keep the original protected vocabulary/card object when the authoring
    # pack references its canonical catalog ID. This avoids duplicate cards
    # and preserves the legacy payload byte-for-byte.
    mapped_existing_id = catalog_info["existingByCatalogID"].get(entry["id"])
    if mapped_existing_id in existing_vocab:
        return mapped_existing_id, copy.deepcopy(existing_vocab[mapped_existing_id])
    return "vocab-" + entry["id"], catalog_vocab(entry, catalog_info)


def normalize_objective(objective: dict[str, Any], context: str) -> dict[str, Any]:
    result = copy.deepcopy(objective)
    if "statement" not in result:
        result["statement"] = result.pop("text", None)
    localized(require(result, "statement", context), context + ".statement")
    result.setdefault("required", True)
    return result


def normalize_header(exercise: dict[str, Any], context: str) -> dict[str, Any]:
    header = copy.deepcopy(exercise.get("header", {}))
    if not header:
        header = {
            "id": require(exercise, "id", context),
            "prompt": require(exercise, "prompt", context),
            "instruction": exercise.get("instruction", exercise.get("prompt")),
            "objectiveIDs": exercise.get("objectiveIDs", []),
            "required": exercise.get("required", True),
        }
    else:
        header.setdefault("id", exercise.get("id"))
        header.setdefault("prompt", exercise.get("prompt"))
        header.setdefault("instruction", exercise.get("instruction", header.get("prompt")))
        header.setdefault("objectiveIDs", exercise.get("objectiveIDs", []))
        header.setdefault("required", exercise.get("required", True))
    string(require(header, "id", context), context + ".header.id")
    localized(require(header, "prompt", context), context + ".header.prompt")
    localized(require(header, "instruction", context), context + ".header.instruction")
    return header


def normalize_exercise(exercise: dict[str, Any], context: str) -> dict[str, Any]:
    kind = string(require(exercise, "kind", context), context + ".kind")
    allowed = {"choice", "wordOrder", "fillBlank", "listeningChoice", "speaking", "handwriting", "flashcard", *NEW_KINDS}
    if kind not in allowed:
        raise ContentError(f"{context}.kind: unsupported '{kind}'")
    result: dict[str, Any] = {"kind": kind, "header": normalize_header(exercise, context)}
    common = {"objectiveIDs", "required", "prompt", "instruction", "id", "kind", "header"}
    for key, value in exercise.items():
        if key not in common:
            result[key] = copy.deepcopy(value)
    if kind in {"listeningChoice", "dictation", "toneDiscrimination", "conversationChoice"} and not result.get("promptAudio") and not result.get("promptText"):
        raise ContentError(f"{context}: {kind} requires promptAudio or promptText")
    if kind == "speaking":
        result.setdefault("acceptedTranscripts", [])
        result.setdefault("allowSelfRating", True)
    if kind == "fillBlank":
        result.setdefault("caseSensitive", False)
    return result


def generated_card(vocab: dict[str, Any], vocab_id: str) -> dict[str, Any]:
    card_id = "card-" + vocab_id
    return {
        "id": card_id,
        "vocabularyID": vocab_id,
        # New cards use the same two-sided contract as the protected starter
        # cards: the front asks the learner to recognise the Hanzi, while the
        # revealed back supplies the authored pronunciation and translation.
        # Keep pinyin off the front so a review cannot reveal the answer early.
        "front": {"hanzi": vocab.get("hanzi"), "pinyin": None, "text": None, "audio": vocab.get("audio")},
        "back": {"hanzi": vocab.get("hanzi"), "pinyin": vocab.get("pinyin"), "text": vocab.get("meaning"), "audio": vocab.get("audio")},
        "tags": ["catalog"] if vocab.get("canonicalID") else ["extra"],
    }


def resolve_local_reference(
    ref: str,
    local_vocab: dict[str, dict[str, Any]],
    existing_vocab: dict[str, dict[str, Any]],
    catalog_info: dict[str, Any] | None,
    context: str,
) -> str:
    if ref in local_vocab:
        return ref
    resolved = resolve_catalog_or_existing(ref, existing_vocab, catalog_info)
    if resolved is None or resolved[0] not in local_vocab:
        raise ContentError(f"{context}: unknown local vocabulary reference '{ref}'")
    return resolved[0]


def grammar_introduction(
    note: dict[str, Any],
    index: int,
    context: str,
) -> dict[str, Any]:
    """Lower one authoring grammar note to the existing lesson block shape.

    Grammar is a lesson explanation, rather than a property of a vocabulary
    entry.  Keeping this lowering here means a reused entry can retain its
    canonical JSON object while the lesson can introduce another use of the
    same lexeme.
    """
    location = f"{context}.grammar[{index}]"
    pattern = string(require(note, "pattern", location), location + ".pattern")
    explanation = localized(require(note, "explanation", location), location + ".explanation")
    if "fr" not in explanation:
        raise ContentError(f"{location}.explanation: expected a 'fr' translation")

    examples = require(note, "examples", location)
    if not isinstance(examples, list) or not examples:
        raise ContentError(f"{location}.examples: expected a non-empty array")
    lines = [explanation["fr"]]
    for example_index, example in enumerate(examples):
        example_location = f"{location}.examples[{example_index}]"
        if not isinstance(example, dict):
            raise ContentError(f"{example_location}: expected an object")
        hanzi = string(require(example, "hanzi", example_location), example_location + ".hanzi")
        pinyin = string(require(example, "pinyin", example_location), example_location + ".pinyin")
        translation = localized(require(example, "translation", example_location), example_location + ".translation")
        if "fr" not in translation:
            raise ContentError(f"{example_location}.translation: expected a 'fr' translation")
        lines.extend([
            f"Exemple {example_index + 1} : {hanzi}",
            pinyin,
            translation["fr"],
        ])

    return {
        "kind": "introduction",
        "id": f"block-{context.removeprefix('lesson ')}-grammar-{index + 1:02d}",
        "title": {"fr": f"Grammaire — {pattern}"},
        "body": {"fr": "\n".join(lines)},
    }


def normalize_lesson(
    blueprint: dict[str, Any],
    content_version: str,
    existing_vocab: dict[str, dict[str, Any]],
    existing_cards: dict[str, dict[str, Any]],
    catalog_info: dict[str, Any] | None,
) -> dict[str, Any]:
    lesson_id = string(require(blueprint, "id", "lesson blueprint"), "lesson.id")
    context = f"lesson {lesson_id}"
    result: dict[str, Any] = {
        "schemaVersion": SCHEMA_VERSION,
        "contentVersion": content_version,
        "id": lesson_id,
        "moduleID": string(require(blueprint, "moduleID", context), context + ".moduleID"),
        "order": integer(require(blueprint, "order", context), context + ".order", minimum=1),
        "title": localized(require(blueprint, "title", context), context + ".title"),
        "summary": localized(require(blueprint, "summary", context), context + ".summary"),
        "estimatedMinutes": integer(require(blueprint, "estimatedMinutes", context), context + ".estimatedMinutes", minimum=1),
    }
    if blueprint.get("level") is not None:
        result["level"] = string(blueprint["level"], context + ".level")
    objectives = require(blueprint, "objectives", context)
    if not isinstance(objectives, list) or not objectives:
        raise ContentError(f"{context}.objectives: expected a non-empty array")
    result["objectives"] = [normalize_objective(item, context + ".objectives") for item in objectives]

    references = blueprint.get("vocabularyIDs")
    if references is None:
        references = []
        # A transitional direct form is accepted for one-off content packs;
        # release should use the shared catalog reference form below.
        direct = blueprint.get("vocabulary", [])
        if not isinstance(direct, list):
            raise ContentError(f"{context}.vocabulary: expected an array")
        vocabulary = copy.deepcopy(direct)
    else:
        if not isinstance(references, list):
            raise ContentError(f"{context}.vocabularyIDs: expected an array")
        vocabulary = []
        for index, ref in enumerate(references):
            ref = string(ref, f"{context}.vocabularyIDs[{index}]")
            resolved = resolve_catalog_or_existing(ref, existing_vocab, catalog_info)
            if resolved is None:
                raise ContentError(f"{context}: unknown vocabulary reference '{ref}'")
            vocabulary.append(resolved[1])
    extras = blueprint.get("extraVocabulary", [])
    if not isinstance(extras, list):
        raise ContentError(f"{context}.extraVocabulary: expected an array")
    for index, entry in enumerate(extras):
        entry = copy.deepcopy(entry)
        if "canonicalID" in entry or entry.get("canonical") is True:
            raise ContentError(f"{context}.extraVocabulary[{index}]: extra words cannot be canonical")
        vocabulary.append(entry)
    vocab_ids = [string(require(entry, "id", context + ".vocabulary"), context + ".vocabulary.id") for entry in vocabulary]
    unique(vocab_ids, context + ".vocabulary.id")
    result["vocabulary"] = vocabulary

    grammar = blueprint.get("grammar", [])
    if not isinstance(grammar, list):
        raise ContentError(f"{context}.grammar: expected an array")
    local_vocab = {entry["id"]: entry for entry in vocabulary}
    for index, note in enumerate(grammar):
        location = f"{context}.grammar[{index}]"
        if not isinstance(note, dict):
            raise ContentError(f"{location}: expected an object")
        vocab_ref = string(require(note, "vocabularyID", location), location + ".vocabularyID")
        resolve_local_reference(vocab_ref, local_vocab, existing_vocab, catalog_info, location)

    blocks: list[dict[str, Any]] = []
    if blueprint.get("introduction") is not None:
        introduction = copy.deepcopy(blueprint["introduction"])
        introduction["kind"] = "introduction"
        blocks.append(introduction)
    blocks.extend(grammar_introduction(note, index, context) for index, note in enumerate(grammar))
    if vocabulary:
        blocks.append({"kind": "vocabulary", "id": f"block-{lesson_id}-vocabulary", "vocabularyIDs": vocab_ids})
    for key, kind in (("dialogue", "dialogue"), ("reading", "reading")):
        if blueprint.get(key) is not None:
            block = copy.deepcopy(blueprint[key])
            block["kind"] = kind
            # Reading segmentation is authored against the shared lexical
            # IDs, then lowered to the local app vocabulary IDs.
            if kind == "reading":
                # Paragraph IDs are catalogue identifiers, so the short IDs
                # used by the compact authoring fragments (usually ``p1``
                # and ``p2``) must be scoped to their lesson before they are
                # emitted.  The Swift content contract treats paragraph IDs
                # as globally unique across all stories.
                for paragraph in block.get("paragraphs", []):
                    paragraph_id = paragraph.get("id")
                    if isinstance(paragraph_id, str) and paragraph_id:
                        paragraph["id"] = f"{lesson_id}-{paragraph_id}"
                    for segment in paragraph.get("segmentation", []):
                        if segment.get("vocabularyID") is not None:
                            segment["vocabularyID"] = resolve_local_reference(
                                segment["vocabularyID"], local_vocab, existing_vocab, catalog_info,
                                f"{context}.reading.segmentation"
                            )
            blocks.append(block)
    exercises = require(blueprint, "exercises", context)
    if not isinstance(exercises, list) or not exercises:
        raise ContentError(f"{context}.exercises: expected a non-empty array")
    for index, exercise in enumerate(exercises):
        if not isinstance(exercise, dict):
            raise ContentError(f"{context}.exercises[{index}]: expected an object")
        normalized = normalize_exercise(exercise, f"{context}.exercises[{index}]")
        if normalized["kind"] in {"choice", "listeningChoice"}:
            choices = normalized.get("choices")
            if isinstance(choices, list) and len(choices) > 1:
                # Authoring fragments commonly put the canonical answer at
                # index zero for readability. Rotate only generated daily
                # lessons so the UI cannot teach a position-based shortcut;
                # the stable choice IDs and correctChoiceID stay unchanged.
                day = max(1, lesson_number(result) - 4)
                rotation = (day + index + 1) % len(choices)
                normalized["choices"] = choices[rotation:] + choices[:rotation]
        blocks.append({"kind": "exercise", "id": f"block-{normalized['header']['id']}", "spec": normalized})
    if blueprint.get("recap") is not None:
        recap = copy.deepcopy(blueprint["recap"])
        recap["kind"] = "recap"
        recap["vocabularyIDs"] = [
            resolve_local_reference(ref, local_vocab, existing_vocab, catalog_info, f"{context}.recap.vocabularyIDs")
            for ref in recap.get("vocabularyIDs", [])
        ]
        blocks.append(recap)
    result["blocks"] = blocks

    cards = copy.deepcopy(blueprint.get("cards", []))
    if not isinstance(cards, list):
        raise ContentError(f"{context}.cards: expected an array")
    for index, card_id in enumerate(blueprint.get("reuseCardIDs", [])):
        card_id = string(card_id, f"{context}.reuseCardIDs[{index}]")
        if card_id not in existing_cards:
            raise ContentError(f"{context}: cannot reuse unknown card '{card_id}'")
        cards.append(copy.deepcopy(existing_cards[card_id]))
    card_refs = blueprint.get("cardVocabularyIDs", [])
    if not isinstance(card_refs, list):
        raise ContentError(f"{context}.cardVocabularyIDs: expected an array")
    local_vocab = {entry["id"]: entry for entry in vocabulary}
    for index, ref in enumerate(card_refs):
        ref = string(ref, f"{context}.cardVocabularyIDs[{index}]")
        resolved = resolve_catalog_or_existing(ref, existing_vocab, catalog_info)
        if resolved is None:
            raise ContentError(f"{context}: unknown card vocabulary reference '{ref}'")
        vocab_id, vocab = resolved
        if vocab_id not in local_vocab:
            local_vocab[vocab_id] = vocab
            vocabulary.append(copy.deepcopy(vocab))
            result["vocabulary"] = vocabulary
            vocab_ids.append(vocab_id)
        card_id = "card-" + vocab_id
        cards.append(copy.deepcopy(existing_cards[card_id]) if card_id in existing_cards else generated_card(local_vocab[vocab_id], vocab_id))
    # Every lesson-local word is reviewable.  The range fragments deliberately
    # keep their source compact and therefore omit a redundant
    # `cardVocabularyIDs` list; materialize one stable card per vocabulary row
    # here. Explicit cards and reused protected cards remain authoritative.
    card_vocabulary_ids = {
        card.get("vocabularyID")
        for card in cards
        if isinstance(card, dict) and isinstance(card.get("vocabularyID"), str)
    }
    for vocab in vocabulary:
        vocab_id = vocab["id"]
        if vocab_id in card_vocabulary_ids:
            continue
        card_id = "card-" + vocab_id
        cards.append(copy.deepcopy(existing_cards[card_id]) if card_id in existing_cards else generated_card(vocab, vocab_id))
        card_vocabulary_ids.add(vocab_id)
    # A compact blueprint may refer to a generated card through the shared
    # catalogue ID. Lower it to the stable local card ID for the Swift model.
    local_card_ids = {card["id"] for card in cards if isinstance(card, dict) and "id" in card}
    for block in blocks:
        if block.get("kind") != "exercise" or not isinstance(block.get("spec"), dict):
            continue
        spec = block["spec"]
        if spec.get("kind") != "flashcard" or not spec.get("cardID"):
            continue
        card_ref = spec["cardID"]
        if card_ref not in local_card_ids:
            resolved = resolve_catalog_or_existing(card_ref.removeprefix("card-"), existing_vocab, catalog_info)
            if resolved is not None:
                candidate = "card-" + resolved[0]
                if candidate in local_card_ids:
                    spec["cardID"] = candidate
    for block in blocks:
        if block.get("kind") == "vocabulary":
            block["vocabularyIDs"] = [entry["id"] for entry in vocabulary]
    result["cards"] = cards
    # Preserve optional editorial fields from the blueprint. The release
    # metadata pass below enriches these fields with stable local vocabulary
    # IDs and activity stages after all fragments have been normalized.
    for key in ("metadata", "grammarPoints", "adaptation", "stage", "skill", "errorTags", "feedback", "reviewDimensions", "reviewDirections"):
        if key in blueprint:
            result[key] = copy.deepcopy(blueprint[key])
    return result


def collect_existing(root: Path) -> tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]]]:
    vocab: dict[str, dict[str, Any]] = {}
    cards: dict[str, dict[str, Any]] = {}
    for lesson in all_lesson_files(root).values():
        for entry in lesson.get("vocabulary", []):
            vocab.setdefault(entry["id"], entry)
        for card in lesson.get("cards", []):
            cards.setdefault(card["id"], card)
    return vocab, cards


def editorial_block_metadata(block: dict[str, Any]) -> dict[str, Any]:
    """Describe the learning stage represented by a normalized block."""
    kind = block.get("kind")
    if kind == "introduction":
        return {"stage": "introduce", "skill": "recognition"}
    if kind == "vocabulary":
        return {"stage": "observe", "skill": "recognition"}
    if kind == "dialogue":
        return {"stage": "understand", "skill": "listening"}
    if kind == "reading":
        return {"stage": "transfer", "skill": "reading"}
    if kind == "recap":
        return {"stage": "review", "skill": ["recognition", "production"]}
    if kind == "exercise":
        spec = block.get("spec") if isinstance(block.get("spec"), dict) else {}
        exercise_kind = spec.get("kind")
        # Daily lessons carry their session phase (discover, guided, reuse)
        # in the stage; keep it and only derive the skill from the family.
        preset = block.get("metadata", {}).get("stage") if isinstance(block.get("metadata"), dict) else None
        if exercise_kind in {"choice", "listeningChoice", "flashcard", "matching", "dictation", "toneDiscrimination", "conversationChoice", "dialogueOrder"}:
            return {"stage": preset or "recover", "skill": "recognition"}
        if exercise_kind == "speaking":
            return {"stage": preset or "produce", "skill": "speaking"}
        if exercise_kind in {"wordOrder", "fillBlank", "handwriting", "translation"}:
            return {"stage": preset or "produce", "skill": "production"}
        return {"stage": preset or "practice", "skill": "production"}
    return {"stage": "practice", "skill": "recognition"}


def effective_material_vocabulary_ids(lesson: dict[str, Any]) -> set[str]:
    """Return vocabulary IDs evidenced by authored lesson material.

    Inventory and recap blocks describe what is available in a lesson, but do
    not prove that a reused lexeme is practised. Vocabulary cards also render
    their authored example sentence, so an example containing its linked
    lexeme is visible practice context. Keep this in lockstep with the Swift
    contract's effective-reuse check: reading segmentation and flashcards
    carry IDs directly; dialogue, word-order, speaking, and handwriting
    activities are matched by their authored Hanzi.
    """
    vocabulary = [entry for entry in lesson.get("vocabulary", []) if isinstance(entry, dict)]
    local_ids = {entry.get("id") for entry in vocabulary if isinstance(entry.get("id"), str)}
    by_hanzi: dict[str, set[str]] = {}
    for entry in vocabulary:
        hanzi = entry.get("hanzi")
        vocabulary_id = entry.get("id")
        if isinstance(hanzi, str) and isinstance(vocabulary_id, str):
            by_hanzi.setdefault(hanzi, set()).add(vocabulary_id)

    used: set[str] = set()
    for entry in vocabulary:
        hanzi = entry.get("hanzi")
        vocabulary_id = entry.get("id")
        example = entry.get("example")
        if (
            isinstance(hanzi, str)
            and hanzi
            and isinstance(vocabulary_id, str)
            and isinstance(example, dict)
            and isinstance(example.get("hanzi"), str)
            and hanzi in example["hanzi"]
        ):
            used.add(vocabulary_id)
    for block in lesson.get("blocks", []):
        if not isinstance(block, dict):
            continue
        kind = block.get("kind")
        if kind == "reading":
            for paragraph in block.get("paragraphs", []):
                if not isinstance(paragraph, dict):
                    continue
                for segment in paragraph.get("segmentation", []):
                    if not isinstance(segment, dict):
                        continue
                    vocabulary_id = segment.get("vocabularyID")
                    if isinstance(vocabulary_id, str):
                        used.add(vocabulary_id)
        elif kind == "dialogue":
            for line in block.get("lines", []):
                if not isinstance(line, dict):
                    continue
                hanzi = line.get("hanzi")
                if isinstance(hanzi, str):
                    for surface, vocabulary_ids in by_hanzi.items():
                        if surface in hanzi:
                            used.update(vocabulary_ids)
        elif kind != "exercise":
            continue
        spec = block.get("spec")
        if not isinstance(spec, dict):
            continue
        exercise_kind = spec.get("kind")
        if exercise_kind == "wordOrder":
            for token in spec.get("tokens", []):
                if isinstance(token, dict):
                    used.update(by_hanzi.get(token.get("hanzi"), set()))
        elif exercise_kind == "matching":
            for pair in spec.get("pairs", []):
                if isinstance(pair, dict):
                    used.update(by_hanzi.get(pair.get("left"), set()))
        elif exercise_kind == "translation":
            for token in spec.get("tokens", []):
                if isinstance(token, dict):
                    used.update(by_hanzi.get(token.get("hanzi"), set()))
        elif exercise_kind == "dialogueOrder":
            for item in spec.get("lines", []):
                if isinstance(item, dict) and isinstance(item.get("hanzi"), str):
                    for surface, vocabulary_ids in by_hanzi.items():
                        if surface in item["hanzi"]:
                            used.update(vocabulary_ids)
        elif exercise_kind == "conversationChoice":
            texts = [spec.get("promptText")] + [reply.get("hanzi") for reply in spec.get("replies", []) if isinstance(reply, dict)]
            for text in texts:
                if isinstance(text, str):
                    for surface, vocabulary_ids in by_hanzi.items():
                        if surface in text:
                            used.update(vocabulary_ids)
        elif exercise_kind == "speaking":
            text = spec.get("referenceText")
            if isinstance(text, str):
                for surface, vocabulary_ids in by_hanzi.items():
                    if surface in text:
                        used.update(vocabulary_ids)
        elif exercise_kind == "handwriting":
            text = spec.get("targetHanzi")
            if isinstance(text, str):
                for surface, vocabulary_ids in by_hanzi.items():
                    if surface in text:
                        used.update(vocabulary_ids)
        elif exercise_kind == "flashcard":
            card_id = spec.get("cardID")
            for card in lesson.get("cards", []):
                if isinstance(card, dict) and card.get("id") == card_id:
                    vocabulary_id = card.get("vocabularyID")
                    if isinstance(vocabulary_id, str):
                        used.add(vocabulary_id)
                    break
    return used.intersection(local_ids)


def canonical_catalog_entry_id(entry: dict[str, Any], catalog_info: dict[str, Any] | None) -> str | None:
    """Resolve a normalized local vocabulary row to its catalog entry ID."""
    if catalog_info is None:
        return None
    canonical = entry.get("canonicalID")
    if canonical in catalog_info["byID"]:
        return canonical
    if canonical in catalog_info["byLexeme"]:
        return catalog_info["byLexeme"][canonical]["id"]
    vocabulary_id = entry.get("id")
    if vocabulary_id in catalog_info["byID"]:
        return vocabulary_id
    if isinstance(vocabulary_id, str) and vocabulary_id.startswith("vocab-"):
        candidate = vocabulary_id.removeprefix("vocab-")
        if candidate in catalog_info["byID"]:
            return candidate
    mapped = catalog_info["existingByVocabularyID"].get(vocabulary_id)
    return mapped if mapped in catalog_info["byID"] else None


def apply_block_metadata(lesson: dict[str, Any], day: int) -> None:
    for block in lesson.get("blocks", []):
        if not isinstance(block, dict):
            continue
        block_metadata = copy.deepcopy(block.get("metadata", {}))
        if not isinstance(block_metadata, dict):
            block_metadata = {}
        block_metadata.update(editorial_block_metadata(block))
        block_metadata.setdefault("lessonDay", day)
        block["metadata"] = block_metadata


def apply_editorial_metadata(
    root: Path,
    generated_lessons: list[dict[str, Any]],
    catalog_info: dict[str, Any] | None,
) -> set[str]:
    """Add reviewable lesson and block metadata after fragment normalization.

    Returns the words sentence tiles are segmented against.

    Vocabulary introduction is computed from the final lesson order and local
    IDs. This matters when a natural late-course scene reuses a catalogue row
    before the allocation's nominal new-vocabulary row; allocation labels are
    retained only as contextual metadata.
    """
    generated_ids = {lesson["id"] for lesson in generated_lessons}
    existing_lessons = [
        lesson
        for lesson_id, lesson in all_lesson_files(root).items()
        if lesson_id not in generated_ids and not is_derived(lesson)
    ]
    ordered_lessons = sorted(
        [lesson for lesson in existing_lessons if not is_pinyin(lesson)] + generated_lessons,
        key=lambda lesson: (lesson.get("order", 0), lesson.get("id", "")),
    )
    introduced: set[str] = set()
    # Existing documents establish the baseline in order. The protected
    # starter lessons therefore seed the first generated session naturally.
    for lesson in ordered_lessons:
        if lesson.get("id") in generated_ids:
            break
        introduced.update(
            entry.get("id")
            for entry in lesson.get("vocabulary", [])
            if isinstance(entry, dict) and isinstance(entry.get("id"), str)
        )

    # Sentence tiles are segmented against every known word: the release
    # catalogue plus each lesson's own vocabulary.
    lexicon = {
        entry["hanzi"]
        for lesson in ordered_lessons
        for entry in lesson.get("vocabulary", [])
        if isinstance(entry, dict) and isinstance(entry.get("hanzi"), str)
    }
    if catalog_info is not None:
        lexicon.update(entry["hanzi"] for entry in catalog_info["byID"].values())
    # Authored two-character tiles are real words that the catalogue may omit.
    lexicon.update(
        token["hanzi"]
        for lesson in ordered_lessons
        for spec in exercise_specs(lesson)
        if spec.get("kind") == "wordOrder"
        for token in spec.get("tokens", [])
        if len(token.get("hanzi", "")) == 2
    )

    for lesson in generated_lessons:
        vocabulary = [entry for entry in lesson.get("vocabulary", []) if isinstance(entry, dict)]
        vocabulary_ids = [entry.get("id") for entry in vocabulary]
        new_ids = [vocab_id for vocab_id in vocabulary_ids if vocab_id not in introduced]
        reused_ids = [vocab_id for vocab_id in vocabulary_ids if vocab_id in introduced]
        # Extend the six authored exercises to the three-phase session before
        # reuse is measured, so new exercises count as practice evidence.
        earlier_vocabulary = [
            entry
            for earlier in [item for item in ordered_lessons if item.get("order", 0) < lesson.get("order", 0)][-2:]
            for entry in earlier.get("vocabulary", [])
            if isinstance(entry, dict)
        ]
        try:
            expand_lesson_exercises(lesson, set(new_ids), earlier_vocabulary, lexicon)
        except ExpansionError as exc:
            raise ContentError(str(exc)) from exc
        extra_ids = [
            vocab_id for entry, vocab_id in zip(vocabulary, vocabulary_ids)
            if vocab_id is not None and canonical_catalog_entry_id(entry, catalog_info) is None
        ]
        day = max(1, lesson_number(lesson) - 4)
        metadata = copy.deepcopy(lesson.get("metadata", {}))
        if not isinstance(metadata, dict):
            metadata = {}
        allocation_new_ids = metadata.get("newVocabularyIDs")
        allocation_reused_ids = metadata.get("reusedVocabularyIDs")
        if isinstance(allocation_new_ids, list):
            metadata["allocationNewVocabularyIDs"] = copy.deepcopy(allocation_new_ids)
        if isinstance(allocation_reused_ids, list):
            metadata["allocationReusedVocabularyIDs"] = copy.deepcopy(allocation_reused_ids)
        # The allocation intentionally reserves a few earlier words for each
        # day, but a compact fragment may only use some of those words in its
        # dialogue or activities. Report effective reuse in the contract
        # field, while retaining the complete allocation for editorial audit.
        effective_reused_ids = sorted(effective_material_vocabulary_ids(lesson).intersection(reused_ids))
        metadata.update({
            "standardID": HSK_LEGACY_STANDARD_ID,
            "standardVersion": HSK_LEGACY_STANDARD_VERSION,
            "legacyStandardID": HSK_LEGACY_STANDARD_ID,
            "legacyStandardVersion": HSK_LEGACY_STANDARD_VERSION,
            "levelID": "level-01" if metadata.get("phase") == "classic-1-150" else "level-02",
            "sectionID": "section-01",
            "unitID": lesson.get("moduleID"),
            "newVocabularyIDs": new_ids,
            "reusedVocabularyIDs": effective_reused_ids,
            "newVocabularyCount": len(new_ids),
            "extraVocabularyIDs": extra_ids,
        })
        lesson["metadata"] = metadata

        apply_block_metadata(lesson, day)
        introduced.update(vocab_id for vocab_id in new_ids if isinstance(vocab_id, str))
    return lexicon


def lint_reference(reference: Any, context: str) -> None:
    if not isinstance(reference, dict):
        raise ContentError(f"{context}: expected an object")
    framework = string(require(reference, "framework", context), context + ".framework")
    string(require(reference, "level", context), context + ".level")
    standard_id = string(require(reference, "standardID", context), context + ".standardID")
    standard_version = string(require(reference, "standardVersion", context), context + ".standardVersion")
    if framework.lower() == "hsk" and (standard_id, standard_version) != (HSK_LEGACY_STANDARD_ID, HSK_LEGACY_STANDARD_VERSION):
        raise ContentError(f"{context}: HSK references must use {HSK_LEGACY_STANDARD_ID}/2.0")


def canonical_catalog_id(entry: dict[str, Any], catalog: dict[str, Any]) -> str | None:
    """Resolve a local vocabulary row to a catalog entry ID for coverage."""
    canonical = entry.get("canonicalID")
    if canonical in catalog["byID"]:
        return canonical
    if canonical in catalog["byLexeme"]:
        return catalog["byLexeme"][canonical]["id"]
    vocabulary_id = entry.get("id")
    if vocabulary_id in catalog["byID"]:
        return vocabulary_id
    if isinstance(vocabulary_id, str) and vocabulary_id.startswith("vocab-"):
        candidate = vocabulary_id.removeprefix("vocab-")
        if candidate in catalog["byID"]:
            return candidate
    mapped = catalog["existingByVocabularyID"].get(vocabulary_id)
    return mapped if mapped in catalog["byID"] else None


def lint_plan(course: dict[str, Any], lesson_ids: list[str], lessons: dict[str, dict[str, Any]], catalogs: dict[str, dict[str, Any]], context: str) -> None:
    plan = course.get("plan")
    if plan is None:
        return
    if not isinstance(plan, dict):
        raise ContentError(f"{context}.plan: expected an object")
    target = integer(require(plan, "targetMinutes", context + ".plan"), context + ".plan.targetMinutes", minimum=1)
    if target != 15:
        raise ContentError(f"{context}.plan.targetMinutes: the programme contract requires 15")
    sessions = require(plan, "sessions", context + ".plan")
    if not isinstance(sessions, list) or not sessions:
        raise ContentError(f"{context}.plan.sessions: expected a non-empty array")
    days: list[int] = []
    session_lesson_ids: list[str] = []
    for index, session in enumerate(sessions):
        location = f"{context}.plan.sessions[{index}]"
        if not isinstance(session, dict):
            raise ContentError(f"{location}: expected an object")
        day = integer(require(session, "day", location), location + ".day", minimum=1)
        lesson_id = string(require(session, "lessonID", location), location + ".lessonID")
        course_minutes = integer(require(session, "courseMinutes", location), location + ".courseMinutes", minimum=1)
        review_minutes = integer(require(session, "reviewMinutes", location), location + ".reviewMinutes", minimum=1)
        if course_minutes + review_minutes != target:
            raise ContentError(f"{location}: courseMinutes + reviewMinutes must equal 15")
        if lesson_id not in lesson_ids:
            raise ContentError(f"{location}: unknown lesson '{lesson_id}'")
        days.append(day)
        session_lesson_ids.append(lesson_id)
    if days != list(range(1, len(days) + 1)):
        raise ContentError(f"{context}.plan.sessions: days must be contiguous starting at 1")
    unique(session_lesson_ids, context + ".plan.sessions.lessonID")

    plan_catalog_id = plan.get("catalogID")
    plan_catalog_version = plan.get("catalogVersion")
    if plan_catalog_id is not None:
        plan_catalog_id = string(plan_catalog_id, context + ".plan.catalogID")
        plan_catalog_version = string(plan_catalog_version, context + ".plan.catalogVersion")
        catalog = catalogs.get(plan_catalog_id)
        if catalog is None or catalog["version"] != plan_catalog_version:
            raise ContentError(f"{context}.plan: missing catalog or version")

    milestones = plan.get("milestones", [])
    if not isinstance(milestones, list):
        raise ContentError(f"{context}.plan.milestones: expected an array")
    milestone_ids: list[str] = []
    for index, milestone in enumerate(milestones):
        location = f"{context}.plan.milestones[{index}]"
        if not isinstance(milestone, dict):
            raise ContentError(f"{location}: expected an object")
        milestone_ids.append(string(require(milestone, "id", location), location + ".id"))
        day = integer(require(milestone, "day", location), location + ".day", minimum=1)
        if day > len(sessions):
            raise ContentError(f"{location}.day: outside the authored plan")
        localized(require(milestone, "title", location), location + ".title")
        if milestone.get("reference") is not None:
            lint_reference(milestone["reference"], location + ".reference")
        claims = milestone.get("claims", [])
        if not isinstance(claims, list) or not all(isinstance(claim, str) and claim.strip() for claim in claims):
            raise ContentError(f"{location}.claims: expected an array of non-empty strings")
        coverage = milestone.get("coverage")
        if coverage is None:
            continue
        if not isinstance(coverage, dict):
            raise ContentError(f"{location}.coverage: expected an object")
        vocabulary_target = integer(require(coverage, "vocabularyTarget", location + ".coverage"), location + ".coverage.vocabularyTarget", minimum=0)
        if coverage.get("canonicalOnly") is not True:
            raise ContentError(f"{location}.coverage.canonicalOnly must be true")
        coverage_catalog_id = coverage.get("catalogID", plan_catalog_id)
        coverage_catalog_version = coverage.get("catalogVersion", plan_catalog_version)
        if coverage_catalog_id is None or coverage_catalog_version is None:
            raise ContentError(f"{location}.coverage: catalogID and catalogVersion are required")
        coverage_catalog_id = string(coverage_catalog_id, location + ".coverage.catalogID")
        coverage_catalog_version = string(coverage_catalog_version, location + ".coverage.catalogVersion")
        catalog = catalogs.get(coverage_catalog_id)
        if catalog is None or catalog["version"] != coverage_catalog_version:
            raise ContentError(f"{location}.coverage: referenced catalog is unavailable or has another version")
        # The four protected starter lessons are taught before day 1 of the
        # authored programme. Their canonical lexemes form the starting
        # inventory for milestone coverage, but they must not be counted as
        # newly introduced by the 90-day plan.
        starter_covered: set[str] = set()
        for starter_id in sorted(PROTECTED_LEGACY_LESSONS):
            starter = lessons.get(starter_id)
            if starter is None:
                continue
            for entry in starter.get("vocabulary", []):
                canonical_id = canonical_catalog_id(entry, catalog)
                if canonical_id is not None:
                    starter_covered.add(canonical_id)

        covered: set[str] = set(starter_covered)
        introduced_by_plan: set[str] = set()
        for session in sessions[:day]:
            # Module 0 previews words that the daily lessons introduce: it covers none.
            if is_pinyin(lessons[session["lessonID"]]):
                continue
            for entry in lessons[session["lessonID"]].get("vocabulary", []):
                canonical_id = canonical_catalog_id(entry, catalog)
                if canonical_id is not None:
                    covered.add(canonical_id)
                    if canonical_id not in starter_covered:
                        introduced_by_plan.add(canonical_id)
        if len(covered) < vocabulary_target:
            raise ContentError(f"{location}.coverage: target {vocabulary_target}, but only {len(covered)} catalog lexemes are covered by day {day}")

        required_by_rank = {
            entry["id"]
            for entry in catalog["byID"].values()
            if entry["rank"] <= vocabulary_target
        }
        missing_by_rank = sorted(required_by_rank - covered)
        if missing_by_rank:
            preview = ", ".join(missing_by_rank[:8])
            suffix = "…" if len(missing_by_rank) > 8 else ""
            raise ContentError(
                f"{location}.coverage: missing rank-boundary lexemes by day {day}: {preview}{suffix}"
            )
        if "newVocabularyTarget" in coverage:
            new_target = integer(coverage["newVocabularyTarget"], location + ".coverage.newVocabularyTarget", minimum=0)
            if len(introduced_by_plan) < new_target:
                raise ContentError(f"{location}.coverage: new target {new_target}, but only {len(introduced_by_plan)} new catalog lexemes are covered after the starter lessons")
    unique(milestone_ids, context + ".plan.milestones.id")


def _hanzi_only(text: Any) -> str:
    return "".join(char for char in text if "\u3400" <= char <= "\u9fff") if isinstance(text, str) else ""


def _label(choice: Any) -> str:
    label = choice.get("label") if isinstance(choice, dict) else None
    return label.get("fr", "") if isinstance(label, dict) else ""


def lint_new_kind(spec: dict[str, Any], lesson: dict[str, Any], where: str) -> None:
    """Check one `matching`, `dictation`, `toneDiscrimination`, `translation`,
    `conversationChoice` or `dialogueOrder` exercise against its own lesson:
    identifiers resolve, answers exist, and every Mandarin text, pinyin and
    meaning is the lesson's, not a new invention."""
    kind = spec["kind"]
    entries = [entry for entry in lesson.get("vocabulary", []) if isinstance(entry, dict) and isinstance(entry.get("hanzi"), str)]
    by_hanzi: dict[str, list[dict[str, Any]]] = {}
    for entry in entries:
        by_hanzi.setdefault(entry["hanzi"], []).append(entry)

    def word(hanzi: Any) -> dict[str, Any] | None:
        """The lesson's row for a word, unless two rows share its Hanzi."""
        rows = by_hanzi.get(hanzi, [])
        return rows[0] if len(rows) == 1 else None
    dialogue = next((block for block in lesson.get("blocks", []) if isinstance(block, dict) and block.get("kind") == "dialogue"), {})
    lines = [line for line in dialogue.get("lines", []) if isinstance(line, dict)]
    line_hanzi = [_hanzi_only(line.get("hanzi")) for line in lines]
    # Everything Mandarin the lesson itself shows, without punctuation.
    material = list(line_hanzi) + [
        _hanzi_only(entry.get("example", {}).get("hanzi")) for entry in entries if isinstance(entry.get("example"), dict)
    ]
    examples = [
        example
        for block in lesson.get("blocks", []) if isinstance(block, dict) and block.get("kind") == "introduction"
        for example in introduction_examples(block)
    ]
    material.extend(_hanzi_only(hanzi) for hanzi, _, _ in examples)
    for block in lesson.get("blocks", []):
        if isinstance(block, dict) and block.get("kind") == "reading":
            material.extend(_hanzi_only(paragraph.get("hanzi")) for paragraph in block.get("paragraphs", []) if isinstance(paragraph, dict))

    def check(condition: bool, message: str) -> None:
        if not condition:
            raise ContentError(f"{where} {message}")

    def choice_ids(choices: Any, correct: Any) -> None:
        check(isinstance(choices, list) and len(choices) >= 2, "needs at least two choices")
        ids = [choice.get("id") for choice in choices]
        labels = [json.dumps(choice.get("label"), sort_keys=True) for choice in choices]
        check(len(set(ids)) == len(ids) and correct in ids, "has duplicate choice IDs or a missing correct choice")
        check(len(set(labels)) == len(labels), "has duplicate choice labels")

    def sourced_pinyin(hanzi: str) -> set[str]:
        """The pinyin the lesson gives for exactly this Mandarin text."""
        result = {entry["pinyin"] for entry in by_hanzi.get(hanzi, []) if isinstance(entry.get("pinyin"), str)}
        for entry in entries:
            example = entry.get("example")
            if isinstance(example, dict) and _hanzi_only(example.get("hanzi")) == hanzi:
                result.add(example.get("pinyin"))
        result.update(line.get("pinyin") for line in lines if _hanzi_only(line.get("hanzi")) == hanzi)
        result.update(pinyin for example_hanzi, pinyin, _ in examples if _hanzi_only(example_hanzi) == hanzi)
        return result

    if kind in {"dictation", "toneDiscrimination", "conversationChoice"}:
        check(bool(spec.get("promptAudio") or spec.get("promptText")), f"{kind} requires promptAudio or promptText")
    if kind == "matching":
        pairs = spec.get("pairs")
        check(isinstance(pairs, list) and MATCHING_PAIRS[0] <= len(pairs) <= MATCHING_PAIRS[1], f"needs {MATCHING_PAIRS[0]} to {MATCHING_PAIRS[1]} pairs")
        for key in ("id", "left"):
            values = [pair.get(key) for pair in pairs]
            check(len(set(values)) == len(values), f"has duplicate pair {key} values")
        rights = [_label({"label": pair.get("right")}) for pair in pairs]
        check(all(rights) and len(set(rights)) == len(rights), "has empty or duplicate right-hand items")
        for pair, right in zip(pairs, rights):
            entry = word(pair.get("left"))
            check(entry is not None, f"pairs '{pair.get('left')}', which is not a single word of the lesson's vocabulary")
            expected = entry["meaning"].get("fr") if pair.get("pinyin") is not None else entry["pinyin"]
            check(pair.get("pinyin") in {None, entry["pinyin"]} and right == expected, f"pairs '{pair['left']}' with something else than its meaning or pinyin")
    elif kind == "dictation":
        check(spec.get("script") in DICTATION_SCRIPTS, f"needs a script in {', '.join(DICTATION_SCRIPTS)}")
        choice_ids(spec.get("choices"), spec.get("correctChoiceID"))
        spoken = _hanzi_only(spec.get("promptText"))
        correct = next(_label(choice) for choice in spec["choices"] if choice["id"] == spec["correctChoiceID"])
        if spec["script"] == "hanzi":
            check(_hanzi_only(correct) == spoken and _hanzi_only(correct) == correct, "has a correct choice that is not the spoken text")
        else:
            check(correct in sourced_pinyin(spoken), "has a correct pinyin that the lesson does not give for the spoken text")
    elif kind == "toneDiscrimination":
        choice_ids(spec.get("choices"), spec.get("correctChoiceID"))
        entry = word(spec.get("promptText"))
        tones = entry_tones(entry) if entry is not None else None
        check(tones is not None, "asks the tones of a word that is not in the lesson or whose tones cannot be heard reliably")
        check(spec["correctChoiceID"] == tone_choice_id(tones), "has a correct choice that differs from the word's tone numbers")
        check(all(choice["id"].startswith("t") and len(choice["id"]) == len(tones) + 1 for choice in spec["choices"]), "mixes tone patterns of different lengths")
    elif kind == "translation":
        tokens = spec.get("tokens")
        check(isinstance(tokens, list), "needs tiles")
        ids = [token.get("id") for token in tokens]
        hanzi = [token.get("hanzi") for token in tokens]
        check(len(set(ids)) == len(ids) and len(set(hanzi)) == len(hanzi), "has duplicate tile IDs or Hanzi")
        order = spec.get("correctOrder")
        check(isinstance(order, list) and order and len(set(order)) == len(order) and set(order) <= set(ids), "has a correct order that does not use its tiles once")
        check(len(order) < len(ids), "needs at least one distractor tile")
        by_id = dict(zip(ids, hanzi))
        for sequence in [order] + list(spec.get("acceptedOrders", [])):
            check(set(sequence) <= set(ids) and len(set(sequence)) == len(sequence), "has an accepted order that does not use its tiles once")
            sentence = "".join(by_id[tile] for tile in sequence)
            check(any(sentence in text for text in material), f"assembles '{sentence}', which the lesson never shows")
    elif kind == "dialogueOrder":
        items = spec.get("lines")
        check(isinstance(items, list) and DIALOGUE_ORDER_LINES[0] <= len(items) <= DIALOGUE_ORDER_LINES[1], f"needs {DIALOGUE_ORDER_LINES[0]} to {DIALOGUE_ORDER_LINES[1]} lines")
        ids = [item.get("id") for item in items]
        order = spec.get("correctOrder")
        check(len(set(ids)) == len(ids) and isinstance(order, list) and sorted(order) == sorted(ids), "has a correct order that is not a permutation of its lines")
        check(order != ids, "shows its lines already in order")
        by_id = {item["id"]: item for item in items}
        ordered = [_hanzi_only(by_id[line_id].get("hanzi")) for line_id in order]
        check(len(set(ordered)) == len(ordered), "repeats a line")
        check(any(line_hanzi[start:start + len(ordered)] == ordered for start in range(len(line_hanzi))), "does not follow the lesson's dialogue")
        for line_id in order:
            source = next(line for line in lines if _hanzi_only(line.get("hanzi")) == _hanzi_only(by_id[line_id].get("hanzi")))
            check(by_id[line_id].get("hanzi") == source.get("hanzi") and by_id[line_id].get("pinyin") == source.get("pinyin") and by_id[line_id].get("speaker") == source.get("speaker"), "changes a dialogue line")
    elif kind == "conversationChoice":
        replies = spec.get("replies")
        check(isinstance(replies, list) and len(replies) == CONVERSATION_REPLIES, f"needs exactly {CONVERSATION_REPLIES} replies")
        ids = [reply.get("id") for reply in replies]
        hanzi = [_hanzi_only(reply.get("hanzi")) for reply in replies]
        check(len(set(ids)) == len(ids) and len(set(hanzi)) == len(hanzi) and spec.get("correctReplyID") in ids, "has duplicate replies or a missing correct reply")
        correct = next(reply for reply in replies if reply["id"] == spec["correctReplyID"])
        prompt = _hanzi_only(spec.get("promptText"))
        check(prompt not in hanzi, "offers the spoken line as a reply")
        check(any(line_hanzi[index] == prompt and line_hanzi[index + 1] == _hanzi_only(correct["hanzi"]) for index in range(len(line_hanzi) - 1)), "has a correct reply that does not follow the spoken line in the dialogue")
        for reply in replies:
            source = next((line for line in lines if line.get("hanzi") == reply.get("hanzi")), None)
            check(source is not None and source.get("pinyin") == reply.get("pinyin"), "has a reply that is not a dialogue line")


def exercise_subject(spec: dict[str, Any]) -> str:
    """What an exercise is about, beyond its prompt: the text it plays, the words it pairs or the lines it orders."""
    if spec.get("promptText"):
        return spec["promptText"]
    if spec.get("pairs"):
        return " ".join(pair["left"] for pair in spec["pairs"])
    lines = {line["id"]: line["hanzi"] for line in spec.get("lines", [])}
    return "".join(lines[line_id] for line_id in spec.get("correctOrder", [])) if lines else ""


def lint_exercise_session(lesson: dict[str, Any], location: str) -> None:
    """Check a generated daily lesson's three-phase exercise session."""
    blocks = [
        block for block in lesson.get("blocks", [])
        if isinstance(block, dict) and block.get("kind") == "exercise" and isinstance(block.get("spec"), dict)
    ]
    if not EXERCISE_BUDGET[0] <= len(blocks) <= EXERCISE_BUDGET[1]:
        raise ContentError(f"{location}: {len(blocks)} exercises, expected {EXERCISE_BUDGET[0]}–{EXERCISE_BUDGET[1]}")
    phases: list[str] = []
    identities: set[tuple[str, str]] = set()
    for block in blocks:
        spec = block["spec"]
        exercise_id = spec["header"]["id"]
        stage = block.get("metadata", {}).get("stage") if isinstance(block.get("metadata"), dict) else None
        if stage not in PHASES:
            raise ContentError(f"{location}: exercise '{exercise_id}' needs a stage in {', '.join(PHASES)}")
        phases.append(stage)
        identity = (spec["header"]["prompt"].get("fr", ""), exercise_subject(spec))
        if identity in identities:
            raise ContentError(f"{location}: exercise '{exercise_id}' repeats an earlier prompt")
        identities.add(identity)
        if spec["kind"] in {"choice", "listeningChoice"}:
            labels = [json.dumps(choice.get("label"), sort_keys=True) for choice in spec["choices"]]
            if len(set(labels)) != len(labels):
                raise ContentError(f"{location}: exercise '{exercise_id}' has duplicate choice labels")
        if spec["kind"] == "wordOrder":
            hanzi = [token["hanzi"] for token in spec["tokens"]]
            if len(set(hanzi)) != len(hanzi) or sorted(spec["correctOrder"]) != sorted(token["id"] for token in spec["tokens"]):
                raise ContentError(f"{location}: exercise '{exercise_id}' has ambiguous or inconsistent tiles")
        if spec["kind"] in NEW_KINDS:
            lint_new_kind(spec, lesson, f"{location}: exercise '{exercise_id}'")
    kinds = {block["spec"]["kind"] for block in blocks}.intersection(NEW_KINDS)
    if len(kinds) < MIN_NEW_KINDS:
        raise ContentError(f"{location}: only {len(kinds)} of the newer exercise kinds ({', '.join(sorted(kinds)) or 'none'}), expected {MIN_NEW_KINDS}")
    rank = [PHASES.index(phase) for phase in phases]
    if rank != sorted(rank) or set(rank) != set(range(len(PHASES))):
        raise ContentError(f"{location}: exercises must run through {', '.join(PHASES)} in order")


def new_vocabulary_by_lesson(lessons: dict[str, dict[str, Any]]) -> dict[str, list[str]]:
    """Map each lesson to the vocabulary IDs no earlier lesson lists."""
    introduced: set[str] = set()
    result: dict[str, list[str]] = {}
    for lesson in sorted(lessons.values(), key=lambda item: (item.get("order", 0), item.get("id", ""))):
        # Module 0 previews words that the daily lessons introduce: it owns none.
        if is_pinyin(lesson):
            result[lesson["id"]] = []
            continue
        ids = [entry["id"] for entry in lesson.get("vocabulary", []) if isinstance(entry, dict) and isinstance(entry.get("id"), str)]
        result[lesson["id"]] = [vocab_id for vocab_id in ids if vocab_id not in introduced]
        introduced.update(ids)
    return result


def lint_new_vocabulary(lesson: dict[str, Any], new_ids: list[str], location: str) -> None:
    """Check that a lesson teaches few words and practises each of them enough."""
    if len(new_ids) > MAX_NEW_WORDS:
        raise ContentError(f"{location}: {len(new_ids)} new words, expected at most {MAX_NEW_WORDS}")
    metadata = lesson.get("metadata") if isinstance(lesson.get("metadata"), dict) else {}
    if metadata.get("newVocabularyIDs") != new_ids:
        raise ContentError(f"{location}: metadata.newVocabularyIDs differs from the words no earlier lesson lists")
    hanzi = {entry["id"]: entry["hanzi"] for entry in lesson["vocabulary"] if entry["id"] in new_ids}
    shortfalls = exposure_shortfalls(word_exposures(exercise_specs(lesson), hanzi))
    if shortfalls:
        detail = ", ".join(f"{hanzi[vocab_id]} ({count} exercises, {kinds} kinds)" for vocab_id, (count, kinds) in sorted(shortfalls.items()))
        raise ContentError(
            f"{location}: each new word needs {MIN_EXPOSURES} exercises of {MIN_EXPOSURE_KINDS} kinds: {detail}"
        )


def lint_derived_lesson(lesson: dict[str, Any], lessons: dict[str, dict[str, Any]], location: str) -> None:
    """Check a review or boss: what it covers, that it teaches no word, and how its exercises run."""
    metadata = lesson["metadata"]
    kind = metadata["lessonKind"]
    covers = metadata.get("reviewedLessonIDs")
    if not isinstance(covers, list) or not covers or any(cover not in lessons or is_derived(lessons[cover]) for cover in covers):
        raise ContentError(f"{location}: metadata.reviewedLessonIDs must list daily lessons")
    if any(lessons[cover]["moduleID"] != lesson["moduleID"] or lessons[cover]["order"] >= lesson["order"] for cover in covers):
        raise ContentError(f"{location}: covers lessons of its own unit that come before it")
    if kind == REVIEW and len(covers) != REVIEW_EVERY:
        raise ContentError(f"{location}: a review covers {REVIEW_EVERY} lessons, found {len(covers)}")
    if not lesson["id"].startswith(f"{kind}-"):
        raise ContentError(f"{location}: the ID of a {kind} starts with '{kind}-'")
    if metadata.get("newVocabularyIDs") != [] or metadata.get("newVocabularyCount") != 0:
        raise ContentError(f"{location}: a {kind} introduces no word")
    covered_words = {entry["id"] for cover in covers for entry in lessons[cover]["vocabulary"]}
    strangers = sorted({entry["id"] for entry in lesson["vocabulary"]} - covered_words)
    if strangers:
        raise ContentError(f"{location}: vocabulary outside the covered lessons: {', '.join(strangers)}")
    if lesson["estimatedMinutes"] != SESSION_MINUTES[kind][0]:
        raise ContentError(f"{location}: estimatedMinutes must be {SESSION_MINUTES[kind][0]}")
    if not any(isinstance(block, dict) and block.get("kind") == "dialogue" and block.get("lines") for block in lesson["blocks"]):
        raise ContentError(f"{location}: a {kind} needs the dialogue its exercises draw on")

    exercises = [block for block in lesson["blocks"] if isinstance(block, dict) and block.get("kind") == "exercise"]
    low, high = DERIVED_BUDGET[kind]
    if not low <= len(exercises) <= high:
        raise ContentError(f"{location}: a {kind} runs {low}–{high} exercises, found {len(exercises)}")
    kinds = {block["spec"]["kind"] for block in exercises}
    required = set(NEW_KINDS) if kind == REVIEW else set(BOSS_KINDS)
    if not required <= kinds:
        raise ContentError(f"{location}: a {kind} needs the exercise kinds {', '.join(sorted(required - kinds))}")
    if kind == BOSS:
        challenge = {block["spec"]["kind"] for block in exercises if block["metadata"]["stage"] == PHASES[-1]}
        if not set(BOSS_KINDS) <= challenge:
            raise ContentError(f"{location}: the last phase of a boss must run its dialogue challenge ({', '.join(BOSS_KINDS)})")
    previous: dict[str, int] = {}
    asked: dict[str, int] = {}
    for block in exercises:
        source = block["metadata"].get("sourceLessonID")
        if source not in covers:
            raise ContentError(f"{location}: exercise '{block['spec']['header']['id']}' needs a sourceLessonID among the covered lessons")
        stage, position = block["metadata"]["stage"], covers.index(source)
        if position < previous.get(stage, 0):
            raise ContentError(f"{location}: exercise '{block['spec']['header']['id']}' comes after a more recent lesson; each phase starts with the oldest")
        previous[stage] = position
        asked[source] = asked.get(source, 0) + 1
    unasked = [cover for cover in covers if asked.get(cover, 0) < (2 if kind == REVIEW else 1)]
    if unasked:
        raise ContentError(f"{location}: the exercises skip {', '.join(unasked)}")


def lint_review_structure(course: dict[str, Any], lessons: dict[str, dict[str, Any]], context: str) -> None:
    """Reviews and bosses in the plan's units: a review after each five daily lessons, a boss closing each unit.

    A unit whose lessons the plan never schedules (the four starters) is exempt.
    A boss that ends a run of five stands in for that run's review.
    """
    planned = {session["lessonID"] for session in course.get("plan", {}).get("sessions", [])}
    for module in course["modules"]:
        lesson_ids = module["lessonIDs"]
        location = f"{context}.modules[{module['id']}]"
        derived = [lesson_id for lesson_id in lesson_ids if is_derived(lessons[lesson_id])]
        if any(is_pinyin(lessons[lesson_id]) for lesson_id in lesson_ids):
            # Module 0 has its own rules: pinyin_module.check_structure.
            continue
        if not planned.intersection(lesson_ids):
            if derived:
                raise ContentError(f"{location}: reviews and bosses belong to the planned units")
            continue
        run: list[str] = []
        for lesson_id in lesson_ids:
            if lesson_id not in derived:
                run.append(lesson_id)
                if len(run) > REVIEW_EVERY:
                    raise ContentError(f"{location}: more than {REVIEW_EVERY} lessons in a row without a review, from '{run[0]}'")
                continue
            metadata = lessons[lesson_id]["metadata"]
            if lesson_id not in planned:
                raise ContentError(f"{location}: '{lesson_id}' is not in the plan")
            if metadata["lessonKind"] == REVIEW:
                if len(run) != REVIEW_EVERY or metadata.get("reviewedLessonIDs") != run or lesson_id == lesson_ids[-1]:
                    raise ContentError(f"{location}: '{lesson_id}' must follow exactly {REVIEW_EVERY} lessons that it covers, and not end the unit")
            elif lesson_id != lesson_ids[-1] or lesson_id != f"boss-{module['id']}" or metadata.get("reviewedLessonIDs") != [item for item in lesson_ids if item not in derived]:
                raise ContentError(f"{location}: '{lesson_id}' must be the last lesson of its unit and cover all of the unit's daily lessons")
            run = []
        if not is_derived(lessons[lesson_ids[-1]]) or lessons[lesson_ids[-1]]["metadata"]["lessonKind"] != BOSS:
            raise ContentError(f"{location}: the unit must end with a boss")


def course_path(course: dict[str, Any]) -> list[str]:
    """The lesson IDs in the order the learner walks them: units by order, lessons as listed."""
    return [lesson_id for module in sorted(course["modules"], key=lambda module: module["order"]) for lesson_id in module["lessonIDs"]]


def lint_lesson_order(course: dict[str, Any], lessons: dict[str, dict[str, Any]], context: str) -> None:
    """A lesson's `order` is its 1-based position on the path."""
    for position, lesson_id in enumerate(course_path(course), start=1):
        if lessons[lesson_id].get("order") != position:
            raise ContentError(f"{context}: lesson '{lesson_id}' has order {lessons[lesson_id].get('order')}, expected its path position {position}")


def lint_bundle(root: Path) -> None:
    manifest = load_json(root / "manifest.json")
    if not isinstance(manifest, dict):
        raise ContentError("manifest.json: expected an object")
    if integer(require(manifest, "schemaVersion", "manifest"), "manifest.schemaVersion", minimum=1) != SCHEMA_VERSION:
        raise ContentError("manifest.schemaVersion: unsupported schema")
    content_version = string(require(manifest, "contentVersion", "manifest"), "manifest.contentVersion")
    course_ids = require(manifest, "courseIDs", "manifest")
    if not isinstance(course_ids, list) or not course_ids:
        raise ContentError("manifest.courseIDs: expected a non-empty array")
    course_ids = [string(value, "manifest.courseIDs") for value in course_ids]
    unique(course_ids, "manifest.courseIDs")
    default_course_id = string(require(manifest, "defaultCourseID", "manifest"), "manifest.defaultCourseID")
    if default_course_id not in course_ids:
        raise ContentError("manifest.defaultCourseID: not present in courseIDs")
    lessons = all_lesson_files(root)
    new_by_lesson = new_vocabulary_by_lesson(lessons)
    catalogs: dict[str, dict[str, Any]] = {}
    for path in sorted((root / "authoring").glob("*.json")) + sorted((root / "catalogs").glob("*.json")):
        value = load_json(path)
        if isinstance(value, dict) and "entries" in value and "standard" in value:
            info = validate_catalog(value, str(path))
            catalogs[info["standardID"]] = info
            catalogs[info["id"]] = info
    global_exercise_ids: set[str] = set()
    global_block_ids: set[str] = set()
    global_card_objects: dict[str, dict[str, Any]] = {}
    global_vocab_objects: dict[str, dict[str, Any]] = {}
    for course_id in course_ids:
        course = load_json(root / "courses" / f"{course_id}.json")
        if not isinstance(course, dict):
            raise ContentError(f"courses/{course_id}.json: expected an object")
        context = f"course {course_id}"
        if integer(require(course, "schemaVersion", context), context + ".schemaVersion", minimum=1) != SCHEMA_VERSION:
            raise ContentError(f"{context}: unsupported schema")
        if string(require(course, "contentVersion", context), context + ".contentVersion") != content_version:
            raise ContentError(f"{context}: contentVersion differs from manifest")
        if string(require(course, "id", context), context + ".id") != course_id:
            raise ContentError(f"{context}: id differs from filename")
        modules = require(course, "modules", context)
        if not isinstance(modules, list) or not modules:
            raise ContentError(f"{context}.modules: expected a non-empty array")
        module_ids: list[str] = []
        listed_lesson_ids: list[str] = []
        module_orders: list[int] = []
        for index, module in enumerate(modules):
            location = f"{context}.modules[{index}]"
            if not isinstance(module, dict):
                raise ContentError(f"{location}: expected an object")
            module_ids.append(string(require(module, "id", location), location + ".id"))
            module_orders.append(integer(require(module, "order", location), location + ".order", minimum=0))
            localized(require(module, "title", location), location + ".title")
            if module.get("level") is not None:
                string(module["level"], location + ".level")
            lesson_ids = require(module, "lessonIDs", location)
            if not isinstance(lesson_ids, list) or not lesson_ids:
                raise ContentError(f"{location}.lessonIDs: expected a non-empty array")
            listed_lesson_ids.extend(string(value, location + ".lessonIDs") for value in lesson_ids)
        unique(module_ids, context + ".modules.id")
        unique(listed_lesson_ids, context + ".modules.lessonIDs")
        if len(set(module_orders)) != len(module_orders):
            raise ContentError(f"{context}.modules.order: duplicate order")
        missing = sorted(set(listed_lesson_ids) - set(lessons))
        if missing:
            raise ContentError(f"{context}: missing lesson files: {', '.join(missing)}")
        lint_plan(course, listed_lesson_ids, lessons, catalogs, context)
        lint_review_structure(course, lessons, context)
        try:
            check_structure(course, lessons, context)
        except PinyinError as exc:
            raise ContentError(str(exc)) from exc
        lint_lesson_order(course, lessons, context)
        for lesson_id in listed_lesson_ids:
            lesson = lessons[lesson_id]
            location = f"lessons/{lesson_id}.json"
            if integer(require(lesson, "schemaVersion", location), location + ".schemaVersion", minimum=1) != SCHEMA_VERSION:
                raise ContentError(f"{location}: unsupported schema")
            if string(require(lesson, "contentVersion", location), location + ".contentVersion") != content_version:
                raise ContentError(f"{location}: contentVersion differs from manifest")
            if string(require(lesson, "id", location), location + ".id") != lesson_id:
                raise ContentError(f"{location}: id differs from course reference")
            owning_modules = [module for module in modules if lesson_id in module["lessonIDs"]]
            if len(owning_modules) != 1:
                raise ContentError(f"{location}: must belong to exactly one module")
            if string(require(lesson, "moduleID", location), location + ".moduleID") != owning_modules[0]["id"]:
                raise ContentError(f"{location}: moduleID differs from course module")
            integer(require(lesson, "order", location), location + ".order", minimum=1)
            if lesson.get("level") is not None:
                string(lesson["level"], location + ".level")
            localized(require(lesson, "title", location), location + ".title")
            localized(require(lesson, "summary", location), location + ".summary")
            integer(require(lesson, "estimatedMinutes", location), location + ".estimatedMinutes", minimum=1)
            objectives = require(lesson, "objectives", location)
            if not isinstance(objectives, list) or not objectives:
                raise ContentError(f"{location}.objectives: expected a non-empty array")
            objective_ids = [string(require(item, "id", location + ".objectives"), location + ".objectives.id") for item in objectives]
            unique(objective_ids, location + ".objectives.id")
            for item in objectives:
                localized(item.get("statement", item.get("text")), location + ".objectives.statement")
            vocabulary = require(lesson, "vocabulary", location)
            if not isinstance(vocabulary, list):
                raise ContentError(f"{location}.vocabulary: expected an array")
            vocab_ids = [string(require(item, "id", location + ".vocabulary"), location + ".vocabulary.id") for item in vocabulary]
            unique(vocab_ids, location + ".vocabulary.id")
            local_vocab = set(vocab_ids)
            for item in vocabulary:
                if item["id"] in global_vocab_objects and global_vocab_objects[item["id"]] != item:
                    raise ContentError(f"{location}: vocabulary '{item['id']}' changes its canonical object")
                global_vocab_objects[item["id"]] = item
            blocks = require(lesson, "blocks", location)
            if not isinstance(blocks, list) or not blocks:
                raise ContentError(f"{location}.blocks: expected a non-empty array")
            block_ids = [string(require(block, "id", location + ".blocks"), location + ".blocks.id") for block in blocks]
            unique(block_ids, location + ".blocks.id")
            for block_id in block_ids:
                if block_id in global_block_ids:
                    raise ContentError(f"duplicate global block ID '{block_id}'")
                global_block_ids.add(block_id)
            if is_pinyin(lesson):
                try:
                    check_lesson(lesson)
                except PinyinError as exc:
                    raise ContentError(f"{location}: {exc}") from exc
            elif lesson_id not in PROTECTED_LEGACY_LESSONS:
                lint_exercise_session(lesson, location)
                lint_new_vocabulary(lesson, new_by_lesson[lesson_id], location)
                if is_derived(lesson):
                    lint_derived_lesson(lesson, lessons, location)
            specs = exercise_specs(lesson)
            spec_ids = [string(require(spec.get("header", {}), "id", location + ".exercise.header"), location + ".exercise.header.id") for spec in specs]
            unique(spec_ids, location + ".exercise.id")
            local_exercises = set(spec_ids)
            for spec_id in spec_ids:
                if spec_id in global_exercise_ids:
                    raise ContentError(f"duplicate global exercise ID '{spec_id}'")
                global_exercise_ids.add(spec_id)
            local_cards = {card["id"] for card in lesson.get("cards", []) if isinstance(card, dict) and "id" in card}
            for block in blocks:
                kind = block.get("kind")
                if kind in {"dialogue", "reading"}:
                    if kind == "reading" and block.get("level") is not None:
                        string(block["level"], location + ".reading.level")
                    for exercise_id in block.get("comprehensionExerciseIDs", []):
                        if exercise_id not in local_exercises:
                            raise ContentError(f"{location}.{kind}: unknown comprehension exercise '{exercise_id}'")
                if kind in {"vocabulary", "recap"}:
                    for vocab_id in block.get("vocabularyIDs", []):
                        if vocab_id not in local_vocab:
                            raise ContentError(f"{location}.{kind}: unknown vocabulary '{vocab_id}'")
                if kind == "exercise" and isinstance(block.get("spec"), dict):
                    spec = block["spec"]
                    if spec.get("kind") == "listeningChoice" and not spec.get("promptAudio") and not spec.get("promptText"):
                        raise ContentError(f"{location}: listeningChoice requires promptAudio or promptText")
                    if spec.get("kind") == "flashcard" and spec.get("cardID") not in local_cards:
                        raise ContentError(f"{location}: flashcard references a missing local card")
                    for objective_id in spec.get("header", {}).get("objectiveIDs", []):
                        if objective_id not in objective_ids:
                            raise ContentError(f"{location}: exercise references unknown objective '{objective_id}'")
            cards = require(lesson, "cards", location)
            if not isinstance(cards, list):
                raise ContentError(f"{location}.cards: expected an array")
            card_ids = [string(require(card, "id", location + ".cards"), location + ".cards.id") for card in cards]
            unique(card_ids, location + ".cards.id")
            card_vocabulary_ids = {
                card.get("vocabularyID")
                for card in cards
                if isinstance(card, dict) and isinstance(card.get("vocabularyID"), str)
            }
            if card_vocabulary_ids != local_vocab:
                raise ContentError(f"{location}.cards: every lesson vocabulary entry needs exactly one review-card reference")
            for card in cards:
                if card.get("vocabularyID") not in local_vocab:
                    raise ContentError(f"{location}.cards.{card['id']}: vocabularyID is not in the same lesson")
                previous = global_card_objects.get(card["id"])
                if previous is not None and previous != card:
                    raise ContentError(f"{location}: card '{card['id']}' changes its canonical object")
                global_card_objects[card["id"]] = card
    if not global_exercise_ids:
        raise ContentError("bundle: no exercise documents found")


def reset_protected_orders(root: Path) -> None:
    """Give the protected starter lessons the order the authoring pack assumes, whatever the course now sequences before them."""
    for lesson_id in sorted(PROTECTED_LEGACY_LESSONS):
        path = root / "lessons" / f"{lesson_id}.json"
        lesson = load_json(path)
        number = int(lesson_id.removeprefix("lesson-"))
        if lesson.get("order") != number:
            lesson["order"] = number
            write_json(path, lesson)


def generate_in_place(root: Path, source: dict[str, Any], catalog: dict[str, Any] | None, catalog_info: dict[str, Any] | None) -> set[Path]:
    source_version = string(require(source, "contentVersion", "authoring"), "authoring.contentVersion")
    course_source = require(source, "course", "authoring")
    if not isinstance(course_source, dict):
        raise ContentError("authoring.course: expected an object")
    course_id = string(require(course_source, "id", "authoring.course"), "authoring.course.id")
    existing_course_path = root / "courses" / f"{course_id}.json"
    existing_course = load_json(existing_course_path) if existing_course_path.exists() else None
    existing_vocab, existing_cards = collect_existing(root) if (root / "lessons").exists() else ({}, {})
    if (root / "lessons").exists():
        reset_protected_orders(root)
    blueprints = require(source, "lessons", "authoring")
    if not isinstance(blueprints, list) or not blueprints:
        raise ContentError("authoring.lessons: expected a non-empty array")
    generated_lessons = [normalize_lesson(item, source_version, existing_vocab, existing_cards, catalog_info) for item in blueprints]
    generated_ids = [lesson["id"] for lesson in generated_lessons]
    unique(generated_ids, "authoring.lessons.id")
    if set(generated_ids) & PROTECTED_LEGACY_LESSONS:
        raise ContentError("authoring.lessons: lesson-01..lesson-04 are protected legacy documents")
    lexicon = apply_editorial_metadata(root, generated_lessons, catalog_info)

    modules_source = require(source, "modules", "authoring")
    if not isinstance(modules_source, list) or not modules_source:
        raise ContentError("authoring.modules: expected a non-empty array")
    derived_blueprints = source.get("reviewLessons", [])
    if not isinstance(derived_blueprints, list) or not all(isinstance(item, dict) for item in derived_blueprints):
        raise ContentError("authoring.reviewLessons: expected an array of objects")
    derived_ids = [string(require(item, "id", "authoring.reviewLessons"), "authoring.reviewLessons.id") for item in derived_blueprints]
    for item in derived_blueprints:
        for key in ("kind", "moduleID", "covers", "order"):
            require(item, key, f"authoring.reviewLessons.{item['id']}")
        if item["kind"] not in DERIVED_KINDS:
            raise ContentError(f"authoring.reviewLessons.{item['id']}.kind: expected one of {', '.join(DERIVED_KINDS)}")
    unique(generated_ids + derived_ids, "authoring.lessons.id")
    unit_titles = {module["id"]: localized(module["title"], "authoring.modules.title")["fr"] for module in modules_source}
    try:
        derived_lessons = build_derived_lessons(
            derived_blueprints, {lesson["id"]: lesson for lesson in generated_lessons}, unit_titles, source_version, lexicon,
        )
    except ExpansionError as exc:
        raise ContentError(str(exc)) from exc
    for lesson in derived_lessons:
        apply_block_metadata(lesson, lesson["order"] - 4)
    generated_lessons += derived_lessons
    pinyin_path = root / "authoring" / PINYIN_MODULE_FILE
    pinyin_data = load_json(pinyin_path) if pinyin_path.exists() else None
    pinyin_lessons: list[dict[str, Any]] = []
    if pinyin_data is not None:
        try:
            pinyin_lessons = build_lessons(
                pinyin_data, source_version,
                lambda ref: resolve_catalog_or_existing(ref, existing_vocab, catalog_info),
                lambda vocab_id, vocab: copy.deepcopy(existing_cards["card-" + vocab_id]) if "card-" + vocab_id in existing_cards else generated_card(vocab, vocab_id),
            )
        except PinyinError as exc:
            raise ContentError(f"authoring/{PINYIN_MODULE_FILE}: {exc}") from exc
        except KeyError as exc:
            raise ContentError(f"authoring/{PINYIN_MODULE_FILE}: missing field {exc}") from exc
        unique(generated_ids + derived_ids + [lesson["id"] for lesson in pinyin_lessons], "authoring.lessons.id")
        for lesson in pinyin_lessons:
            apply_block_metadata(lesson, lesson["order"])
        generated_lessons += pinyin_lessons
    # Reviews and pinyin lessons that their pack no longer lists leave the bundle.
    pinyin_ids = [lesson["id"] for lesson in pinyin_lessons]
    for path in sorted((root / "lessons").glob("*.json")):
        existing = load_json(path)
        if (is_derived(existing) and path.stem not in derived_ids) or (is_pinyin(existing) and path.stem not in pinyin_ids):
            path.unlink()
    generated_course = copy.deepcopy(course_source)
    generated_course.update({"schemaVersion": SCHEMA_VERSION, "contentVersion": source_version, "id": course_id})
    generated_course["modules"] = copy.deepcopy(modules_source)
    if pinyin_data is not None:
        add_to_course(generated_course, pinyin_data, pinyin_lessons)
    if isinstance(existing_course, dict):
        existing_modules = {module.get("id"): module for module in existing_course.get("modules", []) if isinstance(module, dict)}
        generated_module_ids = {module.get("id") for module in generated_course["modules"]}
        for module_id, module in existing_modules.items():
            if module_id not in generated_module_ids:
                generated_course["modules"].append(copy.deepcopy(module))
        listed = {lesson_id for module in generated_course["modules"] for lesson_id in module.get("lessonIDs", [])}
        for module in generated_course["modules"]:
            old = existing_modules.get(module.get("id"))
            if old:
                # The pack orders its own lessons; a lesson it lists in no unit stays
                # after them in its old unit, unless its file has been deleted.
                module["lessonIDs"] = module.get("lessonIDs", []) + [
                    lesson_id for lesson_id in old.get("lessonIDs", [])
                    if lesson_id not in listed and not lesson_id.startswith(DERIVED_KINDS)
                    and (root / "lessons" / f"{lesson_id}.json").exists()
                ]
    module_by_id = {module.get("id"): module for module in generated_course["modules"]}
    for lesson in generated_lessons:
        module = module_by_id.get(lesson["moduleID"])
        if module is None:
            raise ContentError(f"lesson {lesson['id']}: moduleID '{lesson['moduleID']}' has no module")
        module.setdefault("lessonIDs", [])
        if lesson["id"] not in module["lessonIDs"]:
            module["lessonIDs"].append(lesson["id"])
    # A lesson's `order` is its position on the path.
    order_of = {lesson_id: position for position, lesson_id in enumerate(course_path(generated_course), start=1)}
    for lesson in generated_lessons:
        lesson["order"] = order_of[lesson["id"]]

    manifest_path = root / "manifest.json"
    manifest = load_json(manifest_path)
    if not isinstance(manifest, dict):
        raise ContentError("manifest.json: expected an object")
    course_ids = list(manifest.get("courseIDs", []))
    if course_id not in course_ids:
        course_ids.append(course_id)
    manifest.update({"schemaVersion": SCHEMA_VERSION, "contentVersion": source_version, "courseIDs": course_ids})
    manifest.setdefault("defaultCourseID", course_id)
    # The manifest's counts describe its default course.
    if manifest["defaultCourseID"] == course_id and isinstance(manifest.get("metadata"), dict):
        course_metadata = generated_course.get("metadata", {})
        manifest["metadata"].update({
            key: course_metadata[key]
            for key in ("starterLessonCount", "plannedSessionCount", "availableLessonCount", "canonicalVocabularyCount")
            if key in course_metadata
        })
    changed: set[Path] = {Path("manifest.json"), Path("courses") / f"{course_id}.json"}
    write_json(root / "courses" / f"{course_id}.json", generated_course)
    for lesson in generated_lessons:
        path = root / "lessons" / f"{lesson['id']}.json"
        write_json(path, lesson)
        changed.add(path.relative_to(root))
    # The bundle has one content version. Changing this scalar leaves every
    # protected lesson's payload, IDs, exercises and cards semantically intact.
    for path in sorted((root / "lessons").glob("*.json")):
        legacy = load_json(path)
        if legacy.get("contentVersion") != source_version or legacy.get("order") != order_of.get(legacy.get("id"), legacy.get("order")):
            legacy["contentVersion"] = source_version
            legacy["order"] = order_of.get(legacy.get("id"), legacy.get("order"))
            write_json(path, legacy)
            changed.add(path.relative_to(root))
    if catalog is not None and isinstance(source.get("catalog"), dict) and "path" not in source["catalog"]:
        catalog_path = root / "authoring" / f"{catalog_info['id']}.json"
        write_json(catalog_path, catalog)
        changed.add(catalog_path.relative_to(root))
    write_json(manifest_path, manifest)
    changed.add(Path("manifest.json"))
    return changed


def generate(root: Path, source_path: Path) -> None:
    source = load_json(source_path)
    if not isinstance(source, dict):
        raise ContentError("authoring pack: expected an object")
    if integer(require(source, "schemaVersion", "authoring"), "authoring.schemaVersion", minimum=1) != SCHEMA_VERSION:
        raise ContentError("authoring.schemaVersion: unsupported schema")
    catalog_pair = find_catalog(root, source, source_path)
    catalog, catalog_info = catalog_pair if catalog_pair else (None, None)
    # Stage the whole bundle first. No target file is touched when authoring or
    # cross-document validation fails.
    with tempfile.TemporaryDirectory(prefix="polygo-content-") as temporary:
        staging = Path(temporary) / "Content"
        shutil.copytree(root, staging)
        changed = generate_in_place(staging, source, catalog, catalog_info)
        lint_bundle(staging)
        for relative in changed:
            source_file = staging / relative
            target_file = root / relative
            target_file.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source_file, target_file)
        for stale in (root / "lessons").glob("*.json"):
            if not (staging / "lessons" / stale.name).exists():
                stale.unlink()


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    lint_parser = subparsers.add_parser("lint", help="validate a generated content root")
    lint_parser.add_argument("--root", type=Path, default=Path("Content"))
    generate_parser = subparsers.add_parser("generate", help="expand an authoring pack")
    generate_parser.add_argument("--input", type=Path, required=True)
    generate_parser.add_argument("--root", type=Path, default=Path("Content"))
    args = parser.parse_args(argv)
    try:
        if args.command == "lint":
            lint_bundle(args.root)
            print(f"content lint passed: {args.root}")
        else:
            generate(args.root, args.input)
            print(f"content generated and linted: {args.root}")
        return 0
    except ContentError as exc:
        print(f"content error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
