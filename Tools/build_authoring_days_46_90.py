#!/usr/bin/env python3
"""Lower the reviewed late-course scenes into an authoring fragment.

The linguistic material below is editorial data: each dialogue line, reading
paragraph, example and exercise answer is written explicitly.  The only code
in this file is serialization and structural validation.  Vocabulary IDs come
from the release allocation and are never turned into sentences from a gloss.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
AUTHORING = ROOT / "Content" / "authoring"
ALLOCATION_PATH = AUTHORING / "90-day-allocation.json"
OUTPUT_PATH = AUTHORING / "90-day-authoring-days-46-90.json"
CATALOG_PATH = AUTHORING / "hsk-legacy-600.json"
CONTENT_VERSION = "2026.10.0"
LEVEL = "HSK classique 3"


def fr(text: str | dict[str, str]) -> dict[str, str]:
    """Return a French localization without nesting an existing one.

    Scene data stores exercise prompts as localized values so the authoring
    source stays uniform with titles and summaries. The exercise lowerers
    receive those values again; accepting both forms keeps the generated JSON
    at the normative ``{"fr": "..."}`` shape.
    """
    if isinstance(text, dict):
        return dict(text)
    return {"fr": text}


def line(speaker: str, hanzi: str, pinyin: str, translation: str) -> dict[str, Any]:
    return {"speaker": speaker, "hanzi": hanzi, "pinyin": pinyin, "translation": fr(translation), "audio": None}


def paragraph(pid: str, hanzi: str, pinyin: str, translation: str) -> dict[str, Any]:
    return {"id": pid, "hanzi": hanzi, "pinyin": pinyin, "translation": fr(translation), "segmentation": [], "audio": None}


def grammar(anchor: str, pattern: str, explanation: str, examples: list[tuple[str, str, str]]) -> dict[str, Any]:
    return {
        "vocabularyID": anchor,
        "pattern": pattern,
        "explanation": fr(explanation),
        "examples": [{"hanzi": h, "pinyin": p, "translation": fr(t), "audio": None} for h, p, t in examples],
    }


def scene(
    title: str,
    summary: str,
    dialogue: list[dict[str, Any]],
    reading_title: str,
    reading: list[dict[str, Any]],
    meaning_target: str,
    meaning_prompt: str,
    meaning_choices: list[tuple[str, str]],
    meaning_correct: str,
    order_prompt: str,
    order_tokens: list[tuple[str, str, str]],
    order_correct: list[str],
    order_accepted: list[str],
    fill_prompt: str,
    fill_sentence: str,
    fill_answers: list[str],
    listen_line: int,
    listen_prompt: str,
    listen_choices: list[tuple[str, str]],
    listen_correct: str,
    speak_line: int,
    speak_prompt: str,
    reading_prompt: str,
    reading_choices: list[tuple[str, str]],
    reading_correct: str,
    grammar_note: dict[str, Any],
) -> dict[str, Any]:
    return {
        "title": fr(title),
        "summary": fr(summary),
        "dialogue": dialogue,
        "reading": {"title": fr(reading_title), "paragraphs": reading},
        "meaning": {"target": meaning_target, "prompt": fr(meaning_prompt), "choices": meaning_choices, "correct": meaning_correct},
        "order": {"prompt": fr(order_prompt), "tokens": order_tokens, "correct": order_correct, "accepted": order_accepted},
        "fill": {"prompt": fr(fill_prompt), "sentence": fill_sentence, "answers": fill_answers},
        "listen": {"line": listen_line, "prompt": fr(listen_prompt), "choices": listen_choices, "correct": listen_correct},
        "speak": {"line": speak_line, "prompt": fr(speak_prompt)},
        "readingQuestion": {"prompt": fr(reading_prompt), "choices": reading_choices, "correct": reading_correct},
        "grammar": grammar_note,
    }


# The allocation generator's thematic cycling is intentionally overridden for
# this fragment with concrete learner-facing session titles and level-3
# structures.  The override is kept in this file so the common allocation can
# be regenerated later without erasing the late-course editorial decisions.
ALLOCATION_OVERRIDES: dict[int, dict[str, Any]] = {
    46: {"themeLabel": "Prendre soin de soi après le sport", "pattern": "把 + objet + verbe", "anchor": "hsk20-452", "reused": ["hsk20-312", "hsk20-319", "hsk20-334"]},
    47: {"themeLabel": "Une rue bien entretenue", "pattern": "被 + agent", "anchor": "hsk20-303", "reused": ["hsk20-452", "hsk20-507", "hsk20-515"]},
    48: {"themeLabel": "Le nettoyage du quartier", "pattern": "除了…以外…", "anchor": "hsk20-337", "reused": ["hsk20-303", "hsk20-332", "hsk20-333"]},
    49: {"themeLabel": "Préparer une réunion", "pattern": "因为…所以…", "anchor": "hsk20-346", "reused": ["hsk20-337", "hsk20-338", "hsk20-339"]},
    50: {"themeLabel": "Un devoir sur la culture", "pattern": "关于 + nom", "anchor": "hsk20-595", "reused": ["hsk20-346", "hsk20-348", "hsk20-350"]},
    51: {"themeLabel": "Le message du matin", "pattern": "一边…一边…", "anchor": "hsk20-358", "reused": ["hsk20-595", "hsk20-599", "hsk20-533"]},
    52: {"themeLabel": "Une explication au déjeuner", "pattern": "越来越 + adjectif", "anchor": "hsk20-600", "reused": ["hsk20-358", "hsk20-359", "hsk20-362"]},
    53: {"themeLabel": "Le rangement du bureau", "pattern": "把 + objet + verbe", "anchor": "hsk20-371", "reused": ["hsk20-600", "hsk20-365", "hsk20-367"]},
    54: {"themeLabel": "Manger avec attention", "pattern": "虽然…但是…", "anchor": "hsk20-540", "reused": ["hsk20-371", "hsk20-372", "hsk20-375"]},
    55: {"themeLabel": "Traverser une vieille rue", "pattern": "以前…现在…", "anchor": "hsk20-394", "reused": ["hsk20-540", "hsk20-544", "hsk20-349"]},
    56: {"themeLabel": "Les habitudes du week-end", "pattern": "一直 + verbe", "anchor": "hsk20-564", "reused": ["hsk20-394", "hsk20-401", "hsk20-415"]},
    57: {"themeLabel": "Choisir une tenue", "pattern": "如果…就…", "anchor": "hsk20-462", "reused": ["hsk20-564", "hsk20-565", "hsk20-566"]},
    58: {"themeLabel": "Une carte difficile à lire", "pattern": "比较 + adjectif", "anchor": "hsk20-461", "reused": ["hsk20-462", "hsk20-489", "hsk20-546"]},
    59: {"themeLabel": "Le récit d’un voisin", "pattern": "根据 + information", "anchor": "hsk20-378", "reused": ["hsk20-461", "hsk20-466", "hsk20-470"]},
    60: {"themeLabel": "Bilan : comprendre, écouter et produire", "pattern": "Bilan des structures du niveau 3", "anchor": "hsk20-378", "reused": ["hsk20-378", "hsk20-381", "hsk20-385", "hsk20-387", "hsk20-389", "hsk20-390", "hsk20-391", "hsk20-393", "hsk20-394", "hsk20-401"]},
    61: {"themeLabel": "Préparer un voyage à l’étranger", "pattern": "关于…，我想…", "anchor": "hsk20-390", "reused": ["hsk20-378", "hsk20-381", "hsk20-385"]},
    62: {"themeLabel": "Le parc au fil des saisons", "pattern": "虽然…但是…", "anchor": "hsk20-304", "reused": ["hsk20-387", "hsk20-389", "hsk20-390"]},
    63: {"themeLabel": "Un spectacle de quartier", "pattern": "一边…一边…", "anchor": "hsk20-308", "reused": ["hsk20-304", "hsk20-330", "hsk20-342"]},
    64: {"themeLabel": "Retourner une peinture", "pattern": "还 + objet (huán)", "anchor": "hsk20-402", "reused": ["hsk20-308", "hsk20-323", "hsk20-473"]},
    65: {"themeLabel": "Trouver son chemin au parc", "pattern": "越来越 + adjectif", "anchor": "hsk20-487", "reused": ["hsk20-398", "hsk20-400", "hsk20-402"]},
    66: {"themeLabel": "Une occasion de voyager", "pattern": "几乎 + fréquence", "anchor": "hsk20-408", "reused": ["hsk20-487", "hsk20-494", "hsk20-589"]},
    67: {"themeLabel": "Le jardin après la pluie", "pattern": "经常 + verbe", "anchor": "hsk20-395", "reused": ["hsk20-408", "hsk20-409", "hsk20-410"]},
    68: {"themeLabel": "Un oiseau sous la pluie", "pattern": "如果…就…", "anchor": "hsk20-433", "reused": ["hsk20-395", "hsk20-399", "hsk20-404"]},
    69: {"themeLabel": "Musique et pandas en été", "pattern": "一边…一边…", "anchor": "hsk20-568", "reused": ["hsk20-433", "hsk20-474", "hsk20-488"]},
    70: {"themeLabel": "Un repas équilibré", "pattern": "除了…以外…", "anchor": "hsk20-465", "reused": ["hsk20-568", "hsk20-573", "hsk20-512"]},
    71: {"themeLabel": "Se retrouver au marché", "pattern": "一共 + quantité", "anchor": "hsk20-527", "reused": ["hsk20-465", "hsk20-477", "hsk20-479"]},
    72: {"themeLabel": "La fête avant la fin", "pattern": "先…然后…", "anchor": "hsk20-421", "reused": ["hsk20-527", "hsk20-542", "hsk20-416"]},
    73: {"themeLabel": "Résoudre la logistique d’un événement", "pattern": "因为…所以…", "anchor": "hsk20-428", "reused": ["hsk20-580", "hsk20-421", "hsk20-424"]},
    74: {"themeLabel": "Une sortie avec un enfant", "pattern": "虽然…但是…", "anchor": "hsk20-438", "reused": ["hsk20-428", "hsk20-429", "hsk20-431"]},
    75: {"themeLabel": "Une lettre sur l’histoire", "pattern": "为了…，…", "anchor": "hsk20-449", "reused": ["hsk20-438", "hsk20-439", "hsk20-442"]},
    76: {"themeLabel": "La ferme au sud", "pattern": "从 A 到 B", "anchor": "hsk20-459", "reused": ["hsk20-449", "hsk20-451", "hsk20-453"]},
    77: {"themeLabel": "Une présentation en classe", "pattern": "其实…", "anchor": "hsk20-472", "reused": ["hsk20-459", "hsk20-460", "hsk20-463"]},
    78: {"themeLabel": "Donner son avis avec tact", "pattern": "如果…就…", "anchor": "hsk20-490", "reused": ["hsk20-472", "hsk20-481", "hsk20-482"]},
    79: {"themeLabel": "Réparer un appel en ligne", "pattern": "使 + objet + adjectif", "anchor": "hsk20-497", "reused": ["hsk20-490", "hsk20-491", "hsk20-492"]},
    80: {"themeLabel": "Un atelier de langue et de culture", "pattern": "虽然…但是…", "anchor": "hsk20-509", "reused": ["hsk20-497", "hsk20-499", "hsk20-500"]},
    81: {"themeLabel": "Une collecte qui change soudain", "pattern": "突然 + événement", "anchor": "hsk20-521", "reused": ["hsk20-509", "hsk20-511", "hsk20-514"]},
    82: {"themeLabel": "Choisir une routine utile", "pattern": "为了…，…", "anchor": "hsk20-530", "reused": ["hsk20-521", "hsk20-523", "hsk20-526"]},
    83: {"themeLabel": "Vérifier une nouvelle", "pattern": "先…然后…", "anchor": "hsk20-537", "reused": ["hsk20-530", "hsk20-531", "hsk20-534"]},
    84: {"themeLabel": "Choisir des produits frais", "pattern": "需要 + objet", "anchor": "hsk20-548", "reused": ["hsk20-537", "hsk20-539", "hsk20-541"]},
    85: {"themeLabel": "Organiser une activité commune", "pattern": "一边…一边…", "anchor": "hsk20-556", "reused": ["hsk20-548", "hsk20-549", "hsk20-550"]},
    86: {"themeLabel": "Une erreur à la banque", "pattern": "以为…，其实…", "anchor": "hsk20-567", "reused": ["hsk20-556", "hsk20-558", "hsk20-559"]},
    87: {"themeLabel": "Une rencontre sous la lune", "pattern": "越来越 + adjectif", "anchor": "hsk20-576", "reused": ["hsk20-567", "hsk20-569", "hsk20-572"]},
    88: {"themeLabel": "Le jardin de l’école", "pattern": "终于 + résultat", "anchor": "hsk20-582", "reused": ["hsk20-576", "hsk20-577", "hsk20-578"]},
    89: {"themeLabel": "Bilan personnel récent", "pattern": "自己 + verbe", "anchor": "hsk20-592", "reused": ["hsk20-582", "hsk20-586", "hsk20-587"]},
    90: {"themeLabel": "Bilan final : comprendre, écouter et agir", "pattern": "Bilan intégré du niveau 3", "anchor": "hsk20-592", "reused": ["hsk20-592", "hsk20-593", "hsk20-594", "hsk20-596", "hsk20-598", "hsk20-582", "hsk20-586", "hsk20-587", "hsk20-576", "hsk20-577"]},
}


SCENES: dict[int, dict[str, Any]] = {
    46: scene(
        "Prendre soin de soi après le sport",
        "Parler d’une douleur et décrire une petite routine de soin.",
        [
            line("Mina", "你跑步以后，腿还疼吗？", "nǐ pǎo bù yǐ hòu, tuǐ hái téng ma?", "Après ta course, ta jambe te fait encore mal ?"),
            line("Tao", "好多了。我先刷牙，再洗脸。", "hǎo duō le. wǒ xiān shuā yá, zài xǐ liǎn.", "Ça va beaucoup mieux. Je me brosse d’abord les dents, puis je me lave le visage."),
            line("Mina", "你的头发也湿了，先休息吧。", "nǐ de tóu fa yě shī le, xiān xiū xi ba.", "Tes cheveux sont aussi mouillés, repose-toi d’abord."),
            line("Tao", "谢谢你帮忙，我会照顾好自己。", "xiè xie nǐ bāng máng, wǒ huì zhào gù hǎo zì jǐ.", "Merci de m’aider, je vais bien prendre soin de moi."),
        ],
        "Une routine après la course",
        [
            paragraph("p1", "跑步以后，Tao的腿有一点疼。", "pǎo bù yǐ hòu, Tao de tuǐ yǒu yì diǎn téng.", "Après avoir couru, la jambe de Tao lui fait un peu mal."),
            paragraph("p2", "他把水放在桌上，刷牙、洗脸，然后休息。", "tā bǎ shuǐ fàng zài zhuō shàng, shuā yá, xǐ liǎn, rán hòu xiū xi.", "Il pose l’eau sur la table, se brosse les dents, se lave le visage, puis se repose."),
        ],
        "hsk20-515", "Que signifie 疼 dans la première réplique ?", [("a", "propre"), ("b", "douloureux"), ("c", "long")], "b",
        "Remets les groupes dans l’ordre : « Je me lave d’abord le visage ». ", [("a", "我", "wǒ"), ("b", "先", "xiān"), ("c", "洗脸", "xǐ liǎn")], ["a", "b", "c"], ["我先洗脸。", "我先洗脸"],
        "Complète : 我的腿还___吗？", "我的腿还___吗？", ["疼"],
        1, "Quelle routine entends-tu ?", [("a", "Il se repose avant de courir."), ("b", "Il se brosse les dents puis se lave le visage."), ("c", "Il se coupe les cheveux.")], "b",
        3, "Dis la phrase de Tao sur le fait de prendre soin de soi.",
        "Que fait Tao après avoir posé l’eau ?", [("a", "Il se brosse les dents et se lave le visage."), ("b", "Il part au travail."), ("c", "Il prépare un repas.")], "a",
        grammar("hsk20-452", "把 + objet + verbe", "把 place l’objet avant l’action et met en relief ce qu’on en fait.", [("我把水放在桌上。", "wǒ bǎ shuǐ fàng zài zhuō shàng.", "Je pose l’eau sur la table.")]),
    ),
    47: scene(
        "Une rue bien entretenue",
        "Décrire les qualités d’une rue et expliquer un petit problème de hauteur.",
        [
            line("Mina", "你看，这条街很干净。", "nǐ kàn, zhè tiáo jiē hěn gān jìng.", "Regarde, cette rue est très propre."),
            line("Tao", "那栋楼很长，但是入口有点矮。", "nà dòng lóu hěn cháng, dàn shì rù kǒu yǒu diǎn ǎi.", "Cet immeuble est long, mais l’entrée est un peu basse."),
            line("Mina", "打扫的人很聪明，知道哪里最差。", "dǎ sǎo de rén hěn cōng ming, zhī dào nǎ lǐ zuì chà.", "Les personnes qui nettoient sont astucieuses et savent où c’est le pire."),
            line("Tao", "雨水被风吹进来了，我们一起看看。", "yǔ shuǐ bèi fēng chuī jìn lái le, wǒ men yì qǐ kàn kan.", "L’eau de pluie a été poussée à l’intérieur par le vent ; regardons ensemble."),
        ],
        "Le porche de l’immeuble",
        [
            paragraph("p1", "街道很干净，只有入口还需要打扫。", "jiē dào hěn gān jìng, zhǐ yǒu rù kǒu hái xū yào dǎ sǎo.", "La rue est propre ; seul le porche doit encore être nettoyé."),
            paragraph("p2", "入口很矮，雨水被风吹到里面。", "rù kǒu hěn ǎi, yǔ shuǐ bèi fēng chuī dào lǐ miàn.", "L’entrée est basse et l’eau de pluie est poussée à l’intérieur par le vent."),
        ],
        "hsk20-303", "Que signifie 矮 à propos de l’entrée ?", [("a", "basse"), ("b", "propre"), ("c", "longue")], "a",
        "Remets les groupes dans l’ordre : « La rue est propre ». ", [("a", "街道", "jiē dào"), ("b", "很", "hěn"), ("c", "干净", "gān jìng")], ["a", "b", "c"], ["街道很干净。", "街道很干净"],
        "Complète : 入口有点___。", "入口有点___。", ["矮"],
        3, "Que s’est-il passé dans le porche ?", [("a", "La pluie a été poussée à l’intérieur par le vent."), ("b", "Le mur est devenu plus long."), ("c", "La rue a disparu.")], "a",
        0, "Décris la rue en une phrase.",
        "Quelle partie doit encore être nettoyée ?", [("a", "La rue entière."), ("b", "L’entrée."), ("c", "Le toit de l’école.")], "b",
        grammar("hsk20-303", "被 + agent", "被 présente ce qui subit une action et peut ensuite préciser l’agent.", [("雨水被风吹进来了。", "yǔ shuǐ bèi fēng chuī jìn lái le.", "L’eau de pluie a été poussée à l’intérieur par le vent.")]),
    ),
    48: scene(
        "Le nettoyage du quartier",
        "Organiser une action collective et parler d’un retard dans la ville.",
        [
            line("Mina", "今天公共汽车迟到了，街上突然出现很多人。", "jīn tiān gōng gòng qì chē chí dào le, jiē shàng tū rán chū xiàn hěn duō rén.", "Aujourd’hui le bus est en retard et beaucoup de gens sont soudain apparus dans la rue."),
            line("Tao", "我们约好打扫公园，除了邻居以外，学生也来了。", "wǒ men yuē hǎo dǎ sǎo gōng yuán, chú le lín jū yǐ wài, xué shēng yě lái le.", "Nous avions prévu de nettoyer le parc ; en plus des voisins, des élèves sont venus aussi."),
            line("Mina", "城市变得更干净了。", "chéng shì biàn de gèng gān jìng le.", "La ville est devenue plus propre."),
            line("Tao", "等公共汽车的时候，我们先把树叶扫好。", "děng gōng gòng qì chē de shí hou, wǒ men xiān bǎ shù yè sǎo hǎo.", "En attendant le bus, nous ramassons d’abord bien les feuilles."),
        ],
        "Une matinée de bénévolat",
        [
            paragraph("p1", "公共汽车迟到了，志愿者们先在公园见面。", "gōng gòng qì chē chí dào le, zhì yuàn zhě men xiān zài gōng yuán jiàn miàn.", "Le bus est arrivé en retard ; les bénévoles se sont d’abord retrouvés au parc."),
            paragraph("p2", "除了邻居以外，学生也参加了打扫。", "chú le lín jū yǐ wài, xué shēng yě cān jiā le dǎ sǎo.", "En plus des voisins, des élèves ont aussi participé au nettoyage."),
        ],
        "hsk20-338", "Que signifie 迟到 dans la scène ?", [("a", "être en retard"), ("b", "apparaître"), ("c", "nettoyer")], "a",
        "Remets les groupes dans l’ordre : « Les élèves participent aussi ». ", [("a", "学生", "xué shēng"), ("b", "也", "yě"), ("c", "参加", "cān jiā")], ["a", "b", "c"], ["学生也参加。", "学生也参加"],
        "Complète : ___邻居以外，学生也来了。", "___邻居以外，学生也来了。", ["除了"],
        1, "Qui est venu en plus des voisins ?", [("a", "Des chauffeurs."), ("b", "Des élèves."), ("c", "Des médecins.")], "b",
        2, "Dis que la ville est devenue plus propre.",
        "Où les bénévoles se retrouvent-ils ?", [("a", "À l’aéroport."), ("b", "Au parc."), ("c", "Au bureau.")], "b",
        grammar("hsk20-337", "除了…以外…", "除了…以外… ajoute un groupe à un autre groupe déjà mentionné.", [("除了邻居以外，学生也来了。", "chú le lín jū yǐ wài, xué shēng yě lái le.", "En plus des voisins, des élèves sont venus aussi.")]),
    ),
    49: scene(
        "Préparer une réunion",
        "Dire ce qu’on prévoit et expliquer une arrivée anticipée au bureau.",
        [
            line("Mina", "你打算在哪里开会？", "nǐ dǎ suàn zài nǎ lǐ kāi huì?", "Où comptes-tu tenir la réunion ?"),
            line("Tao", "在办公室。因为会议很早，所以我提前到了。", "zài bàn gōng shì. yīn wèi huì yì hěn zǎo, suǒ yǐ wǒ tí qián dào le.", "Au bureau. Comme la réunion est tôt, je suis arrivé en avance."),
            line("Mina", "你担心桌子太低吗？", "nǐ dān xīn zhuō zi tài dī ma?", "Tu crains que la table soit trop basse ?"),
            line("Tao", "不用担心，这个地方当然可以。", "bú yòng dān xīn, zhè ge dì fāng dāng rán kě yǐ.", "Ne t’inquiète pas, cet endroit convient bien sûr."),
        ],
        "Une salle prête à temps",
        [
            paragraph("p1", "Tao打算在办公室开会。", "Tao dǎ suàn zài bàn gōng shì kāi huì.", "Tao compte tenir une réunion au bureau."),
            paragraph("p2", "因为会议很早，所以他提前到了。桌子虽然有点低，但是地方很方便。", "yīn wèi huì yì hěn zǎo, suǒ yǐ tā tí qián dào le. zhuō zi suī rán yǒu diǎn dī, dàn shì dì fāng hěn fāng biàn.", "Comme la réunion est tôt, il est arrivé en avance. Même si la table est un peu basse, l’endroit est pratique."),
        ],
        "hsk20-346", "Que signifie 打算 ?", [("a", "compter faire"), ("b", "s’inquiéter"), ("c", "être bas")], "a",
        "Remets les groupes dans l’ordre : « La réunion est tôt ». ", [("a", "会议", "huì yì"), ("b", "很早", "hěn zǎo")], ["a", "b"], ["会议很早。", "会议很早"],
        "Complète : 因为会议很早，___我提前到了。", "因为会议很早，___我提前到了。", ["所以"],
        1, "Pourquoi Tao est-il arrivé en avance ?", [("a", "Parce que la réunion est tôt."), ("b", "Parce que la table est longue."), ("c", "Parce que la ville est propre.")], "a",
        3, "Dis que tu ne t’inquiètes pas.",
        "Comment est la table ?", [("a", "Un peu basse."), ("b", "Très haute."), ("c", "Cassée.")], "a",
        grammar("hsk20-346", "因为…所以…", "因为 introduit la cause et 所以 annonce sa conséquence.", [("因为会议很早，所以我提前到了。", "yīn wèi huì yì hěn zǎo, suǒ yǐ wǒ tí qián dào le.", "Comme la réunion est tôt, je suis arrivé en avance.")]),
    ),
    50: scene(
        "Un devoir sur la culture",
        "Parler d’une recherche scolaire et de l’effet d’un mot dans un texte.",
        [
            line("Mina", "你的作业写完了吗？", "nǐ de zuò yè xiě wán le ma?", "As-tu fini tes devoirs ?"),
            line("Tao", "还差一点。我用字典查词语。", "hái chà yì diǎn. wǒ yòng zì diǎn chá cí yǔ.", "Il reste encore un peu. Je cherche les mots dans le dictionnaire."),
            line("Mina", "这是关于中国文化的作业吗？", "zhè shì guān yú Zhōng guó wén huà de zuò yè ma?", "C’est un devoir sur la culture chinoise ?"),
            line("Tao", "是。这个词会影响整句话的意思。", "shì. zhè ge cí huì yǐng xiǎng zhěng jù huà de yì si.", "Oui. Ce mot peut influencer le sens de toute la phrase."),
        ],
        "Chercher un mot juste",
        [
            paragraph("p1", "Tao写关于中国文化的作业，但是还有一个词不明白。", "Tao xiě guān yú Zhōng guó wén huà de zuò yè, dàn shì hái yǒu yí ge cí bù míng bai.", "Tao écrit un devoir sur la culture chinoise, mais il ne comprend pas encore un mot."),
            paragraph("p2", "他查了字典，发现这个词会影响整句话的意思。", "tā chá le zì diǎn, fā xiàn zhè ge cí huì yǐng xiǎng zhěng jù huà de yì si.", "Il consulte le dictionnaire et découvre que ce mot peut influencer le sens de toute la phrase."),
        ],
        "hsk20-595", "À quoi sert le 字典 de la scène ?", [("a", "À chercher les mots."), ("b", "À faire du sport."), ("c", "À acheter un billet.")], "a",
        "Remets les groupes dans l’ordre : « Je cherche un mot ». ", [("a", "我", "wǒ"), ("b", "查", "chá"), ("c", "词语", "cí yǔ")], ["a", "b", "c"], ["我查词语。", "我查词语"],
        "Complète : 这个词会___整句话的意思。", "这个词会___整句话的意思。", ["影响"],
        3, "Quel est l’effet du mot ?", [("a", "Il influence le sens de la phrase."), ("b", "Il rend la table basse."), ("c", "Il ferme la bibliothèque.")], "a",
        1, "Dis que tu consultes le dictionnaire.",
        "Quel est le sujet du devoir ?", [("a", "La météo."), ("b", "La culture chinoise."), ("c", "Le sport.")], "b",
        grammar("hsk20-595", "关于 + nom", "关于 introduit le sujet dont on parle ou dont traite un texte.", [("这是关于中国文化的作业。", "zhè shì guān yú Zhōng guó wén huà de zuò yè.", "C’est un devoir sur la culture chinoise.")]),
    ),
    51: scene(
        "Le message du matin",
        "Décrire une routine brève et distinguer un message court d’un long passage.",
        [
            line("Mina", "你看电子邮件了吗？", "nǐ kàn diàn zǐ yóu jiàn le ma?", "As-tu vu le courriel ?"),
            line("Tao", "看了。邮件很短，只有一段。", "kàn le. yóu jiàn hěn duǎn, zhǐ yǒu yí duàn.", "Oui. Le courriel est court, il n’a qu’un paragraphe."),
            line("Mina", "你早上从东边走来吗？", "nǐ zǎo shang cóng dōng biān zǒu lái ma?", "Es-tu venu de l’est ce matin ?"),
            line("Tao", "是。我一边走路，一边听音乐。", "shì. wǒ yì biān zǒu lù, yì biān tīng yīn yuè.", "Oui. Je marche tout en écoutant de la musique."),
        ],
        "Un courriel très court",
        [
            paragraph("p1", "早上，Tao收到一封电子邮件。", "zǎo shang, Tao shōu dào yì fēng diàn zǐ yóu jiàn.", "Le matin, Tao reçoit un courriel."),
            paragraph("p2", "邮件只有一段，他从东边走来时就读完了。", "yóu jiàn zhǐ yǒu yí duàn, tā cóng dōng biān zǒu lái shí jiù dú wán le.", "Le courriel ne contient qu’un paragraphe ; il le termine en venant de l’est."),
        ],
        "hsk20-358", "Que signifie 电子邮件 ?", [("a", "courriel"), ("b", "gare"), ("c", "parapluie")], "a",
        "Remets les groupes dans l’ordre : « Le courriel est court ». ", [("a", "邮件", "yóu jiàn"), ("b", "很", "hěn"), ("c", "短", "duǎn")], ["a", "b", "c"], ["邮件很短。", "邮件很短"],
        "Complète : 邮件只有一___。", "邮件只有一___。", ["段"],
        1, "Combien de paragraphes contient le courriel ?", [("a", "Un seul."), ("b", "Deux longs passages."), ("c", "Aucun.")], "a",
        3, "Dis que tu marches tout en écoutant de la musique.",
        "D’où Tao vient-il ?", [("a", "De l’ouest."), ("b", "De l’est."), ("c", "Du sud.")], "b",
        grammar("hsk20-358", "一边…一边…", "一边 relie deux actions réalisées en même temps.", [("我一边走路，一边听音乐。", "wǒ yì biān zǒu lù, yì biān tīng yīn yuè.", "Je marche tout en écoutant de la musique.")]),
    ),
    52: scene(
        "Une explication au déjeuner",
        "Expliquer le rôle d’un mot et faire le lien entre faim et repas.",
        [
            line("Mina", "你饿了吗？", "nǐ è le ma?", "As-tu faim ?"),
            line("Tao", "有一点。这个词的作用是什么？", "yǒu yì diǎn. zhè ge cí de zuò yòng shì shén me?", "Un peu. Quel est le rôle de ce mot ?"),
            line("Mina", "它使句子更清楚，而且意思越来越自然。", "tā shǐ jù zi gèng qīng chu, ér qiě yì si yuè lái yuè zì rán.", "Il rend la phrase plus claire et le sens devient de plus en plus naturel."),
            line("Tao", "我发现这样说比较好，我们吃饭吧。", "wǒ fā xiàn zhè yàng shuō bǐ jiào hǎo, wǒ men chī fàn ba.", "Je constate que c’est mieux ainsi ; mangeons."),
        ],
        "Une phrase plus claire",
        [
            paragraph("p1", "Tao有一点饿，但是他先问一个词的作用。", "Tao yǒu yì diǎn è, dàn shì tā xiān wèn yí ge cí de zuò yòng.", "Tao a un peu faim, mais il demande d’abord le rôle d’un mot."),
            paragraph("p2", "Mina解释以后，句子的意思越来越清楚。", "Mina jiě shì yǐ hòu, jù zi de yì si yuè lái yuè qīng chu.", "Après l’explication de Mina, le sens de la phrase devient de plus en plus clair."),
        ],
        "hsk20-600", "Que signifie 作用 ici ?", [("a", "rôle"), ("b", "faim"), ("c", "déjeuner")], "a",
        "Remets les groupes dans l’ordre : « La phrase est claire ». ", [("a", "句子", "jù zi"), ("b", "很", "hěn"), ("c", "清楚", "qīng chu")], ["a", "b", "c"], ["句子很清楚。", "句子很清楚"],
        "Complète : 我___这样说比较好。", "我___这样说比较好。", ["发现"],
        2, "Que devient le sens ?", [("a", "Il devient de plus en plus clair."), ("b", "Il disparaît."), ("c", "Il devient très long.")], "a",
        0, "Dis que tu as un peu faim.",
        "Que fait Tao avant de manger ?", [("a", "Il demande le rôle d’un mot."), ("b", "Il prend le métro."), ("c", "Il dort.")], "a",
        grammar("hsk20-600", "越来越 + adjectif", "越来越 indique une évolution progressive vers un degré plus élevé.", [("句子的意思越来越清楚。", "jù zi de yì si yuè lái yuè qīng chu.", "Le sens de la phrase devient de plus en plus clair.")]),
    ),
    53: scene(
        "Le rangement du bureau",
        "Organiser un espace de travail et rassurer une collègue.",
        [
            line("Mina", "文件放在哪里？", "wén jiàn fàng zài nǎ lǐ?", "Où met-on les documents ?"),
            line("Tao", "我把文件放在这个盒子里。", "wǒ bǎ wén jiàn fàng zài zhè ge hé zi lǐ.", "Je mets les documents dans cette boîte."),
            line("Mina", "这里方便吗？附近有打印机吗？", "zhè lǐ fāng biàn ma? fù jìn yǒu dǎ yìn jī ma?", "Est-ce pratique ici ? Y a-t-il une imprimante à proximité ?"),
            line("Tao", "很方便，你放心吧。五分钟就能完成。", "hěn fāng biàn, nǐ fàng xīn ba. wǔ fēn zhōng jiù néng wán chéng.", "C’est très pratique, rassure-toi. Ce sera terminé en cinq minutes."),
        ],
        "Un bureau bien rangé",
        [
            paragraph("p1", "Tao把文件放在盒子里，把桌面留出来。", "Tao bǎ wén jiàn fàng zài hé zi lǐ, bǎ zhuō miàn liú chū lái.", "Tao met les documents dans la boîte et libère le bureau."),
            paragraph("p2", "打印机在附近，所以同事不用担心。", "dǎ yìn jī zài fù jìn, suǒ yǐ tóng shì bú yòng dān xīn.", "L’imprimante est à proximité, la collègue n’a donc pas à s’inquiéter."),
        ],
        "hsk20-371", "Que signifie 方便 ?", [("a", "pratique"), ("b", "rassuré"), ("c", "minute")], "a",
        "Remets les groupes dans l’ordre : « Je mets les documents dans la boîte ». ", [("a", "我", "wǒ"), ("b", "把文件", "bǎ wén jiàn"), ("c", "放在盒子里", "fàng zài hé zi lǐ")], ["a", "b", "c"], ["我把文件放在盒子里。", "我把文件放在盒子里"],
        "Complète : 你___吧。", "你___吧。", ["放心"],
        3, "Combien de temps faut-il ?", [("a", "Cinq minutes."), ("b", "Une heure."), ("c", "Toute la journée.")], "a",
        1, "Dis où tu mets les documents.",
        "Pourquoi la collègue est-elle rassurée ?", [("a", "L’imprimante est à proximité."), ("b", "La rue est longue."), ("c", "Le bus est en retard.")], "a",
        grammar("hsk20-371", "把 + objet + verbe", "把 place l’objet avant le verbe quand on décrit ce qu’on en fait.", [("我把文件放在盒子里。", "wǒ bǎ wén jiàn fàng zài hé zi lǐ.", "Je mets les documents dans la boîte.")]),
    ),
    54: scene(
        "Manger avec attention",
        "Comparer un repas sucré et une option plus légère.",
        [
            line("Mina", "你要吃蛋糕吗？", "nǐ yào chī dàn gāo ma?", "Tu veux manger du gâteau ?"),
            line("Tao", "虽然蛋糕很甜，但是我只喝果汁。", "suī rán dàn gāo hěn tián, dàn shì wǒ zhǐ hē guǒ zhī.", "Même si le gâteau est sucré, je ne bois que du jus de fruit."),
            line("Mina", "用筷子吃饭要小心，别碰到盘子。", "yòng kuài zi chī fàn yào xiǎo xīn, bié pèng dào pán zi.", "Fais attention en mangeant avec les baguettes, ne touche pas l’assiette."),
            line("Tao", "这两杯果汁的味道相同。", "zhè liǎng bēi guǒ zhī de wèi dào xiāng tóng.", "Le goût de ces deux jus est identique."),
        ],
        "Choisir une boisson",
        [
            paragraph("p1", "桌上有蛋糕和果汁，Tao选择了果汁。", "zhuō shàng yǒu dàn gāo hé guǒ zhī, Tao xuǎn zé le guǒ zhī.", "Il y a du gâteau et du jus sur la table ; Tao choisit le jus."),
            paragraph("p2", "他用筷子吃了一点饭，小心地没有碰倒盘子。", "tā yòng kuài zi chī le yì diǎn fàn, xiǎo xīn de méi yǒu pèng dǎo pán zi.", "Il mange un peu de riz avec des baguettes et fait attention à ne pas renverser l’assiette."),
        ],
        "hsk20-540", "Que signifie 相同 ?", [("a", "identique"), ("b", "sucré"), ("c", "assiette")], "a",
        "Remets les groupes dans l’ordre : « Le gâteau est très sucré ». ", [("a", "蛋糕", "dàn gāo"), ("b", "很", "hěn"), ("c", "甜", "tián")], ["a", "b", "c"], ["蛋糕很甜。", "蛋糕很甜"],
        "Complète : 我只喝___。", "我只喝___。", ["果汁"],
        1, "Que choisit Tao ?", [("a", "Du gâteau."), ("b", "Du jus de fruit."), ("c", "De la bière.")], "b",
        2, "Dis qu’il faut faire attention avec les baguettes.",
        "Que ne renverse pas Tao ?", [("a", "Le bol."), ("b", "L’assiette."), ("c", "La table.")], "b",
        grammar("hsk20-540", "虽然…但是…", "虽然 introduit une concession et 但是 présente le contraste.", [("虽然蛋糕很甜，但是我只喝果汁。", "suī rán dàn gāo hěn tián, dàn shì wǒ zhǐ hē guǒ zhī.", "Même si le gâteau est sucré, je ne bois que du jus de fruit.")]),
    ),
    55: scene(
        "Traverser une vieille rue",
        "Décrire une peur passée et constater qu’un trajet est simple aujourd’hui.",
        [
            line("Mina", "你害怕走这条街吗？", "nǐ hài pà zǒu zhè tiáo jiē ma?", "Tu as peur de marcher dans cette rue ?"),
            line("Tao", "以前我很害怕，因为灯很少。", "yǐ qián wǒ hěn hài pà, yīn wèi dēng hěn shǎo.", "Avant, j’avais très peur parce qu’il y avait peu de lampes."),
            line("Mina", "现在路灯多了，走路很简单。", "xiàn zài lù dēng duō le, zǒu lù hěn jiǎn dān.", "Maintenant il y a plus de lampes et marcher est simple."),
            line("Tao", "那座老房子虽然旧，但是没有坏。", "nà zuò lǎo fáng zi suī rán jiù, dàn shì méi yǒu huài.", "Même si cette vieille maison est usée, elle n’est pas cassée."),
        ],
        "Une rue éclairée",
        [
            paragraph("p1", "以前这条街很暗，Tao害怕一个人走。", "yǐ qián zhè tiáo jiē hěn àn, Tao hài pà yí ge rén zǒu.", "Avant, cette rue était sombre et Tao avait peur d’y marcher seul."),
            paragraph("p2", "现在路灯更多了，旧房子也还在。", "xiàn zài lù dēng gèng duō le, jiù fáng zi yě hái zài.", "Maintenant il y a davantage de lampes et la vieille maison est toujours là."),
        ],
        "hsk20-394", "Que signifie 害怕 ?", [("a", "avoir peur"), ("b", "être simple"), ("c", "être vieux")], "a",
        "Remets les groupes dans l’ordre : « Marcher est simple ». ", [("a", "走路", "zǒu lù"), ("b", "很", "hěn"), ("c", "简单", "jiǎn dān")], ["a", "b", "c"], ["走路很简单。", "走路很简单"],
        "Complète : 那座房子虽然___，但是没有坏。", "那座房子虽然___，但是没有坏。", ["旧"],
        2, "Pourquoi la rue est-elle plus facile maintenant ?", [("a", "Il y a plus de lampes."), ("b", "La maison est neuve."), ("c", "Le bus est rapide.")], "a",
        0, "Dis que tu avais peur avant.",
        "Quel est l’état de la vieille maison ?", [("a", "Elle est cassée."), ("b", "Elle est usée mais pas cassée."), ("c", "Elle est neuve.")], "b",
        grammar("hsk20-394", "以前…现在…", "以前 situe une situation passée et 现在 introduit la situation actuelle.", [("以前我很害怕，现在走路很简单。", "yǐ qián wǒ hěn hài pà, xiàn zài zǒu lù hěn jiǎn dān.", "Avant j’avais très peur ; maintenant marcher est simple.")]),
    ),
    56: scene(
        "Les habitudes du week-end",
        "Parler d’habitudes régulières et de projets pour l’avenir.",
        [
            line("Mina", "你以前周末做什么？", "nǐ yǐ qián zhōu mò zuò shén me?", "Que faisais-tu le week-end avant ?"),
            line("Tao", "以前我总是在家，以后想去旅行。", "yǐ qián wǒ zǒng shì zài jiā, yǐ hòu xiǎng qù lǚ xíng.", "Avant, j’étais toujours à la maison ; à l’avenir, je veux voyager."),
            line("Mina", "你现在还会一直学习吗？", "nǐ xiàn zài hái huì yì zhí xué xí ma?", "Tu continueras encore à étudier sans arrêt ?"),
            line("Tao", "会，学习以后再安排旅行。", "huì, xué xí yǐ hòu zài ān pái lǚ xíng.", "Oui, j’organiserai le voyage après les études."),
        ],
        "Un projet pour plus tard",
        [
            paragraph("p1", "Tao以前周末总是在家，现在想改变习惯。", "Tao yǐ qián zhōu mò zǒng shì zài jiā, xiàn zài xiǎng gǎi biàn xí guàn.", "Avant, Tao était toujours à la maison le week-end ; maintenant il veut changer cette habitude."),
            paragraph("p2", "他一直学习，计划以后去旅行。", "tā yì zhí xué xí, jì huà yǐ hòu qù lǚ xíng.", "Il étudie sans relâche et prévoit de voyager plus tard."),
        ],
        "hsk20-564", "Que signifie 一直 ?", [("a", "sans arrêt"), ("b", "avant"), ("c", "week-end")], "a",
        "Remets les groupes dans l’ordre : « Je veux voyager plus tard ». ", [("a", "以后", "yǐ hòu"), ("b", "想", "xiǎng"), ("c", "去旅行", "qù lǚ xíng")], ["a", "b", "c"], ["以后想去旅行。", "以后想去旅行"],
        "Complète : ___我总是在家。", "___我总是在家。", ["以前"],
        1, "Que faisait Tao avant ?", [("a", "Il voyageait toujours."), ("b", "Il était toujours à la maison."), ("c", "Il travaillait au bureau.")], "b",
        3, "Dis que tu étudies sans relâche.",
        "Que prévoit Tao ?", [("a", "Changer de ville demain."), ("b", "Voyager plus tard."), ("c", "Acheter une maison.")], "b",
        grammar("hsk20-564", "一直 + verbe", "一直 place l’action dans une continuité qui se prolonge.", [("他一直学习，计划以后去旅行。", "tā yì zhí xué xí, jì huà yǐ hòu qù lǚ xíng.", "Il étudie sans relâche et prévoit de voyager plus tard.")]),
    ),
    57: scene(
        "Choisir une tenue",
        "Exprimer une préférence et résoudre un problème dans un magasin.",
        [
            line("Mina", "这条裙子好看吗？", "zhè tiáo qún zi hǎo kàn ma?", "Cette jupe est-elle jolie ?"),
            line("Tao", "如果你不满意，就换一条。", "rú guǒ nǐ bù mǎn yì, jiù huàn yì tiáo.", "Si tu n’es pas satisfaite, change-la."),
            line("Mina", "我喜欢这顶帽子，但是鞋有点小。", "wǒ xǐ huan zhè dǐng mào zi, dàn shì xié yǒu diǎn xiǎo.", "J’aime ce chapeau, mais les chaussures sont un peu petites."),
            line("Tao", "别生气，我们再看看。", "bié shēng qì, wǒ men zài kàn kan.", "Ne te fâche pas, regardons encore."),
        ],
        "Au magasin de vêtements",
        [
            paragraph("p1", "Mina喜欢一条裙子，但是对鞋不满意。", "Mina xǐ huan yì tiáo qún zi, dàn shì duì xié bù mǎn yì.", "Mina aime une jupe, mais elle n’est pas satisfaite des chaussures."),
            paragraph("p2", "如果鞋太小，她就换一双。", "rú guǒ xié tài xiǎo, tā jiù huàn yì shuāng.", "Si les chaussures sont trop petites, elle en changera une paire."),
        ],
        "hsk20-462", "Que signifie 帽子 ?", [("a", "chapeau"), ("b", "jupe"), ("c", "chaussure")], "a",
        "Remets les groupes dans l’ordre : « Elle change une paire ». ", [("a", "她", "tā"), ("b", "就换", "jiù huàn"), ("c", "一双", "yì shuāng")], ["a", "b", "c"], ["她就换一双。", "她就换一双"],
        "Complète : 如果鞋太小，她就___一双。", "如果鞋太小，她就___一双。", ["换"],
        1, "Que fera Mina si les chaussures sont trop petites ?", [("a", "Elle les changera."), ("b", "Elle les donnera."), ("c", "Elle les nettoiera.")], "a",
        2, "Dis que tu aimes le chapeau.",
        "Pourquoi Mina n’est-elle pas satisfaite ?", [("a", "La jupe est vieille."), ("b", "Les chaussures sont trop petites."), ("c", "Le chapeau est jaune.")], "b",
        grammar("hsk20-462", "如果…就…", "如果 pose une condition et 就 donne la conséquence prévue.", [("如果鞋太小，她就换一双。", "rú guǒ xié tài xiǎo, tā jiù huàn yì shuāng.", "Si les chaussures sont trop petites, elle en changera une paire.")]),
    ),
    58: scene(
        "Une carte difficile à lire",
        "Demander son chemin et comparer deux itinéraires en ville.",
        [
            line("Mina", "你对这张地图满意吗？", "nǐ duì zhè zhāng dì tú mǎn yì ma?", "Es-tu satisfait de cette carte ?"),
            line("Tao", "我不太满意，但是这条路比较难。", "wǒ bú tài mǎn yì, dàn shì zhè tiáo lù bǐ jiào nán.", "Je ne suis pas très satisfait, mais cette route est assez difficile."),
            line("Mina", "那个胖叔叔也在找车站。", "nà ge pàng shū shu yě zài zhǎo chē zhàn.", "Cet oncle corpulent cherche aussi la gare."),
            line("Tao", "走另一边吧，那里更容易。", "zǒu lìng yì biān ba, nà lǐ gèng róng yì.", "Prenons l’autre côté, c’est plus facile par là."),
        ],
        "Trouver une route plus facile",
        [
            paragraph("p1", "Tao对地图不太满意，一条路比较难，另一条路更容易。", "Tao duì dì tú bú tài mǎn yì, yì tiáo lù bǐ jiào nán, lìng yì tiáo lù gèng róng yì.", "Tao n’est pas très satisfait de la carte : une route est assez difficile, l’autre est plus facile."),
            paragraph("p2", "Mina和Tao跟着另一条路去车站。", "Mina hé Tao gēn zhe lìng yì tiáo lù qù chē zhàn.", "Mina et Tao suivent l’autre route jusqu’à la gare."),
        ],
        "hsk20-461", "Que signifie 满意 dans le dialogue ?", [("a", "satisfait"), ("b", "difficile"), ("c", "étrange")], "a",
        "Remets les groupes dans l’ordre : « Cette route est assez difficile ». ", [("a", "这条路", "zhè tiáo lù"), ("b", "比较", "bǐ jiào"), ("c", "难", "nán")], ["a", "b", "c"], ["这条路比较难。", "这条路比较难"],
        "Complète : 那里更___。", "那里更___。", ["容易"],
        3, "Quelle route choisissent-ils ?", [("a", "La route difficile."), ("b", "L’autre route, plus facile."), ("c", "Ils rentrent chez eux.")], "b",
        0, "Dis que tu comprends la carte.",
        "Où vont Mina et Tao ?", [("a", "À la gare."), ("b", "À l’hôpital."), ("c", "Au supermarché.")], "a",
        grammar("hsk20-461", "比较 + adjectif", "比较 atténue ou compare un degré : une chose est relativement plus ou moins ainsi.", [("这条路比较难，另一条路更容易。", "zhè tiáo lù bǐ jiào nán, lìng yì tiáo lù gèng róng yì.", "Cette route est assez difficile, l’autre est plus facile.")]),
    ),
    59: scene(
        "Le récit d’un voisin",
        "Écouter une histoire et déduire un choix à partir d’informations précises.",
        [
            line("Mina", "你敢讲这个故事吗？", "nǐ gǎn jiǎng zhè ge gù shi ma?", "Oseras-tu raconter cette histoire ?"),
            line("Tao", "敢。根据邻居的话，他跟朋友走了另一条路。", "gǎn. gēn jù lín jū de huà, tā gēn péng you zǒu le lìng yì tiáo lù.", "Oui. D’après les paroles du voisin, il a pris une autre route avec un ami."),
            line("Mina", "这条路更容易吗？", "zhè tiáo lù gèng róng yì ma?", "Cette route était-elle plus facile ?"),
            line("Tao", "是，所以他们终于到了公园。", "shì, suǒ yǐ tā men zhōng yú dào le gōng yuán.", "Oui, alors ils sont finalement arrivés au parc."),
        ],
        "Une route racontée par le voisin",
        [
            paragraph("p1", "邻居讲了一个故事：他跟朋友一起走路。", "lín jū jiǎng le yí ge gù shi: tā gēn péng you yì qǐ zǒu lù.", "Le voisin raconte une histoire : il a marché avec un ami."),
            paragraph("p2", "根据他的说明，另一条路更容易，他们终于到了公园。", "gēn jù tā de shuō míng, lìng yì tiáo lù gèng róng yì, tā men zhōng yú dào le gōng yuán.", "D’après ses explications, l’autre route était plus facile et ils sont finalement arrivés au parc."),
        ],
        "hsk20-378", "Que signifie 敢 ?", [("a", "oser"), ("b", "suivre"), ("c", "raconter")], "a",
        "Remets les groupes dans l’ordre : « Ils arrivent enfin au parc ». ", [("a", "他们", "tā men"), ("b", "终于", "zhōng yú"), ("c", "到了公园", "dào le gōng yuán")], ["a", "b", "c"], ["他们终于到了公园。", "他们终于到了公园"],
        "Complète : ___他的说明，另一条路更容易。", "___他的说明，另一条路更容易。", ["根据"],
        1, "Avec qui le voisin marche-t-il ?", [("a", "Avec un ami."), ("b", "Avec son professeur."), ("c", "Avec le chauffeur.")], "a",
        0, "Raconte que tu oses parler.",
        "Pourquoi la route est-elle choisie ?", [("a", "Elle est plus ancienne."), ("b", "Elle est plus facile."), ("c", "Elle est plus longue.")], "b",
        grammar("hsk20-381", "根据 + information", "根据 introduit l’information sur laquelle on fonde une conclusion.", [("根据他的说明，另一条路更容易。", "gēn jù tā de shuō míng, lìng yì tiáo lù gèng róng yì.", "D’après ses explications, l’autre route est plus facile.")]),
    ),
    60: scene(
        "Bilan : comprendre, écouter et produire",
        "Réinvestir plusieurs structures de niveau 3 dans une scène courte.",
        [
            line("Mina", "昨天我们因为下雨改变了计划。", "zuó tiān wǒ men yīn wèi xià yǔ gǎi biàn le jì huà.", "Hier, nous avons changé nos plans parce qu’il pleuvait."),
            line("Tao", "我把地图放在桌上，大家就明白了。", "wǒ bǎ dì tú fàng zài zhuō shàng, dà jiā jiù míng bai le.", "J’ai posé la carte sur la table et tout le monde a compris."),
            line("Mina", "虽然路很长，但是我们终于到了。", "suī rán lù hěn cháng, dàn shì wǒ men zhōng yú dào le.", "Même si la route était longue, nous sommes finalement arrivés."),
            line("Tao", "现在请听问题，再用完整的句子回答。", "xiàn zài qǐng tīng wèn tí, zài yòng wán zhěng de jù zi huí dá.", "Maintenant, écoute la question puis réponds avec une phrase complète."),
        ],
        "Une journée de révision",
        [
            paragraph("p1", "下雨以后，大家根据地图改变了路线。", "xià yǔ yǐ hòu, dà jiā gēn jù dì tú gǎi biàn le lù xiàn.", "Après la pluie, tout le monde a changé d’itinéraire en fonction de la carte."),
            paragraph("p2", "路虽然很长，但是大家互相帮忙，终于到了目的地。", "lù suī rán hěn cháng, dàn shì dà jiā hù xiāng bāng máng, zhōng yú dào le mù dì dì.", "Même si la route était longue, tout le monde s’est aidé et a finalement atteint sa destination."),
        ],
        "hsk20-381", "Que signifie 根据 dans le texte ?", [("a", "d’après / selon"), ("b", "soudain"), ("c", "seulement")], "a",
        "Construis : « Nous avons finalement compris ». ", [("a", "我们", "wǒ men"), ("b", "终于", "zhōng yú"), ("c", "明白了", "míng bai le")], ["a", "b", "c"], ["我们终于明白了。", "我们终于明白了"],
        "Complète : 我___地图放在桌上。", "我___地图放在桌上。", ["把"],
        2, "Quelle difficulté est mentionnée ?", [("a", "La route est longue."), ("b", "La carte est neuve."), ("c", "Le bureau est fermé.")], "a",
        3, "Réponds avec une phrase complète après l’écoute.",
        "Comment le groupe atteint-il sa destination ?", [("a", "Chacun part seul."), ("b", "Le groupe s’entraide."), ("c", "Le groupe annule le voyage.")], "b",
        grammar("hsk20-381", "Bilan des structures du niveau 3", "Cette séance réunit cause, 把, concession et résultat dans une réponse suivie.", [("虽然路很长，但是我们终于到了。", "suī rán lù hěn cháng, dàn shì wǒ men zhōng yú dào le.", "Même si la route était longue, nous sommes finalement arrivés."), ("我把地图放在桌上。", "wǒ bǎ dì tú fàng zài zhuō shàng.", "J’ai posé la carte sur la table.")]),
    ),
    61: scene(
        "Préparer un voyage à l’étranger",
        "Parler d’un pays et de ce qui préoccupe un voyageur avant le départ.",
        [
            line("Mina", "你想去哪个国家？", "nǐ xiǎng qù nǎ ge guó jiā?", "Dans quel pays veux-tu aller ?"),
            line("Tao", "我想去法国。关于这个国家，我还想了解更多。", "wǒ xiǎng qù Fǎ guó. guān yú zhè ge guó jiā, wǒ hái xiǎng liǎo jiě gèng duō.", "Je veux aller en France. Je veux encore mieux connaître ce pays."),
            line("Mina", "别忘记关窗，也要关心天气。", "bié wàng jì guān chuāng, yě yào guān xīn tiān qì.", "N’oublie pas de fermer la fenêtre et pense aussi à la météo."),
            line("Tao", "我记得。过去的旅行经验会帮助我。", "wǒ jì de. guò qù de lǚ xíng jīng yàn huì bāng zhù wǒ.", "Je m’en souviens. Mon expérience passée du voyage m’aidera."),
        ],
        "Une destination à découvrir",
        [
            paragraph("p1", "Tao准备去法国，想了解这个国家的生活。", "Tao zhǔn bèi qù Fǎ guó, xiǎng liǎo jiě zhè ge guó jiā de shēng huó.", "Tao se prépare à aller en France et veut connaître la vie de ce pays."),
            paragraph("p2", "他关心天气，也记得离开以前关好窗。", "tā guān xīn tiān qì, yě jì de lí kāi yǐ qián guān hǎo chuāng.", "Il pense à la météo et se souvient de bien fermer la fenêtre avant de partir."),
        ],
        "hsk20-390", "Que signifie 关于 ?", [("a", "au sujet de"), ("b", "dans le passé"), ("c", "fermer")], "a",
        "Remets les groupes dans l’ordre : « Je veux connaître ce pays ». ", [("a", "我", "wǒ"), ("b", "想了解", "xiǎng liǎo jiě"), ("c", "这个国家", "zhè ge guó jiā")], ["a", "b", "c"], ["我想了解这个国家。", "我想了解这个国家"],
        "Complète : 我还想___更多。", "我还想___更多。", ["了解"],
        2, "Que doit faire Tao avant de partir ?", [("a", "Fermer la fenêtre."), ("b", "Changer de pays."), ("c", "Acheter un gâteau.")], "a",
        1, "Dis que tu veux mieux connaître ce pays.",
        "Qu’est-ce qui peut aider Tao ?", [("a", "Son expérience passée."), ("b", "Une vieille chaise."), ("c", "Une route plus longue.")], "a",
        grammar("hsk20-390", "关于…，我想…", "关于 introduit un sujet, puis 我想 exprime le projet ou le souhait qui s’y rapporte.", [("关于这个国家，我还想了解更多。", "guān yú zhè ge guó jiā, wǒ hái xiǎng liǎo jiě gèng duō.", "Au sujet de ce pays, je veux encore en apprendre davantage.")]),
    ),
    62: scene(
        "Le parc au fil des saisons",
        "Comparer les activités possibles au printemps et en hiver.",
        [
            line("Mina", "你有什么爱好？", "nǐ yǒu shén me ài hào?", "Quels sont tes loisirs ?"),
            line("Tao", "我喜欢在春天看草和动物。", "wǒ xǐ huan zài chūn tiān kàn cǎo hé dòng wù.", "J’aime regarder l’herbe et les animaux au printemps."),
            line("Mina", "虽然冬天很冷，但是公园也很安静。", "suī rán dōng tiān hěn lěng, dàn shì gōng yuán yě hěn ān jìng.", "Même si l’hiver est froid, le parc est aussi très calme."),
            line("Tao", "那我们冬天再来，带一杯热茶。", "nà wǒ men dōng tiān zài lái, dài yì bēi rè chá.", "Alors revenons en hiver avec une tasse de thé chaud."),
        ],
        "Deux saisons au parc",
        [
            paragraph("p1", "春天，草变绿了，公园里出现很多小动物。", "chūn tiān, cǎo biàn lǜ le, gōng yuán lǐ chū xiàn hěn duō xiǎo dòng wù.", "Au printemps, l’herbe verdit et beaucoup de petits animaux apparaissent dans le parc."),
            paragraph("p2", "冬天虽然冷，但是这里很安静，Tao还是喜欢来。", "dōng tiān suī rán lěng, dàn shì zhè lǐ hěn ān jìng, Tao hái shì xǐ huan lái.", "Même si l’hiver est froid, l’endroit est calme et Tao aime toujours venir."),
        ],
        "hsk20-304", "Que signifie 爱好 ?", [("a", "loisir"), ("b", "hiver"), ("c", "animal")], "a",
        "Remets les groupes dans l’ordre : « L’herbe devient verte ». ", [("a", "草", "cǎo"), ("b", "变绿", "biàn lǜ"), ("c", "了", "le")], ["a", "b", "c"], ["草变绿了。", "草变绿"],
        "Complète : ___天，草变绿了。", "___天，草变绿了。", ["春"],
        2, "Comment est le parc en hiver ?", [("a", "Très bruyant."), ("b", "Calme."), ("c", "Fermé.")], "b",
        0, "Dis quel est ton loisir.",
        "Que voit-on au printemps ?", [("a", "De petits animaux."), ("b", "Des avions."), ("c", "Des réunions.")], "a",
        grammar("hsk20-304", "虽然…但是…", "虽然 introduit une concession ; 但是 maintient le point principal malgré celle-ci.", [("虽然冬天很冷，但是公园也很安静。", "suī rán dōng tiān hěn lěng, dàn shì gōng yuán yě hěn ān jìng.", "Même si l’hiver est froid, le parc est aussi très calme.")]),
    ),
    63: scene(
        "Un spectacle de quartier",
        "Parler d’un déménagement et d’une représentation sportive préparée par de jeunes voisins.",
        [
            line("Mina", "你搬到这里多久了？", "nǐ bān dào zhè lǐ duō jiǔ le?", "Depuis combien de temps as-tu déménagé ici ?"),
            line("Tao", "不久。年轻人正在准备一个表演。", "bù jiǔ. nián qīng rén zhèng zài zhǔn bèi yí ge biǎo yǎn.", "Pas longtemps. Les jeunes préparent un spectacle."),
            line("Mina", "他们一边练习体育动作，一边听音乐吗？", "tā men yì biān liàn xí tǐ yù dòng zuò, yì biān tīng yīn yuè ma?", "Ils répètent des mouvements sportifs tout en écoutant de la musique ?"),
            line("Tao", "是，周末就可以看到了。", "shì, zhōu mò jiù kě yǐ kàn dào le.", "Oui, on pourra le voir ce week-end."),
        ],
        "舞台前的练习",
        [
            paragraph("p1", "Tao搬到社区不久，发现年轻人喜欢体育。", "Tao bān dào shè qū bù jiǔ, fā xiàn nián qīng rén xǐ huan tǐ yù.", "Tao a déménagé dans le quartier récemment et découvre que les jeunes aiment le sport."),
            paragraph("p2", "他们一边练习，一边准备周末的表演。", "tā men yì biān liàn xí, yì biān zhǔn bèi zhōu mò de biǎo yǎn.", "Ils répètent tout en préparant le spectacle du week-end."),
        ],
        "hsk20-323", "Que signifie 表演 ?", [("a", "spectacle"), ("b", "déménager"), ("c", "jeune")], "a",
        "Remets les groupes dans l’ordre : « Les jeunes préparent un spectacle ». ", [("a", "年轻人", "nián qīng rén"), ("b", "准备", "zhǔn bèi"), ("c", "表演", "biǎo yǎn")], ["a", "b", "c"], ["年轻人准备表演。", "年轻人准备表演"],
        "Complète : 他们一边练习，一边准备周末的___。", "他们一边练习，一边准备周末的___。", ["表演"],
        1, "Que préparent les jeunes ?", [("a", "Un voyage."), ("b", "Un spectacle."), ("c", "Un examen.")], "b",
        3, "Dis que les jeunes répètent tout en écoutant de la musique.",
        "Quand peut-on voir le spectacle ?", [("a", "Ce soir."), ("b", "Ce week-end."), ("c", "L’hiver prochain.")], "b",
        grammar("hsk20-308", "一边…一边…", "一边…一边… coordonne deux actions simultanées réalisées par le même sujet.", [("他们一边练习，一边准备表演。", "tā men yì biān liàn xí, yì biān zhǔn bèi biǎo yǎn.", "Ils répètent tout en préparant le spectacle.")]),
    ),
    64: scene(
        "Retourner une peinture",
        "Demander un échange et rendre une œuvre empruntée dans une classe d’art.",
        [
            line("Mina", "这幅画是黄色的吗？", "zhè fú huà shì huáng sè de ma?", "Cette peinture est-elle jaune ?"),
            line("Tao", "是。我想换一幅，因为颜色太暗了。", "shì. wǒ xiǎng huàn yì fú, yīn wèi yán sè tài àn le.", "Oui. Je voudrais en changer parce que la couleur est trop sombre."),
            line("Mina", "你明天把画还给老师吗？", "nǐ míng tiān bǎ huà huán gěi lǎo shī ma?", "Tu rends la peinture au professeur demain ?"),
            line("Tao", "当然，我会把它还给老师。", "dāng rán, wǒ huì bǎ tā huán gěi lǎo shī.", "Bien sûr, je la rendrai au professeur."),
        ],
        "Une couleur à remplacer",
        [
            paragraph("p1", "Tao借了一幅画，但是颜色太暗，他想换一幅。", "Tao jiè le yì fú huà, dàn shì yán sè tài àn, tā xiǎng huàn yì fú.", "Tao a emprunté une peinture, mais la couleur est trop sombre et il veut en changer."),
            paragraph("p2", "明天他会把第一幅画还给老师。", "míng tiān tā huì bǎ dì yī fú huà huán gěi lǎo shī.", "Demain, il rendra la première peinture au professeur."),
        ],
        "hsk20-402", "Que signifie 还 dans la scène ?", [("a", "rendre"), ("b", "jaune"), ("c", "dessiner")], "a",
        "Remets les groupes dans l’ordre : « Je rendrai la peinture ». ", [("a", "我会", "wǒ huì"), ("b", "把画", "bǎ huà"), ("c", "还给老师", "huán gěi lǎo shī")], ["a", "b", "c"], ["我会把画还给老师。", "我会把画还给老师"],
        "Complète : 我想___一幅画。", "我想___一幅画。", ["换"],
        2, "Que fera Tao demain ?", [("a", "Il rendra la peinture."), ("b", "Il achètera du thé."), ("c", "Il fermera la classe.")], "a",
        0, "Dis que la peinture est jaune.",
        "Pourquoi Tao veut-il changer de peinture ?", [("a", "Elle est trop claire."), ("b", "Sa couleur est trop sombre."), ("c", "Elle est trop grande.")], "b",
        grammar("hsk20-402", "还 + objet (huán)", "Dans 还书 ou 还画, 还 se prononce huán et signifie rendre quelque chose.", [("我会把画还给老师。", "wǒ huì bǎ huà huán gěi lǎo shī.", "Je rendrai la peinture au professeur.")]),
    ),
    65: scene(
        "Trouver son chemin au parc",
        "Demander une indication malgré le vent et rendre un trajet progressivement plus clair.",
        [
            line("Mina", "请把公园的地址说清楚。", "qǐng bǎ gōng yuán de dì zhǐ shuō qīng chu.", "Dis clairement l’adresse du parc, s’il te plaît."),
            line("Tao", "从这里往北走，路就容易找了。", "cóng zhè lǐ wǎng běi zǒu, lù jiù róng yì zhǎo le.", "Depuis ici, va vers le nord et la route sera facile à trouver."),
            line("Mina", "今天刮风，带上地图很重要。", "jīn tiān guā fēng, dài shàng dì tú hěn zhòng yào.", "Il y a du vent aujourd’hui ; il est important de prendre une carte."),
            line("Tao", "公园越来越近了。", "gōng yuán yuè lái yuè jìn le.", "Le parc est de plus en plus proche."),
        ],
        "L’adresse du parc",
        [
            paragraph("p1", "刮风的时候，Tao把公园地址说得很清楚。", "guā fēng de shí hou, Tao bǎ gōng yuán dì zhǐ shuō de hěn qīng chu.", "Quand il y a du vent, Tao énonce clairement l’adresse du parc."),
            paragraph("p2", "他们往北走，公园越来越近。", "tā men wǎng běi zǒu, gōng yuán yuè lái yuè jìn.", "Ils marchent vers le nord et le parc se rapproche de plus en plus."),
        ],
        "hsk20-487", "Que signifie 清楚 ?", [("a", "clairement"), ("b", "important"), ("c", "venteux")], "a",
        "Remets les groupes dans l’ordre : « Le parc est de plus en plus proche ». ", [("a", "公园", "gōng yuán"), ("b", "越来越", "yuè lái yuè"), ("c", "近", "jìn")], ["a", "b", "c"], ["公园越来越近。", "公园越来越近"],
        "Complète : 今天___风。", "今天___风。", ["刮"],
        3, "Que devient la distance au parc ?", [("a", "Le parc s’éloigne."), ("b", "Le parc se rapproche."), ("c", "Le parc ferme.")], "b",
        0, "Dis l’adresse clairement.",
        "Dans quelle direction marchent-ils ?", [("a", "Vers le nord."), ("b", "Vers l’ouest."), ("c", "Vers le sud.")], "a",
        grammar("hsk20-487", "越来越 + adjectif", "越来越 montre un changement progressif qui rapproche la situation d’un degré nouveau.", [("公园越来越近了。", "gōng yuán yuè lái yuè jìn le.", "Le parc est de plus en plus proche.")]),
    ),
    66: scene(
        "Une occasion de voyager",
        "Choisir un itinéraire et se souvenir des consignes avant un départ.",
        [
            line("Mina", "你想坐火车或者坐飞机？", "nǐ xiǎng zuò huǒ chē huò zhě zuò fēi jī?", "Tu veux prendre le train ou l’avion ?"),
            line("Tao", "这是一次极好的机会，我几乎每天都在计划。", "zhè shì yí cì jí hǎo de jī huì, wǒ jī hū měi tiān dōu zài jì huà.", "C’est une très bonne occasion ; je planifie presque tous les jours."),
            line("Mina", "记得带护照。", "jì de dài hù zhào.", "N’oublie pas ton passeport."),
            line("Tao", "我记得，明天就出发。", "wǒ jì de, míng tiān jiù chū fā.", "Je m’en souviens, je pars demain."),
        ],
        "Le choix du transport",
        [
            paragraph("p1", "Tao有一次旅行机会，要在火车和飞机之间选择。", "Tao yǒu yí cì lǚ xíng jī huì, yào zài huǒ chē hé fēi jī zhī jiān xuǎn zé.", "Tao a une occasion de voyager et doit choisir entre le train et l’avion."),
            paragraph("p2", "他几乎准备好了，只要记得带护照就可以出发。", "tā jī hū zhǔn bèi hǎo le, zhǐ yào jì de dài hù zhào jiù kě yǐ chū fā.", "Il est presque prêt ; il lui suffit de se souvenir de prendre son passeport pour partir."),
        ],
        "hsk20-409", "Que signifie 机会 ?", [("a", "occasion"), ("b", "avion"), ("c", "se souvenir")], "a",
        "Remets les groupes dans l’ordre : « N’oublie pas ton passeport ». ", [("a", "记得", "jì de"), ("b", "带", "dài"), ("c", "护照", "hù zhào")], ["a", "b", "c"], ["记得带护照。", "记得带护照"],
        "Complète : 我___每天都在计划。", "我___每天都在计划。", ["几乎"],
        0, "Entre quels moyens de transport Tao choisit-il ?", [("a", "Le train et l’avion."), ("b", "Le métro et le vélo."), ("c", "Le taxi et le bateau.")], "a",
        2, "Dis que tu n’oublies pas le passeport.",
        "Que doit faire Tao pour partir ?", [("a", "Prendre le passeport."), ("b", "Changer de ville."), ("c", "Fermer la gare.")], "a",
        grammar("hsk20-409", "几乎 + fréquence", "几乎 signifie « presque » et modifie ici une fréquence ou une quantité.", [("我几乎每天都在计划。", "wǒ jī hū měi tiān dōu zài jì huà.", "Je planifie presque tous les jours.")]),
    ),
    67: scene(
        "Le jardin après la pluie",
        "Observer un jardin, une rivière et les changements d’environnement au fil des saisons.",
        [
            line("Mina", "你经常来这个花园吗？", "nǐ jīng cháng lái zhè ge huā yuán ma?", "Viens-tu souvent dans ce jardin ?"),
            line("Tao", "经常。河边的环境在春天特别好。", "jīng cháng. hé biān de huán jìng zài chūn tiān tè bié hǎo.", "Souvent. L’environnement près de la rivière est particulièrement beau au printemps."),
            line("Mina", "每个季节都有变化。", "měi ge jì jié dōu yǒu biàn huà.", "Chaque saison apporte des changements."),
            line("Tao", "是，雨后花也更鲜艳了。", "shì, yǔ hòu huā yě gèng xiān yàn le.", "Oui, après la pluie les fleurs sont aussi plus éclatantes."),
        ],
        "Une promenade près de l’eau",
        [
            paragraph("p1", "Tao经常到河边的花园散步。", "Tao jīng cháng dào hé biān de huā yuán sàn bù.", "Tao se promène souvent dans le jardin près de la rivière."),
            paragraph("p2", "他发现不同季节的环境都有变化，雨后的花特别好看。", "tā fā xiàn bù tóng jì jié de huán jìng dōu yǒu biàn huà, yǔ hòu de huā tè bié hǎo kàn.", "Il constate que l’environnement change selon les saisons et que les fleurs après la pluie sont particulièrement belles."),
        ],
        "hsk20-404", "Que signifie 环境 ?", [("a", "environnement"), ("b", "jardinier"), ("c", "saison")], "a",
        "Remets les groupes dans l’ordre : « Chaque saison change ». ", [("a", "每个季节", "měi ge jì jié"), ("b", "都有", "dōu yǒu"), ("c", "变化", "biàn huà")], ["a", "b", "c"], ["每个季节都有变化。", "每个季节都有变化"],
        "Complète : ___边的环境特别好。", "___边的环境特别好。", ["河"],
        1, "Où se trouve le jardin ?", [("a", "Près de la rivière."), ("b", "Près de la gare."), ("c", "Dans l’école.")], "a",
        3, "Dis que chaque saison apporte des changements.",
        "Quand les fleurs sont-elles particulièrement belles ?", [("a", "Avant l’hiver."), ("b", "Après la pluie."), ("c", "Pendant la nuit.")], "b",
        grammar("hsk20-395", "经常 + verbe", "经常 place une action dans une fréquence habituelle.", [("Tao经常到河边的花园散步。", "Tao jīng cháng dào hé biān de huā yuán sàn bù.", "Tao se promène souvent dans le jardin près de la rivière.")]),
    ),
    68: scene(
        "Un oiseau sous la pluie",
        "Décrire un après-midi d’automne et choisir quoi faire quand la pluie commence.",
        [
            line("Mina", "你在树下看见什么？", "nǐ zài shù xià kàn jiàn shén me?", "Qu’as-tu vu sous l’arbre ?"),
            line("Tao", "一只鸟。秋天这里很安静。", "yì zhī niǎo. qiū tiān zhè lǐ hěn ān jìng.", "Un oiseau. Ici, c’est très calme en automne."),
            line("Mina", "如果下雨，你有伞吗？", "rú guǒ xià yǔ, nǐ yǒu sǎn ma?", "S’il pleut, as-tu un parapluie ?"),
            line("Tao", "有。我们等一会儿，雨停了再走。", "yǒu. wǒ men děng yí huìr, yǔ tíng le zài zǒu.", "Oui. Attendons un moment et partons quand la pluie s’arrêtera."),
        ],
        "Attendre sous un arbre",
        [
            paragraph("p1", "秋天的公园很安静，Tao在树下发现一只鸟。", "qiū tiān de gōng yuán hěn ān jìng, Tao zài shù xià fā xiàn yì zhī niǎo.", "Le parc est très calme en automne ; Tao découvre un oiseau sous un arbre."),
            paragraph("p2", "雨来了，他打开伞，等了一会儿再回家。", "yǔ lái le, tā dǎ kāi sǎn, děng le yí huìr zài huí jiā.", "La pluie arrive ; il ouvre son parapluie, attend un moment puis rentre chez lui."),
        ],
        "hsk20-474", "Que signifie 鸟 ?", [("a", "oiseau"), ("b", "arbre"), ("c", "automne")], "a",
        "Remets les groupes dans l’ordre : « Attendons un moment ». ", [("a", "我们", "wǒ men"), ("b", "等", "děng"), ("c", "一会儿", "yí huìr")], ["a", "b", "c"], ["我们等一会儿。", "我们等一会儿"],
        "Complète : 如果下雨，我有___。", "如果下雨，我有___。", ["伞"],
        3, "Que font-ils avant de repartir ?", [("a", "Ils attendent que la pluie s’arrête."), ("b", "Ils montent dans un avion."), ("c", "Ils nettoient la rivière.")], "a",
        0, "Dis que tu as vu un oiseau.",
        "Où Tao découvre-t-il l’oiseau ?", [("a", "Sous un arbre."), ("b", "Dans une salle."), ("c", "À la banque.")], "a",
        grammar("hsk20-433", "如果…就…", "如果 pose la condition ; dans cette scène, la conséquence est organisée avec le parapluie et l’attente.", [("如果下雨，我们就等一会儿。", "rú guǒ xià yǔ, wǒ men jiù děng yí huìr.", "S’il pleut, nous attendrons un moment.")]),
    ),
    69: scene(
        "Musique et pandas en été",
        "Raconter une sortie au zoo et proposer une activité pour l’après-midi.",
        [
            line("Mina", "夏天的太阳很强，你想去哪里？", "xià tiān de tài yáng hěn qiáng, nǐ xiǎng qù nǎ lǐ?", "Le soleil est fort en été ; où veux-tu aller ?"),
            line("Tao", "去动物园看熊猫，再听音乐。", "qù dòng wù yuán kàn xióng māo, zài tīng yīn yuè.", "Au zoo pour voir les pandas, puis écouter de la musique."),
            line("Mina", "你一边玩游戏，一边听吗？", "nǐ yì biān wán yóu xì, yì biān tīng ma?", "Tu écoutes tout en jouant à un jeu ?"),
            line("Tao", "不，先看熊猫，晚上再玩游戏。", "bù, xiān kàn xióng māo, wǎn shang zài wán yóu xì.", "Non, je regarde d’abord les pandas et je jouerai le soir."),
        ],
        "Une sortie au zoo",
        [
            paragraph("p1", "夏天太阳很强，Tao和Mina先去动物园。", "xià tiān tài yáng hěn qiáng, Tao hé Mina xiān qù dòng wù yuán.", "En été le soleil est fort ; Tao et Mina vont d’abord au zoo."),
            paragraph("p2", "他们看了熊猫，晚上回家听音乐、玩游戏。", "tā men kàn le xióng māo, wǎn shang huí jiā tīng yīn yuè, wán yóu xì.", "Ils regardent les pandas puis rentrent le soir écouter de la musique et jouer."),
        ],
        "hsk20-552", "Que signifie 熊猫 ?", [("a", "panda"), ("b", "soleil"), ("c", "musique")], "a",
        "Remets les groupes dans l’ordre : « Nous regardons les pandas ». ", [("a", "我们", "wǒ men"), ("b", "看", "kàn"), ("c", "熊猫", "xióng māo")], ["a", "b", "c"], ["我们看熊猫。", "我们看熊猫"],
        "Complète : 夏天的___很大。", "夏天的___很大。", ["太阳"],
        1, "Que font-ils d’abord ?", [("a", "Ils jouent à un jeu."), ("b", "Ils regardent les pandas."), ("c", "Ils écoutent la radio.")], "b",
        2, "Dis que tu veux aller au zoo.",
        "Que font-ils le soir ?", [("a", "Ils rentrent écouter de la musique et jouer."), ("b", "Ils vont à la banque."), ("c", "Ils font une randonnée.")], "a",
        grammar("hsk20-568", "一边…一边…", "一边…一边… décrit deux actions simultanées ; ici, la scène distingue cette simultanéité du programme successif.", [("他一边听音乐，一边玩游戏。", "tā yì biān tīng yīn yuè, yì biān wán yóu xì.", "Il écoute de la musique tout en jouant à un jeu.")]),
    ),
    70: scene(
        "Un repas équilibré",
        "Choisir des aliments et parler d’une consommation raisonnable.",
        [
            line("Mina", "你要吃面条吗？", "nǐ yào chī miàn tiáo ma?", "Tu veux manger des nouilles ?"),
            line("Tao", "要，但是除了葡萄以外，糖要少吃。", "yào, dàn shì chú le pú tao yǐ wài, táng yào shǎo chī.", "Oui, mais à part les raisins, il faut manger peu de sucre."),
            line("Mina", "啤酒也要少喝。", "pí jiǔ yě yào shǎo hē.", "Il faut aussi boire peu de bière."),
            line("Tao", "我把面条放在盘子里，慢慢吃。", "wǒ bǎ miàn tiáo fàng zài pán zi lǐ, màn màn chī.", "Je mets les nouilles dans l’assiette et je mange lentement."),
        ],
        "À table sans excès",
        [
            paragraph("p1", "Tao要吃面条，也想吃一点葡萄。", "Tao yào chī miàn tiáo, yě xiǎng chī yì diǎn pú tao.", "Tao veut manger des nouilles et aussi un peu de raisins."),
            paragraph("p2", "糖要少吃，啤酒也喝得很少。", "táng yào shǎo chī, pí jiǔ yě hē de hěn shǎo.", "Il mange peu de sucre et boit aussi très peu de bière."),
        ],
        "hsk20-465", "Que signifie 面条 ?", [("a", "nouilles"), ("b", "raisins"), ("c", "sucre")], "a",
        "Remets les groupes dans l’ordre : « Je mets les nouilles dans l’assiette ». ", [("a", "我把", "wǒ bǎ"), ("b", "面条", "miàn tiáo"), ("c", "放在盘子里", "fàng zài pán zi lǐ")], ["a", "b", "c"], ["我把面条放在盘子里。", "我把面条放在盘子里"],
        "Complète : 我不吃___。", "我不吃___。", ["糖"],
        1, "Que ne mange pas Tao ?", [("a", "Du sucre."), ("b", "Des nouilles."), ("c", "Des raisins.")], "a",
        3, "Dis que tu mets les nouilles dans l’assiette.",
        "Que fait Tao avec la bière ?", [("a", "Il en boit beaucoup."), ("b", "Il en boit très peu."), ("c", "Il la vend.")], "b",
        grammar("hsk20-465", "除了…以外…", "除了…以外… permet d’isoler un élément dans une liste et de préciser ce qui reste.", [("除了葡萄以外，糖要少吃。", "chú le pú tao yǐ wài, táng yào shǎo chī.", "À part les raisins, il faut manger peu de sucre.")]),
    ),
    71: scene(
        "Se retrouver au marché",
        "Fixer un rendez-vous, compter les personnes et demander un petit prix.",
        [
            line("Mina", "我们几点见面？", "wǒ men jǐ diǎn jiàn miàn?", "À quelle heure nous retrouvons-nous ?"),
            line("Tao", "十点。到时候我买两个碗和一根香蕉。", "shí diǎn. dào shí hou wǒ mǎi liǎng ge wǎn hé yì gēn xiāng jiāo.", "À dix heures. Je vais acheter deux bols et une banane."),
            line("Mina", "你会讲价吗？这个一共多少钱？", "nǐ huì jiǎng jià ma? zhè ge yí gòng duō shǎo qián?", "Sais-tu marchander ? Combien cela coûte-t-il au total ?"),
            line("Tao", "五块三角，价格很合适。", "wǔ kuài sān jiǎo, jià gé hěn hé shì.", "Cinq yuans et trente centimes, le prix est convenable."),
        ],
        "Un rendez-vous au marché",
        [
            paragraph("p1", "Mina和Tao十点在市场见面。", "Mina hé Tao shí diǎn zài shì chǎng jiàn miàn.", "Mina et Tao se retrouvent au marché à dix heures."),
            paragraph("p2", "Tao买了两个碗和一根香蕉，一共五块三角。", "Tao mǎi le liǎng ge wǎn hé yì gēn xiāng jiāo, yí gòng wǔ kuài sān jiǎo.", "Tao achète deux bols et une banane pour un total de cinq yuans et trente centimes."),
        ],
        "hsk20-527", "Que signifie 碗 ?", [("a", "bol"), ("b", "banane"), ("c", "rendez-vous")], "a",
        "Remets les groupes dans l’ordre : « Nous nous retrouvons à dix heures ». ", [("a", "我们", "wǒ men"), ("b", "十点", "shí diǎn"), ("c", "见面", "jiàn miàn")], ["a", "b", "c"], ["我们十点见面。", "我们十点见面"],
        "Complète : 这___多少钱？", "这___多少钱？", ["一共"],
        3, "Quel est le prix total ?", [("a", "Trois yuans."), ("b", "Cinq yuans et trente centimes."), ("c", "Dix yuans.")], "b",
        1, "Dis que vous vous retrouvez à dix heures.",
        "Que va acheter Tao ?", [("a", "Deux bols et une banane."), ("b", "Une jupe et un chapeau."), ("c", "Un billet de train.")], "a",
        grammar("hsk20-527", "一共 + quantité", "一共 sert à donner le total après avoir regroupé plusieurs éléments.", [("两个碗和一根香蕉一共五块三角。", "liǎng ge wǎn hé yì gēn xiāng jiāo yí gòng wǔ kuài sān jiǎo.", "Deux bols et une banane coûtent au total cinq yuans et trente centimes.")]),
    ),
    72: scene(
        "La fête avant la fin",
        "Suivre un programme de fête et comprendre l’annonce de fin d’une émission.",
        [
            line("Mina", "你看今天的节目吗？", "nǐ kàn jīn tiān de jié mù ma?", "Tu regardes l’émission d’aujourd’hui ?"),
            line("Tao", "看。先看表演，然后听老师讲节日。", "kàn. xiān kàn biǎo yǎn, rán hòu tīng lǎo shī jiǎng jié rì.", "Oui. Je regarde d’abord le spectacle, puis j’écoute le professeur parler de la fête."),
            line("Mina", "天上的云很好看。", "tiān shàng de yún hěn hǎo kàn.", "Les nuages dans le ciel sont très beaux."),
            line("Tao", "节目结束以后，我们一起回家。", "jié mù jié shù yǐ hòu, wǒ men yì qǐ huí jiā.", "Quand l’émission sera finie, nous rentrerons ensemble."),
        ],
        "Le programme de la fête",
        [
            paragraph("p1", "节目先介绍节日，再播放一个表演。", "jié mù xiān jiè shào jié rì, zài bō fàng yí ge biǎo yǎn.", "L’émission présente d’abord la fête, puis diffuse un spectacle."),
            paragraph("p2", "云在天上慢慢移动，节目结束时大家一起回家。", "yún zài tiān shàng màn man yí dòng, jié mù jié shù shí dà jiā yì qǐ huí jiā.", "Les nuages se déplacent lentement dans le ciel ; à la fin de l’émission, tout le monde rentre ensemble."),
        ],
        "hsk20-424", "Que signifie 节目 ?", [("a", "émission / programme"), ("b", "nuage"), ("c", "fête")], "a",
        "Remets les groupes dans l’ordre : « Nous rentrons après l’émission ». ", [("a", "节目结束以后", "jié mù jié shù yǐ hòu"), ("b", "我们", "wǒ men"), ("c", "回家", "huí jiā")], ["a", "b", "c"], ["节目结束以后我们回家。", "节目结束以后我们回家"],
        "Complète : 先看表演，___听老师讲节日。", "先看表演，___听老师讲节日。", ["然后"],
        1, "Que fait-on après le spectacle ?", [("a", "On écoute le professeur parler de la fête."), ("b", "On prend l’avion."), ("c", "On nettoie la rue.")], "a",
        3, "Dis que vous rentrez ensemble après l’émission.",
        "Quand rentrent-ils ?", [("a", "Avant l’émission."), ("b", "Quand l’émission est finie."), ("c", "Demain matin.")], "b",
        grammar("hsk20-421", "先…然后…", "先 annonce la première étape et 然后 introduit l’étape suivante.", [("先看表演，然后听老师讲节日。", "xiān kàn biǎo yǎn, rán hòu tīng lǎo shī jiǎng jié rì.", "Je regarde d’abord le spectacle, puis j’écoute le professeur parler de la fête.")]),
    ),
    73: scene(
        "Résoudre la logistique d’un événement",
        "Prendre une décision et trouver une solution quand du matériel manque.",
        [
            line("Mina", "明天的活动在哪里举行？", "míng tiān de huó dòng zài nǎ lǐ jǔ xíng?", "Où l’activité de demain a-t-elle lieu ?"),
            line("Tao", "在学校。我们经过车站以后就到了。", "zài xué xiào. wǒ men jīng guò chē zhàn yǐ hòu jiù dào le.", "À l’école. Nous y arrivons après être passés par la gare."),
            line("Mina", "还缺一张桌子，怎么办？", "hái quē yì zhāng zhuō zi, zěn me bàn?", "Il manque encore une table, que fait-on ?"),
            line("Tao", "我去借一张。这样就解决了。", "wǒ qù jiè yì zhāng. zhè yàng jiù jiě jué le.", "Je vais en emprunter une. Comme ça, le problème est résolu."),
        ],
        "Une table pour la fête",
        [
            paragraph("p1", "学校明天举行活动，Tao决定今天先准备。", "xué xiào míng tiān jǔ xíng huó dòng, Tao jué dìng jīn tiān xiān zhǔn bèi.", "L’école organise une activité demain ; Tao décide de préparer aujourd’hui."),
            paragraph("p2", "经过检查，他们发现少一张桌子，于是去借一张。", "jīng guò jiǎn chá, tā men fā xiàn shǎo yì zhāng zhuō zi, yú shì qù jiè yì zhāng.", "Après vérification, ils découvrent qu’il manque une table et vont en emprunter une."),
        ],
        "hsk20-428", "Que signifie 解决 ?", [("a", "résoudre"), ("b", "emprunter"), ("c", "traverser")], "a",
        "Remets les groupes dans l’ordre : « Je vais emprunter une table ». ", [("a", "我", "wǒ"), ("b", "去借", "qù jiè"), ("c", "一张桌子", "yì zhāng zhuō zi")], ["a", "b", "c"], ["我去借一张桌子。", "我去借一张桌子"],
        "Complète : Tao___ de préparer aujourd’hui. (en chinois)", "Tao___今天先准备。", ["决定"],
        3, "Que manque-t-il ?", [("a", "Une table."), ("b", "Un billet."), ("c", "Un passeport.")], "a",
        1, "Dis que tu vas emprunter une table.",
        "Quand l’activité a-t-elle lieu ?", [("a", "Aujourd’hui."), ("b", "Demain."), ("c", "La semaine dernière.")], "b",
        grammar("hsk20-428", "因为…所以…", "Une cause peut guider une décision ; ici, la découverte du manque conduit à chercher une table.", [("我们发现少一张桌子，所以去借一张。", "wǒ men fā xiàn shǎo yì zhāng zhuō zi, suǒ yǐ qù jiè yì zhāng.", "Nous découvrons qu’il manque une table, alors nous allons en emprunter une.")]),
    ),
    74: scene(
        "Une sortie avec un enfant",
        "Gérer la chaleur, la soif et les émotions d’un enfant pendant une sortie.",
        [
            line("Mina", "这个孩子很可爱，但是走了一会儿就哭了。", "zhè ge hái zi hěn kě ài, dàn shì zǒu le yí huìr jiù kū le.", "Cet enfant est adorable, mais il s’est mis à pleurer après avoir marché un moment."),
            line("Tao", "虽然天气很热，但是空调马上就开了。", "suī rán tiān qì hěn rè, dàn shì kōng tiáo mǎ shàng jiù kāi le.", "Même s’il fait chaud, la climatisation sera allumée tout de suite."),
            line("Mina", "他渴了，给他一点水吧。", "tā kě le, gěi tā yì diǎn shuǐ ba.", "Il a soif, donne-lui un peu d’eau."),
            line("Tao", "好，他看到蓝色的气球就笑了。", "hǎo, tā kàn dào lán sè de qì qiú jiù xiào le.", "D’accord, il sourit dès qu’il voit le ballon bleu."),
        ],
        "Une pause au frais",
        [
            paragraph("p1", "孩子走了一会儿觉得渴，因为天气很热。", "hái zi zǒu le yí huìr jué de kě, yīn wèi tiān qì hěn rè.", "Après avoir marché un moment, l’enfant a soif parce qu’il fait chaud."),
            paragraph("p2", "他们打开空调，给他水；看到蓝色气球后，孩子不哭了。", "tā men dǎ kāi kōng tiáo, gěi tā shuǐ; kàn dào lán sè qì qiú hòu, hái zi bù kū le.", "Ils allument la climatisation et lui donnent de l’eau ; après avoir vu un ballon bleu, l’enfant ne pleure plus."),
        ],
        "hsk20-438", "Que signifie 可爱 ?", [("a", "adorable"), ("b", "avoir soif"), ("c", "climatisation")], "a",
        "Remets les groupes dans l’ordre : « L’enfant a soif ». ", [("a", "孩子", "hái zi"), ("b", "渴了", "kě le")], ["a", "b"], ["孩子渴了。", "孩子渴了"],
        "Complète : 空调___就开了。", "空调___就开了。", ["马上"],
        3, "Pourquoi l’enfant sourit-il ?", [("a", "Il voit un ballon bleu."), ("b", "Il entend une réunion."), ("c", "Il trouve un passeport.")], "a",
        0, "Dis que l’enfant est adorable.",
        "Pourquoi l’enfant a-t-il soif ?", [("a", "Il fait chaud."), ("b", "Il neige."), ("c", "Il est au bureau.")], "a",
        grammar("hsk20-438", "虽然…但是…", "虽然…但是… oppose ici la chaleur à la solution apportée pour aider l’enfant.", [("虽然天气很热，但是空调马上就开了。", "suī rán tiān qì hěn rè, dàn shì kōng tiáo mǎ shàng jiù kāi le.", "Même s’il fait chaud, la climatisation sera allumée tout de suite.")]),
    ),
    75: scene(
        "Une lettre sur l’histoire",
        "Comprendre une lettre et expliquer comment on apprend par la lecture et la pratique.",
        [
            line("Mina", "你要离开图书馆了吗？", "nǐ yào lí kāi tú shū guǎn le ma?", "Tu vas quitter la bibliothèque ?"),
            line("Tao", "还没有。为了了解历史，我每天练习阅读。", "hái méi yǒu. wèi le liǎo jiě lì shǐ, wǒ měi tiān liàn xí yuè dú.", "Pas encore. Pour comprendre l’histoire, je m’exerce à lire chaque jour."),
            line("Mina", "这封信讲了什么？", "zhè fēng xìn jiǎng le shén me?", "De quoi parle cette lettre ?"),
            line("Tao", "讲一个绿色城市的故事。", "jiǎng yí ge lǜ sè chéng shì de gù shi.", "Elle raconte l’histoire d’une ville verte."),
        ],
        "Une lettre à la bibliothèque",
        [
            paragraph("p1", "Tao在图书馆读历史，也练习普通话。", "Tao zài tú shū guǎn dú lì shǐ, yě liàn xí pǔ tōng huà.", "Tao lit l’histoire à la bibliothèque et pratique aussi le mandarin standard."),
            paragraph("p2", "这封信讲一个绿色城市，Tao读完以后才离开。", "zhè fēng xìn jiǎng yí ge lǜ sè chéng shì, Tao dú wán yǐ hòu cái lí kāi.", "La lettre raconte une ville verte ; Tao ne part qu’après l’avoir terminée."),
        ],
        "hsk20-451", "Que signifie 历史 ?", [("a", "histoire"), ("b", "lettre"), ("c", "vert")], "a",
        "Remets les groupes dans l’ordre : « Je pratique la lecture chaque jour ». ", [("a", "我", "wǒ"), ("b", "每天练习", "měi tiān liàn xí"), ("c", "阅读", "yuè dú")], ["a", "b", "c"], ["我每天练习阅读。", "我每天练习阅读"],
        "Complète : 为了___历史，我每天练习阅读。", "为了___历史，我每天练习阅读。", ["了解"],
        2, "De quoi parle la lettre ?", [("a", "D’une ville verte."), ("b", "D’un voyage en avion."), ("c", "D’une recette.")], "a",
        3, "Dis que tu pratiques la lecture pour comprendre l’histoire.",
        "Quand Tao quitte-t-il la bibliothèque ?", [("a", "Avant de lire la lettre."), ("b", "Après avoir fini de la lire."), ("c", "À midi seulement.")], "b",
        grammar("hsk20-449", "为了…，…", "为了 introduit le but poursuivi par l’action exprimée ensuite.", [("为了了解历史，我每天练习阅读。", "wèi le liǎo jiě lì shǐ, wǒ měi tiān liàn xí yuè dú.", "Pour comprendre l’histoire, je m’exerce à lire chaque jour.")]),
    ),
    76: scene(
        "La ferme au sud",
        "Décrire un trajet, transporter un objet et parler d’un départ immédiat.",
        [
            line("Mina", "你去过南方的农场吗？", "nǐ qù guo nán fāng de nóng chǎng ma?", "Es-tu déjà allé dans une ferme du sud ?"),
            line("Tao", "去过。那里有一匹马，离车站三米远。", "qù guo. nà lǐ yǒu yì pǐ mǎ, lí chē zhàn sān mǐ yuǎn.", "Oui. Il y a un cheval là-bas, à trois mètres de la gare."),
            line("Mina", "你拿什么去农场？", "nǐ ná shén me qù nóng chǎng?", "Qu’emportes-tu pour aller à la ferme ?"),
            line("Tao", "拿一袋米。马上出发。", "ná yí dài mǐ. mǎ shàng chū fā.", "Un sac de riz. Je pars tout de suite."),
        ],
        "De la gare à la ferme",
        [
            paragraph("p1", "农场在南方，离车站不远。", "nóng chǎng zài nán fāng, lí chē zhàn bù yuǎn.", "La ferme est au sud, non loin de la gare."),
            paragraph("p2", "Tao拿一袋米去看马，马上就要出发。", "Tao ná yí dài mǐ qù kàn mǎ, mǎ shàng jiù yào chū fā.", "Tao emporte un sac de riz pour voir le cheval et va partir tout de suite."),
        ],
        "hsk20-459", "Que signifie 马 ?", [("a", "cheval"), ("b", "sud"), ("c", "riz")], "a",
        "Remets les groupes dans l’ordre : « Je pars tout de suite ». ", [("a", "我", "wǒ"), ("b", "马上", "mǎ shàng"), ("c", "出发", "chū fā")], ["a", "b", "c"], ["我马上出发。", "我马上出发"],
        "Complète : Tao___一袋米。", "Tao___一袋米。", ["拿"],
        1, "Où se trouve la ferme ?", [("a", "Au sud."), ("b", "À l’ouest."), ("c", "Au nord.")], "a",
        3, "Dis que tu pars tout de suite.",
        "Que transporte Tao ?", [("a", "Un sac de riz."), ("b", "Un parapluie."), ("c", "Une valise vide.")], "a",
        grammar("hsk20-459", "从 A 到 B", "从 et 到 encadrent le point de départ et le point d’arrivée d’un trajet.", [("从车站到农场不远。", "cóng chē zhàn dào nóng chǎng bù yuǎn.", "De la gare à la ferme, ce n’est pas loin.")]),
    ),
    77: scene(
        "Une présentation en classe",
        "Présenter son niveau scolaire, expliquer une difficulté et utiliser un crayon.",
        [
            line("Mina", "你是几年级的学生？", "nǐ shì jǐ nián jí de xué shēng?", "Tu es en quelle année scolaire ?"),
            line("Tao", "我上三年级。其实我喜欢说普通话。", "wǒ shàng sān nián jí. qí shí wǒ xǐ huan shuō pǔ tōng huà.", "Je suis en troisième année. En fait, j’aime parler mandarin standard."),
            line("Mina", "其他同学用铅笔写吗？", "qí tā tóng xué yòng qiān bǐ xiě ma?", "Les autres élèves écrivent-ils au crayon ?"),
            line("Tao", "是，老师说这样比较清楚。", "shì, lǎo shī shuō zhè yàng bǐ jiào qīng chu.", "Oui, le professeur dit que c’est plus clair ainsi."),
        ],
        "La présentation de Tao",
        [
            paragraph("p1", "Tao上三年级，喜欢在课堂上说普通话。", "Tao shàng sān nián jí, xǐ huan zài kè táng shàng shuō pǔ tōng huà.", "Tao est en troisième année et aime parler mandarin standard en classe."),
            paragraph("p2", "其他同学用铅笔写，老师觉得字很清楚。", "qí tā tóng xué yòng qiān bǐ xiě, lǎo shī jué de zì hěn qīng chu.", "Les autres élèves écrivent au crayon et le professeur trouve les caractères très clairs."),
        ],
        "hsk20-472", "Que signifie 年级 ?", [("a", "niveau scolaire"), ("b", "crayon"), ("c", "mandarin")], "a",
        "Remets les groupes dans l’ordre : « Je suis en troisième année ». ", [("a", "我", "wǒ"), ("b", "上三年级", "shàng sān nián jí")], ["a", "b"], ["我上三年级。", "我上三年级"],
        "Complète : 其他同学用___写。", "其他同学用___写。", ["铅笔"],
        1, "Que font les autres élèves ?", [("a", "Ils écrivent au crayon."), ("b", "Ils jouent dehors."), ("c", "Ils prennent le train.")], "a",
        3, "Dis que tu aimes parler mandarin standard.",
        "Que pense le professeur de l’écriture ?", [("a", "Elle est claire."), ("b", "Elle est trop longue."), ("c", "Elle est mauvaise.")], "a",
        grammar("hsk20-472", "其实…", "其实 introduit une précision qui corrige ou nuance ce que l’on attendait.", [("其实我喜欢说普通话。", "qí shí wǒ xǐ huan shuō pǔ tōng huà.", "En fait, j’aime parler mandarin standard.")]),
    ),
    78: scene(
        "Donner son avis avec tact",
        "Exprimer une opinion, écouter un avis chaleureux et proposer une condition.",
        [
            line("Mina", "你认为这个活动怎么样？", "nǐ rèn wéi zhè ge huó dòng zěn me yàng?", "Que penses-tu de cette activité ?"),
            line("Tao", "我认为很好，大家都很热情。", "wǒ rèn wéi hěn hǎo, dà jiā dōu hěn rè qíng.", "Je la trouve très bien, tout le monde est chaleureux."),
            line("Mina", "如果时间够，我们就去公园。", "rú guǒ shí jiān gòu, wǒ men jiù qù gōng yuán.", "Si nous avons assez de temps, nous irons au parc."),
            line("Tao", "可以。我会认真安排路线。", "kě yǐ. wǒ huì rèn zhēn ān pái lù xiàn.", "Oui. Je préparerai l’itinéraire sérieusement."),
        ],
        "Une proposition après l’activité",
        [
            paragraph("p1", "Tao认为活动很好，因为大家都很热情。", "Tao rèn wéi huó dòng hěn hǎo, yīn wèi dà jiā dōu hěn rè qíng.", "Tao trouve l’activité très bien parce que tout le monde est chaleureux."),
            paragraph("p2", "如果时间够，他们就一起去公园。", "rú guǒ shí jiān gòu, tā men jiù yì qǐ qù gōng yuán.", "S’ils ont assez de temps, ils iront ensemble au parc."),
        ],
        "hsk20-492", "Que signifie 认为 ?", [("a", "penser / estimer"), ("b", "être sérieux"), ("c", "être chaleureux")], "a",
        "Remets les groupes dans l’ordre : « Je pense que c’est très bien ». ", [("a", "我认为", "wǒ rèn wéi"), ("b", "很好", "hěn hǎo")], ["a", "b"], ["我认为很好。", "我认为很好"],
        "Complète : 如果时间够，我们___去公园。", "如果时间够，我们___去公园。", ["就"],
        1, "Pourquoi Tao apprécie-t-il l’activité ?", [("a", "Les gens sont chaleureux."), ("b", "Le trajet est long."), ("c", "Il pleut beaucoup.")], "a",
        3, "Dis que tu organiseras l’itinéraire sérieusement.",
        "Que feront-ils ensuite si le temps suffit ?", [("a", "Ils iront au parc."), ("b", "Ils retourneront au bureau."), ("c", "Ils écriront une lettre.")], "a",
        grammar("hsk20-492", "如果…就…", "如果 pose une condition ; la conséquence peut être annoncée par 就 ou rester implicite dans une proposition.", [("如果时间够，我们就去公园。", "rú guǒ shí jiān gòu, wǒ men jiù qù gōng yuán.", "Si nous avons assez de temps, nous irons au parc.")]),
    ),
    79: scene(
        "Réparer un appel en ligne",
        "Résoudre un problème de son et rassurer une personne pendant un appel.",
        [
            line("Mina", "你听得见我的声音吗？", "nǐ tīng de jiàn wǒ de shēng yīn ma?", "Entends-tu ma voix ?"),
            line("Tao", "声音太小，我先上网检查。", "shēng yīn tài xiǎo, wǒ xiān shàng wǎng jiǎn chá.", "Le son est trop faible, je vais d’abord vérifier en ligne."),
            line("Mina", "这次调整会使通话更清楚。", "zhè cì tiáo zhěng huì shǐ tōng huà gèng qīng chu.", "Cet ajustement rendra l’appel plus clair."),
            line("Tao", "好了。你穿哪一双鞋？", "hǎo le. nǐ chuān nǎ yì shuāng xié?", "C’est bon. Quelle paire de chaussures portes-tu ?"),
        ],
        "Un son trop faible",
        [
            paragraph("p1", "Tao上网检查声音，因为Mina听不清楚。", "Tao shàng wǎng jiǎn chá shēng yīn, yīn wèi Mina tīng bù qīng chu.", "Tao vérifie le son en ligne parce que Mina n’entend pas clairement."),
            paragraph("p2", "调整以后，通话更清楚，两个人可以继续说话。", "tiáo zhěng yǐ hòu, tōng huà gèng qīng chu, liǎng ge rén kě yǐ jì xù shuō huà.", "Après l’ajustement, l’appel est plus clair et les deux personnes peuvent continuer à parler."),
        ],
        "hsk20-499", "Que signifie 声音 ?", [("a", "son / voix"), ("b", "Internet"), ("c", "paire")], "a",
        "Remets les groupes dans l’ordre : « Je vérifie en ligne ». ", [("a", "我", "wǒ"), ("b", "上网", "shàng wǎng"), ("c", "检查", "jiǎn chá")], ["a", "b", "c"], ["我上网检查。", "我上网检查"],
        "Complète : 调整会___通话更清楚。", "调整会___通话更清楚。", ["使"],
        1, "Pourquoi Tao vérifie-t-il en ligne ?", [("a", "La voix est trop faible."), ("b", "La rue est trop longue."), ("c", "La banque est fermée.")], "a",
        3, "Dis que l’ajustement rend l’appel plus clair.",
        "Que peuvent-ils faire après l’ajustement ?", [("a", "Continuer à parler."), ("b", "Partir en montagne."), ("c", "Manger du gâteau.")], "a",
        grammar("hsk20-500", "使 + objet + adjectif", "使 introduit la cause qui rend un objet ou une situation différente.", [("调整会使通话更清楚。", "tiáo zhěng huì shǐ tōng huà gèng qīng chu.", "L’ajustement rendra l’appel plus clair.")]),
    ),
    80: scene(
        "Un atelier de langue et de culture",
        "Parler de progrès et d’une difficulté pendant un atelier culturel.",
        [
            line("Mina", "虽然这篇文章很难，但是很有文化。", "suī rán zhè piān wén zhāng hěn nán, dàn shì hěn yǒu wén huà.", "Même si cet article est difficile, il est très riche culturellement."),
            line("Tao", "我的中文水平提高了。", "wǒ de Zhōng wén shuǐ píng tí gāo le.", "Mon niveau de chinois s’est amélioré."),
            line("Mina", "你最喜欢哪一段？", "nǐ zuì xǐ huan nǎ yí duàn?", "Quel passage préfères-tu ?"),
            line("Tao", "最后一段，故事特别有意思，而且很有文化。", "zuì hòu yí duàn, gù shi tè bié yǒu yì si, ér qiě hěn yǒu wén huà.", "Le dernier passage : l’histoire est particulièrement intéressante et riche culturellement."),
        ],
        "Un passage qui fait progresser",
        [
            paragraph("p1", "文章虽然难，但是Tao认真学习，中文水平提高了。", "wén zhāng suī rán nán, dàn shì Tao rèn zhēn xué xí, Zhōng wén shuǐ píng tí gāo le.", "Même si l’article est difficile, Tao étudie sérieusement et son niveau de chinois s’améliore."),
            paragraph("p2", "他最喜欢最后一段，因为故事特别有意思。", "tā zuì xǐ huan zuì hòu yí duàn, yīn wèi gù shi tè bié yǒu yì si.", "Il préfère le dernier passage parce que l’histoire est particulièrement intéressante."),
        ],
        "hsk20-509", "Que signifie 水平 ?", [("a", "niveau"), ("b", "article"), ("c", "sucré")], "a",
        "Remets les groupes dans l’ordre : « Mon niveau s’est amélioré ». ", [("a", "我的中文水平", "wǒ de Zhōng wén shuǐ píng"), ("b", "提高", "tí gāo"), ("c", "了", "le")], ["a", "b", "c"], ["我的中文水平提高了。", "我的中文水平提高"],
        "Complète : 故事___有意思。", "故事___有意思。", ["特别"],
        0, "Quelle difficulté est mentionnée ?", [("a", "L’article est difficile."), ("b", "Le son est faible."), ("c", "La route est fermée.")], "a",
        3, "Dis que ton niveau de chinois s’est amélioré.",
        "Quel passage Tao préfère-t-il ?", [("a", "Le premier."), ("b", "Le dernier."), ("c", "Aucun.")], "b",
        grammar("hsk20-509", "虽然…但是…", "虽然…但是… permet de maintenir une information positive malgré une difficulté.", [("虽然文章很难，但是我的中文水平提高了。", "suī rán wén zhāng hěn nán, dàn shì wǒ de Zhōng wén shuǐ píng tí gāo le.", "Même si l’article est difficile, mon niveau de chinois s’est amélioré.")]),
    ),
    81: scene(
        "Une collecte qui change soudain",
        "Raconter une collecte, signaler un changement soudain et terminer une tâche.",
        [
            line("Mina", "你同意把活动改到下午吗？", "nǐ tóng yì bǎ huó dòng gǎi dào xià wǔ ma?", "Es-tu d’accord pour déplacer l’activité à l’après-midi ?"),
            line("Tao", "同意。突然下雨了，大家不能出去。", "tóng yì. tū rán xià yǔ le, dà jiā bù néng chū qù.", "Oui. Il s’est soudain mis à pleuvoir et personne ne peut sortir."),
            line("Mina", "我们已经完成一半了吗？", "wǒ men yǐ jīng wán chéng yí bàn le ma?", "Avons-nous déjà terminé la moitié ?"),
            line("Tao", "还没有，别忘记最后一箱书。", "hái méi yǒu, bié wàng jì zuì hòu yì xiāng shū.", "Pas encore, n’oublie pas le dernier carton de livres."),
        ],
        "Une collecte déplacée",
        [
            paragraph("p1", "大家同意改变活动时间，因为突然下雨了。", "dà jiā tóng yì gǎi biàn huó dòng shí jiān, yīn wèi tū rán xià yǔ le.", "Tout le monde est d’accord pour changer l’horaire de l’activité parce qu’il s’est soudain mis à pleuvoir."),
            paragraph("p2", "他们完成了一半，还要记得搬最后一箱书。", "tā men wán chéng le yí bàn, hái yào jì de bān zuì hòu yì xiāng shū.", "Ils ont terminé la moitié et doivent encore penser à déplacer le dernier carton de livres."),
        ],
        "hsk20-523", "Que signifie 突然 ?", [("a", "soudain"), ("b", "d’accord"), ("c", "moitié")], "a",
        "Remets les groupes dans l’ordre : « Nous avons terminé la moitié ». ", [("a", "我们", "wǒ men"), ("b", "完成了一半", "wán chéng le yí bàn")], ["a", "b"], ["我们完成了一半。", "我们完成了一半"],
        "Complète : 别___最后一箱书。", "别___最后一箱书。", ["忘记"],
        1, "Pourquoi l’activité est-elle déplacée ?", [("a", "Parce qu’il s’est soudain mis à pleuvoir."), ("b", "Parce que les livres sont sucrés."), ("c", "Parce que la gare est loin.")], "a",
        3, "Dis que vous êtes d’accord.",
        "Que reste-t-il à faire ?", [("a", "Déplacer le dernier carton de livres."), ("b", "Acheter une jupe."), ("c", "Fermer la banque.")], "a",
        grammar("hsk20-521", "突然 + événement", "突然 signale qu’un événement commence de manière inattendue.", [("突然下雨了，大家不能出去。", "tū rán xià yǔ le, dà jiā bù néng chū qù.", "Il s’est soudain mis à pleuvoir et personne ne peut sortir.")]),
    ),
    82: scene(
        "Choisir une routine utile",
        "Comparer des habitudes et choisir un trajet qui facilite la journée.",
        [
            line("Mina", "你为什么每天走这么远？", "nǐ wèi shén me měi tiān zǒu zhè me yuǎn?", "Pourquoi marches-tu si loin chaque jour ?"),
            line("Tao", "为了锻炼，也为了养成好习惯。", "wèi le duàn liàn, yě wèi le yǎng chéng hǎo xí guàn.", "Pour faire de l’exercice et prendre une bonne habitude."),
            line("Mina", "西边有洗手间吗？", "xī biān yǒu xǐ shǒu jiān ma?", "Y a-t-il des toilettes à l’ouest ?"),
            line("Tao", "有。路线虽然长，但是很方便。", "yǒu. lù xiàn suī rán cháng, dàn shì hěn fāng biàn.", "Oui. Même si l’itinéraire est long, il est pratique."),
        ],
        "Une habitude qui aide",
        [
            paragraph("p1", "Tao为了锻炼，每天走到西边。", "Tao wèi le duàn liàn, měi tiān zǒu dào xī biān.", "Pour faire de l’exercice, Tao marche chaque jour vers l’ouest."),
            paragraph("p2", "路线虽然长，但是有洗手间，也很方便。", "lù xiàn suī rán cháng, dàn shì yǒu xǐ shǒu jiān, yě hěn fāng biàn.", "Même si l’itinéraire est long, il y a des toilettes et il est pratique."),
        ],
        "hsk20-535", "Que signifie 习惯 ?", [("a", "habitude"), ("b", "ouest"), ("c", "toilettes")], "a",
        "Remets les groupes dans l’ordre : « Je fais de l’exercice pour prendre une habitude ». ", [("a", "为了锻炼", "wèi le duàn liàn"), ("b", "我", "wǒ"), ("c", "养成好习惯", "yǎng chéng hǎo xí guàn")], ["a", "b", "c"], ["为了锻炼，我养成好习惯。", "为了锻炼，我养成好习惯"],
        "Complète : ___路线虽然长，但是很方便。", "___路线虽然长，但是很方便。", ["这条"],
        3, "Pourquoi Tao marche-t-il chaque jour ?", [("a", "Pour faire de l’exercice."), ("b", "Pour acheter du sucre."), ("c", "Pour voir un film.")], "a",
        1, "Dis que tu fais de l’exercice pour une bonne habitude.",
        "Que trouve-t-on à l’ouest ?", [("a", "Des toilettes."), ("b", "Une banque fermée."), ("c", "Un zoo.")], "a",
        grammar("hsk20-531", "为了…，…", "为了 donne le but d’une action et se place avant la proposition principale.", [("为了锻炼，Tao每天走到西边。", "wèi le duàn liàn, Tao měi tiān zǒu dào xī biān.", "Pour faire de l’exercice, Tao marche chaque jour vers l’ouest.")]),
    ),
    83: scene(
        "Vérifier une nouvelle",
        "Décrire une routine du soir et vérifier une information avant de la partager.",
        [
            line("Mina", "你看今天的新闻了吗？", "nǐ kàn jīn tiān de xīn wén le ma?", "As-tu vu les informations d’aujourd’hui ?"),
            line("Tao", "先洗澡，然后再看。", "xiān xǐ zǎo, rán hòu zài kàn.", "Je prends d’abord une douche, puis je regarde."),
            line("Mina", "你相信这个消息吗？", "nǐ xiāng xìn zhè ge xiāo xi ma?", "Crois-tu cette nouvelle ?"),
            line("Tao", "照片里的月亮像真的，我要先检查。", "zhào piàn lǐ de yuè liang xiàng zhēn de, wǒ yào xiān jiǎn chá.", "La lune sur la photo semble réelle ; je dois d’abord vérifier."),
        ],
        "Une information à vérifier",
        [
            paragraph("p1", "Tao先洗澡，然后看新闻。", "Tao xiān xǐ zǎo, rán hòu kàn xīn wén.", "Tao prend d’abord une douche, puis regarde les informations."),
            paragraph("p2", "照片里的月亮像真的，但是他还是要检查。", "zhào piàn lǐ de yuè liang xiàng zhēn de, dàn shì tā hái shì yào jiǎn chá.", "La lune sur la photo semble réelle, mais il doit quand même vérifier."),
        ],
        "hsk20-547", "Que signifie 新闻 ?", [("a", "informations"), ("b", "douche"), ("c", "photo")], "a",
        "Remets les groupes dans l’ordre : « Je regarde ensuite les informations ». ", [("a", "然后", "rán hòu"), ("b", "我", "wǒ"), ("c", "看新闻", "kàn xīn wén")], ["a", "b", "c"], ["然后我看新闻。", "然后我看新闻"],
        "Complète : 我___相信这个消息。", "我___相信这个消息。", ["不"],
        2, "Pourquoi Tao vérifie-t-il la photo ?", [("a", "Il veut vérifier la nouvelle."), ("b", "Il veut changer de chaussures."), ("c", "Il veut fermer la fenêtre.")], "a",
        0, "Dis que tu prends d’abord une douche.",
        "Que fait Tao avant de regarder les informations ?", [("a", "Il prend une douche."), ("b", "Il va au bureau."), ("c", "Il mange des nouilles.")], "a",
        grammar("hsk20-539", "先…然后…", "先 ordonne la première action et 然后 introduit celle qui suit.", [("先洗澡，然后看新闻。", "xiān xǐ zǎo, rán hòu kàn xīn wén.", "Je prends d’abord une douche, puis je regarde les informations.")]),
    ),
    84: scene(
        "Choisir des produits frais",
        "Faire une liste, exprimer un intérêt et choisir ce dont on a besoin.",
        [
            line("Mina", "你对什么有兴趣？", "nǐ duì shén me yǒu xìng qù?", "Qu’est-ce qui t’intéresse ?"),
            line("Tao", "我想买新鲜的水果，但是不知道选哪一种。", "wǒ xiǎng mǎi xīn xiān de shuǐ guǒ, dàn shì bù zhī dào xuǎn nǎ yì zhǒng.", "Je veux acheter des fruits frais, mais je ne sais pas lequel choisir."),
            line("Mina", "你需要写信的纸吗？", "nǐ xū yào xiě xìn de zhǐ ma?", "As-tu besoin de papier pour écrire une lettre ?"),
            line("Tao", "需要。先选水果，再写信。", "xū yào. xiān xuǎn shuǐ guǒ, zài xiě xìn.", "Oui. Je choisis d’abord les fruits, puis j’écris la lettre."),
        ],
        "Une liste au marché",
        [
            paragraph("p1", "Tao需要新鲜水果，也需要纸和笔写信。", "Tao xū yào xīn xiān shuǐ guǒ, yě xū yào zhǐ hé bǐ xiě xìn.", "Tao a besoin de fruits frais et aussi de papier et d’un stylo pour écrire une lettre."),
            paragraph("p2", "他有兴趣了解不同种水果，最后选择了最好的一种。", "tā yǒu xìng qù liǎo jiě bù tóng zhǒng shuǐ guǒ, zuì hòu xuǎn zé le zuì hǎo de yì zhǒng.", "Il s’intéresse aux différentes sortes de fruits et choisit finalement la meilleure."),
        ],
        "hsk20-548", "Que signifie 新鲜 ?", [("a", "frais"), ("b", "choisir"), ("c", "lettre")], "a",
        "Remets les groupes dans l’ordre : « Je choisis des fruits frais ». ", [("a", "我", "wǒ"), ("b", "选择", "xuǎn zé"), ("c", "新鲜水果", "xīn xiān shuǐ guǒ")], ["a", "b", "c"], ["我选择新鲜水果。", "我选择新鲜水果"],
        "Complète : 我___写信的纸。", "我___写信的纸。", ["需要"],
        1, "Que veut acheter Tao ?", [("a", "Des fruits frais."), ("b", "Une valise."), ("c", "Un billet.")], "a",
        3, "Dis que tu as besoin de papier.",
        "Que fait Tao après avoir choisi les fruits ?", [("a", "Il écrit une lettre."), ("b", "Il ferme le magasin."), ("c", "Il prend une douche.")], "a",
        grammar("hsk20-548", "需要 + objet", "需要 précède l’objet dont on a besoin pour réaliser une action.", [("我需要纸和笔写信。", "wǒ xū yào zhǐ hé bǐ xiě xìn.", "J’ai besoin de papier et d’un stylo pour écrire une lettre.")]),
    ),
    85: scene(
        "Organiser une activité commune",
        "Formuler des consignes, compter un groupe et coordonner deux actions.",
        [
            line("Mina", "活动有什么要求？", "huó dòng yǒu shén me yāo qiú?", "Quelles sont les consignes de l’activité ?"),
            line("Tao", "一般要两个人一组，一边读，一边记录。", "yì bān yào liǎng ge rén yì zǔ, yì biān dú, yì biān jì lù.", "En général, il faut deux personnes par groupe : on lit tout en prenant des notes."),
            line("Mina", "一共几个小组？", "yí gòng jǐ ge xiǎo zǔ?", "Combien de groupes y a-t-il au total ?"),
            line("Tao", "四个。每组的任务不一样。", "sì ge. měi zǔ de rèn wù bù yí yàng.", "Quatre. La tâche de chaque groupe est différente."),
        ],
        "Les consignes du travail en groupe",
        [
            paragraph("p1", "活动一般要求两个人一组，一边读一边记录。", "huó dòng yì bān yāo qiú liǎng ge rén yì zǔ, yì biān dú yì biān jì lù.", "L’activité demande en général deux personnes par groupe, qui lisent tout en prenant des notes."),
            paragraph("p2", "一共四个小组，每组的任务不一样。", "yí gòng sì ge xiǎo zǔ, měi zǔ de rèn wù bù yí yàng.", "Il y a quatre groupes au total et la tâche de chaque groupe est différente."),
        ],
        "hsk20-556", "Que signifie 要求 ?", [("a", "exigence / consigne"), ("b", "groupe"), ("c", "pareil")], "a",
        "Remets les groupes dans l’ordre : « Il y a quatre groupes au total ». ", [("a", "一共", "yí gòng"), ("b", "四个", "sì ge"), ("c", "小组", "xiǎo zǔ")], ["a", "b", "c"], ["一共四个小组。", "一共四个小组"],
        "Complète : 每组的任务不___。", "每组的任务不___。", ["一样"],
        1, "Combien de groupes y a-t-il ?", [("a", "Deux."), ("b", "Quatre."), ("c", "Six.")], "b",
        0, "Dis qu’il faut lire tout en prenant des notes.",
        "Les tâches des groupes sont-elles identiques ?", [("a", "Oui, toutes identiques."), ("b", "Non, elles sont différentes."), ("c", "Le texte ne le dit pas.")], "b",
        grammar("hsk20-559", "一边…一边…", "一边…一边… coordonne les deux actions réalisées en parallèle par chaque groupe.", [("一边读，一边记录。", "yì biān dú, yì biān jì lù.", "Lire tout en prenant des notes.")]),
    ),
    86: scene(
        "Une erreur à la banque",
        "Rectifier une supposition et utiliser un service bancaire avec calme.",
        [
            line("Mina", "你以为银行已经关门了吗？", "nǐ yǐ wéi yín háng yǐ jīng guān mén le ma?", "Tu croyais que la banque était déjà fermée ?"),
            line("Tao", "是，但是它又开了。", "shì, dàn shì tā yòu kāi le.", "Oui, mais elle a rouvert."),
            line("Mina", "可以用手机转钱吗？", "kě yǐ yòng shǒu jī zhuǎn qián ma?", "Peut-on transférer de l’argent avec le téléphone ?"),
            line("Tao", "可以。这家银行很有名，办理业务很方便。", "kě yǐ. zhè jiā yín háng hěn yǒu míng, bàn lǐ yè wù hěn fāng biàn.", "Oui. Cette banque est très connue et ses services sont pratiques."),
        ],
        "La banque finalement ouverte",
        [
            paragraph("p1", "Tao以为银行关门了，其实银行又开了。", "Tao yǐ wéi yín háng guān mén le, qí shí yín háng yòu kāi le.", "Tao croyait que la banque était fermée ; en fait elle a rouvert."),
            paragraph("p2", "Mina教他用手机办理事情，他们很快完成了。", "Mina jiāo tā yòng shǒu jī bàn lǐ shì qing, tā men hěn kuài wán chéng le.", "Mina lui apprend à utiliser le téléphone pour faire la démarche et ils terminent rapidement."),
        ],
        "hsk20-567", "Que signifie 以为 ?", [("a", "croire à tort"), ("b", "utiliser"), ("c", "célèbre")], "a",
        "Remets les groupes dans l’ordre : « La banque a rouvert ». ", [("a", "银行", "yín háng"), ("b", "又开了", "yòu kāi le")], ["a", "b"], ["银行又开了。", "银行又开了"],
        "Complète : 可以___手机转钱吗？", "可以___手机转钱吗？", ["用"],
        1, "Que croyait Tao ?", [("a", "Que la banque était fermée."), ("b", "Que la banque était au nord."), ("c", "Que le thé était froid.")], "a",
        3, "Dis que tu peux utiliser ton téléphone.",
        "Comment terminent-ils la démarche ?", [("a", "Rapidement."), ("b", "Après une semaine."), ("c", "Jamais.")], "a",
        grammar("hsk20-567", "以为…，其实…", "以为 présente une croyance erronée ; 其实 la corrige avec le fait réel.", [("我以为银行关门了，其实它又开了。", "wǒ yǐ wéi yín háng guān mén le, qí shí tā yòu kāi le.", "Je croyais que la banque était fermée ; en fait elle a rouvert.")]),
    ),
    87: scene(
        "Une rencontre sous la lune",
        "Raconter une rencontre à une station et décrire une lumière qui augmente.",
        [
            line("Mina", "你在车站遇到谁了？", "nǐ zài chē zhàn yù dào shuí le?", "Qui as-tu rencontré à la gare ?"),
            line("Tao", "遇到一位老朋友。他愿意一起看月亮。", "yù dào yí wèi lǎo péng you. tā yuàn yì yì qǐ kàn yuè liang.", "Un vieil ami. Il veut bien regarder la lune avec moi."),
            line("Mina", "月亮越来越亮了吗？", "yuè liang yuè lái yuè liàng le ma?", "La lune devient-elle de plus en plus brillante ?"),
            line("Tao", "是。我们在下一站下车。", "shì. wǒ men zài xià yí zhàn xià chē.", "Oui. Nous descendons à la prochaine station."),
        ],
        "Une lune de plus en plus claire",
        [
            paragraph("p1", "Tao在车站遇到一位老朋友，两个人愿意一起散步。", "Tao zài chē zhàn yù dào yí wèi lǎo péng you, liǎng ge rén yuàn yì yì qǐ sàn bù.", "Tao rencontre un vieil ami à la gare et ils veulent bien se promener ensemble."),
            paragraph("p2", "月亮越来越亮，他们在下一站下车看了一会儿。", "yuè liang yuè lái yuè liàng, tā men zài xià yí zhàn xià chē kàn le yí huìr.", "La lune devient de plus en plus brillante ; ils descendent à la prochaine station pour la regarder un moment."),
        ],
        "hsk20-576", "Que signifie 遇到 ?", [("a", "rencontrer"), ("b", "vouloir bien"), ("c", "station")], "a",
        "Remets les groupes dans l’ordre : « Nous descendons à la prochaine station ». ", [("a", "我们", "wǒ men"), ("b", "在下一站", "zài xià yí zhàn"), ("c", "下车", "xià chē")], ["a", "b", "c"], ["我们在下一站下车。", "我们在下一站下车"],
        "Complète : 他___一起看月亮。", "他___一起看月亮。", ["愿意"],
        2, "Que devient la lune ?", [("a", "Elle brille davantage."), ("b", "Elle disparaît."), ("c", "Elle devient bleue.")], "a",
        0, "Dis que tu as rencontré un vieil ami.",
        "Où descendent-ils ?", [("a", "À la prochaine station."), ("b", "À l’aéroport."), ("c", "À la banque.")], "a",
        grammar("hsk20-579", "越来越 + adjectif", "越来越 décrit une évolution progressive vers un degré plus élevé.", [("月亮越来越亮了。", "yuè liang yuè lái yuè liàng le.", "La lune est devenue de plus en plus brillante.")]),
    ),
    88: scene(
        "Le jardin de l’école",
        "Décrire un projet de jardin et identifier le résultat obtenu après plusieurs jours.",
        [
            line("Mina", "谁照顾学校中间的花园？", "shuí zhào gù xué xiào zhōng jiān de huā yuán?", "Qui s’occupe du jardin au milieu de l’école ?"),
            line("Tao", "学生们。我们种了两种花。", "xué shēng men. wǒ men zhòng le liǎng zhǒng huā.", "Les élèves. Nous avons planté deux sortes de fleurs."),
            line("Mina", "主要的问题解决了吗？", "zhǔ yào de wèn tí jiě jué le ma?", "Le problème principal est-il résolu ?"),
            line("Tao", "终于解决了，花也长大了。", "zhōng yú jiě jué le, huā yě zhǎng dà le.", "Il est enfin résolu, et les fleurs ont grandi."),
        ],
        "Le jardin au centre de l’école",
        [
            paragraph("p1", "学生在学校中间种了两种花，老师和同学一起照顾。", "xué shēng zài xué xiào zhōng jiān zhòng le liǎng zhǒng huā, lǎo shī hé tóng xué yì qǐ zhào gù.", "Les élèves ont planté deux sortes de fleurs au milieu de l’école ; le professeur et les camarades s’en occupent ensemble."),
            paragraph("p2", "主要问题是没有水，后来他们找到办法，花终于长大了。", "zhǔ yào wèn tí shì méi yǒu shuǐ, hòu lái tā men zhǎo dào bàn fǎ, huā zhōng yú zhǎng dà le.", "Le problème principal était le manque d’eau ; ils ont trouvé une solution et les fleurs ont enfin grandi."),
        ],
        "hsk20-582", "Que signifie 照顾 ?", [("a", "s’occuper de"), ("b", "planter"), ("c", "milieu")], "a",
        "Remets les groupes dans l’ordre : « Les fleurs ont enfin grandi ». ", [("a", "花", "huā"), ("b", "终于", "zhōng yú"), ("c", "长大了", "zhǎng dà le")], ["a", "b", "c"], ["花终于长大了。", "花终于长大了"],
        "Complète : 学校___的花园。", "学校___的花园。", ["中间"],
        3, "Quel était le problème principal ?", [("a", "Il n’y avait pas d’eau."), ("b", "Il y avait trop de fleurs."), ("c", "Le jardin était au nord.")], "a",
        1, "Dis que les élèves s’occupent du jardin.",
        "Quel résultat obtiennent-ils ?", [("a", "Les fleurs grandissent enfin."), ("b", "Le jardin ferme."), ("c", "Les élèves partent.")], "a",
        grammar("hsk20-587", "终于 + résultat", "终于 marque l’aboutissement obtenu après une attente ou une difficulté.", [("花终于长大了。", "huā zhōng yú zhǎng dà le.", "Les fleurs ont enfin grandi.")]),
    ),
    89: scene(
        "Bilan personnel récent",
        "Faire le point sur une habitude récente et encourager une action autonome.",
        [
            line("Mina", "最近你的学习怎么样？", "zuì jìn nǐ de xué xí zěn me yàng?", "Comment se passent tes études récemment ?"),
            line("Tao", "我自己安排时间，已经不着急了。", "wǒ zì jǐ ān pái shí jiān, yǐ jīng bù zháo jí le.", "J’organise moi-même mon temps et je ne suis plus pressé."),
            line("Mina", "你注意休息了吗？", "nǐ zhù yì xiū xi le ma?", "As-tu pensé à te reposer ?"),
            line("Tao", "注意了。祝你也找到自己的节奏。", "zhù yì le. zhù nǐ yě zhǎo dào zì jǐ de jié zòu.", "Oui. Je te souhaite aussi de trouver ton propre rythme."),
        ],
        "Une semaine mieux organisée",
        [
            paragraph("p1", "最近Tao自己安排学习和休息，不再着急。", "zuì jìn Tao zì jǐ ān pái xué xí hé xiū xi, bú zài zháo jí.", "Récemment, Tao organise lui-même ses études et son repos sans se presser."),
            paragraph("p2", "他注意每天的节奏，也祝朋友学习顺利。", "tā zhù yì měi tiān de jié zòu, yě zhù péng you xué xí shùn lì.", "Il fait attention au rythme de chaque journée et souhaite aussi de bonnes études à son ami."),
        ],
        "hsk20-596", "Que signifie 自己 ?", [("a", "soi-même"), ("b", "récemment"), ("c", "se presser")], "a",
        "Remets les groupes dans l’ordre : « J’organise moi-même mon temps ». ", [("a", "我", "wǒ"), ("b", "自己安排", "zì jǐ ān pái"), ("c", "时间", "shí jiān")], ["a", "b", "c"], ["我自己安排时间。", "我自己安排时间"],
        "Complète : 最近我不再___。", "最近我不再___。", ["着急"],
        2, "À quoi Tao fait-il attention ?", [("a", "Au rythme de chaque journée."), ("b", "À la couleur d’une jupe."), ("c", "Au prix du thé.")], "a",
        0, "Dis que tu organises toi-même ton temps.",
        "Comment Tao se sent-il maintenant ?", [("a", "Il ne se presse plus."), ("b", "Il a peur."), ("c", "Il est en retard.")], "a",
        grammar("hsk20-596", "自己 + verbe", "自己 insiste sur le fait que le sujet réalise lui-même l’action.", [("我自己安排时间。", "wǒ zì jǐ ān pái shí jiān.", "J’organise moi-même mon temps.")]),
    ),
    90: scene(
        "Bilan final : comprendre, écouter et agir",
        "Réinvestir le vocabulaire du parcours dans une tâche finale de compréhension et de production.",
        [
            line("Mina", "这九十天你学会了什么？", "zhè jiǔ shí tiān nǐ xué huì le shén me?", "Qu’as-tu appris pendant ces quatre-vingt-dix jours ?"),
            line("Tao", "我能听懂短对话，也能用地图安排旅行。", "wǒ néng tīng dǒng duǎn duì huà, yě néng yòng dì tú ān pái lǚ xíng.", "Je peux comprendre de courts dialogues et organiser un voyage avec une carte."),
            line("Mina", "遇到问题时，你会怎么做？", "yù dào wèn tí shí, nǐ huì zěn me zuò?", "Que fais-tu quand tu rencontres un problème ?"),
            line("Tao", "我会注意信息：先听清楚，再说明办法，最后自己完成。", "wǒ huì zhù yì xìn xī: xiān tīng qīng chu, zài shuō míng bàn fǎ, zuì hòu zì jǐ wán chéng.", "Je fais attention aux informations : j’écoute d’abord clairement, j’explique ensuite la solution et je termine moi-même."),
        ],
        "Une tâche pour conclure",
        [
            paragraph("p1", "在最后一天，Tao听一段对话，读一张地图，再回答问题。", "zài zuì hòu yì tiān, Tao tīng yí duàn duì huà, dú yì zhāng dì tú, zài huí dá wèn tí.", "Le dernier jour, Tao écoute un dialogue, lit une carte, puis répond aux questions."),
            paragraph("p2", "他遇到困难时先检查信息，再说明办法，最后自己完成任务。", "tā yù dào kùn nán shí xiān jiǎn chá xìn xī, zài shuō míng bàn fǎ, zuì hòu zì jǐ wán chéng rèn wù.", "Quand il rencontre une difficulté, il vérifie d’abord les informations, explique ensuite la solution et termine la tâche lui-même."),
        ],
        "hsk20-592", "Que signifie 注意 dans la dernière réplique ?", [("a", "faire attention"), ("b", "terminer"), ("c", "voyager")], "a",
        "Remets les groupes dans l’ordre : « Je termine moi-même la tâche ». ", [("a", "我", "wǒ"), ("b", "自己", "zì jǐ"), ("c", "完成任务", "wán chéng rèn wù")], ["a", "b", "c"], ["我自己完成任务。", "我自己完成任务"],
        "Complète : 遇到问题时，我先___信息。", "遇到问题时，我先___信息。", ["检查"],
        3, "Quelle est la dernière étape ?", [("a", "Terminer soi-même la tâche."), ("b", "Prendre un taxi."), ("c", "Acheter un dessert.")], "a",
        1, "Dis que tu peux comprendre de courts dialogues.",
        "Que fait Tao après avoir vérifié les informations ?", [("a", "Il explique la solution."), ("b", "Il ferme la banque."), ("c", "Il dort.")], "a",
        grammar("hsk20-592", "Bilan intégré du niveau 3", "La tâche finale enchaîne écoute, lecture, explication et production autonome dans une situation complète.", [("遇到问题时，我先检查信息，再说明办法。", "yù dào wèn tí shí, wǒ xiān jiǎn chá xìn xī, zài shuō míng bàn fǎ.", "Quand je rencontre un problème, je vérifie d’abord les informations puis j’explique la solution."), ("最后我自己完成任务。", "zuì hòu wǒ zì jǐ wán chéng rèn wù.", "Enfin, je termine moi-même la tâche.")]),
    ),
}


def normalize_reference(value: str) -> str:
    """Return the canonical catalogue spelling used by the authoring pack."""
    if value.startswith("hsk") and value[3:].isdigit() and len(value) == 6:
        return f"hsk20-{value[3:]}"
    return value


def normalized_references(values: list[str], context: str) -> list[str]:
    result = [normalize_reference(value) for value in values]
    if any(not value.startswith("hsk20-") for value in result):
        raise ValueError(f"{context}: expected hsk20 catalogue references")
    if len(set(result)) != len(result):
        raise ValueError(f"{context}: duplicate catalogue references")
    return result


def rotate_order_tokens(tokens: list[tuple[str, str, str]], correct: list[str], day: int) -> list[tuple[str, str, str]]:
    """Give the learner a deterministic shuffled presentation order.

    The authored `correct` list remains untouched.  Rotating the authored
    tokens makes accidental source ordering visible in previews while keeping
    every token and its explicit pinyin attached to one another.
    """
    if len(tokens) < 2:
        raise ValueError(f"day {day}: word-order exercise needs at least two tokens")
    token_ids = [token[0] for token in tokens]
    if len(set(token_ids)) != len(token_ids) or set(token_ids) != set(correct):
        raise ValueError(f"day {day}: word-order tokens and correctOrder differ")
    shift = day % len(tokens) or 1
    shuffled = tokens[shift:] + tokens[:shift]
    if [token[0] for token in shuffled] == correct:
        shuffled = list(reversed(shuffled))
    if [token[0] for token in shuffled] == correct:
        raise ValueError(f"day {day}: word-order presentation was not shuffled")
    return shuffled


def choice_exercise(
    exercise_id: str,
    objective_id: str,
    prompt: str,
    choices: list[tuple[str, str]],
    correct: str,
    instruction: str,
) -> dict[str, Any]:
    if correct not in {choice_id for choice_id, _ in choices}:
        raise ValueError(f"{exercise_id}: correct choice is not present")
    return {
        "id": exercise_id,
        "kind": "choice",
        "prompt": fr(prompt),
        "instruction": fr(instruction),
        "objectiveIDs": [objective_id],
        "required": True,
        "choices": [{"id": choice_id, "label": fr(label), "audio": None} for choice_id, label in choices],
        "correctChoiceID": correct,
    }


def order_exercise(
    exercise_id: str,
    objective_id: str,
    data: dict[str, Any],
    day: int,
) -> dict[str, Any]:
    tokens = data["tokens"]
    correct = [normalize_reference(token) if token.startswith("hsk") else token for token in data["correct"]]
    # The token IDs are authored as short local IDs (a/b/c), so only the
    # catalogue references elsewhere in a scene go through normalization.
    displayed = rotate_order_tokens(tokens, correct, day)
    return {
        "id": exercise_id,
        "kind": "wordOrder",
        "prompt": fr(data["prompt"]),
        "instruction": fr("Replace chaque groupe dans l’ordre, puis relis la phrase complète."),
        "objectiveIDs": [objective_id],
        "required": True,
        "tokens": [{"id": token_id, "hanzi": hanzi, "pinyin": pinyin, "audio": None} for token_id, hanzi, pinyin in displayed],
        "correctOrder": correct,
        "acceptedVariants": list(data["accepted"]),
    }


def fill_exercise(exercise_id: str, objective_id: str, data: dict[str, Any]) -> dict[str, Any]:
    if not data["answers"]:
        raise ValueError(f"{exercise_id}: fill exercise needs an accepted answer")
    return {
        "id": exercise_id,
        "kind": "fillBlank",
        "prompt": fr(data["prompt"]),
        "instruction": fr("Écris le mot manquant en caractères chinois."),
        "objectiveIDs": [objective_id],
        "required": True,
        "sentence": data["sentence"],
        "acceptedAnswers": list(data["answers"]),
        "caseSensitive": False,
    }


def listening_exercise(exercise_id: str, objective_id: str, data: dict[str, Any], line_data: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": exercise_id,
        "kind": "listeningChoice",
        "prompt": fr(data["prompt"]),
        "instruction": fr("Écoute la phrase en mandarin, puis choisis son sens."),
        "objectiveIDs": [objective_id],
        "required": True,
        "promptText": line_data["hanzi"],
        "choices": [{"id": choice_id, "label": fr(label), "audio": None} for choice_id, label in data["choices"]],
        "correctChoiceID": data["correct"],
    }


def speaking_exercise(exercise_id: str, objective_id: str, data: dict[str, Any], line_data: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": exercise_id,
        "kind": "speaking",
        "prompt": fr(data["prompt"]),
        "instruction": fr("Écoute le modèle, dis la phrase, puis auto-évalue-toi."),
        "objectiveIDs": [objective_id],
        "required": False,
        "referenceText": line_data["hanzi"],
        "referencePinyin": line_data["pinyin"],
        "referenceAudio": None,
        "acceptedTranscripts": [line_data["hanzi"], line_data["hanzi"].rstrip("。？！")],
        "allowSelfRating": True,
    }


def build_lesson(day: int, row: dict[str, Any], catalog_ids: set[str]) -> dict[str, Any]:
    scene_data = SCENES[day]
    override = ALLOCATION_OVERRIDES[day]
    lesson_id = row["lessonID"]
    lesson_number = day + 4
    expected_lesson_id = f"lesson-{lesson_number:02d}"
    if lesson_id != expected_lesson_id:
        raise ValueError(f"day {day}: allocation lessonID {lesson_id} does not match {expected_lesson_id}")

    new = normalized_references(list(row["newCanonicalIDs"]), f"day {day}.newCanonicalIDs")
    reused = normalized_references(list(override["reused"]), f"day {day}.reused")
    refs = list(dict.fromkeys(new + reused))
    anchor = normalize_reference(override["anchor"])
    grammar_note = scene_data["grammar"]
    grammar_note["vocabularyID"] = normalize_reference(grammar_note["vocabularyID"])
    if grammar_note["pattern"] != override["pattern"]:
        raise ValueError(f"day {day}: authored grammar pattern differs from allocation override")
    if anchor not in refs:
        raise ValueError(f"day {day}: grammar anchor {anchor} is outside lesson vocabulary")
    if grammar_note["vocabularyID"] not in refs:
        raise ValueError(f"day {day}: grammar note reference is outside lesson vocabulary")
    meaning_target = normalize_reference(scene_data["meaning"]["target"])
    if meaning_target not in refs:
        raise ValueError(f"day {day}: meaning target {meaning_target} is outside lesson vocabulary")
    unknown = sorted(set(refs) - catalog_ids)
    if unknown:
        raise ValueError(f"day {day}: unknown catalogue references: {', '.join(unknown)}")

    understanding = f"l{lesson_number}-understand"
    production = f"l{lesson_number}-produce"
    exercise_prefix = f"ex-l{lesson_number:02d}"
    dialogue_lines = scene_data["dialogue"]
    listen_line = scene_data["listen"]["line"]
    speak_line = scene_data["speak"]["line"]
    if not isinstance(listen_line, int) or not 0 <= listen_line < len(dialogue_lines):
        raise ValueError(f"day {day}: listening line is outside dialogue")
    if not isinstance(speak_line, int) or not 0 <= speak_line < len(dialogue_lines):
        raise ValueError(f"day {day}: speaking line is outside dialogue")
    reading_question = scene_data["readingQuestion"]
    exercises = [
        choice_exercise(
            f"{exercise_prefix}-meaning",
            understanding,
            scene_data["meaning"]["prompt"],
            scene_data["meaning"]["choices"],
            scene_data["meaning"]["correct"],
            "Choisis le sens correspondant au dialogue.",
        ),
        order_exercise(f"{exercise_prefix}-order", production, scene_data["order"], day),
        fill_exercise(f"{exercise_prefix}-fill", production, scene_data["fill"]),
        listening_exercise(f"{exercise_prefix}-listen", understanding, scene_data["listen"], dialogue_lines[listen_line]),
        speaking_exercise(f"{exercise_prefix}-speak", production, scene_data["speak"], dialogue_lines[speak_line]),
        choice_exercise(
            f"{exercise_prefix}-reading",
            understanding,
            reading_question["prompt"],
            reading_question["choices"],
            reading_question["correct"],
            "Relis les deux paragraphes avant de répondre.",
        ),
    ]
    reading = scene_data["reading"]
    reading_block = {
        "id": f"block-{lesson_id}-reading",
        "storyID": f"story-{lesson_id}",
        "level": LEVEL,
        "title": reading["title"],
        "paragraphs": reading["paragraphs"],
        "comprehensionExerciseIDs": [f"{exercise_prefix}-reading"],
    }
    metadata = {
        "allocationDay": day,
        "allocationRange": "days46-90",
        "theme": override["themeLabel"],
        "themeLabel": fr(override["themeLabel"]),
        "phase": row["phase"],
        "checkpoint": bool(row["checkpoint"]),
        "newVocabularyIDs": new,
        "reusedVocabularyIDs": reused,
        "newCanonicalIDs": new,
        "reusedCanonicalIDs": reused,
        "grammarPattern": override["pattern"],
        "grammarAnchor": anchor,
    }
    return {
        "id": lesson_id,
        "moduleID": row["moduleID"],
        "order": lesson_number,
        "level": LEVEL,
        "title": scene_data["title"],
        "summary": scene_data["summary"],
        "estimatedMinutes": 12,
        "objectives": [
            {"id": understanding, "text": fr("Comprendre la scène et les informations essentielles."), "required": True},
            {"id": production, "text": fr("Réutiliser une structure dans une phrase courte."), "required": True},
        ],
        "vocabularyIDs": refs,
        "extraVocabulary": [],
        "grammar": [grammar_note],
        "dialogue": {"id": f"block-{lesson_id}-dialogue", "lines": dialogue_lines},
        "reading": reading_block,
        "exercises": exercises,
        "recap": {"id": f"block-{lesson_id}-recap", "vocabularyIDs": refs, "objectiveIDs": [understanding, production]},
        "metadata": metadata,
    }


def allocation_override_document() -> dict[str, Any]:
    """Serialize editorial decisions in a form that can be merged upstream."""
    result: dict[str, Any] = {}
    for day in range(46, 91):
        override = ALLOCATION_OVERRIDES[day]
        result[str(day)] = {
            "themeLabel": override["themeLabel"],
            "grammarTarget": {
                "patterns": [override["pattern"]],
                "anchorCanonicalID": normalize_reference(override["anchor"]),
                "reviewable": True,
            },
            "reusedVocabularyIDs": normalized_references(list(override["reused"]), f"day {day}.reused"),
        }
    return result


def main() -> None:
    allocation_document = json.loads(ALLOCATION_PATH.read_text(encoding="utf-8"))
    allocation_rows = {row["day"]: row for row in allocation_document["lessons"]}
    expected_days = set(range(46, 91))
    if set(SCENES) != expected_days:
        missing = sorted(expected_days - set(SCENES))
        extra = sorted(set(SCENES) - expected_days)
        raise SystemExit(f"scene days mismatch; missing={missing}, extra={extra}")
    if set(ALLOCATION_OVERRIDES) != expected_days:
        raise SystemExit("allocation overrides must cover exactly days 46–90")
    if not expected_days.issubset(allocation_rows):
        raise SystemExit("allocation is missing one or more late-course days")

    catalog_document = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    entries = catalog_document.get("entries", [])
    catalog_ids = {entry["id"] for entry in entries}
    if len(catalog_ids) != len(entries) or len(catalog_ids) < 600:
        raise SystemExit("catalogue must contain at least 600 unique entries")

    lessons = [build_lesson(day, allocation_rows[day], catalog_ids) for day in range(46, 91)]
    lesson_ids = [lesson["id"] for lesson in lessons]
    if len(set(lesson_ids)) != len(lesson_ids):
        raise SystemExit("duplicate lesson IDs")
    budgets = [
        {"day": day, "lessonID": allocation_rows[day]["lessonID"], "courseMinutes": 12, "reviewMinutes": 3}
        for day in range(46, 91)
    ]
    output = {
        "schemaVersion": 1,
        "contentVersion": CONTENT_VERSION,
        "courseID": allocation_document["courseID"],
        "catalog": "authoring/hsk-legacy-600.json",
        "allocationReference": {
            "path": "authoring/90-day-allocation.json",
            "contentVersion": allocation_document["contentVersion"],
        },
        "allocationRange": {"startDay": 46, "endDay": 90},
        "allocationOverrides": allocation_override_document(),
        "sessions": budgets,
        "sessionBudgets": budgets,
        "lessons": lessons,
    }
    OUTPUT_PATH.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {OUTPUT_PATH} ({len(lessons)} lessons, {len(budgets)} session budgets)")


if __name__ == "__main__":
    main()
