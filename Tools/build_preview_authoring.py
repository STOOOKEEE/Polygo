#!/usr/bin/env python3
"""Write the first five authoring sessions from the shared catalog."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Content" / "authoring" / "preview-first-five.json"


def fr(text: str) -> dict[str, str]:
    return {"fr": text}


def line(speaker: str, hanzi: str, pinyin: str, translation: str) -> dict:
    return {"speaker": speaker, "hanzi": hanzi, "pinyin": pinyin, "translation": fr(translation), "audio": None}


def paragraph(pid: str, hanzi: str, pinyin: str, translation: str) -> dict:
    return {"id": pid, "hanzi": hanzi, "pinyin": pinyin, "translation": fr(translation), "segmentation": [], "audio": None}


def choice(eid: str, prompt: str, instruction: str, objective: str, choices: list[tuple[str, str]], correct: str) -> dict:
    return {
        "id": eid, "kind": "choice", "prompt": fr(prompt), "instruction": fr(instruction),
        "objectiveIDs": [objective], "required": True,
        "choices": [{"id": cid, "label": fr(label), "audio": None} for cid, label in choices],
        "correctChoiceID": correct,
    }


def order(eid: str, prompt: str, objective: str, tokens: list[tuple[str, str, str]], correct: list[str], accepted: list[str]) -> dict:
    return {
        "id": eid, "kind": "wordOrder", "prompt": fr(prompt),
        "instruction": fr("Replace chaque groupe dans l’ordre, puis relis la phrase complète."),
        "objectiveIDs": [objective], "required": True,
        "tokens": [{"id": tid, "hanzi": hanzi, "pinyin": py, "audio": None} for tid, hanzi, py in tokens],
        "correctOrder": correct, "acceptedVariants": accepted,
    }


def fill(eid: str, prompt: str, sentence: str, answers: list[str], objective: str) -> dict:
    return {
        "id": eid, "kind": "fillBlank", "prompt": fr(prompt),
        "instruction": fr("Écris le mot manquant en caractères chinois."),
        "objectiveIDs": [objective], "required": True,
        "sentence": sentence, "acceptedAnswers": answers, "caseSensitive": False,
    }


def listen(eid: str, prompt: str, text: str, objective: str, choices: list[tuple[str, str]], correct: str) -> dict:
    return {
        "id": eid, "kind": "listeningChoice", "prompt": fr(prompt),
        "instruction": fr("Écoute la phrase en mandarin, puis choisis son sens."),
        "objectiveIDs": [objective], "required": True, "promptText": text,
        "choices": [{"id": cid, "label": fr(label), "audio": None} for cid, label in choices],
        "correctChoiceID": correct,
    }


def speak(eid: str, prompt: str, reference: str, pinyin: str, objective: str) -> dict:
    return {
        "id": eid, "kind": "speaking", "prompt": fr(prompt),
        "instruction": fr("Écoute le modèle, dis la phrase, puis réécoute-toi ou auto-évalue-toi."),
        "objectiveIDs": [objective], "required": False,
        "referenceText": reference, "referencePinyin": pinyin, "referenceAudio": None,
        "acceptedTranscripts": [reference], "allowSelfRating": True,
    }


def reading_choice(eid: str, prompt: str, objective: str, choices: list[tuple[str, str]], correct: str) -> dict:
    return choice(eid, prompt, "Relis le petit texte avant de répondre.", objective, choices, correct)


def vocab_card(vocab_id: str, hanzi: str, pinyin: str, meaning: str) -> dict:
    # The current generator creates cards from catalog references. This helper
    # is retained for authoring previews that need to be inspected standalone.
    return {
        "id": f"card-{vocab_id}", "vocabularyID": vocab_id,
        "front": {"hanzi": hanzi, "pinyin": None, "text": None, "audio": None},
        "back": {"hanzi": hanzi, "pinyin": f"{pinyin} · ", "text": fr(meaning), "audio": None},
        "tags": ["unit-02", vocab_id, "hsk-classic-2.0"],
        "reviewDimensions": ["word", "meaning", "tone", "listening"],
        "reviewDirections": ["hanzi-to-meaning", "meaning-to-hanzi"],
    }


# The first five sessions are a compact authoring preview around the existing
# greeting/identity introduction.  The 90-day pack uses thematic allocation
# and spaced reuse; this preview is intentionally kept separate from it.
LESSONS = [
    {
        "id": "lesson-05", "moduleID": "unit-02", "order": 5,
        "title": fr("Boire et manger"),
        "summary": fr("Nommer une boisson et un plat, puis faire une proposition simple."),
        "estimatedMinutes": 12,
        "objectives": [
            {"id": "l5-understand", "text": fr("Comprendre une question simple sur une boisson ou un plat."), "required": True},
            {"id": "l5-produce", "text": fr("Produire une phrase courte avec un nom et un verbe d’action."), "required": True},
        ],
        # The four mapped starter lexemes keep the first planned day
        # self-contained for the 1–300 coverage boundary, even though their
        # cards were introduced in the protected greeting lessons.
        "vocabularyIDs": ["hsk20-007", "hsk20-009", "hsk20-010", "hsk20-011", "hsk20-021", "hsk20-024", "hsk20-036", "hsk20-037", "hsk20-038", "hsk20-039", "hsk20-062", "hsk20-068", "hsk20-070", "hsk20-086", "hsk20-126", "vocab-ni", "vocab-wo"],
        "extraVocabulary": [{
            "id": "vocab-dan", "hanzi": "但", "traditionalHanzi": "但", "pinyin": "dàn", "toneNumbers": [4],
            "segmentation": [{"surface": "但", "vocabularyID": "vocab-dan", "pinyin": "dàn", "partOfSpeech": "conjunction"}],
            "partOfSpeech": "conjunction", "grammarNotes": [], "meaning": {"fr": "mais"},
            "audio": None, "example": None, "memoryStory": None
        }],
        "grammar": [
            {"vocabularyID": "hsk20-038", "pattern": "A 和 B", "explanation": fr("和 relie deux noms ou deux groupes : 茶和菜 signifie « le thé et le plat »."), "examples": [{"hanzi": "茶和菜都很好。", "pinyin": "chá hé cài dōu hěn hǎo.", "translation": fr("Le thé et le plat sont tous les deux très bons."), "audio": None}]},
            {"vocabularyID": "hsk20-062", "pattern": "phrase + 吗？", "explanation": fr("吗 transforme une phrase déclarative en question oui/non."), "examples": [{"hanzi": "你喝茶吗？", "pinyin": "nǐ hē chá ma?", "translation": fr("Tu bois du thé ?"), "audio": None}]},
        ],
        "dialogue": {"id": "block-l5-dialogue", "lines": [
            line("Mina", "你喝茶吗？", "nǐ hē chá ma?", "Tu bois du thé ?"),
            line("Tao", "喝。", "hē.", "Oui."),
            line("Mina", "你吃菜吗？", "nǐ chī cài ma?", "Tu manges le plat ?"),
            line("Tao", "吃，但不多。", "chī, dàn bù duō.", "Oui, mais pas beaucoup."),
            line("Mina", "茶和菜都很好！", "chá hé cài dōu hěn hǎo!", "Le thé et le plat sont très bons !"),
            line("Tao", "很好！", "hěn hǎo!", "Très bien !"),
        ]},
        "reading": {"id": "block-l5-reading", "storyID": "story-l5-tea", "title": fr("Une tasse"), "paragraphs": [
            paragraph("p1", "我喝茶。", "wǒ hē chá.", "Je bois du thé."),
            paragraph("p2", "我喝茶，吃菜。", "wǒ hē chá, chī cài.", "Je bois du thé et je mange un plat."),
        ], "comprehensionExerciseIDs": ["ex-l5-reading"]},
        "exercises": [
            choice("ex-l5-meaning", "Que signifie 茶 ?", "Choisis le sens du mot entendu dans le dialogue.", "l5-understand", [("a", "riz"), ("b", "thé"), ("c", "tasse")], "b"),
            order("ex-l5-order", "Construis « Je bois du thé ». ", "l5-produce", [("a", "茶", "chá"), ("b", "我", "wǒ"), ("c", "喝", "hē")], ["b", "c", "a"], ["我喝茶。", "我喝茶"]),
            fill("ex-l5-fill", "Complète la question « Tu bois du thé ? » : 你___茶吗？", "你___茶吗？", ["喝"], "l5-produce"),
            listen("ex-l5-listen", "Quelle phrase entends-tu ?", "茶和菜都很好！", "l5-understand", [("a", "Le thé est froid."), ("b", "Je n’ai pas de tasse."), ("c", "Le thé et le plat sont très bons.")], "c"),
            speak("ex-l5-speak", "Dis « Le thé et le plat sont très bons ». ", "茶和菜都很好！", "chá hé cài dōu hěn hǎo!", "l5-produce"),
            reading_choice("ex-l5-reading", "Que fait la personne dans le texte ?", "l5-understand", [("a", "Elle prend le bus."), ("b", "Elle lit un journal."), ("c", "Elle boit du thé et mange un plat.")], "c"),
        ],
        "recap": {"id": "block-l5-recap", "vocabularyIDs": ["hsk20-009", "hsk20-010", "hsk20-011", "hsk20-021", "hsk20-037", "hsk20-038"], "objectiveIDs": ["l5-understand", "l5-produce"]},
    },
    {
        "id": "lesson-06", "moduleID": "unit-02", "order": 6,
        "title": fr("À la maison"),
        "summary": fr("Parler de ce qu’on regarde et de ce qui se trouve à la maison."),
        "estimatedMinutes": 12,
        "objectives": [
            {"id": "l6-understand", "text": fr("Repérer un objet et un lieu dans une phrase courte."), "required": True},
            {"id": "l6-produce", "text": fr("Dire où se trouve une personne ou un objet."), "required": True},
        ],
        "vocabularyIDs": ["hsk20-017", "hsk20-018", "hsk20-019", "hsk20-020", "hsk20-021", "hsk20-034", "hsk20-038", "hsk20-045", "hsk20-050", "hsk20-051", "hsk20-062", "hsk20-120", "hsk20-139", "hsk20-275", "vocab-ni", "vocab-wo"],
        "grammar": [
            {"vocabularyID": "hsk20-139", "pattern": "sujet + 在 + lieu", "explanation": fr("在 se place après le sujet et avant le lieu : 电脑在家里 signifie « l’ordinateur est à la maison »."), "examples": [{"hanzi": "电脑在家里。", "pinyin": "diàn nǎo zài jiā lǐ.", "translation": fr("L’ordinateur est à la maison."), "audio": None}]},
            {"vocabularyID": "hsk20-275", "pattern": "也 + verbe", "explanation": fr("也 ajoute une information équivalente : « aussi » se place avant le verbe."), "examples": [{"hanzi": "我也看电影。", "pinyin": "wǒ yě kàn diàn yǐng.", "translation": fr("Je regarde aussi un film."), "audio": None}]},
            {"vocabularyID": "hsk20-021", "pattern": "都 + verbe", "explanation": fr("都 indique que l’ensemble du groupe est concerné."), "examples": [{"hanzi": "东西都在家。", "pinyin": "dōng xi dōu zài jiā.", "translation": fr("Les affaires sont toutes à la maison."), "audio": None}]},
        ],
        "dialogue": {"id": "block-l6-dialogue", "lines": [
            line("Mina", "你在家吗？", "nǐ zài jiā ma?", "Tu es à la maison ?"),
            line("Tao", "我看电影。", "wǒ kàn diàn yǐng.", "Je regarde un film."),
            line("Mina", "电脑和电视在家。", "diàn nǎo hé diàn shì zài jiā.", "L’ordinateur et la télévision sont à la maison."),
            line("Tao", "你的狗也在家吗？", "nǐ de gǒu yě zài jiā ma?", "Ton chien est aussi à la maison ?"),
            line("Mina", "在家。现在开电视。", "zài jiā. xiàn zài kāi diàn shì.", "Il est à la maison. J’allume la télévision maintenant."),
            line("Tao", "好！", "hǎo!", "D’accord !"),
        ]},
        "reading": {"id": "block-l6-reading", "storyID": "story-l6-home", "title": fr("Dans le salon"), "paragraphs": [
            paragraph("p1", "我在家看电影。", "wǒ zài jiā kàn diàn yǐng.", "Je regarde un film à la maison."),
            paragraph("p2", "电脑和电视在家。", "diàn nǎo hé diàn shì zài jiā.", "L’ordinateur et la télévision sont à la maison."),
        ], "comprehensionExerciseIDs": ["ex-l6-reading"]},
        "exercises": [
            choice("ex-l6-meaning", "Que signifie 电脑 ?", "Choisis l’objet correct.", "l6-understand", [("a", "télévision"), ("b", "chien"), ("c", "ordinateur")], "c"),
            order("ex-l6-order", "Construis « L’ordinateur est à la maison ». ", "l6-produce", [("a", "家里", "jiā lǐ"), ("b", "在", "zài"), ("c", "电脑", "diàn nǎo")], ["c", "b", "a"], ["电脑在家里。", "电脑在家里"]),
            fill("ex-l6-fill", "Complète : 电脑___家里。", "电脑___家里。", ["在"], "l6-produce"),
            listen("ex-l6-listen", "Où sont les appareils ?", "电脑和电视在家。", "l6-understand", [("a", "Ils sont à l’école."), ("b", "Ils sont à la maison."), ("c", "Ils sont dans le train.")], "b"),
            speak("ex-l6-speak", "Dis « Je regarde un film ». ", "我看电影。", "wǒ kàn diàn yǐng.", "l6-produce"),
            reading_choice("ex-l6-reading", "Que trouve-t-on à la maison ?", "l6-understand", [("a", "Un avion et un bateau."), ("b", "Un journal et un billet."), ("c", "Un ordinateur et une télévision.")], "c"),
        ],
        "recap": {"id": "block-l6-recap", "vocabularyIDs": ["hsk20-017", "hsk20-019", "hsk20-020", "hsk20-038", "hsk20-051", "hsk20-139"], "objectiveIDs": ["l6-understand", "l6-produce"]},
    },
    {
        "id": "lesson-07", "moduleID": "unit-02", "order": 7,
        "title": fr("La famille et la date"),
        "summary": fr("Nommer des proches et situer une activité dans le temps."),
        "estimatedMinutes": 12,
        "objectives": [
            {"id": "l7-understand", "text": fr("Comprendre qui est présent et quand une activité a lieu."), "required": True},
            {"id": "l7-produce", "text": fr("Présenter un membre de la famille avec 的."), "required": True},
        ],
        "vocabularyIDs": ["hsk20-003", "hsk20-015", "hsk20-026", "hsk20-038", "hsk20-044", "hsk20-047", "hsk20-048", "hsk20-049", "hsk20-061", "hsk20-076", "hsk20-088", "hsk20-089", "hsk20-137", "hsk20-139", "hsk20-045", "vocab-ni", "vocab-wo", "vocab-ne", "vocab-shi"],
        "grammar": [
            {"vocabularyID": "hsk20-015", "pattern": "nom + 的 + nom", "explanation": fr("的 relie un possesseur et ce qui lui appartient : 我的妈妈 signifie « ma maman »."), "examples": [{"hanzi": "我的妈妈在家。", "pinyin": "wǒ de mā ma zài jiā.", "translation": fr("Ma maman est à la maison."), "audio": None}]},
        ],
        "dialogue": {"id": "block-l7-dialogue", "lines": [
            line("Mina", "今天是几月几日？", "jīn tiān shì jǐ yuè jǐ rì?", "Quelle date sommes-nous ?"),
            line("Tao", "今天是九月三日。", "jīn tiān shì jiǔ yuè sān rì.", "Nous sommes le 3 septembre."),
            line("Mina", "我妈妈和我爸爸在家。", "wǒ mā ma hé wǒ bà ba zài jiā.", "Ma maman et mon papa sont à la maison."),
            line("Tao", "她的儿子在家。", "tā de ér zi zài jiā.", "Son fils est à la maison."),
            line("Mina", "我的女儿在家。", "wǒ de nǚ ér zài jiā.", "Ma fille est à la maison."),
            line("Tao", "你呢？", "nǐ ne?", "Et toi ?"),
        ]},
        "reading": {"id": "block-l7-reading", "storyID": "story-l7-family", "title": fr("Un calendrier familial"), "paragraphs": [
            paragraph("p1", "今天是九月三日。", "jīn tiān shì jiǔ yuè sān rì.", "Nous sommes le 3 septembre."),
            paragraph("p2", "她的儿子在家，我的女儿在家。", "tā de ér zi zài jiā, wǒ de nǚ ér zài jiā.", "Son fils et ma fille sont à la maison."),
        ], "comprehensionExerciseIDs": ["ex-l7-reading"]},
        "exercises": [
            choice("ex-l7-meaning", "Que signifie 妈妈 ?", "Choisis le membre de la famille.", "l7-understand", [("a", "petit frère"), ("b", "fille"), ("c", "maman")], "c"),
            order("ex-l7-order", "Construis « Ma maman est à la maison ». ", "l7-produce", [("a", "在家", "zài jiā"), ("b", "妈妈", "mā ma"), ("c", "我的", "wǒ de")], ["c", "b", "a"], ["我的妈妈在家。", "我的妈妈在家"]),
            fill("ex-l7-fill", "Complète « Son fils est à la maison » : 她的___在家。", "她的___在家。", ["儿子"], "l7-produce"),
            listen("ex-l7-listen", "Qui est à la maison ?", "她的儿子在家。", "l7-understand", [("a", "Sa fille."), ("b", "Son fils."), ("c", "Son père.")], "b"),
            speak("ex-l7-speak", "Dis « Ma maman est à la maison ». ", "我的妈妈在家。", "wǒ de mā ma zài jiā.", "l7-produce"),
            reading_choice("ex-l7-reading", "Qui est à la maison ?", "l7-understand", [("a", "La fille."), ("b", "Le fils."), ("c", "Le père.")], "b"),
        ],
        "recap": {"id": "block-l7-recap", "vocabularyIDs": ["hsk20-003", "hsk20-026", "hsk20-047", "hsk20-048", "hsk20-061", "hsk20-076"], "objectiveIDs": ["l7-understand", "l7-produce"]},
    },
    {
        "id": "lesson-08", "moduleID": "unit-02", "order": 8,
        "title": fr("Acheter des pommes"),
        "summary": fr("Dire l’heure, demander un prix et acheter des pommes."),
        "estimatedMinutes": 12,
        "objectives": [
            {"id": "l8-understand", "text": fr("Comprendre un lieu, une heure et un prix simple."), "required": True},
            {"id": "l8-produce", "text": fr("Demander un billet ou exprimer un souhait."), "required": True},
        ],
        "vocabularyIDs": ["hsk20-016", "hsk20-025", "hsk20-044", "hsk20-053", "hsk20-063", "hsk20-079", "hsk20-082", "hsk20-084", "hsk20-089", "hsk20-090", "hsk20-120", "hsk20-121", "vocab-wo"],
        "grammar": [
            {"vocabularyID": "hsk20-121", "pattern": "想 + verbe", "explanation": fr("想 exprime un souhait et se place avant l’action : 我想买苹果 signifie « je veux acheter des pommes »."), "examples": [{"hanzi": "我想买苹果。", "pinyin": "wǒ xiǎng mǎi píng guǒ.", "translation": fr("Je veux acheter des pommes."), "audio": None}]},
            {"vocabularyID": "hsk20-053", "pattern": "prix + 块", "explanation": fr("块 est l’unité familière du yuan dans un prix courant."), "examples": [{"hanzi": "苹果三块。", "pinyin": "píng guǒ sān kuài.", "translation": fr("Les pommes coûtent trois yuans."), "audio": None}]},
        ],
        "dialogue": {"id": "block-l8-dialogue", "lines": [
            line("Mina", "现在几点？", "xiàn zài jǐ diǎn?", "Quelle heure est-il ?"),
            line("Tao", "现在三点。", "xiàn zài sān diǎn.", "Il est trois heures."),
            line("Mina", "我想去商店买苹果。", "wǒ xiǎng qù shāng diàn mǎi píng guǒ.", "Je veux aller au magasin acheter des pommes."),
            line("Tao", "苹果多少钱？", "píng guǒ duō shao qián?", "Combien coûtent les pommes ?"),
            line("Mina", "苹果三块。", "píng guǒ sān kuài.", "Les pommes coûtent trois yuans."),
            line("Tao", "我买。", "wǒ mǎi.", "J’achète."),
        ]},
        "reading": {"id": "block-l8-reading", "storyID": "story-l8-shop", "title": fr("Au magasin"), "paragraphs": [
            paragraph("p1", "现在三点，我想去商店。", "xiàn zài sān diǎn, wǒ xiǎng qù shāng diàn.", "Il est trois heures, je veux aller au magasin."),
            paragraph("p2", "苹果三块。", "píng guǒ sān kuài.", "Les pommes coûtent trois yuans."),
        ], "comprehensionExerciseIDs": ["ex-l8-reading"]},
        "exercises": [
            choice("ex-l8-meaning", "Que signifie 商店 ?", "Choisis le lieu où l’on achète les pommes.", "l8-understand", [("a", "restaurant"), ("b", "magasin"), ("c", "hôpital")], "b"),
            order("ex-l8-order", "Construis « Je veux acheter des pommes ». ", "l8-produce", [("a", "苹果", "píng guǒ"), ("b", "买", "mǎi"), ("c", "我想", "wǒ xiǎng")], ["c", "b", "a"], ["我想买苹果。", "我想买苹果"]),
            fill("ex-l8-fill", "Dans le dialogue, quelle unité familière suit le prix ?", "苹果三___。", ["块"], "l8-produce"),
            listen("ex-l8-listen", "Quel est le prix ?", "苹果三块。", "l8-understand", [("a", "20 yuans"), ("b", "3 yuans"), ("c", "30 yuans")], "b"),
            speak("ex-l8-speak", "Dis « Je veux aller au magasin ». ", "我想去商店。", "wǒ xiǎng qù shāng diàn.", "l8-produce"),
            reading_choice("ex-l8-reading", "Où la personne veut-elle aller ?", "l8-understand", [("a", "À l’école."), ("b", "À la gare."), ("c", "Au magasin.")], "c"),
        ],
        "recap": {"id": "block-l8-recap", "vocabularyIDs": ["hsk20-016", "hsk20-053", "hsk20-063", "hsk20-079", "hsk20-090", "hsk20-121"], "objectiveIDs": ["l8-understand", "l8-produce"]},
    },
    {
        "id": "lesson-09", "moduleID": "unit-02", "order": 9,
        "title": fr("Une journée organisée"),
        "summary": fr("Parler d’un déplacement, d’une capacité et d’une action terminée."),
        "estimatedMinutes": 12,
        "objectives": [
            {"id": "l9-understand", "text": fr("Comprendre un itinéraire et une action déjà terminée."), "required": True},
            {"id": "l9-produce", "text": fr("Dire ce qu’on peut faire et où l’on va."), "required": True},
        ],
        "vocabularyIDs": ["hsk20-007", "hsk20-016", "hsk20-041", "hsk20-042", "hsk20-043", "hsk20-044", "hsk20-045", "hsk20-058", "hsk20-084", "hsk20-139", "hsk20-148", "hsk20-165", "hsk20-170", "hsk20-297", "hsk20-298", "hsk20-485", "vocab-ni", "vocab-wo"],
        "grammar": [
            {"vocabularyID": "hsk20-058", "pattern": "verbe + 了", "explanation": fr("了 placé après le verbe signale ici une action terminée : 我看了 signifie « j’ai regardé »."), "examples": [{"hanzi": "我看了电影。", "pinyin": "wǒ kàn le diàn yǐng.", "translation": fr("J’ai regardé un film."), "audio": None}]},
            {"vocabularyID": "hsk20-042", "pattern": "会 + verbe", "explanation": fr("会 indique une capacité apprise ou une possibilité future : 我会说汉语 signifie « je sais parler chinois »."), "examples": [{"hanzi": "我会说汉语。", "pinyin": "wǒ huì shuō Hàn yǔ.", "translation": fr("Je sais parler chinois."), "audio": None}]},
            {"vocabularyID": "hsk20-165", "pattern": "从 A 到 B", "explanation": fr("从 et 到 encadrent un point de départ et un point d’arrivée."), "examples": [{"hanzi": "从家到火车站很近。", "pinyin": "cóng jiā dào huǒ chē zhàn hěn jìn.", "translation": fr("De la maison à la gare, c’est proche."), "audio": None}]},
        ],
        "dialogue": {"id": "block-l9-dialogue", "lines": [
            line("Mina", "你昨天在家吗？", "nǐ zuó tiān zài jiā ma?", "Tu étais à la maison hier ?"),
            line("Tao", "不在，我去了火车站。", "bù zài, wǒ qù le huǒ chē zhàn.", "Non, je suis allé à la gare."),
            line("Mina", "你会骑自行车吗？你几点回家？", "nǐ huì qí zì xíng chē ma? nǐ jǐ diǎn huí jiā?", "Tu sais faire du vélo ? À quelle heure rentres-tu ?"),
            line("Tao", "会。五点回家。", "huì. wǔ diǎn huí jiā.", "Oui. Je rentre à cinq heures."),
            line("Mina", "我从家走到火车站。", "wǒ cóng jiā zǒu dào huǒ chē zhàn.", "Je marche de la maison jusqu’à la gare."),
            line("Tao", "好，我回家。", "hǎo, wǒ huí jiā.", "D’accord, je rentre à la maison."),
        ]},
        "reading": {"id": "block-l9-reading", "storyID": "story-l9-station", "title": fr("Vers la gare"), "paragraphs": [
            paragraph("p1", "我昨天去了火车站。", "wǒ zuó tiān qù le huǒ chē zhàn.", "Je suis allé à la gare hier."),
            paragraph("p2", "我从家走到火车站，我回家。", "wǒ cóng jiā zǒu dào huǒ chē zhàn, wǒ huí jiā.", "Je marche de la maison jusqu’à la gare, puis je rentre."),
        ], "comprehensionExerciseIDs": ["ex-l9-reading"]},
        "exercises": [
            choice("ex-l9-meaning", "Que signifie 火车站 ?", "Choisis le lieu du train.", "l9-understand", [("a", "hôpital"), ("b", "banque"), ("c", "gare")], "c"),
            order("ex-l9-order", "Construis « Je rentre à la maison ». ", "l9-produce", [("a", "家", "jiā"), ("b", "回", "huí"), ("c", "我", "wǒ")], ["c", "b", "a"], ["我回家。", "我回家"]),
            fill("ex-l9-fill", "Complète avec le mot qui marque l’action terminée dans le dialogue.", "我昨天去___火车站。", ["了"], "l9-produce"),
            listen("ex-l9-listen", "Que fait Mina ?", "我从家走到火车站。", "l9-understand", [("a", "Elle prend l’avion."), ("b", "Elle marche jusqu’à la gare."), ("c", "Elle reste à la maison.")], "b"),
            speak("ex-l9-speak", "Dis « Je marche de la maison jusqu’à la gare ». ", "我从家走到火车站。", "wǒ cóng jiā zǒu dào huǒ chē zhàn.", "l9-produce"),
            reading_choice("ex-l9-reading", "Comment la personne se déplace-t-elle ?", "l9-understand", [("a", "Elle marche."), ("b", "Elle prend l’avion."), ("c", "Elle nage.")], "a"),
        ],
        "recap": {"id": "block-l9-recap", "vocabularyIDs": ["hsk20-041", "hsk20-042", "hsk20-043", "hsk20-058", "hsk20-165", "hsk20-297"], "objectiveIDs": ["l9-understand", "l9-produce"]},
    },
]


def main() -> None:
    payload = {
        "schemaVersion": 1,
        "contentVersion": "2026.10.0",
        "course": {
            "id": "mandarin-starter",
            "slug": "mandarin-starter",
            "title": fr("Mandarin au quotidien — premières semaines"),
            "description": fr("Cinq séances d’auteur après l’introduction : vie quotidienne, famille, achat et déplacement. Repère HSK classique 2.0 ; la couverture décrit les lexèmes rencontrés et ne garantit pas l’acquisition."),
            "alignment": [
                {"framework": "HSK-classic-2.0", "level": "1–2"},
                {"framework": "HSK-3.0", "level": "reference-transition"},
            ],
        },
        "catalog": "authoring/hsk-legacy-600.json",
        "modules": [{"id": "unit-02", "order": 2, "title": fr("Vie quotidienne — bases"), "lessonIDs": [lesson["id"] for lesson in LESSONS]}],
        "lessons": LESSONS,
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {OUT} ({len(LESSONS)} lessons)")


if __name__ == "__main__":
    main()
