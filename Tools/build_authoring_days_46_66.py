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
OUTPUT_PATH = AUTHORING / "90-day-authoring-days-46-66.json"
CATALOG_PATH = AUTHORING / "hsk-legacy-600.json"
CONTENT_VERSION = "2026.10.0"
# Days 46–66 all lie in the allocation's second phase (after HSK 1 closes on day 40).
LEVEL = "HSK classique 2"


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
    46: {"themeLabel": "Prendre soin de soi après le sport", "pattern": "把 + objet + verbe", "anchor": "hsk20-452"},
    47: {"themeLabel": "Une rue bien entretenue", "pattern": "被 + agent", "anchor": "hsk20-303"},
    48: {"themeLabel": "Le nettoyage du quartier", "pattern": "除了…以外…", "anchor": "hsk20-337"},
    49: {"themeLabel": "Préparer une réunion", "pattern": "因为…所以…", "anchor": "hsk20-346"},
    50: {"themeLabel": "Un devoir sur la culture", "pattern": "关于 + nom", "anchor": "hsk20-595"},
    51: {"themeLabel": "Le message du matin", "pattern": "一边…一边…", "anchor": "hsk20-358"},
    52: {"themeLabel": "Une explication au déjeuner", "pattern": "越来越 + adjectif", "anchor": "hsk20-600"},
    53: {"themeLabel": "Le rangement du bureau", "pattern": "把 + objet + verbe", "anchor": "hsk20-371"},
    54: {"themeLabel": "Manger avec attention", "pattern": "虽然…但是…", "anchor": "hsk20-540"},
    55: {"themeLabel": "Traverser une vieille rue", "pattern": "以前…现在…", "anchor": "hsk20-394"},
    56: {"themeLabel": "Les habitudes du week-end", "pattern": "一直 + verbe", "anchor": "hsk20-564"},
    57: {"themeLabel": "Choisir une tenue", "pattern": "如果…就…", "anchor": "hsk20-462"},
    58: {"themeLabel": "Une carte difficile à lire", "pattern": "比较 + adjectif", "anchor": "hsk20-461"},
    59: {"themeLabel": "Le récit d’un voisin", "pattern": "根据 + information", "anchor": "hsk20-378"},
    60: {"themeLabel": "Bilan : comprendre, écouter et produire", "pattern": "Bilan des structures du niveau 3", "anchor": "hsk20-378"},
    61: {"themeLabel": "Préparer un voyage à l’étranger", "pattern": "关于…，我想…", "anchor": "hsk20-390"},
    62: {"themeLabel": "Le parc au fil des saisons", "pattern": "虽然…但是…", "anchor": "hsk20-304"},
    63: {"themeLabel": "Un spectacle de quartier", "pattern": "一边…一边…", "anchor": "hsk20-308"},
    64: {"themeLabel": "Retourner une peinture", "pattern": "还 + objet (huán)", "anchor": "hsk20-402"},
    65: {"themeLabel": "Trouver son chemin au parc", "pattern": "越来越 + adjectif", "anchor": "hsk20-487"},
    66: {"themeLabel": "Une occasion de voyager", "pattern": "几乎 + fréquence", "anchor": "hsk20-408"},
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
    reused = normalized_references(list(row["reusedCanonicalIDs"]), f"day {day}.reusedCanonicalIDs")
    refs = list(dict.fromkeys(new + reused))
    grammar_note = scene_data["grammar"]
    grammar_note["vocabularyID"] = normalize_reference(grammar_note["vocabularyID"])
    if grammar_note["pattern"] != override["pattern"]:
        raise ValueError(f"day {day}: authored grammar pattern differs from allocation override")
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
        "allocationRange": "days46-66",
        "theme": override["themeLabel"],
        "themeLabel": fr(override["themeLabel"]),
        "phase": row["phase"],
        "newVocabularyIDs": new,
        "reusedVocabularyIDs": reused,
        "newCanonicalIDs": new,
        "reusedCanonicalIDs": reused,
        "grammarPattern": override["pattern"],
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
    for day in range(46, 67):
        override = ALLOCATION_OVERRIDES[day]
        result[str(day)] = {
            "themeLabel": override["themeLabel"],
            "grammarTarget": {
                "patterns": [override["pattern"]],
                "anchorCanonicalID": normalize_reference(override["anchor"]),
                "reviewable": True,
            },
        }
    return result


def main() -> None:
    allocation_document = json.loads(ALLOCATION_PATH.read_text(encoding="utf-8"))
    allocation_rows = {row["day"]: row for row in allocation_document["lessons"]}
    expected_days = set(range(46, 67))
    if set(SCENES) != expected_days:
        missing = sorted(expected_days - set(SCENES))
        extra = sorted(set(SCENES) - expected_days)
        raise SystemExit(f"scene days mismatch; missing={missing}, extra={extra}")
    if set(ALLOCATION_OVERRIDES) != expected_days:
        raise SystemExit("allocation overrides must cover exactly days 46–66")
    if not expected_days.issubset(allocation_rows):
        raise SystemExit("allocation is missing one or more late-course days")

    catalog_document = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    entries = catalog_document.get("entries", [])
    catalog_ids = {entry["id"] for entry in entries}
    if len(catalog_ids) != len(entries) or len(catalog_ids) < 600:
        raise SystemExit("catalogue must contain at least 600 unique entries")

    lessons = [build_lesson(day, allocation_rows[day], catalog_ids) for day in range(46, 67)]
    lesson_ids = [lesson["id"] for lesson in lessons]
    if len(set(lesson_ids)) != len(lesson_ids):
        raise SystemExit("duplicate lesson IDs")
    budgets = [
        {"day": day, "lessonID": allocation_rows[day]["lessonID"], "courseMinutes": 12, "reviewMinutes": 3}
        for day in range(46, 67)
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
        "allocationRange": {"startDay": 46, "endDay": 66},
        "allocationOverrides": allocation_override_document(),
        "sessions": budgets,
        "sessionBudgets": budgets,
        "lessons": lessons,
    }
    OUTPUT_PATH.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {OUTPUT_PATH} ({len(lessons)} lessons, {len(budgets)} session budgets)")


if __name__ == "__main__":
    main()
