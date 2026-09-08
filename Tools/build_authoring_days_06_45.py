#!/usr/bin/env python3
"""Serialize the explicitly authored lesson lot for course days 6–45.

The editorial table below is the source of every Chinese sentence and French
translation. Helpers only add the stable JSON envelope, pinyin presentation,
and exercise block fields after those sentences have been authored.
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from pypinyin import Style, pinyin


ROOT = Path(__file__).resolve().parents[1]
AUTHORING = ROOT / "Content" / "authoring"
ALLOCATION_PATH = AUTHORING / "90-day-allocation.json"
OUTPUT_PATH = AUTHORING / "90-day-authoring-days-06-45.json"


def sentence_pinyin(hanzi: str) -> str:
    """Render pinyin for an already authored sentence; never author text."""
    # The custom error callback returns one token per non-Chinese character;
    # the default callback groups ``，Mina`` and makes character-wise zipping
    # lose both punctuation and the following name.
    values = pinyin(hanzi, style=Style.TONE, heteronym=False, errors=lambda chars: list(chars))
    result: list[str] = []
    punctuation = set("，。？！：；、,.!?;:")
    previous_kind: str | None = None
    for char, value in zip(hanzi, values):
        if char in punctuation:
            if result:
                result[-1] += char
            else:
                result.append(char)
        elif re.search(r"[\u3400-\u9fff]", char):
            result.append(value[0] if value else char)
            previous_kind = "hanzi"
        else:
            # Keep names and numbers readable as one token while retaining a
            # boundary after a Chinese syllable.
            if previous_kind == "latin" and result:
                result[-1] += char
            else:
                result.append(char)
            previous_kind = "latin"
    return " ".join(result)


def line(speaker: str, hanzi: str, translation: str) -> dict[str, Any]:
    return {"speaker": speaker, "hanzi": hanzi, "pinyin": sentence_pinyin(hanzi), "translation": {"fr": translation}, "audio": None}


def paragraph(pid: str, hanzi: str, translation: str) -> dict[str, Any]:
    return {"id": pid, "hanzi": hanzi, "pinyin": sentence_pinyin(hanzi), "translation": {"fr": translation}, "segmentation": [], "audio": None}


def grammar(anchor: str, pattern: str, explanation: str, example_hanzi: str, example_fr: str) -> dict[str, Any]:
    return {"vocabularyID": anchor, "pattern": pattern, "explanation": {"fr": explanation}, "examples": [{"hanzi": example_hanzi, "pinyin": sentence_pinyin(example_hanzi), "translation": {"fr": example_fr}, "audio": None}]}


# Every day has its own scene, reading, and answer data. The IDs are supplied
# by the allocation and are checked against this table when the lot is built.
DAY_DATA: dict[int, dict[str, Any]] = {
    6: {
        "title": "Ranger la chambre",
        "summary": "Situer des objets dans une chambre et appeler le professeur.",
        "dialogue": [
            ("Mina", "你的房间有桌子和椅子吗？", "Ta chambre a une table et des chaises ?"),
            ("Tao", "有，桌子上有一本书。", "Oui, il y a un livre sur la table."),
            ("Mina", "门旁边有手机吗？", "Y a-t-il un téléphone près de la porte ?"),
            ("Tao", "手机在桌子上，我给老师打电话。", "Le téléphone est sur la table ; j’appelle le professeur."),
            ("Mina", "你的朋友也在房间吗？", "Ton ami est aussi dans la chambre ?"),
            ("Tao", "他不在。老师要这本书，所以我先整理房间。", "Il n’est pas là. Le professeur veut ce livre, alors je range d’abord la chambre."),
        ],
        "reading": ("La chambre", "我在家整理房间。桌子上有一本书，椅子在桌子旁边。", "Je range la chambre à la maison. Il y a un livre sur la table et la chaise est à côté.", "我在家整理房间，因为老师要这本书。", "Je range la chambre à la maison parce que le professeur veut ce livre."),
        "grammar": [grammar("hsk20-098", "在 + lieu", "在 se place après le sujet et avant le lieu.", "手机在桌子上。", "Le téléphone est sur la table.")],
        "choice": ("Que signifie 书 ?", "Choisis l’objet mentionné sur la table.", [("a", "porte"), ("b", "livre"), ("c", "téléphone")], "b"),
        "order": ("Construis « Le téléphone est sur la table ». ", [("a", "桌子上"), ("b", "手机"), ("c", "在")], ["b", "c", "a"], ["手机在桌子上。", "手机在桌子上"]),
        "fill": ("Complète : 手机___桌子上。", "手机___桌子上。", ["在"]),
        "listen": ("Où est le téléphone ?", "手机在桌子上。", [("a", "Dans la chambre."), ("b", "Sur la table."), ("c", "Près de la porte.")], "b"),
        "speak": ("Dis « J’appelle le professeur ». ", "我给老师打电话。", "J’appelle le professeur."),
        "readingChoice": ("Où est le livre dans le texte ?", [("a", "Sur la table."), ("b", "Près de la porte."), ("c", "Dans le téléphone.")], "a"),
    },
    7: {
        "title": "Déjeuner au restaurant",
        "summary": "Commander un repas et choisir une boisson selon ses goûts.",
        "dialogue": [
            ("Mina", "中午我们去饭馆吗？", "Nous allons au restaurant à midi ?"),
            ("Tao", "好，我要米饭和鱼。", "D’accord, je veux du riz et du poisson."),
            ("Mina", "这里还有鸡蛋、水果和牛奶。", "Il y a aussi des œufs, des fruits et du lait."),
            ("Tao", "我不喝咖啡，我喝牛奶。", "Je ne bois pas de café, je bois du lait."),
            ("Mina", "天气很热，吃西瓜吧。", "Il fait très chaud, mangeons de la pastèque."),
            ("Tao", "好，吃完我们去买衣服。", "D’accord, après le repas nous irons acheter des vêtements."),
        ],
        "reading": ("Le déjeuner", "中午我和朋友在饭馆吃米饭、鱼和鸡蛋。", "À midi, mon ami et moi mangeons du riz, du poisson et des œufs au restaurant.", "我喝牛奶，不喝咖啡。吃完饭，我们买了一件衣服。", "Je bois du lait, pas de café. Après le repas, nous achetons un vêtement."),
        "grammar": [grammar("hsk20-019", "也 + verbe", "也 ajoute une information équivalente avant le verbe.", "我也吃米饭。", "Je mange aussi du riz.")],
        "choice": ("Que signifie 牛奶 ?", "Choisis la boisson du dialogue.", [("a", "café"), ("b", "lait"), ("c", "thé")], "b"),
        "order": ("Construis « Je mange du riz ». ", [("a", "米饭"), ("b", "我"), ("c", "吃")], ["b", "c", "a"], ["我吃米饭。", "我吃米饭"]),
        "fill": ("Complète : 我不喝___，我喝牛奶。", "我不喝___，我喝牛奶。", ["咖啡"]),
        "listen": ("Que mange Tao ?", "好，我要米饭和鱼。", [("a", "Du riz et du poisson."), ("b", "Des œufs et du café."), ("c", "Du pain et du lait.")], "a"),
        "speak": ("Dis « Il fait très chaud, mangeons de la pastèque ». ", "天气很热，吃西瓜吧。", "Il fait très chaud, mangeons de la pastèque."),
        "readingChoice": ("Que boit la personne ?", [("a", "Du café."), ("b", "Du lait."), ("c", "De l’eau.")], "b"),
    },
    8: {
        "title": "Une famille au complet",
        "summary": "Présenter les proches présents et demander combien de frères et sœurs il y a.",
        "dialogue": [
            ("Mina", "你有几个兄弟姐妹？", "Combien de frères et sœurs as-tu ?"),
            ("Tao", "我有五个兄弟姐妹：一个弟弟、两个妹妹，还有哥哥和姐姐。", "J’ai cinq frères et sœurs : un petit frère, deux petites sœurs, un grand frère et une grande sœur."),
            ("Mina", "你的哥哥也是学生吗？", "Ton grand frère est aussi étudiant ?"),
            ("Tao", "是，他和姐姐在学校。", "Oui, il est à l’école avec ma grande sœur."),
            ("Mina", "那位男人是谁？", "Qui est cet homme ?"),
            ("Tao", "他是我丈夫；那位女人是服务员。", "C’est mon mari ; cette femme est serveuse."),
        ],
        "reading": ("Les proches", "我有五个兄弟姐妹：一个弟弟、两个妹妹、一个哥哥和一个姐姐。", "J’ai cinq frères et sœurs : un petit frère, deux petites sœurs, un grand frère et une grande sœur.", "他们回来以后，那个男人和女人在饭馆工作，服务员给他们水。", "Après leur retour, l’homme et la femme travaillent au restaurant ; la serveuse leur donne de l’eau."),
        "grammar": [grammar("hsk20-128", "有 + nom", "有 exprime ici l’existence ou la possession.", "我家有两个孩子。", "Il y a deux enfants dans ma famille.")],
        "choice": ("Que signifie 妹妹 ?", "Choisis le membre de la famille.", [("a", "petite sœur"), ("b", "grand frère"), ("c", "mari")], "a"),
        "order": ("Construis « J’ai un petit frère ». ", [("a", "弟弟"), ("b", "我有一个"), ("c", "。")], ["b", "a", "c"], ["我有一个弟弟。", "我有一个弟弟"]),
        "fill": ("Complète la phrase : « J’ai un petit frère et deux petites sœurs » : 我有一个弟弟和两个___。", "我有一个弟弟和两个___。", ["妹妹"]),
        "listen": ("Qui est à l’école ?", "他和姐姐在学校。", [("a", "Le mari et la femme."), ("b", "Le grand frère et la grande sœur."), ("c", "Le petit frère et la serveuse.")], "b"),
        "speak": ("Dis « Il y a deux petites sœurs ». ", "有两个妹妹。", "Il y a deux petites sœurs."),
        "readingChoice": ("Combien de frères et sœurs a Tao ?", [("a", "Deux."), ("b", "Cinq."), ("c", "Quatre.")], "b"),
    },
    9: {
        "title": "Organiser demain",
        "summary": "Situer un rendez-vous dans la journée et lire une information dans le journal.",
        "dialogue": [
            ("Mina", "明天上午你有时间吗？", "Tu as du temps demain matin ?"),
            ("Tao", "有，我们十点见。", "Oui, retrouvons-nous à dix heures."),
            ("Mina", "中午吃饭要多少分钟？", "Combien de minutes faut-il pour déjeuner à midi ?"),
            ("Tao", "二十分钟就够了，下午我还要上课。", "Vingt minutes suffisent, j’ai encore cours l’après-midi."),
            ("Mina", "今天是星期几？", "Quel jour sommes-nous ?"),
            ("Tao", "星期三。看完报纸我很高兴。", "Mercredi. Je suis content après avoir lu le journal."),
        ],
        "reading": ("Le programme", "明天上午十点，我和同学见面。中午我们吃饭二十分钟。", "Demain à dix heures du matin, je retrouve un camarade. À midi, nous déjeunons pendant vingt minutes.", "下午我去学校，晚上在家看报纸。星期三的安排让我很高兴。", "L’après-midi, je vais à l’école et le soir je lis le journal à la maison. Le programme du mercredi me rend heureux."),
        "grammar": [grammar("hsk20-069", "这/那 + nom", "这 désigne ce qui est proche et 那 ce qui est plus éloigné.", "这是今天的报纸。", "Voici le journal d’aujourd’hui.")],
        "choice": ("Que signifie 明天 ?", "Choisis le moment indiqué.", [("a", "hier"), ("b", "demain"), ("c", "ce soir")], "b"),
        "order": ("Construis « Nous nous retrouvons demain matin ». ", [("a", "见面"), ("b", "明天上午"), ("c", "我们")], ["c", "b", "a"], ["我们明天上午见面。", "我们明天上午见面"]),
        "fill": ("Complète : 下午我还要上___。", "下午我还要上___。", ["课"]),
        "listen": ("Quel jour est indiqué ?", "星期三。", [("a", "Lundi."), ("b", "Mercredi."), ("c", "Vendredi.")], "b"),
        "speak": ("Dis « À midi, nous déjeunons pendant vingt minutes ». ", "中午我们吃饭二十分钟。", "À midi, nous déjeunons pendant vingt minutes."),
        "readingChoice": ("Que fait la personne le soir ?", [("a", "Elle lit le journal."), ("b", "Elle travaille au restaurant."), ("c", "Elle prend le taxi.")], "a"),
    },
    10: {
        "title": "Partir pour l’aéroport",
        "summary": "Choisir un moyen de transport et situer un départ en cours.",
        "dialogue": [
            ("Mina", "你怎么去机场？", "Comment vas-tu à l’aéroport ?"),
            ("Tao", "我坐出租车，不坐公共汽车。", "Je prends un taxi, pas le bus."),
            ("Mina", "飞机几点走？", "À quelle heure part l’avion ?"),
            ("Tao", "下午三点。船和火车今天都没有。", "À trois heures de l’après-midi. Il n’y a ni bateau ni train aujourd’hui."),
            ("Mina", "你正在买票吗？", "Tu es en train d’acheter le billet ?"),
            ("Tao", "是，我买二号票，然后去旅游。", "Oui, j’achète le billet numéro deux, puis je pars voyager."),
        ],
        "reading": ("Le départ", "下午三点，飞机从机场出发。Tao坐出租车去机场，手里拿着二号票。", "À trois heures, l’avion part de l’aéroport. Tao prend un taxi pour l’aéroport et tient le billet numéro deux.", "他没有坐公共汽车，也没有坐船，因为他正在赶飞机。", "Il n’a pris ni le bus ni le bateau, car il se dépêche pour l’avion."),
        "grammar": [grammar("hsk20-197", "几 + classificateur", "几 demande une petite quantité ou un numéro.", "你买几张票？", "Tu achètes combien de billets ?")],
        "choice": ("Que signifie 机场 ?", "Choisis le lieu du départ.", [("a", "aéroport"), ("b", "restaurant"), ("c", "hôtel")], "a"),
        "order": ("Construis « Je prends un taxi ». ", [("a", "出租车"), ("b", "坐"), ("c", "我")], ["c", "b", "a"], ["我坐出租车。", "我坐出租车"]),
        "fill": ("Complète le document du départ : 我正在买二号___。", "我正在买二号___。", ["票"]),
        "listen": ("À quelle heure part l’avion ?", "下午三点。", [("a", "À midi."), ("b", "À trois heures de l’après-midi."), ("c", "À huit heures du matin.")], "b"),
        "speak": ("Dis « Je prends un taxi pour l’aéroport ». ", "我坐出租车去机场。", "Je prends un taxi pour l’aéroport."),
        "readingChoice": ("Pourquoi Tao ne prend-il pas le bateau ?", [("a", "Parce qu’il n’y en a pas aujourd’hui."), ("b", "Parce qu’il est malade."), ("c", "Parce qu’il a oublié son billet.")], "a"),
    },
    11: {
        "title": "Un appel à Pékin",
        "summary": "Parler de ses goûts et proposer un rendez-vous en chinois.",
        "dialogue": [
            ("Mina", "你爱北京吗？", "Tu aimes Pékin ?"),
            ("Tao", "爱。我想学汉语。", "Oui. Je veux apprendre le chinois."),
            ("Mina", "你有几个杯子？", "Combien de tasses as-tu ?"),
            ("Tao", "我有两个杯子，一个是朋友送的。", "J’ai deux tasses ; l’une vient d’un cadeau d’un ami."),
            ("Mina", "我在后面，你来吗？", "Je suis derrière, tu viens ?"),
            ("Tao", "来，对不起，我马上到。", "Oui, désolé, j’arrive tout de suite."),
        ],
        "reading": ("Le rendez-vous", "我爱北京，也喜欢学汉语。今天我有两个杯子，一个给朋友。", "J’aime Pékin et j’aime aussi apprendre le chinois. Aujourd’hui, j’ai deux tasses, dont une pour un ami.", "朋友在我后面等我。我说对不起，然后马上来。", "Un ami m’attend derrière moi. Je dis désolé, puis j’arrive tout de suite."),
        "grammar": [grammar("hsk20-035", "想/要 + verbe", "想 et 要 se placent avant l’action souhaitée.", "我想学汉语。", "Je veux apprendre le chinois.")],
        "choice": ("Que signifie 学汉语 ?", "Choisis l’action de Tao.", [("a", "acheter des vêtements"), ("b", "apprendre le chinois"), ("c", "prendre l’avion")], "b"),
        "order": ("Construis « Je veux apprendre le chinois ». ", [("a", "学汉语"), ("b", "我想"), ("c", "。")], ["b", "a", "c"], ["我想学汉语。", "我想学汉语"]),
        "fill": ("Complète : 我有两___杯子。", "我有两___杯子。", ["个"]),
        "listen": ("Combien de tasses Tao a-t-il ?", "我有两个杯子。", [("a", "Une."), ("b", "Deux."), ("c", "Huit.")], "b"),
        "speak": ("Dis « Je veux apprendre le chinois ». ", "我想学汉语。", "Je veux apprendre le chinois."),
        "readingChoice": ("Où l’ami attend-il ?", [("a", "Devant la porte."), ("b", "Derrière Tao."), ("c", "À l’aéroport.")], "b"),
    },
    12: {
        "title": "Corriger un exercice",
        "summary": "Demander une explication, comparer des réponses et faire le bilan.",
        "dialogue": [
            ("Mina", "大家有几道题？", "Combien d’exercices avez-vous tous ?"),
            ("Tao", "我们有三道题，但是我不懂第二道。", "Nous en avons trois, mais je ne comprends pas le deuxième."),
            ("Mina", "为什么不懂？", "Pourquoi ne le comprends-tu pas ?"),
            ("Tao", "这道题比第一道难，所以我问你。", "Cet exercice est plus difficile que le premier, alors je te demande."),
            ("Mina", "答案怎么样？", "Comment sont les réponses ?"),
            ("Tao", "现在我懂了，做完我们走吧。", "Maintenant j’ai compris ; quand nous aurons fini, partons."),
        ],
        "reading": ("Le bilan", "大家一起做题。第一道题比较简单，第二道题比第一道难。", "Tout le monde fait les exercices ensemble. Le premier est assez simple ; le deuxième est plus difficile que le premier.", "Tao问为什么，Mina告诉他答案。做完三道题以后，大家都懂了。", "Tao demande pourquoi et Mina lui explique les réponses. Après les trois exercices, tout le monde a compris."),
        "grammar": [grammar("hsk20-156", "会/能 + verbe", "会 ou 能 précède une capacité ou une possibilité.", "现在我能回答这道题。", "Maintenant je peux répondre à cet exercice.")],
        "choice": ("Que signifie 为什么 ?", "Choisis le mot interrogatif correct.", [("a", "pourquoi"), ("b", "combien"), ("c", "comment")], "a"),
        "order": ("Construis « Pourquoi ne comprends-tu pas ? ». ", [("a", "不懂"), ("b", "你"), ("c", "为什么")], ["c", "b", "a"], ["为什么你不懂？", "为什么你不懂"]),
        "fill": ("Complète : 这道题比第一道___。", "这道题比第一道___。", ["难"]),
        "listen": ("Combien d’exercices le groupe fait-il ?", "我们有三道题。", [("a", "Deux."), ("b", "Trois."), ("c", "Dix.")], "b"),
        "speak": ("Dis « Maintenant je comprends ». ", "现在我懂了。", "Maintenant je comprends."),
        "readingChoice": ("Que fait Mina ?", [("a", "Elle explique les réponses."), ("b", "Elle prend un taxi."), ("c", "Elle dort.")], "a"),
    },
    13: {
        "title": "Préparer l’examen",
        "summary": "Lire et écrire dans la classe avant un examen.",
        "dialogue": [
            ("Mina", "你正在读什么？", "Qu’es-tu en train de lire ?"),
            ("Tao", "我正在读课本，准备考试。", "Je lis le manuel et je prépare l’examen."),
            ("Mina", "同学们在哪里写字？", "Où les camarades écrivent-ils ?"),
            ("Tao", "他们在教室写字，也学习新课。", "Ils écrivent dans la classe et étudient aussi la nouvelle leçon."),
            ("Mina", "老师要什么？", "Que veut le professeur ?"),
            ("Tao", "老师要我们读这个字，然后回答问题。", "Le professeur veut que nous lisions ce caractère puis répondions à la question."),
        ],
        "reading": ("Dans la classe", "同学们在教室读书、写字。老师说今天开始新课。", "Les camarades lisent et écrivent dans la classe. Le professeur dit que la nouvelle leçon commence aujourd’hui.", "下午大家学习，明天考试。每个人都要认真回答问题。", "L’après-midi, tout le monde étudie ; l’examen a lieu demain. Chacun doit répondre sérieusement aux questions."),
        "grammar": [grammar("hsk20-129", "正在 + verbe", "正在 indique une action en cours au moment où l’on parle.", "我正在写字。", "Je suis en train d’écrire des caractères." )],
        "choice": ("Que signifie 教室 ?", "Choisis le lieu de la scène.", [("a", "classe"), ("b", "hôpital"), ("c", "gare")], "a"),
        "order": ("Construis « Je suis en train de lire ». ", [("a", "读书"), ("b", "我正在"), ("c", "。")], ["b", "a", "c"], ["我正在读书。", "我正在读书"]),
        "fill": ("Complète : 明天考___。", "明天考___。", ["试"]),
        "listen": ("Que font les camarades ?", "他们在教室写字，也学习新课。", [("a", "Ils cuisinent."), ("b", "Ils écrivent et étudient."), ("c", "Ils voyagent.")], "b"),
        "speak": ("Dis « Je prépare l’examen ». ", "我准备考试。", "Je prépare l’examen."),
        "readingChoice": ("Quand a lieu l’examen ?", [("a", "Aujourd’hui."), ("b", "Demain."), ("c", "La semaine prochaine.")], "b"),
    },
    14: {
        "title": "Le chat dans la maison",
        "summary": "Indiquer où se trouve un animal et raconter ce qui vient de se passer.",
        "dialogue": [
            ("Mina", "你的猫在哪里？", "Où est ton chat ?"),
            ("Tao", "它在房间里，不在门前面。", "Il est dans la chambre, pas devant la porte."),
            ("Mina", "那只猫刚才出来了吗？", "Ce chat est-il sorti tout à l’heure ?"),
            ("Tao", "它出来了，现在在桌子后面。", "Il est sorti ; maintenant il est derrière la table."),
            ("Mina", "你能找到它吗？", "Peux-tu le trouver ?"),
            ("Tao", "能。没关系，我马上把它带回家。", "Oui. Ce n’est pas grave, je le ramène tout de suite à la maison."),
        ],
        "reading": ("Où est le chat ?", "我的猫在房间里。它刚才在门前面，现在到了桌子后面。", "Mon chat est dans la chambre. Il était devant la porte tout à l’heure ; il est maintenant derrière la table.", "我没有找到它，所以请朋友帮忙。朋友说：没关系，它在这里。", "Je ne l’ai pas trouvé, alors je demande de l’aide à un ami. L’ami dit : ce n’est pas grave, il est ici."),
        "grammar": [grammar("hsk20-065", "verbe + 了", "了 placé après le verbe marque ici une action terminée.", "猫出来了。", "Le chat est sorti.")],
        "choice": ("Que signifie 里 ?", "Choisis la position du chat.", [("a", "devant"), ("b", "dans"), ("c", "à droite")], "b"),
        "order": ("Construis « Le chat est dans la chambre ». ", [("a", "猫"), ("b", "房间里"), ("c", "在")], ["a", "c", "b"], ["猫在房间里。", "猫在房间里"]),
        "fill": ("Complète : 它___了。", "它___了。", ["出来"]),
        "listen": ("Où est le chat maintenant ?", "现在在桌子后面。", [("a", "Derrière la table."), ("b", "Dans la rue."), ("c", "Devant la porte.")], "a"),
        "speak": ("Dis « Je peux le trouver ». ", "我能找到它。", "Je peux le trouver."),
        "readingChoice": ("Pourquoi la personne demande-t-elle de l’aide ?", [("a", "Elle n’a pas trouvé le chat."), ("b", "Elle veut acheter un chat."), ("c", "Elle est à l’aéroport.")], "a"),
    },
    15: {
        "title": "À l’hôpital",
        "summary": "Décrire un état de santé et distinguer plusieurs degrés de température.",
        "dialogue": [
            ("Mina", "你的身体怎么样？", "Comment vas-tu ?"),
            ("Tao", "我生病了，今天很冷。", "Je suis malade, il fait très froid aujourd’hui."),
            ("Mina", "医院里热吗？", "Fait-il chaud dans l’hôpital ?"),
            ("Tao", "里面很暖，我觉得好多了。", "Il fait bien chaud à l’intérieur, je me sens beaucoup mieux."),
            ("Mina", "医生给你什么药？", "Quel médicament le médecin te donne-t-il ?"),
            ("Tao", "给我药。我希望很快好起来。", "Il me donne un médicament. J’espère aller mieux rapidement."),
        ],
        "reading": ("Une visite à l’hôpital", "Tao生病了，身体不舒服，所以去医院看医生。", "Tao est malade et ne se sent pas bien, alors il va à l’hôpital voir le médecin.", "外面很冷，医院里面很热。医生给他药，他希望明天好起来。", "Il fait froid dehors et chaud dans l’hôpital. Le médecin lui donne un médicament ; il espère aller mieux demain."),
        "grammar": [grammar("hsk20-240", "verbe + 过", "过 indique une expérience passée.", "我去过医院。", "Je suis déjà allé à l’hôpital.")],
        "choice": ("Que signifie 生病 ?", "Choisis l’état de santé.", [("a", "être malade"), ("b", "être grand"), ("c", "être rapide")], "a"),
        "order": ("Construis « Je suis allé à l’hôpital ». ", [("a", "医院"), ("b", "我去过"), ("c", "。")], ["b", "a", "c"], ["我去过医院。", "我去过医院"]),
        "fill": ("Complète : 医生给我___。", "医生给我___。", ["药"]),
        "listen": ("Comment Tao se sent-il ?", "我生病了，今天很冷。", [("a", "Il est malade."), ("b", "Il est très heureux."), ("c", "Il est en retard.")], "a"),
        "speak": ("Dis « Je suis allé à l’hôpital ». ", "我去过医院。", "Je suis allé à l’hôpital."),
        "readingChoice": ("Pourquoi Tao va-t-il à l’hôpital ?", [("a", "Parce qu’il prépare un examen."), ("b", "Parce qu’il est malade."), ("c", "Parce qu’il achète un billet.")], "b"),
    },
    16: {
        "title": "Clarifier une question",
        "summary": "Demander le sens d’une phrase et comparer deux informations.",
        "dialogue": [
            ("Mina", "请问，这个问题是什么意思？", "Excusez-moi, que signifie cette question ?"),
            ("Tao", "请你再说一遍，我听不清楚。", "Répétez, s’il vous plaît, je n’entends pas clairement."),
            ("Mina", "这句话比较长，那句话比较短。", "Cette phrase est plus longue, cette autre est plus courte."),
            ("Tao", "我认识那个姓李的男人。", "Je connais l’homme qui s’appelle Li."),
            ("Mina", "他是你的丈夫吗？", "Est-ce ton mari ?"),
            ("Tao", "不是，他是朋友。请坐在我旁边。", "Non, c’est un ami. Asseyez-vous à côté de moi."),
        ],
        "reading": ("Une précision", "学生请老师解释问题的意思。老师把长句子写在黑板上。", "L’étudiant demande au professeur d’expliquer le sens de la question. Le professeur écrit la longue phrase au tableau.", "短句子在上面，学生在旁边听。后来他认识了那个姓李的人。", "La phrase courte est au-dessus et l’étudiant écoute à côté. Plus tard, il fait connaissance avec la personne appelée Li."),
        "grammar": [grammar("hsk20-259", "比较 + adjectif", "比较 se place avant un adjectif pour atténuer la description : la phrase est assez longue.", "这句话比较长。", "Cette phrase est assez longue.")],
        "choice": ("Que signifie 意思 ?", "Choisis le mot correct.", [("a", "sens"), ("b", "nom"), ("c", "mari")], "a"),
        "order": ("Construis « Cette phrase est plus longue ». ", [("a", "长"), ("b", "这句话"), ("c", "比较")], ["b", "c", "a"], ["这句话比较长。", "这句话比较长"]),
        "fill": ("Complète : 请你再说一___。", "请你再说一___。", ["遍"]),
        "listen": ("Que demande la personne ?", "这个问题是什么意思？", [("a", "Elle demande le sens de la question."), ("b", "Elle demande le prix du billet."), ("c", "Elle demande où est l’hôpital.")], "a"),
        "speak": ("Dis « Cette phrase est plus longue ». ", "这句话比较长。", "Cette phrase est plus longue."),
        "readingChoice": ("Que fait le professeur ?", [("a", "Il écrit la phrase au tableau."), ("b", "Il prend le train."), ("c", "Il achète un médicament.")], "a"),
    },
    17: {
        "title": "Un message du soir",
        "summary": "Parler d’une journée, demander qui parle et expliquer une conséquence.",
        "dialogue": [
            ("Mina", "喂，谁在说话？", "Allô, qui parle ?"),
            ("Tao", "是我。你今天喝水了吗？", "C’est moi. As-tu bu de l’eau aujourd’hui ?"),
            ("Mina", "我喝了十杯水，但是现在想睡觉。", "J’ai bu dix verres d’eau, mais maintenant je veux dormir."),
            ("Tao", "因为你太累，所以想睡觉。", "Comme tu es trop fatiguée, tu veux dormir."),
            ("Mina", "他也在听吗？", "Est-ce qu’il écoute aussi ?"),
            ("Tao", "他在。他四岁，正在听我们说话。", "Oui, il est là. Il a quatre ans et nous écoute parler."),
        ],
        "reading": ("Le coup de fil", "晚上我给朋友打电话。她喝了十杯水，还是觉得累。", "Le soir, j’appelle une amie. Elle a bu dix verres d’eau mais se sent toujours fatiguée.", "因为她今天工作太多，所以她要睡觉。她的孩子也在听电话。", "Comme elle a beaucoup travaillé aujourd’hui, elle doit dormir. Son enfant écoute aussi l’appel."),
        "grammar": [grammar("hsk20-109", "因为…所以…", "因为 présente la cause et 所以 la conséquence.", "因为下雨，所以我在家。", "Comme il pleut, je suis à la maison.")],
        "choice": ("Que signifie 睡觉 ?", "Choisis l’action du soir.", [("a", "dormir"), ("b", "écouter"), ("c", "répondre")], "a"),
        "order": ("Construis « Je veux dormir ». ", [("a", "睡觉"), ("b", "我想"), ("c", "。")], ["b", "a", "c"], ["我想睡觉。", "我想睡觉"]),
        "fill": ("Complète : 因为你太累，___想睡觉。", "因为你太累，___想睡觉。", ["所以"]),
        "listen": ("Combien de verres d’eau Mina a-t-elle bus ?", "我喝了十杯水。", [("a", "Quatre."), ("b", "Dix."), ("c", "Vingt.")], "b"),
        "speak": ("Dis « Comme tu es fatiguée, tu veux dormir ». ", "因为你太累，所以想睡觉。", "Comme tu es fatiguée, tu veux dormir."),
        "readingChoice": ("Pourquoi l’amie veut-elle dormir ?", [("a", "Elle a trop travaillé."), ("b", "Elle a raté l’avion."), ("c", "Elle a acheté une voiture.")], "a"),
    },
    18: {
        "title": "La pluie au bureau",
        "summary": "Décrire un trajet professionnel et réagir à la pluie.",
        "dialogue": [
            ("Mina", "喂，你在公司吗？", "Allô, tu es à l’entreprise ?"),
            ("Tao", "我在上班，从家到公司要半小时。", "Je suis au travail ; de la maison à l’entreprise, il faut une demi-heure."),
            ("Mina", "外面下雨，你怎么来？", "Il pleut dehors, comment es-tu venu ?"),
            ("Tao", "我坐车来的。先生，你喜欢下雨吗？", "Je suis venu en voiture. Monsieur, aimez-vous la pluie ?"),
            ("Mina", "我不喜欢，但是我们有工作。", "Je n’aime pas ça, mais nous avons du travail."),
            ("Tao", "没关系，我们五点一起回家。", "Ce n’est pas grave, nous rentrerons ensemble à cinq heures."),
        ],
        "reading": ("Le trajet", "Tao从家到公司上班，路上开始下雨。他坐车，没有迟到。", "Tao va de la maison à l’entreprise pour travailler ; il commence à pleuvoir en route. Il prend une voiture et n’est pas en retard.", "下午五点，他和同事一起回家。虽然下雨，但是大家都喜欢今天的工作。", "À cinq heures, il rentre avec ses collègues. Même s’il pleut, tout le monde aime le travail d’aujourd’hui."),
        "grammar": [grammar("hsk20-033", "从 A 到 B", "从 et 到 encadrent le départ et l’arrivée d’un trajet.", "从家到公司要半小时。", "De la maison à l’entreprise, il faut une demi-heure.")],
        "choice": ("Que signifie 上班 ?", "Choisis l’activité de Tao.", [("a", "aller travailler"), ("b", "faire du sport"), ("c", "lire le journal")], "a"),
        "order": ("Construis « De la maison à l’entreprise ». ", [("a", "公司"), ("b", "到"), ("c", "从家")], ["c", "b", "a"], ["从家到公司。", "从家到公司"]),
        "fill": ("Complète : 外面下___。", "外面下___。", ["雨"]),
        "listen": ("Combien de temps dure le trajet ?", "从家到公司要半小时。", [("a", "Un quart d’heure."), ("b", "Une demi-heure."), ("c", "Deux heures.")], "b"),
        "speak": ("Dis « Nous rentrerons ensemble à cinq heures ». ", "我们五点一起回家。", "Nous rentrerons ensemble à cinq heures."),
        "readingChoice": ("Comment Tao se rend-il au travail ?", [("a", "En voiture."), ("b", "À pied."), ("c", "En avion.")], "a"),
    },
    19: {
        "title": "Préparer un anniversaire",
        "summary": "Organiser une journée d’anniversaire et enchaîner les actions.",
        "dialogue": [
            ("Mina", "去年你的生日怎么样？", "Comment était ton anniversaire l’an dernier ?"),
            ("Tao", "很好。今年我的生日在星期六。", "Très bien. Cette année, mon anniversaire est samedi."),
            ("Mina", "早上你先做什么？", "Que fais-tu d’abord le matin ?"),
            ("Tao", "我先去医院看爷爷，然后回家。", "Je vais d’abord à l’hôpital voir mon grand-père, puis je rentre."),
            ("Mina", "晚上有几个小时的时间？", "Combien d’heures avons-nous le soir ?"),
            ("Tao", "有三个小时，我们一起吃饭。", "Nous avons trois heures ; nous dînerons ensemble."),
        ],
        "reading": ("Le jour spécial", "去年生日的时候，我先和家人吃饭，然后看电影。", "Lors de mon anniversaire l’an dernier, j’ai d’abord mangé avec ma famille, puis j’ai regardé un film.", "今年早上我要去医院看爷爷，晚上有三个小时和朋友在一起。", "Cette année, je vais voir mon grand-père à l’hôpital le matin et j’aurai trois heures avec mes amis le soir."),
        "grammar": [grammar("hsk20-243", "先…然后…", "先 présente la première action et 然后 la suivante.", "我先吃饭，然后看电影。", "Je mange d’abord, puis je regarde un film.")],
        "choice": ("Que signifie 生日 ?", "Choisis l’événement préparé.", [("a", "anniversaire"), ("b", "examen"), ("c", "réunion")], "a"),
        "order": ("Construis « Je rentre à la maison après ». ", [("a", "回家"), ("b", "然后"), ("c", "我")], ["b", "c", "a"], ["然后我回家。", "然后我回家"]),
        "fill": ("Complète : 今年我的生日在星期___。", "今年我的生日在星期___。", ["六"]),
        "listen": ("Que fait Tao d’abord ?", "我先去医院看爷爷。", [("a", "Il va à l’hôpital."), ("b", "Il va au restaurant."), ("c", "Il va à l’école.")], "a"),
        "speak": ("Dis « Je mange d’abord, puis je regarde un film ». ", "我先吃饭，然后看电影。", "Je mange d’abord, puis je regarde un film."),
        "readingChoice": ("Avec qui la personne passe-t-elle la soirée cette année ?", [("a", "Avec ses voisins."), ("b", "Avec ses amis."), ("c", "Avec son professeur.")], "b"),
    },
    20: {
        "title": "Une matinée chargée",
        "summary": "Décrire une visite à l’hôpital et deux actions réalisées en même temps.",
        "dialogue": [
            ("Mina", "你今天忙吗？", "Es-tu occupé aujourd’hui ?"),
            ("Tao", "很忙，也很累。我住在医院附近。", "Très occupé et très fatigué. J’habite près de l’hôpital."),
            ("Mina", "你什么时候去医院？", "Quand vas-tu à l’hôpital ?"),
            ("Tao", "我一边走路一边给医生打电话。", "Je marche tout en appelant le médecin."),
            ("Mina", "医院里有几个房间？", "Combien de pièces y a-t-il dans l’hôpital ?"),
            ("Tao", "有几个房间，白色的门在前面。", "Il y a plusieurs pièces ; la porte blanche est devant."),
        ],
        "reading": ("Près de l’hôpital", "我住在医院附近，今天很忙，所以早上就出门。", "J’habite près de l’hôpital. Comme je suis très occupé aujourd’hui, je sors dès le matin.", "我一边走路一边听医生说话。医院里有几个房间，白色的门在前面。", "Je marche tout en écoutant le médecin parler. L’hôpital a plusieurs pièces ; sa porte blanche est devant."),
        "grammar": [grammar("hsk20-134", "一边…一边…", "一边 relie deux actions simultanées.", "我一边走路一边听音乐。", "J’écoute de la musique tout en marchant.")],
        "choice": ("Que signifie 附近 ?", "Choisis la relation de lieu.", [("a", "près de"), ("b", "derrière"), ("c", "loin de")], "a"),
        "order": ("Construis « Je marche tout en téléphonant ». ", [("a", "打电话"), ("b", "我一边走路一边"), ("c", "。")], ["b", "a", "c"], ["我一边走路一边打电话。", "我一边走路一边打电话"]),
        "fill": ("Complète : 医院里有几个___间。", "医院里有几个___间。", ["房"]),
        "listen": ("Que trouve-t-on dans l’hôpital ?", "医院里有几个房间。", [("a", "Plusieurs pièces."), ("b", "Cent étages."), ("c", "Deux voitures.")], "a"),
        "speak": ("Dis « J’habite près de l’hôpital ». ", "我住在医院附近。", "J’habite près de l’hôpital."),
        "readingChoice": ("De quelle couleur est la porte ?", [("a", "Noire."), ("b", "Blanche."), ("c", "Rouge.")], "b"),
    },
    21: {
        "title": "Le sport du week-end",
        "summary": "Choisir une activité sportive et décrire la météo du parc.",
        "dialogue": [
            ("Mina", "周末你想做什么运动？", "Quel sport veux-tu faire ce week-end ?"),
            ("Tao", "我想跑步，也想打篮球。", "Je veux courir et jouer aussi au basket."),
            ("Mina", "你会踢足球吗？", "Tu sais jouer au football ?"),
            ("Tao", "会，但是今天要下雨。", "Oui, mais il va pleuvoir aujourd’hui."),
            ("Mina", "那我们在家唱歌、跳舞吧。", "Alors chantons et dansons à la maison."),
            ("Tao", "好，明天天气好再去游泳。", "D’accord, nous irons nager demain s’il fait beau."),
        ],
        "reading": ("Au parc", "周末天气很好，我坐在公园里看朋友跑步。", "Le temps est beau ce week-end ; je suis assis dans le parc et je regarde mon ami courir.", "下午我们打篮球、踢足球。下雨以后，我们回家唱歌和跳舞。", "L’après-midi, nous jouons au basket et au football. Après la pluie, nous rentrons chanter et danser."),
        "grammar": [grammar("hsk20-286", "把 + objet + verbe", "把 place l’objet avant l’action et son résultat.", "我把球放在桌子上。", "Je pose le ballon sur la table.")],
        "choice": ("Que signifie 游泳 ?", "Choisis l’activité de demain.", [("a", "nager"), ("b", "chanter"), ("c", "courir")], "a"),
        "order": ("Construis « Je joue au basket ». ", [("a", "打篮球"), ("b", "我"), ("c", "。")], ["b", "a", "c"], ["我打篮球。", "我打篮球"]),
        "fill": ("Complète : 今天要下___。", "今天要下___。", ["雨"]),
        "listen": ("Quel sport Tao veut-il faire ?", "我想跑步，也想打篮球。", [("a", "Nager."), ("b", "Courir et jouer au basket."), ("c", "Danser seulement.")], "b"),
        "speak": ("Dis « Nous irons nager demain ». ", "明天去游泳。", "Nous irons nager demain."),
        "readingChoice": ("Que font-ils après la pluie ?", [("a", "Ils rentrent chanter et danser."), ("b", "Ils prennent l’avion."), ("c", "Ils vont au restaurant.")], "a"),
    },
    22: {
        "title": "Le devoir difficile",
        "summary": "Demander de l’aide pour un devoir et corriger une erreur.",
        "dialogue": [
            ("Mina", "你需要帮助吗？", "As-tu besoin d’aide ?"),
            ("Tao", "需要。这个题太难，我做错了。", "Oui. Cet exercice est trop difficile, je me suis trompé."),
            ("Mina", "别着急，先看第一句话。", "Ne te dépêche pas, regarde d’abord la première phrase."),
            ("Tao", "我不懂，但是我可以再做一次。", "Je ne comprends pas, mais je peux le refaire."),
            ("Mina", "你等我，我告诉你办法。", "Attends-moi, je vais te dire comment faire."),
            ("Tao", "谢谢！我懂了，也能帮助同学。", "Merci ! J’ai compris et je peux aider un camarade."),
        ],
        "reading": ("Corriger", "学生做题的时候发现一个错误。老师让他先读第一句话。", "En faisant l’exercice, l’étudiant découvre une erreur. Le professeur lui demande de lire d’abord la première phrase.", "他等老师解释，然后再做一次。最后他懂了，可以帮助同学。", "Il attend l’explication du professeur puis recommence. Enfin, il comprend et peut aider son camarade."),
        "grammar": [grammar("hsk20-159", "被 + agent", "被 introduit ce qui subit l’action.", "这个错误被老师发现了。", "Cette erreur a été découverte par le professeur.")],
        "choice": ("Que signifie 帮助 ?", "Choisis l’action proposée.", [("a", "aider"), ("b", "attendre"), ("c", "sortir")], "a"),
        "order": ("Construis « Je peux refaire l’exercice ». ", [("a", "再做一次"), ("b", "我可以"), ("c", "。")], ["b", "a", "c"], ["我可以再做一次。", "我可以再做一次"]),
        "fill": ("Complète : 这个题太___。", "这个题太___。", ["难"]),
        "listen": ("Que doit faire Tao en premier ?", "先看第一句话。", [("a", "Regarder la première phrase."), ("b", "Aller au restaurant."), ("c", "Téléphoner à un médecin.")], "a"),
        "speak": ("Dis « Ne te dépêche pas ». ", "别着急。", "Ne te dépêche pas."),
        "readingChoice": ("Qui explique le problème ?", [("a", "Le professeur."), ("b", "Le serveur."), ("c", "Le voisin.")], "a"),
    },
    23: {
        "title": "Une invitation chaleureuse",
        "summary": "Accueillir un invité, décrire un repas et exprimer une concession.",
        "dialogue": [
            ("Mina", "欢迎你来我家！", "Bienvenue chez moi !"),
            ("Tao", "谢谢。这个菜好吃吗？", "Merci. Ce plat est-il bon ?"),
            ("Mina", "非常好吃，但是有一点辣。", "Il est très bon, mais un peu épicé."),
            ("Tao", "我吃了两公斤？", "J’en ai mangé deux kilos ?"),
            ("Mina", "不，只有一点。你给客人红茶吧。", "Non, seulement un peu. Donne plutôt du thé rouge à l’invité."),
            ("Tao", "好，我告诉他黑色的杯子在哪里。", "D’accord, je lui dis où est la tasse noire."),
        ],
        "reading": ("Chez un ami", "朋友欢迎客人到家里，桌子上有好吃的菜和红茶。", "Un ami accueille un invité chez lui ; il y a de bons plats et du thé rouge sur la table.", "菜非常好吃，但是客人只吃了一点。他用黑色的杯子喝茶。", "Les plats sont très bons, mais l’invité n’en mange qu’un peu. Il boit le thé dans une tasse noire."),
        "grammar": [grammar("hsk20-188", "虽然…但是…", "虽然 introduit une concession suivie de 但是.", "虽然很累，但是我欢迎客人。", "Même si je suis fatigué, j’accueille l’invité.")],
        "choice": ("Que signifie 欢迎 ?", "Choisis la formule d’accueil.", [("a", "bienvenue"), ("b", "au revoir"), ("c", "attention")], "a"),
        "order": ("Construis « Le plat est très bon ». ", [("a", "好吃"), ("b", "这个菜"), ("c", "非常")], ["b", "c", "a"], ["这个菜非常好吃。", "这个菜非常好吃"]),
        "fill": ("Complète : 这个菜非常___吃。", "这个菜非常___吃。", ["好"]),
        "listen": ("Quelle boisson Tao doit-il donner ?", "你给客人红茶吧。", [("a", "Du lait."), ("b", "Du thé rouge."), ("c", "Du café.")], "b"),
        "speak": ("Dis « Le plat est très bon, mais un peu épicé ». ", "非常好吃，但是有一点辣。", "Le plat est très bon, mais un peu épicé."),
        "readingChoice": ("Dans quoi l’invité boit-il le thé ?", [("a", "Une tasse noire."), ("b", "Un verre blanc."), ("c", "Une bouteille rouge.")], "a"),
    },
    24: {
        "title": "Entrer chez le médecin",
        "summary": "Répondre au médecin et décider quoi faire selon son état.",
        "dialogue": [
            ("Mina", "你还不舒服吗？", "Tu ne te sens toujours pas bien ?"),
            ("Tao", "是。我回答医生的问题以后才能进来。", "Oui. Je peux entrer seulement après avoir répondu aux questions du médecin."),
            ("Mina", "你觉得哪里不舒服？", "Où te sens-tu mal ?"),
            ("Tao", "我觉得头很热，但是医院很近。", "J’ai la tête très chaude, mais l’hôpital est proche."),
            ("Mina", "如果你能走，就现在进去。", "Si tu peux marcher, entre maintenant."),
            ("Tao", "可以，谢谢你介绍这位医生。", "D’accord, merci de m’avoir présenté ce médecin."),
        ],
        "reading": ("Le rendez-vous", "Tao觉得身体不舒服，先回答医生的问题，然后进入医院。", "Tao ne se sent pas bien ; il répond d’abord aux questions du médecin, puis entre dans l’hôpital.", "医院离家很近。如果他可以走路，就不用坐车。", "L’hôpital est très près de chez lui. S’il peut marcher, il n’a pas besoin de prendre une voiture."),
        "grammar": [grammar("hsk20-210", "如果…就…", "如果 pose une condition et 就 présente sa conséquence.", "如果可以，就现在进去。", "Si c’est possible, entre maintenant.")],
        "choice": ("Que signifie 回答 ?", "Choisis l’action de Tao.", [("a", "répondre"), ("b", "préparer"), ("c", "vendre")], "a"),
        "order": ("Construis « L’hôpital est proche ». ", [("a", "很近"), ("b", "医院"), ("c", "。")], ["b", "a", "c"], ["医院很近。", "医院很近"]),
        "fill": ("Complète : 如果你能走，___现在进去。", "如果你能走，___现在进去。", ["就"]),
        "listen": ("Que doit faire Tao avant d’entrer ?", "先回答医生的问题。", [("a", "Répondre aux questions du médecin."), ("b", "Acheter un cadeau."), ("c", "Lire le journal.")], "a"),
        "speak": ("Dis « Si tu peux marcher, entre maintenant ». ", "如果你能走，就现在进去。", "Si tu peux marcher, entre maintenant."),
        "readingChoice": ("Pourquoi Tao n’a-t-il pas besoin de voiture ?", [("a", "L’hôpital est proche."), ("b", "Il pleut beaucoup."), ("c", "Il est en retard.")], "a"),
    },
    25: {
        "title": "Choisir une veste",
        "summary": "Comparer des vêtements, demander un prix et trouver une taille.",
        "dialogue": [
            ("Mina", "这件衣服多少钱？", "Combien coûte ce vêtement ?"),
            ("Tao", "三百元，但是那件比较便宜。", "Trois cents yuans, mais celui-là est moins cher."),
            ("Mina", "这件很贵，我不买。", "Celui-ci est très cher, je ne l’achète pas."),
            ("Tao", "你穿什么颜色？", "Quelle couleur portes-tu ?"),
            ("Mina", "我穿红衣服。请找两件小的。", "Je porte des vêtements rouges. Cherche deux petites tailles, s’il te plaît."),
            ("Tao", "好，离门近的衣服都在这里。", "D’accord, les vêtements près de la porte sont tous ici."),
        ],
        "reading": ("Au magasin", "商店里有两件衣服：红的很贵，白的比较便宜。", "Dans le magasin, il y a deux vêtements : le rouge est cher et le blanc est moins cher.", "顾客找小的衣服，最后买了两件，一共三百元。", "Le client cherche de petits vêtements et en achète finalement deux, pour trois cents yuans au total."),
        "grammar": [grammar("hsk20-157", "越来越 + adjectif", "越来越 décrit une évolution progressive.", "天气越来越冷。", "Il fait de plus en plus froid.")],
        "choice": ("Que signifie 便宜 ?", "Choisis le prix le plus bas.", [("a", "cher"), ("b", "bon marché"), ("c", "nouveau")], "b"),
        "order": ("Construis « Ce vêtement est cher ». ", [("a", "贵"), ("b", "这件衣服"), ("c", "很")], ["b", "c", "a"], ["这件衣服很贵。", "这件衣服很贵"]),
        "fill": ("Complète : 一共三百___。", "一共三百___。", ["元"]),
        "listen": ("Quel vêtement est moins cher ?", "白的比较便宜。", [("a", "Le rouge."), ("b", "Le blanc."), ("c", "Le noir.")], "b"),
        "speak": ("Dis « Je ne l’achète pas, elle est très chère ». ", "太贵了，我不买。", "Je ne l’achète pas, elle est très chère."),
        "readingChoice": ("Combien de chemises le client achète-t-il ?", [("a", "Une."), ("b", "Deux."), ("c", "Trois.")], "b"),
    },
    26: {
        "title": "Demander son chemin",
        "summary": "Demander poliment une direction et situer les lieux autour de soi.",
        "dialogue": [
            ("Mina", "您好，请问去车站的路怎么走？", "Bonjour, excusez-moi, comment va-t-on à la gare ?"),
            ("Tao", "您先走这条路，每天都有车。", "Prenez d’abord cette route ; il y a des véhicules chaque jour."),
            ("Mina", "车站在商店旁边吗？", "La gare est-elle à côté du magasin ?"),
            ("Tao", "不，在学校旁边，离这里不远。", "Non, elle est à côté de l’école, pas loin d’ici."),
            ("Mina", "我什么时候可以到？", "Quand puis-je arriver ?"),
            ("Tao", "走十分钟就到。请让孩子先过。", "Vous y serez en dix minutes. Laissez d’abord passer les enfants."),
        ],
        "reading": ("Une direction", "客人问去车站的路。车站在学校旁边，离商店不远。", "Un visiteur demande le chemin de la gare. La gare est à côté de l’école, pas loin du magasin.", "他走十分钟就到。路上有很多孩子，所以他让孩子先过。", "Il y arrive en dix minutes. Il y a beaucoup d’enfants sur la route, alors il les laisse passer d’abord."),
        "grammar": [grammar("hsk20-218", "在 + lieu", "在 place le lieu après le sujet ou le lieu recherché.", "车站在学校旁边。", "La gare est à côté de l’école.")],
        "choice": ("Que signifie 旁边 ?", "Choisis la position indiquée.", [("a", "à côté"), ("b", "en haut"), ("c", "à l’intérieur")], "a"),
        "order": ("Construis « La gare est à côté de l’école ». ", [("a", "学校旁边"), ("b", "车站"), ("c", "在")], ["b", "c", "a"], ["车站在学校旁边。", "车站在学校旁边"]),
        "fill": ("Complète : 走十分钟就___。", "走十分钟就___。", ["到"]),
        "listen": ("Combien de temps faut-il marcher ?", "走十分钟就到。", [("a", "Cinq minutes."), ("b", "Dix minutes."), ("c", "Une heure.")], "b"),
        "speak": ("Dis « La gare n’est pas loin d’ici ». ", "车站离这里不远。", "La gare n’est pas loin d’ici."),
        "readingChoice": ("Pourquoi le visiteur laisse-t-il passer les enfants ?", [("a", "Il y a beaucoup d’enfants sur la route."), ("b", "Il est malade."), ("c", "Le magasin est fermé.")], "a"),
    },
    27: {
        "title": "Le repas livré",
        "summary": "Commander un repas, demander une adresse et vérifier la livraison.",
        "dialogue": [
            ("Mina", "你可以送饭到外面吗？", "Peux-tu livrer le repas dehors ?"),
            ("Tao", "可以，请问你要什么？", "Oui, que veux-tu ?"),
            ("Mina", "我要新菜，还希望有水果。", "Je veux un nouveau plat et j’espère qu’il y aura des fruits."),
            ("Tao", "请告诉我地址，我马上送。", "Dis-moi l’adresse, je livre tout de suite."),
            ("Mina", "地址在学校左边。洗手间在里面。", "L’adresse est à gauche de l’école. Les toilettes sont à l’intérieur."),
            ("Tao", "好，事情做完以后我们笑一笑。", "D’accord, après cette tâche nous sourirons un peu."),
        ],
        "reading": ("La livraison", "餐馆准备了新菜和水果。服务员问客人的地址，然后把饭送到外面。", "Le restaurant prépare un nouveau plat et des fruits. Le serveur demande l’adresse du client puis livre le repas dehors.", "地址在学校左边。客人洗手以后开始吃饭，大家都笑了。", "L’adresse est à gauche de l’école. Après s’être lavé les mains, le client commence à manger et tout le monde sourit."),
        "grammar": [grammar("hsk20-261", "也 + verbe", "也 place une information supplémentaire avant le verbe.", "我也希望有水果。", "J’espère aussi qu’il y aura des fruits.")],
        "choice": ("Que signifie 送 ?", "Choisis l’action du serveur.", [("a", "livrer"), ("b", "dormir"), ("c", "comparer")], "a"),
        "order": ("Construis « Je veux un nouveau plat ». ", [("a", "新菜"), ("b", "我要"), ("c", "。")], ["b", "a", "c"], ["我要新菜。", "我要新菜"]),
        "fill": ("Complète : 请告诉我___址。", "请告诉我___址。", ["地"]),
        "listen": ("Où se trouve l’adresse ?", "地址在学校左边。", [("a", "À droite de l’école."), ("b", "À gauche de l’école."), ("c", "Derrière l’hôpital.")], "b"),
        "speak": ("Dis « Je veux aussi des fruits ». ", "我也希望有水果。", "Je veux aussi des fruits."),
        "readingChoice": ("Que fait le client avant de manger ?", [("a", "Il se lave les mains."), ("b", "Il prend le train."), ("c", "Il téléphone au médecin.")], "a"),
    },
    28: {
        "title": "Essayer une tenue",
        "summary": "Décrire une tenue, demander plusieurs pièces et choisir ensemble.",
        "dialogue": [
            ("Mina", "这家商店有新衣服吗？", "Ce magasin a-t-il de nouveaux vêtements ?"),
            ("Tao", "有。你喜欢什么颜色？", "Oui. Quelle couleur aimes-tu ?"),
            ("Mina", "我想买红色的，但是眼睛有点累。", "Je veux acheter le rouge, mais mes yeux sont un peu fatigués."),
            ("Tao", "我们一起休息一下，再看。", "Reposons-nous un peu ensemble, puis regardons."),
            ("Mina", "那件在右边，已经准备好了吗？", "Celui de droite est-il déjà prêt ?"),
            ("Tao", "准备好了。真的很漂亮，商店也不远。", "Oui. Il est vraiment joli et le magasin n’est pas loin."),
        ],
        "reading": ("Une pause", "顾客和朋友一起看衣服。红色的衣服在右边，新的衣服已经准备好。", "Le client et son ami regardent des vêtements ensemble. Les vêtements rouges sont à droite et les nouveaux sont déjà prêts.", "顾客眼睛累了，所以他们先休息，再看衣服。她觉得衣服真的很漂亮。", "Le client a les yeux fatigués, alors ils se reposent puis regardent les vêtements. Elle trouve le vêtement vraiment joli."),
        "grammar": [grammar("hsk20-277", "有 + nom", "有 exprime ici la présence d’un objet dans un magasin.", "这家商店有新衣服。", "Ce magasin a de nouveaux vêtements.")],
        "choice": ("Que signifie 颜色 ?", "Choisis ce que l’on demande.", [("a", "couleur"), ("b", "prix"), ("c", "taille")], "a"),
        "order": ("Construis « Nous regardons ensemble ». ", [("a", "看"), ("b", "我们一起"), ("c", "。")], ["b", "a", "c"], ["我们一起看。", "我们一起看"]),
        "fill": ("Complète : 我们先___息一下。", "我们先___息一下。", ["休"]),
        "listen": ("Où sont les vêtements rouges ?", "红色的衣服在右边。", [("a", "À gauche."), ("b", "À droite."), ("c", "Au centre.")], "b"),
        "speak": ("Dis « Les nouveaux vêtements sont déjà prêts ». ", "新的衣服已经准备好。", "Les nouveaux vêtements sont déjà prêts."),
        "readingChoice": ("Pourquoi se reposent-ils ?", [("a", "Les yeux de la cliente sont fatigués."), ("b", "Le magasin est fermé."), ("c", "Il neige.")], "a"),
    },
    29: {
        "title": "Traverser la ville",
        "summary": "Préparer un trajet selon la météo et choisir la meilleure direction.",
        "dialogue": [
            ("Mina", "今天是晴天还是阴天？", "Aujourd’hui, le ciel est-il dégagé ou couvert ?"),
            ("Tao", "早上是晴天，下午可能下雪。", "Le matin, le ciel est dégagé, mais il pourrait neiger l’après-midi."),
            ("Mina", "我准备去城市左边的公园。", "Je me prépare à aller au parc à gauche de la ville."),
            ("Tao", "因为天气会变，所以我们先回家。", "Comme le temps va changer, rentrons d’abord à la maison."),
            ("Mina", "那只狗是谁的？", "À qui est ce chien ?"),
            ("Tao", "不知道。最重要的是先走左边。", "Je ne sais pas. Le plus important est de prendre d’abord à gauche."),
        ],
        "reading": ("La météo en ville", "早上是晴天，下午的天气可能变成阴天或下雪。", "Le matin, le ciel est dégagé ; l’après-midi, le temps pourrait devenir couvert ou neigeux.", "我们准备去左边的公园。因为天气不好，所以先回家，晚上再出门。", "Nous nous préparons à aller au parc à gauche. Comme le temps est mauvais, nous rentrons d’abord à la maison et ressortons le soir."),
        "grammar": [grammar("hsk20-295", "这/那 + nom", "这 désigne un élément proche et 那 un élément plus éloigné.", "那只狗在公园里。", "Ce chien-là est dans le parc.")],
        "choice": ("Que signifie 晴 ?", "Choisis le temps du matin.", [("a", "dégagé"), ("b", "neigeux"), ("c", "venteux")], "a"),
        "order": ("Construis « Le temps va changer ». ", [("a", "会变化"), ("b", "天气"), ("c", "。")], ["b", "a", "c"], ["天气会变化。", "天气会变化"]),
        "fill": ("Complète : 下午可能下___。", "下午可能下___。", ["雪"]),
        "listen": ("Pourquoi Tao conseille-t-il de prendre un parapluie ?", "因为天气会变，所以带伞。", [("a", "Parce que le temps va changer."), ("b", "Parce qu’il fait très chaud."), ("c", "Parce que le parc est fermé.")], "a"),
        "speak": ("Dis « Je me prépare à aller au parc ». ", "我准备去公园。", "Je me prépare à aller au parc."),
        "readingChoice": ("Où se trouve le parc ?", [("a", "À droite de la ville."), ("b", "À gauche de la ville."), ("c", "Derrière l’hôpital.")], "b"),
    },
    30: {
        "title": "Bilan : parler du quotidien",
        "summary": "Réviser les situations de la maison, de la famille, des études et des déplacements.",
        "dialogue": [
            ("Mina", "今天我们复习什么？", "Que révisons-nous aujourd’hui ?"),
            ("Tao", "我们复习在家、吃饭和去学校。", "Nous révisons la maison, les repas et l’école."),
            ("Mina", "你能说说昨天的安排吗？", "Peux-tu parler du programme d’hier ?"),
            ("Tao", "我先去饭馆，然后去了学校。", "Je suis d’abord allé au restaurant, puis à l’école."),
            ("Mina", "为什么你回家很晚？", "Pourquoi es-tu rentré tard ?"),
            ("Tao", "因为下雨，所以我坐出租车。现在我懂了。", "Comme il pleuvait, j’ai pris un taxi. Maintenant j’ai compris."),
        ],
        "reading": ("Le parcours", "前三十天，我们在家、学校和商店练习说话。", "Pendant les trente premiers jours, nous avons pratiqué la conversation à la maison, à l’école et au magasin.", "昨天我先吃饭，然后坐出租车回家。因为下雨，所以回家很晚，但是我很高兴。", "Hier, j’ai d’abord mangé puis pris un taxi pour rentrer. Comme il pleuvait, je suis rentré tard, mais je suis content."),
        "grammar": [
            grammar("hsk20-211", "因为…所以…", "因为 présente la cause et 所以 la conséquence.", "因为下雨，所以我坐出租车。", "Comme il pleut, je prends un taxi."),
            grammar("hsk20-274", "先…然后…", "先 et 然后 ordonnent deux actions.", "我先吃饭，然后学习。", "Je mange d’abord, puis j’étudie."),
            grammar("hsk20-225", "A 比 B + adjectif", "比 compare deux éléments.", "今天比昨天高兴。", "Aujourd’hui je suis plus heureux qu’hier."),
        ],
        "choice": ("Que signifie 复习 ?", "Choisis l’action du bilan.", [("a", "réviser"), ("b", "acheter"), ("c", "nager")], "a"),
        "order": ("Construis « Comme il pleut, je prends un taxi ». ", [("a", "我坐出租车"), ("b", "因为下雨，所以"), ("c", "。")], ["b", "a", "c"], ["因为下雨，所以我坐出租车。", "因为下雨，所以我坐出租车"]),
        "fill": ("Complète la conséquence : 因为下雨，___我坐出租车。", "因为下雨，___我坐出租车。", ["所以"]),
        "listen": ("Que révise-t-on aujourd’hui ?", "我们复习在家、吃饭和去学校。", [("a", "La météo seulement."), ("b", "La maison, les repas et l’école."), ("c", "Les sports de compétition.")], "b"),
        "speak": ("Dis « Je suis d’abord allé au restaurant, puis à l’école ». ", "我先去饭馆，然后去了学校。", "Je suis d’abord allé au restaurant, puis à l’école."),
        "readingChoice": ("Pourquoi Tao est-il rentré tard ?", [("a", "Parce qu’il pleuvait."), ("b", "Parce qu’il lisait un livre."), ("c", "Parce qu’il nageait.")], "a"),
    },
    31: {
        "title": "Les courses dans la cuisine",
        "summary": "Ranger les courses, utiliser le réfrigérateur et descendre chercher un sac.",
        "dialogue": [
            ("Mina", "你带什么回家？", "Qu’as-tu rapporté à la maison ?"),
            ("Tao", "我带一个包，里面有菜。", "J’ai rapporté un sac qui contient des légumes."),
            ("Mina", "冰箱在厨房吗？", "Le réfrigérateur est-il dans la cuisine ?"),
            ("Tao", "是。灯在门上面，电梯在外面。", "Oui. La lampe est au-dessus de la porte et l’ascenseur est dehors."),
            ("Mina", "你把牛奶放进去了吗？", "As-tu mis le lait dedans ?"),
            ("Tao", "放好了，我要下楼拿另一个包。", "Oui, je l’ai rangé ; je vais descendre prendre un autre sac."),
        ],
        "reading": ("Ranger les courses", "Tao带着一个包进入厨房，把菜和牛奶放进冰箱。", "Tao entre dans la cuisine avec un sac et met les légumes et le lait dans le réfrigérateur.", "厨房的灯很亮。电梯在门外，他下楼再拿一个包。", "La lampe de la cuisine éclaire bien. L’ascenseur est devant la porte ; il redescend chercher un autre sac."),
        "grammar": [grammar("hsk20-326", "想/要 + verbe", "想 et 要 précèdent l’action souhaitée.", "我要拿另一个包。", "Je veux prendre un autre sac.")],
        "choice": ("Que signifie 冰箱 ?", "Choisis l’appareil de la cuisine.", [("a", "réfrigérateur"), ("b", "ascenseur"), ("c", "lampe")], "a"),
        "order": ("Construis « Je mets le lait dans le réfrigérateur ». ", [("a", "放进冰箱"), ("b", "我把牛奶"), ("c", "。")], ["b", "a", "c"], ["我把牛奶放进冰箱。", "我把牛奶放进冰箱"]),
        "fill": ("Complète : 我把菜放进冰___。", "我把菜放进冰___。", ["箱"]),
        "listen": ("Où est la lampe ?", "灯在门上面。", [("a", "Sous la table."), ("b", "Au-dessus de la porte."), ("c", "Dans l’ascenseur.")], "b"),
        "speak": ("Dis « Je rapporte un sac à la maison ». ", "我带一个包回家。", "Je rapporte un sac à la maison."),
        "readingChoice": ("Que met Tao dans le réfrigérateur ?", [("a", "Les légumes et le lait."), ("b", "Les livres et les lunettes."), ("c", "Les billets et les photos.")], "a"),
    },
    32: {
        "title": "Le mariage du voisin",
        "summary": "Parler d’une cérémonie, présenter les invités et accueillir la famille.",
        "dialogue": [
            ("Mina", "你知道邻居要结婚吗？", "Sais-tu que le voisin va se marier ?"),
            ("Tao", "知道。阿姨和叔叔也要来。", "Oui. La tante et l’oncle vont venir aussi."),
            ("Mina", "奶奶是今天的客人吗？", "La grand-mère est-elle l’invitée d’aujourd’hui ?"),
            ("Tao", "是，她和很多客人一起坐。", "Oui, elle s’assoit avec beaucoup d’invités."),
            ("Mina", "你会帮助邻居吗？", "Vas-tu aider le voisin ?"),
            ("Tao", "会。结婚以后，他们住在这座楼里。", "Oui. Après le mariage, ils habiteront dans cet immeuble."),
        ],
        "reading": ("Une fête", "邻居结婚，阿姨、叔叔和奶奶都来参加。", "Le voisin se marie ; la tante, l’oncle et la grand-mère participent tous à la fête.", "客人们坐在一起。婚礼以后，新人住在附近的楼里。", "Les invités s’assoient ensemble. Après le mariage, les jeunes mariés habitent dans un immeuble voisin."),
        "grammar": [grammar("hsk20-426", "会/能 + verbe", "会 indique une capacité ou une intention future.", "我会帮助邻居。", "J’aiderai le voisin.")],
        "choice": ("Que signifie 结婚 ?", "Choisis l’événement.", [("a", "se marier"), ("b", "déménager"), ("c", "réviser")], "a"),
        "order": ("Construis « La grand-mère est une invitée ». ", [("a", "客人"), ("b", "奶奶是"), ("c", "。")], ["b", "a", "c"], ["奶奶是客人。", "奶奶是客人"]),
        "fill": ("Complète : 邻居要___婚。", "邻居要___婚。", ["结"]),
        "listen": ("Qui vient à la fête ?", "阿姨和叔叔也要来。", [("a", "La tante et l’oncle."), ("b", "Le médecin et le professeur."), ("c", "Les élèves seulement.")], "a"),
        "speak": ("Dis « Je vais aider le voisin ». ", "我会帮助邻居。", "Je vais aider le voisin."),
        "readingChoice": ("Où les jeunes mariés habitent-ils ?", [("a", "Dans un immeuble voisin."), ("b", "Dans un avion."), ("c", "À l’hôpital.")], "a"),
    },
    33: {
        "title": "Le contrôle médical",
        "summary": "Décrire des symptômes simples et suivre les indications du médecin.",
        "dialogue": [
            ("Mina", "你的鼻子和耳朵怎么样？", "Comment vont ton nez et tes oreilles ?"),
            ("Tao", "鼻子不舒服，耳朵也有一点疼。", "Mon nez est gênant et j’ai aussi un peu mal aux oreilles."),
            ("Mina", "你发烧了吗？", "As-tu de la fièvre ?"),
            ("Tao", "发烧了，还感冒。", "Oui, et je suis enrhumé."),
            ("Mina", "医生说你健康吗？", "Le médecin dit-il que tu es en bonne santé ?"),
            ("Tao", "他说休息以后会好，我的脚也不疼了。", "Il dit que j’irai mieux après du repos ; mon pied ne me fait plus mal non plus."),
        ],
        "reading": ("Chez le médecin", "Tao感冒发烧，鼻子和耳朵不舒服，所以去看医生。", "Tao est enrhumé et fiévreux ; son nez et ses oreilles le gênent, alors il va voir le médecin.", "医生检查他的身体和脚，让他回家休息。明天他应该更健康。", "Le médecin examine son corps et son pied et lui demande de rentrer se reposer. Demain, il devrait être en meilleure santé."),
        "grammar": [grammar("hsk20-369", "正在 + verbe", "正在 indique que l’examen est en cours.", "医生正在检查我的身体。", "Le médecin examine mon corps en ce moment.")],
        "choice": ("Que signifie 发烧 ?", "Choisis le symptôme.", [("a", "avoir de la fièvre"), ("b", "avoir faim"), ("c", "être en retard")], "a"),
        "order": ("Construis « Je suis enrhumé ». ", [("a", "感冒"), ("b", "我"), ("c", "了")], ["b", "a", "c"], ["我感冒了。", "我感冒了"]),
        "fill": ("Complète : 鼻子和耳朵不___服。", "鼻子和耳朵不___服。", ["舒"]),
        "listen": ("Que demande le médecin ?", "回家休息。", [("a", "Rentrer se reposer."), ("b", "Aller nager."), ("c", "Acheter un billet.")], "a"),
        "speak": ("Dis « J’ai de la fièvre et je suis enrhumé ». ", "我发烧了，还感冒。", "J’ai de la fièvre et je suis enrhumé."),
        "readingChoice": ("Que doit faire Tao ?", [("a", "Rentrer se reposer."), ("b", "Travailler toute la nuit."), ("c", "Prendre l’avion.")], "a"),
    },
    34: {
        "title": "Réviser les phrases",
        "summary": "Travailler en classe, vérifier les mots et préparer un examen.",
        "dialogue": [
            ("Mina", "你在哪个班？", "Dans quelle classe es-tu ?"),
            ("Tao", "我在二班，必须复习词语。", "Je suis dans la classe deux et je dois réviser les mots."),
            ("Mina", "老师检查句子了吗？", "Le professeur a-t-il vérifié les phrases ?"),
            ("Tao", "检查了。他说第一句很清楚。", "Oui. Il a dit que la première phrase était très claire."),
            ("Mina", "你复习完了吗？", "As-tu fini de réviser ?"),
            ("Tao", "还没有，明天考试，我要再读一遍。", "Pas encore ; l’examen est demain, je dois relire encore une fois."),
        ],
        "reading": ("Le travail de classe", "二班的学生复习词语，老师检查每个人写的句子。", "Les élèves de la classe deux révisent les mots ; le professeur vérifie les phrases écrites par chacun.", "有一个句子不清楚，学生改了以后再读。明天考试，所以大家必须认真。", "Une phrase n’est pas claire ; l’élève la corrige puis la relit. Comme l’examen est demain, tout le monde doit être sérieux."),
        "grammar": [grammar("hsk20-436", "verbe + 了", "了 placé après le verbe marque une vérification terminée.", "老师检查了句子。", "Le professeur a vérifié les phrases.")],
        "choice": ("Que signifie 词语 ?", "Choisis ce que les élèves révisent.", [("a", "les mots"), ("b", "les billets"), ("c", "les vêtements")], "a"),
        "order": ("Construis « Le professeur a vérifié les phrases ». ", [("a", "句子"), ("b", "老师检查了"), ("c", "。")], ["b", "a", "c"], ["老师检查了句子。", "老师检查了句子"]),
        "fill": ("Complète : 明天___试。", "明天___试。", ["考"]),
        "listen": ("Dans quelle classe est Tao ?", "我在二班。", [("a", "La classe un."), ("b", "La classe deux."), ("c", "La classe dix.")], "b"),
        "speak": ("Dis « Je dois réviser les mots ». ", "我必须复习词语。", "Je dois réviser les mots."),
        "readingChoice": ("Pourquoi les élèves travaillent-ils sérieusement ?", [("a", "L’examen est demain."), ("b", "Il fait beau."), ("c", "Le magasin est proche.")], "a"),
    },
    35: {
        "title": "La réunion du matin",
        "summary": "Parler d’une réunion au bureau et préciser l’heure du rendez-vous.",
        "dialogue": [
            ("Mina", "你几点到办公室？", "À quelle heure arrives-tu au bureau ?"),
            ("Tao", "我八点半到，会议九点开始。", "J’arrive à huit heures et demie ; la réunion commence à neuf heures."),
            ("Mina", "经理在办公室吗？", "Le manager est-il au bureau ?"),
            ("Tao", "在。他让大家安静地听。", "Oui. Il demande à tout le monde d’écouter calmement."),
            ("Mina", "今天的工作努力做完了吗？", "As-tu fini sérieusement le travail d’aujourd’hui ?"),
            ("Tao", "做完了，下午还要开会。", "Oui, c’est fini ; nous avons encore une réunion l’après-midi."),
        ],
        "reading": ("Au bureau", "早上八点半，员工到办公室。经理九点开始会议。", "À huit heures et demie, les employés arrivent au bureau. Le manager commence la réunion à neuf heures.", "会议的时候大家安静地听。上午的工作做完以后，下午还有一次会议。", "Pendant la réunion, tout le monde écoute calmement. Après le travail du matin, il y a encore une réunion l’après-midi."),
        "grammar": [grammar("hsk20-407", "verbe + 过", "过 indique une expérience déjà vécue.", "我参加过这个会议。", "J’ai déjà participé à cette réunion.")],
        "choice": ("Que signifie 办公室 ?", "Choisis le lieu de travail.", [("a", "bureau"), ("b", "bibliothèque"), ("c", "cuisine")], "a"),
        "order": ("Construis « La réunion commence à neuf heures ». ", [("a", "九点"), ("b", "会议开始"), ("c", "。")], ["a", "b", "c"], ["九点会议开始。", "九点会议开始"]),
        "fill": ("Complète : 会议九点开___。", "会议九点开___。", ["始"]),
        "listen": ("À quelle heure commence la réunion ?", "会议九点开始。", [("a", "À huit heures."), ("b", "À neuf heures."), ("c", "À midi.")], "b"),
        "speak": ("Dis « Tout le monde écoute calmement ». ", "大家安静地听。", "Tout le monde écoute calmement."),
        "readingChoice": ("Que se passe-t-il l’après-midi ?", [("a", "Il y a encore une réunion."), ("b", "Tout le monde va nager."), ("c", "Le bureau ferme pour un mois.")], "a"),
    },
    36: {
        "title": "Trouver une solution",
        "summary": "Décrire un problème, comparer deux options et choisir une solution.",
        "dialogue": [
            ("Mina", "啊，电脑怎么了？", "Ah, qu’est-ce qui arrive à l’ordinateur ?"),
            ("Tao", "它不能打开，问题比较大。", "Il ne peut pas s’ouvrir ; le problème est assez important."),
            ("Mina", "我们有什么办法？", "Quelle solution avons-nous ?"),
            ("Tao", "我把电脑拿给经理，他会帮助我们。", "Je donne l’ordinateur au manager ; il nous aidera."),
            ("Mina", "它是被谁关上的？", "Par qui a-t-il été fermé ?"),
            ("Tao", "不知道。现在我认真地检查它。", "Je ne sais pas. Maintenant je le vérifie attentivement."),
        ],
        "reading": ("Un ordinateur bloqué", "电脑不能打开，员工觉得问题比较大，但是经理有办法。", "L’ordinateur ne peut pas s’ouvrir. L’employé trouve le problème assez important, mais le manager a une solution.", "员工把电脑给经理，经理认真地检查。电脑被他打开以后，大家都笑了。", "L’employé donne l’ordinateur au manager, qui l’examine attentivement. Après que l’ordinateur est ouvert, tout le monde sourit."),
        "grammar": [grammar("hsk20-316", "比较 + adjectif", "比较 se place avant un adjectif pour atténuer la description : le problème est assez important.", "这个问题比较大。", "Ce problème est assez important.")],
        "choice": ("Que signifie 办法 ?", "Choisis le mot qui résout le problème.", [("a", "solution"), ("b", "réunion"), ("c", "couleur")], "a"),
        "order": ("Construis « Je donne l’ordinateur au manager ». ", [("a", "拿给经理"), ("b", "我把电脑"), ("c", "。")], ["b", "a", "c"], ["我把电脑拿给经理。", "我把电脑拿给经理"]),
        "fill": ("Complète : 电脑不能___开。", "电脑不能___开。", ["打"]),
        "listen": ("Qui aide les employés ?", "经理会帮助我们。", [("a", "Le professeur."), ("b", "Le manager."), ("c", "Le chauffeur.")], "b"),
        "speak": ("Dis « Le problème est assez important ». ", "问题比较大。", "Le problème est assez important."),
        "readingChoice": ("Que fait le manager ?", [("a", "Il vérifie et ouvre l’ordinateur."), ("b", "Il prépare un repas."), ("c", "Il vend une chemise.")], "a"),
    },
    37: {
        "title": "Arriver en ville",
        "summary": "Lire une carte, trouver l’hôtel et donner son passeport au chauffeur.",
        "dialogue": [
            ("Mina", "宾馆在哪里？", "Où est l’hôtel ?"),
            ("Tao", "在地铁站旁边。你有地图吗？", "À côté de la station de métro. As-tu une carte ?"),
            ("Mina", "有。我从这条街走过去。", "Oui. Je vais marcher depuis cette rue."),
            ("Tao", "请把护照给司机看。", "Montre ton passeport au chauffeur, s’il te plaît."),
            ("Mina", "司机知道去宾馆的路吗？", "Le chauffeur connaît-il le chemin de l’hôtel ?"),
            ("Tao", "知道，他马上带我们到。", "Oui, il va nous y conduire tout de suite."),
        ],
        "reading": ("La carte", "游客看地图，发现宾馆在地铁站旁边，从这条街走十分钟就到。", "Le visiteur regarde la carte et découvre que l’hôtel est à côté du métro, à dix minutes à pied de cette rue.", "司机检查他的护照，然后带他到宾馆。", "Le chauffeur vérifie son passeport puis le conduit à l’hôtel."),
        "grammar": [grammar("hsk20-356", "因为…所以…", "因为 présente la cause et 所以 la conséquence.", "因为有地图，所以我们找到宾馆。", "Comme nous avons une carte, nous trouvons l’hôtel.")],
        "choice": ("Que signifie 护照 ?", "Choisis le document demandé.", [("a", "passeport"), ("b", "billet"), ("c", "menu")], "a"),
        "order": ("Construis « L’hôtel est à côté du métro ». ", [("a", "地铁站旁边"), ("b", "宾馆在"), ("c", "。")], ["b", "a", "c"], ["宾馆在地铁站旁边。", "宾馆在地铁站旁边"]),
        "fill": ("Complète : 请把___照给司机看。", "请把___照给司机看。", ["护"]),
        "listen": ("Où est l’hôtel ?", "在地铁站旁边。", [("a", "À côté du métro."), ("b", "Derrière l’aéroport."), ("c", "Dans la cuisine.")], "a"),
        "speak": ("Dis « Nous trouvons l’hôtel grâce à la carte ». ", "我们根据地图找到宾馆。", "Nous trouvons l’hôtel grâce à la carte."),
        "readingChoice": ("Comment le visiteur arrive-t-il à l’hôtel ?", [("a", "Le chauffeur le conduit."), ("b", "Il prend un bateau."), ("c", "Il nage.")], "a"),
    },
    38: {
        "title": "Une valise oubliée",
        "summary": "Raconter un oubli à la gare et demander quel choix faire.",
        "dialogue": [
            ("Mina", "你的行李箱在哪里？", "Où est ta valise ?"),
            ("Tao", "刚才还在这里，现在不见了。", "Elle était encore ici tout à l’heure, maintenant elle a disparu."),
            ("Mina", "你坐火车还是坐飞机？", "Tu prends le train ou l’avion ?"),
            ("Tao", "坐火车。我们回去找，或者问服务员。", "Le train. Nous pouvons retourner la chercher ou demander au serveur."),
            ("Mina", "别难过，一会儿就能找到。", "Ne sois pas triste, nous la trouverons dans un moment."),
            ("Tao", "好，现在是三点一刻，我们还有时间。", "D’accord, il est trois heures et quart, nous avons encore le temps."),
        ],
        "reading": ("À la gare", "Tao刚才把行李箱放在车站，现在找不到了。他没有坐飞机，要坐火车。", "Tao a posé sa valise à la gare tout à l’heure et ne la trouve plus. Il ne prend pas l’avion, il prend le train.", "他问服务员，决定回去找。三点一刻以后，他终于看见行李箱。", "Il demande au serveur et décide de retourner la chercher. Après trois heures et quart, il voit enfin la valise."),
        "grammar": [grammar("hsk20-562", "从 A 到 B", "从 et 到 encadrent le trajet d’un lieu à l’autre.", "从这里到车站很近。", "D’ici à la gare, c’est proche.")],
        "choice": ("Que signifie 行李箱 ?", "Choisis l’objet perdu.", [("a", "valise"), ("b", "carte"), ("c", "parapluie")], "a"),
        "order": ("Construis « Nous retournons chercher la valise ». ", [("a", "行李箱"), ("b", "我们回去找"), ("c", "。")], ["b", "a", "c"], ["我们回去找行李箱。", "我们回去找行李箱"]),
        "fill": ("Complète : 三点一___。", "三点一___。", ["刻"]),
        "listen": ("Quel transport Tao prend-il ?", "我要坐火车。", [("a", "Le train."), ("b", "L’avion."), ("c", "Le bateau.")], "a"),
        "speak": ("Dis « Ne sois pas triste ». ", "别难过。", "Ne sois pas triste."),
        "readingChoice": ("Quand Tao retrouve-t-il la valise ?", [("a", "Après trois heures et quart."), ("b", "Le lendemain matin."), ("c", "À midi.")], "a"),
    },
    39: {
        "title": "Acheter un cadeau",
        "summary": "Lire un menu, choisir une chemise et remettre un cadeau.",
        "dialogue": [
            ("Mina", "超市旁边有商店吗？", "Y a-t-il un magasin à côté du supermarché ?"),
            ("Tao", "有，我先看菜单，再买礼物。", "Oui ; je regarde d’abord le menu, puis j’achète un cadeau."),
            ("Mina", "这件衬衫和那条裤子多少钱？", "Combien coûtent cette chemise et ce pantalon ?"),
            ("Tao", "衬衫不贵，裤子比较贵。", "La chemise n’est pas chère, le pantalon est assez cher."),
            ("Mina", "谁来接礼物？", "Qui vient recevoir le cadeau ?"),
            ("Tao", "朋友来接。买完以后我们回家。", "Un ami vient le recevoir. Après l’achat, nous rentrons à la maison."),
        ],
        "reading": ("Le cadeau", "Tao在超市旁边的商店买礼物。衬衫便宜，裤子比较贵。", "Tao achète un cadeau dans le magasin à côté du supermarché. La chemise est bon marché, le pantalon est assez cher.", "他先看菜单，再选择一件衬衫。朋友来接礼物，然后他们一起回家。", "Il regarde d’abord le menu puis choisit une chemise. Son ami vient recevoir le cadeau, puis ils rentrent ensemble."),
        "grammar": [grammar("hsk20-328", "先…然后…", "先 et 然后 présentent deux actions dans l’ordre.", "我先看菜单，然后买礼物。", "Je regarde d’abord le menu, puis j’achète un cadeau.")],
        "choice": ("Que signifie 礼物 ?", "Choisis ce que Tao achète.", [("a", "cadeau"), ("b", "passeport"), ("c", "médicament")], "a"),
        "order": ("Construis « Je regarde d’abord le menu ». ", [("a", "看菜单"), ("b", "我先"), ("c", "。")], ["b", "a", "c"], ["我先看菜单。", "我先看菜单"]),
        "fill": ("Complète : 朋友来接礼___。", "朋友来接礼___。", ["物"]),
        "listen": ("Quel vêtement est bon marché ?", "衬衫不贵。", [("a", "Le pantalon."), ("b", "La chemise."), ("c", "Le chapeau.")], "b"),
        "speak": ("Dis « Après l’achat, nous rentrons à la maison ». ", "买完以后我们回家。", "Après l’achat, nous rentrons à la maison."),
        "readingChoice": ("Qui reçoit le cadeau ?", [("a", "Un ami."), ("b", "Un chauffeur."), ("c", "Un médecin.")], "a"),
    },
    40: {
        "title": "La salle de classe",
        "summary": "Décrire un déménagement dans un immeuble et travailler confortablement.",
        "dialogue": [
            ("Mina", "新教室在哪一层？", "À quel étage est la nouvelle classe ?"),
            ("Tao", "在三层，黑板在前面。", "Au troisième étage ; le tableau est devant."),
            ("Mina", "你看得清楚吗？", "Vois-tu clairement ?"),
            ("Tao", "我戴眼镜就看得清楚。", "Avec mes lunettes, je vois clairement."),
            ("Mina", "这里舒服吗？", "Est-ce confortable ici ?"),
            ("Tao", "很舒服。我们拍一张照片给老师看。", "C’est très confortable. Prenons une photo pour la montrer au professeur."),
        ],
        "reading": ("Une nouvelle classe", "新教室在楼的三层，黑板在前面，桌子很干净。", "La nouvelle classe est au troisième étage de l’immeuble ; le tableau est devant et les tables sont propres.", "Tao戴眼镜看黑板，觉得这里很舒服。他拍了一张照片。", "Tao porte ses lunettes pour regarder le tableau et trouve l’endroit très confortable. Il prend une photo."),
        "grammar": [grammar("hsk20-504", "一边…一边…", "一边 relie deux actions réalisées en même temps.", "我一边看黑板一边写字。", "Je regarde le tableau tout en écrivant.")],
        "choice": ("Que signifie 黑板 ?", "Choisis l’objet de la classe.", [("a", "tableau noir"), ("b", "lunettes"), ("c", "photo")], "a"),
        "order": ("Construis « Le tableau est devant ». ", [("a", "前面"), ("b", "黑板在"), ("c", "。")], ["b", "a", "c"], ["黑板在前面。", "黑板在前面"]),
        "fill": ("Complète : 我戴眼___。", "我戴眼___。", ["镜"]),
        "listen": ("À quel étage est la classe ?", "在三层。", [("a", "Au premier étage."), ("b", "Au troisième étage."), ("c", "Au dixième étage.")], "b"),
        "speak": ("Dis « Je vois clairement avec mes lunettes ». ", "我戴眼镜看得清楚。", "Je vois clairement avec mes lunettes."),
        "readingChoice": ("Que fait Tao ?", [("a", "Il prend une photo."), ("b", "Il prépare un examen médical."), ("c", "Il achète un billet.")], "a"),
    },
    41: {
        "title": "Changer la routine",
        "summary": "Parler d’un repas, d’une activité et d’un changement dans la journée.",
        "dialogue": [
            ("Mina", "你吃饱了吗？", "As-tu assez mangé ?"),
            ("Tao", "吃饱了，谢谢你帮忙。", "Oui, merci de m’aider."),
            ("Mina", "北方的天气和这里一样吗？", "Le temps du Nord est-il comme ici ?"),
            ("Tao", "不一样，天气变化很大。", "Non, il est différent ; le temps change beaucoup."),
            ("Mina", "你要参加比赛吗？", "Vas-tu participer à la compétition ?"),
            ("Tao", "要。我把时间改一下，就能参加。", "Oui. Je change un peu l’horaire et je pourrai participer."),
        ],
        "reading": ("Un nouvel horaire", "Tao吃饱以后感谢朋友帮忙。他发现北方和这里的天气不一样。", "Après avoir mangé à sa faim, Tao remercie son ami de son aide. Il découvre que le temps du Nord est différent d’ici.", "天气变化以后，他把时间改好，准备参加比赛。", "Après le changement de temps, il ajuste l’horaire et se prépare à participer à la compétition."),
        "grammar": [grammar("hsk20-321", "把 + objet + verbe", "把 place l’objet avant l’action et son résultat.", "我把时间改好了。", "J’ai bien modifié l’horaire.")],
        "choice": ("Que signifie 吃饱 ?", "Choisis l’état après le repas.", [("a", "avoir assez mangé"), ("b", "avoir sommeil"), ("c", "être en retard")], "a"),
        "order": ("Construis « Je change l’horaire ». ", [("a", "时间"), ("b", "我把"), ("c", "改一下")], ["b", "a", "c"], ["我把时间改一下。", "我把时间改一下"]),
        "fill": ("Complète : 北方的天气不一___。", "北方的天气不一___。", ["样"]),
        "listen": ("À quoi Tao participe-t-il ?", "我要参加比赛。", [("a", "À une réunion."), ("b", "À une compétition."), ("c", "À un examen médical.")], "b"),
        "speak": ("Dis « Le temps change beaucoup ». ", "天气变化很大。", "Le temps change beaucoup."),
        "readingChoice": ("Que fait Tao avant la compétition ?", [("a", "Il modifie l’horaire."), ("b", "Il achète des lunettes."), ("c", "Il prend l’avion.")], "a"),
    },
    42: {
        "title": "La photo de l’équipe",
        "summary": "Présenter les collègues, compter les personnes et expliquer une photo.",
        "dialogue": [
            ("Mina", "这几位是你的同事吗？", "Ces personnes sont-elles tes collègues ?"),
            ("Tao", "是，一共五位。", "Oui, cinq personnes au total."),
            ("Mina", "那位老人是你爷爷吗？", "La personne âgée est-elle ton grand-père ?"),
            ("Tao", "是。他来看我们的工作。", "Oui. Il vient voir notre travail."),
            ("Mina", "你拍的照片表示什么？", "Qu’exprime la photo que tu prends ?"),
            ("Tao", "表示欢迎。请大家一起看照片。", "Elle exprime la bienvenue. Regardons tous la photo ensemble."),
        ],
        "reading": ("Une équipe", "五位同事在办公室见面，爷爷也来看他们的工作。", "Cinq collègues se retrouvent au bureau ; le grand-père vient aussi voir leur travail.", "Tao用照相机拍下大家的样子。这张照片表示欢迎，所有人都很高兴。", "Tao prend tout le monde en photo. Cette photo exprime la bienvenue et tout le monde est heureux."),
        "grammar": [grammar("hsk20-532", "被 + agent", "被 introduit la personne ou la chose qui subit l’action.", "照片被同事看见了。", "La photo a été vue par les collègues.")],
        "choice": ("Que signifie 位 ?", "Choisis le classificateur de personnes.", [("a", "classificateur pour les personnes"), ("b", "étage"), ("c", "kilogramme")], "a"),
        "order": ("Construis « Il y a cinq personnes au total ». ", [("a", "五位"), ("b", "一共"), ("c", "。")], ["b", "a", "c"], ["一共五位。", "一共五位"]),
        "fill": ("Complète : 一共五___。", "一共五___。", ["位"]),
        "listen": ("Combien de collègues sont présents ?", "一共五位。", [("a", "Trois."), ("b", "Cinq."), ("c", "Dix.")], "b"),
        "speak": ("Dis « Cette photo exprime la bienvenue ». ", "这张照片表示欢迎。", "Cette photo exprime la bienvenue."),
        "readingChoice": ("Pourquoi le grand-père vient-il au bureau ?", [("a", "Pour voir leur travail."), ("b", "Pour acheter un cadeau."), ("c", "Pour prendre le train.")], "a"),
    },
    43: {
        "title": "Étudier à la bibliothèque",
        "summary": "Organiser une séance de mathématiques et conseiller une méthode de travail.",
        "dialogue": [
            ("Mina", "你在图书馆学习什么？", "Qu’étudies-tu à la bibliothèque ?"),
            ("Tao", "我学习数学，准备考试。", "J’étudie les mathématiques et je prépare l’examen."),
            ("Mina", "校长说今天要考试吗？", "Le directeur dit-il qu’il y a un examen aujourd’hui ?"),
            ("Tao", "不是，明天考试。我们一定要努力。", "Non, l’examen est demain. Nous devons absolument travailler dur."),
            ("Mina", "你应该先读书还是先写字？", "Devrais-tu d’abord lire ou écrire ?"),
            ("Tao", "我应该先读书，然后写答案。", "Je devrais d’abord lire, puis écrire les réponses."),
        ],
        "reading": ("La préparation", "学生在图书馆学习数学。校长告诉大家明天考试。", "Les étudiants étudient les mathématiques à la bibliothèque. Le directeur leur dit que l’examen est demain.", "他们一定要努力。学生应该先读书，再写答案。", "Ils doivent absolument travailler dur. Les étudiants devraient d’abord lire, puis écrire les réponses."),
        "grammar": [grammar("hsk20-570", "虽然…但是…", "虽然 introduit une concession suivie de 但是.", "虽然考试很难，但是我一定努力。", "Même si l’examen est difficile, je travaillerai sérieusement.")],
        "choice": ("Que signifie 图书馆 ?", "Choisis le lieu d’étude.", [("a", "bibliothèque"), ("b", "bureau"), ("c", "aéroport")], "a"),
        "order": ("Construis « Nous étudions les mathématiques ». ", [("a", "数学"), ("b", "我们学习"), ("c", "。")], ["b", "a", "c"], ["我们学习数学。", "我们学习数学"]),
        "fill": ("Complète : 明天考___。", "明天考___。", ["试"]),
        "listen": ("Quand a lieu l’examen ?", "明天考试。", [("a", "Aujourd’hui."), ("b", "Demain."), ("c", "La semaine dernière.")], "b"),
        "speak": ("Dis « Nous devons absolument travailler dur ». ", "我们一定要努力。", "Nous devons absolument travailler dur."),
        "readingChoice": ("Que doivent faire les étudiants après avoir lu ?", [("a", "Écrire les réponses."), ("b", "Aller nager."), ("c", "Acheter une chemise.")], "a"),
    },
    44: {
        "title": "Le résultat de la réunion",
        "summary": "Participer à une réunion, parler du résultat et attendre le bon moment.",
        "dialogue": [
            ("Mina", "别人都参加会议了吗？", "Les autres ont-ils tous participé à la réunion ?"),
            ("Tao", "大部分参加了，但是小王还没到。", "La plupart ont participé, mais Xiao Wang n’est pas encore arrivé."),
            ("Mina", "经理什么时候来？", "Quand le manager vient-il ?"),
            ("Tao", "他五点才来。我们在二层等。", "Il n’arrive qu’à cinq heures. Nous attendons au deuxième étage."),
            ("Mina", "这次会议的结果怎么样？", "Quel est le résultat de cette réunion ?"),
            ("Tao", "很好。如果大家同意，就开始工作。", "Il est très bon. Si tout le monde est d’accord, nous commençons le travail."),
        ],
        "reading": ("Après la réunion", "大部分同事参加了会议，经理五点才到。大家在二层等他。", "La plupart des collègues ont participé à la réunion ; le manager n’est arrivé qu’à cinq heures. Tout le monde l’attend au deuxième étage.", "会议结束以后，大家看结果。如果同意新的办法，就开始工作。", "Après la réunion, tout le monde regarde le résultat. Si tous sont d’accord avec la nouvelle méthode, ils commencent le travail."),
        "grammar": [grammar("hsk20-336", "如果…就…", "如果 pose une condition et 就 sa conséquence.", "如果大家同意，就开始工作。", "Si tout le monde est d’accord, nous commençons le travail.")],
        "choice": ("Que signifie 参加 ?", "Choisis l’action des collègues.", [("a", "participer"), ("b", "oublier"), ("c", "dormir")], "a"),
        "order": ("Construis « Nous attendons au deuxième étage ». ", [("a", "二层"), ("b", "我们在"), ("c", "等")], ["b", "a", "c"], ["我们在二层等。", "我们在二层等"]),
        "fill": ("Complète : 经理五点___来。", "经理五点___来。", ["才"]),
        "listen": ("Où attendent-ils le manager ?", "我们在二层等。", [("a", "Au premier étage."), ("b", "Au deuxième étage."), ("c", "Dans la rue.")], "b"),
        "speak": ("Dis « Si tout le monde est d’accord, nous commençons le travail ». ", "如果大家同意，就开始工作。", "Si tout le monde est d’accord, nous commençons le travail."),
        "readingChoice": ("Quand le manager arrive-t-il ?", [("a", "À trois heures."), ("b", "À cinq heures."), ("c", "Le lendemain.")], "b"),
    },
    45: {
        "title": "Une enquête sur le quartier",
        "summary": "Décrire les relations du quartier et comparer les moyens de transport.",
        "dialogue": [
            ("Mina", "你和邻居的关系怎么样？", "Comment sont tes relations avec les voisins ?"),
            ("Tao", "很好。我们一起看看街道。", "Très bonnes. Nous regardons la rue ensemble."),
            ("Mina", "街上有几辆车？", "Combien de véhicules y a-t-il dans la rue ?"),
            ("Tao", "有两辆。请张开口说清楚。", "Il y en a deux. Ouvre la bouche et parle clairement, s’il te plaît."),
            ("Mina", "这条路比那条路远吗？", "Cette route est-elle plus éloignée que l’autre ?"),
            ("Tao", "不，这条路更近，所以大家都走这里。", "Non, cette route est plus proche, donc tout le monde passe par ici."),
        ],
        "reading": ("Dans le quartier", "邻居关系很好，大家一起看看街道上的车辆和道路。", "Les relations entre voisins sont très bonnes ; tout le monde regarde ensemble les véhicules et les routes de la rue.", "这条路比较近，另一条路比较远。因为这里有两辆车，所以大家小心地走。", "Cette route est assez proche et l’autre assez éloignée. Comme il y a deux véhicules ici, tout le monde marche avec prudence."),
        "grammar": [grammar("hsk20-388", "越来越 + adjectif", "越来越 décrit une évolution progressive.", "我们的关系越来越好。", "Nos relations s’améliorent de plus en plus.")],
        "choice": ("Que signifie 关系 ?", "Choisis le sujet de l’enquête.", [("a", "relation"), ("b", "résultat"), ("c", "vacances")], "a"),
        "order": ("Construis « Cette route est plus proche ». ", [("a", "更近"), ("b", "这条路"), ("c", "。")], ["b", "a", "c"], ["这条路更近。", "这条路更近"]),
        "fill": ("Complète : 街上有两___车。", "街上有两___车。", ["辆"]),
        "listen": ("Combien de véhicules y a-t-il ?", "有两辆车。", [("a", "Un."), ("b", "Deux."), ("c", "Cinq.")], "b"),
        "speak": ("Dis « Nos relations s’améliorent de plus en plus ». ", "我们的关系越来越好。", "Nos relations s’améliorent de plus en plus."),
        "readingChoice": ("Pourquoi les gens font-ils attention en marchant ?", [("a", "Il y a deux véhicules."), ("b", "La route est fermée."), ("c", "Il neige.")], "a"),
    },
}


def choice_exercise(eid: str, objective: str, data: tuple[str, str, list[tuple[str, str]], str]) -> dict[str, Any]:
    prompt, instruction, choices, correct = data
    return {"id": eid, "kind": "choice", "prompt": {"fr": prompt}, "instruction": {"fr": instruction}, "objectiveIDs": [objective], "required": True, "choices": [{"id": cid, "label": {"fr": label}, "audio": None} for cid, label in choices], "correctChoiceID": correct}


def order_exercise(eid: str, objective: str, data: tuple[str, list[tuple[str, str]], list[str], list[str]]) -> dict[str, Any]:
    prompt, tokens, correct, accepted = data
    return {"id": eid, "kind": "wordOrder", "prompt": {"fr": prompt}, "instruction": {"fr": "Replace chaque groupe dans l’ordre, puis relis la phrase complète."}, "objectiveIDs": [objective], "required": True, "tokens": [{"id": tid, "hanzi": hanzi, "pinyin": sentence_pinyin(hanzi), "audio": None} for tid, hanzi in tokens], "correctOrder": correct, "acceptedVariants": accepted}


def fill_exercise(eid: str, objective: str, data: tuple[str, str, list[str]]) -> dict[str, Any]:
    prompt, sentence, answers = data
    return {"id": eid, "kind": "fillBlank", "prompt": {"fr": prompt}, "instruction": {"fr": "Écris le mot manquant en caractères chinois."}, "objectiveIDs": [objective], "required": True, "sentence": sentence, "acceptedAnswers": answers, "caseSensitive": False}


def listening_exercise(eid: str, objective: str, data: tuple[str, str, list[tuple[str, str]], str]) -> dict[str, Any]:
    prompt, text, choices, correct = data
    return {"id": eid, "kind": "listeningChoice", "prompt": {"fr": prompt}, "instruction": {"fr": "Écoute la phrase en mandarin, puis choisis son sens."}, "objectiveIDs": [objective], "required": True, "promptText": text, "choices": [{"id": cid, "label": {"fr": label}, "audio": None} for cid, label in choices], "correctChoiceID": correct}


def speaking_exercise(eid: str, objective: str, data: tuple[str, str, str]) -> dict[str, Any]:
    prompt, text, translation = data
    return {"id": eid, "kind": "speaking", "prompt": {"fr": prompt}, "instruction": {"fr": "Écoute le modèle, dis la phrase, puis auto-évalue-toi."}, "objectiveIDs": [objective], "required": False, "referenceText": text, "referencePinyin": sentence_pinyin(text), "referenceAudio": None, "acceptedTranscripts": [text], "allowSelfRating": True}


def build_lesson(day: int, data: dict[str, Any], allocation: list[dict[str, Any]]) -> dict[str, Any]:
    row = allocation[day - 1]
    lesson_number = day + 4
    lesson_id = f"lesson-{lesson_number:02d}"
    understand = f"l{lesson_number}-understand"
    produce = f"l{lesson_number}-produce"
    new = list(row["newCanonicalIDs"])
    reused = list(row["reusedCanonicalIDs"])
    refs = list(dict.fromkeys(new + reused))
    reading_title, p1_hanzi, p1_fr, p2_hanzi, p2_fr = data["reading"]
    dialogue = {"id": f"block-{lesson_id}-dialogue", "lines": [line(speaker, hanzi, translation) for speaker, hanzi, translation in data["dialogue"]]}
    reading = {"id": f"block-{lesson_id}-reading", "storyID": f"story-{lesson_id}", "level": "HSK classique 2" if day <= 30 else "HSK classique 3", "title": {"fr": reading_title}, "paragraphs": [paragraph("p1", p1_hanzi, p1_fr), paragraph("p2", p2_hanzi, p2_fr)], "comprehensionExerciseIDs": [f"ex-l{lesson_number:02d}-reading"]}
    reading_question = data["readingChoice"]
    exercises = [
        choice_exercise(f"ex-l{lesson_number:02d}-meaning", understand, data["choice"]),
        order_exercise(f"ex-l{lesson_number:02d}-order", produce, data["order"]),
        fill_exercise(f"ex-l{lesson_number:02d}-fill", produce, data["fill"]),
        listening_exercise(f"ex-l{lesson_number:02d}-listen", understand, data["listen"]),
        speaking_exercise(f"ex-l{lesson_number:02d}-speak", produce, data["speak"]),
        choice_exercise(f"ex-l{lesson_number:02d}-reading", understand, (reading_question[0], "Relis les deux paragraphes avant de répondre.", reading_question[1], reading_question[2])),
    ]
    return {
        "id": lesson_id,
        "moduleID": row["moduleID"],
        "order": lesson_number,
        "level": "HSK classique 2" if day <= 30 else "HSK classique 3",
        "title": {"fr": data["title"]},
        "summary": {"fr": data["summary"]},
        "estimatedMinutes": 12,
        "objectives": [{"id": understand, "text": {"fr": "Comprendre la scène et les informations essentielles."}, "required": True}, {"id": produce, "text": {"fr": "Réutiliser une structure dans une phrase courte."}, "required": True}],
        "vocabularyIDs": refs,
        "extraVocabulary": [],
        "grammar": data["grammar"],
        "dialogue": dialogue,
        "reading": reading,
        "exercises": exercises,
        "recap": {"id": f"block-{lesson_id}-recap", "vocabularyIDs": refs[:6], "objectiveIDs": [understand, produce]},
        "metadata": {"allocationDay": day, "allocationRange": "days06-45", "theme": row["theme"], "newVocabularyIDs": new, "reusedVocabularyIDs": reused, "newCanonicalIDs": new, "reusedCanonicalIDs": reused},
    }


def main() -> None:
    allocation_document = json.loads(ALLOCATION_PATH.read_text(encoding="utf-8"))
    allocation = allocation_document["lessons"]
    missing = sorted(set(range(6, 46)) - set(DAY_DATA))
    if missing:
        raise SystemExit(f"missing authored days: {missing}")
    lessons = [build_lesson(day, DAY_DATA[day], allocation) for day in range(6, 46)]
    OUTPUT_PATH.write_text(json.dumps({"schemaVersion": 1, "contentVersion": "2026.10.0", "catalog": "authoring/hsk-legacy-600.json", "allocationRange": {"startDay": 6, "endDay": 45}, "lessons": lessons}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {OUTPUT_PATH} ({len(lessons)} lessons)")


if __name__ == "__main__":
    main()
