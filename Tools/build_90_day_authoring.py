#!/usr/bin/env python3
"""Build the editorial allocation for the 90-session classic HSK course.

This tool writes a reviewable plan only. It does not invent dialogue,
readings, exercises, pinyin, translations, or lesson prose. Those texts are
authored in separate, range-specific files and are assembled by the release
editor.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
AUTHORING = ROOT / "Content" / "authoring"
CATALOG_PATH = AUTHORING / "hsk-legacy-600.json"
PREVIEW_PATH = AUTHORING / "preview-first-five.json"
ALLOCATION_PATH = AUTHORING / "90-day-allocation.json"
CONTENT_VERSION = "2026.10.0"


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


THEME_BUCKETS: dict[str, list[str]] = {
    "food": ["food", "shopping", "home", "people", "qualities", "actions", "language"],
    "home": ["home", "people", "qualities", "actions", "language"],
    "family": ["people", "time", "qualities", "home", "language"],
    "time": ["time", "actions", "qualities", "language"],
    "shopping": ["shopping", "food", "home", "qualities", "actions", "language"],
    "travel": ["travel", "time", "city", "shopping", "actions", "language"],
    "city": ["travel", "home", "people", "qualities", "language"],
    "study": ["study", "language", "actions", "qualities", "people"],
    "work": ["work", "communication", "actions", "qualities", "people"],
    "routine": ["actions", "time", "home", "health", "language"],
    "health": ["health", "food", "qualities", "actions", "language"],
    "communication": ["language", "communication", "people", "actions", "qualities"],
    "leisure": ["leisure", "nature", "people", "actions", "qualities"],
    "weather": ["nature", "qualities", "time", "actions", "language"],
    "nature": ["nature", "leisure", "qualities", "actions", "language"],
    "community": ["people", "city", "home", "actions", "language"],
    "story": ["actions", "time", "people", "qualities", "language"],
    "opinion": ["qualities", "language", "communication", "actions", "people"],
    "problem-solving": ["language", "actions", "qualities", "work", "city"],
    "culture": ["leisure", "study", "communication", "people", "language"],
    "daily-review": ["language", "actions", "time", "people", "qualities"],
    "classic-checkpoint": ["language", "actions", "time", "people", "qualities"],
    "classic-final-checkpoint": ["language", "actions", "time", "people", "qualities"],
}


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


def bucket(entry: dict[str, Any]) -> str:
    """Classify a catalogue row for allocation; this creates no lesson text."""
    hanzi = entry["hanzi"]
    meaning = entry["meaningFr"].lower()
    if hanzi in {"菜", "茶", "吃", "喝", "饭馆", "鸡蛋", "米饭", "水果", "苹果", "咖啡", "牛奶", "西瓜", "羊肉", "鱼", "果汁", "蛋糕", "糖", "香蕉", "葡萄", "啤酒", "面包", "面条", "筷子", "盘子", "碗"} or any(word in meaning for word in ("repas", "fruit", "boisson", "café", "lait", "pain", "nouille", "gâteau", "sucre", "poisson")):
        return "food"
    if any(word in meaning for word in ("papa", "maman", "fils", "fille", "frère", "sœur", "ami", "épouse", "mari", "enfant", "femme", "homme", "voisin", "collègue", "grand-mère", "grand-père", "oncle", "tante", "personne", "professeur", "élève", "étudiant", "serveur", "client", "invité")):
        return "people"
    if hanzi in {"今天", "明天", "昨天", "上午", "下午", "中午", "晚上", "早上", "星期", "时候", "现在", "时间", "分钟", "小时", "年", "月", "日", "号", "生日", "周末", "去年", "以后", "以前", "一会儿", "刚才"} or any(word in meaning for word in ("heure", "jour", "année", "semaine", "moment", "durée", "anniversaire")):
        return "time"
    if any(word in meaning for word in ("école", "classe", "cours", "leçon", "examen", "étudier", "étudiant", "professeur", "devoir", "mathématiques", "bibliothèque", "phrase", "mot", "dictionnaire", "réviser", "écrire", "lire", "apprendre")):
        return "study"
    if any(word in meaning for word in ("travail", "entreprise", "bureau", "collègue", "réunion", "directeur", "gérant", "manager")):
        return "work"
    if any(word in meaning for word in ("taxi", "bus", "avion", "gare", "train", "aéroport", "billet", "voyager", "voyage", "passeport", "hôtel", "bateau", "vélo", "métro", "chauffeur", "valise", "rue", "carte")):
        return "travel"
    if any(word in meaning for word in ("corps", "santé", "malade", "fièvre", "rhume", "médicament", "nez", "oreille", "œil", "jambe", "pied", "visage", "cheveux", "dent", "douleur", "douloureux")):
        return "health"
    if any(word in meaning for word in ("météo", "temps", "pluie", "neige", "vent", "soleil", "nuage", "saison", "printemps", "été", "automne", "hiver", "rivière", "arbre", "herbe", "animal", "oiseau", "panda", "jardin", "parc", "environnement")):
        return "nature"
    if any(word in meaning for word in ("sport", "courir", "danser", "chanter", "jouer", "musique", "film", "télévision", "jeu", "loisir", "passe-temps", "nager", "basket", "football", "montagne")):
        return "leisure"
    if any(word in meaning for word in ("acheter", "vendre", "prix", "argent", "yuan", "cher", "bon marché", "vêtement", "chemise", "pantalon", "jupe", "chaussure", "chapeau", "cadeau", "supermarché", "magasin", "menu")):
        return "shopping"
    if any(word in meaning for word in ("maison", "chambre", "pièce", "table", "chaise", "porte", "cuisine", "réfrigérateur", "ascenseur", "immeuble", "lampe", "ordinateur", "téléphone", "photo", "appareil", "sac", "lunettes", "parapluie", "livre")):
        return "home"
    if any(word in meaning for word in ("particule", "classificateur", "conjonction", "préposition", "adverbe", "compar", "passif", "complément", "question", "pourquoi", "comment", "sens", "signification", "relation", "problème", "solution", "effet", "rôle", "influencer", "culture", "monde")):
        return "language"
    if any(word in meaning for word in ("bon", "mauvais", "grand", "petit", "beau", "joli", "heureux", "content", "facile", "difficile", "important", "simple", "clair", "propre", "rapide", "lent", "froid", "chaud", "fatigué", "occupé", "triste", "colère", "peur", "satisfait", "jeune", "vieux", "intelligent", "étrange")):
        return "qualities"
    return "actions"


def select_new(entries: list[dict[str, Any]], days: list[int], assigned: set[int], themes_by_day: dict[int, str]) -> dict[int, list[str]]:
    """Assign each unassigned rank once, with 8–10 new rows in phase one."""
    available = {entry["rank"] for entry in entries if entry["rank"] not in assigned}
    by_rank = {entry["rank"]: entry for entry in entries}
    result: dict[int, list[str]] = {}
    for index, day in enumerate(days):
        remaining_days = len(days) - index
        count = (len(available) + remaining_days - 1) // remaining_days
        preferred = THEME_BUCKETS[themes_by_day[day]]
        ranked = sorted(
            available,
            key=lambda rank: (preferred.index(bucket(by_rank[rank])) if bucket(by_rank[rank]) in preferred else len(preferred), rank),
        )
        selected = ranked[:count]
        if not 8 <= count <= 10 and day <= 29:
            raise ValueError(f"day {day} would introduce {count} rows; expected 8–10")
        result[day] = [f"hsk20-{rank:03d}" for rank in selected]
        available.difference_update(selected)
    if available:
        raise ValueError(f"unallocated ranks: {sorted(available)[:8]}")
    return result


def reuse_refs(day: int, seen: list[str], count: int) -> list[str]:
    """Choose explicit retrieval IDs from already encountered canonical rows."""
    if not seen:
        return []
    ordered = sorted(set(seen), key=lambda value: int(value.rsplit("-", 1)[1]))
    stride = 11 if day % 2 else 7
    start = (day * stride) % len(ordered)
    picked: list[str] = []
    for offset in range(len(ordered)):
        value = ordered[(start + offset * stride) % len(ordered)]
        if value not in picked:
            picked.append(value)
        if len(picked) == min(count, len(ordered)):
            break
    return picked


def grammar_target(day: int, anchor: str | None, patterns: list[str] | None = None) -> dict[str, Any]:
    selected = patterns or [GRAMMAR_TARGETS[(day - 6) % len(GRAMMAR_TARGETS)][0]]
    return {"patterns": selected, "anchorCanonicalID": anchor, "reviewable": True}


def build() -> dict[str, Any]:
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    preview = json.loads(PREVIEW_PATH.read_text(encoding="utf-8"))
    entries = catalog["entries"]
    by_id = {entry["id"]: entry for entry in entries}
    existing_to_canonical = {
        item["existingVocabularyID"]: item["canonicalLexemeID"]
        for item in catalog.get("existingCourseMappings", [])
    }
    themes_by_day = {day: DAY_THEMES[day - 1] for day in range(1, 91)}

    # Starter lessons are before day 1. Their mapped rows are the baseline;
    # preview-first-five is the fixed authored route for days 1–5.
    seen: list[str] = list(existing_to_canonical.values())
    rows: list[dict[str, Any]] = []
    fixed_by_day = {day: preview["lessons"][day - 1] for day in range(1, 6)}
    for day in range(1, 6):
        lesson = fixed_by_day[day]
        new: list[str] = []
        reused: list[str] = []
        for ref in lesson.get("vocabularyIDs", []):
            canonical = canonical_ref(ref, by_id, existing_to_canonical)
            if canonical is None:
                continue
            if canonical in seen:
                if canonical not in reused:
                    reused.append(canonical)
            else:
                new.append(canonical)
                seen.append(canonical)
        patterns = [note["pattern"] for note in lesson.get("grammar", [])]
        anchors = [canonical_ref(note["vocabularyID"], by_id, existing_to_canonical) for note in lesson.get("grammar", [])]
        rows.append({
            "day": day,
            "lessonID": lesson["id"],
            "moduleID": lesson["moduleID"],
            "theme": themes_by_day[day],
            "phase": "fixed-preview",
            "newVocabularyIDs": new,
            "reusedVocabularyIDs": reused,
            "newCanonicalIDs": new,
            "reusedCanonicalIDs": reused,
            "newCount": len(new),
            "reusedCount": len(reused),
            "grammarTarget": grammar_target(day, anchors[0] if anchors else (new[0] if new else None), patterns or None),
            "checkpoint": False,
        })

    phase1_assigned = {by_id[value]["rank"] for value in seen if value in by_id and by_id[value]["rank"] <= 300}
    phase1 = [entry for entry in entries if entry["rank"] <= 300]
    phase1_new = select_new(phase1, list(range(6, 30)), phase1_assigned, themes_by_day)
    phase2_assigned = {by_id[value]["rank"] for value in seen if value in by_id and by_id[value]["rank"] >= 301}
    phase2 = [entry for entry in entries if 301 <= entry["rank"] <= 600]
    phase2_new = select_new(phase2, [day for day in range(31, 90) if day != 60], phase2_assigned, themes_by_day)

    for day in range(6, 91):
        checkpoint = day in {30, 60, 90}
        if checkpoint:
            new = []
            reused = reuse_refs(day, seen, 10)
        elif day <= 29:
            new = phase1_new[day]
            reused = reuse_refs(day, seen, 3)
        else:
            new = phase2_new[day]
            reused = reuse_refs(day, seen, 3)
        reused = [value for value in reused if value not in new]
        anchor = new[0] if new else (reused[0] if reused else (seen[0] if seen else None))
        patterns = ["rappel guidé des structures précédentes"] if checkpoint else None
        rows.append({
            "day": day,
            "lessonID": f"lesson-{day + 4:02d}",
            "moduleID": module_for_day(day)["id"],
            "theme": themes_by_day[day],
            "phase": "classic-1-300" if day <= 30 else "classic-301-600",
            "newVocabularyIDs": new,
            "reusedVocabularyIDs": reused,
            "newCanonicalIDs": new,
            "reusedCanonicalIDs": reused,
            "newCount": len(new),
            "reusedCount": len(reused),
            "grammarTarget": grammar_target(day, anchor, patterns),
            "checkpoint": checkpoint,
        })
        for value in new:
            if value not in seen:
                seen.append(value)

    baseline = set(existing_to_canonical.values())
    covered_day30 = baseline | {value for row in rows[:30] for value in row["newCanonicalIDs"] + row["reusedCanonicalIDs"] if value in by_id}
    covered_day90 = baseline | {value for row in rows for value in row["newCanonicalIDs"] + row["reusedCanonicalIDs"] if value in by_id}
    required_300 = {f"hsk20-{rank:03d}" for rank in range(1, 301)}
    required_600 = {f"hsk20-{rank:03d}" for rank in range(1, 601)}
    if not required_300.issubset(covered_day30):
        raise ValueError(f"day 30 misses ranks: {sorted(required_300 - covered_day30)[:8]}")
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
        "rankRanges": {"day30": [1, 300], "day90": [1, 600]},
    }
    milestones = [
        {
            "id": "classic-day-30", "day": 30, "title": localized("Jalon : HSK classique 1–2"), "reference": reference,
            "coverage": {"catalogID": catalog["id"], "catalogVersion": catalog["contentVersion"], "canonicalOnly": True, "vocabularyTarget": 300, "requiredRankRange": [1, 300]},
            "claims": ["Les rangs 1 à 300 du catalogue sont planifiés au plus tard au jour 30.", "Un mot rencontré ne constitue pas une preuve de maîtrise."],
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
            "fixedDays": [1, 5],
            "phaseOneDays": [6, 30],
            "phaseTwoDays": [31, 90],
            "phaseOneNewPerLesson": [8, 10],
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
    covered30 = set(allocation["baselineCanonicalIDs"]) | {value for row in rows[:30] for value in row["newCanonicalIDs"] + row["reusedCanonicalIDs"]}
    covered90 = set(allocation["baselineCanonicalIDs"]) | {value for row in rows for value in row["newCanonicalIDs"] + row["reusedCanonicalIDs"]}
    print(f"wrote {ALLOCATION_PATH} ({len(rows)} days)")
    print("phase-one new counts", [row["newCount"] for row in rows[5:30]])
    print("coverage", {"day30": len(covered30), "day90": len(covered90)})


if __name__ == "__main__":
    main()
