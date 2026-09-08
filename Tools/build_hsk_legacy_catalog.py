#!/usr/bin/env python3
"""Build the compact, authored HSK legacy 2.0 vocabulary catalog.

The official HSK list supplies the ordered lexical inventory and cumulative
level boundaries.  Pinyin readings and French glosses below are editorial
metadata written for Polygo; examples and lesson scenes are authored
separately and are not copied from a course or dictionary.

Usage:
  python3 Tools/build_hsk_legacy_catalog.py /path/to/official-cihui.pdf
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from pypdf import PdfReader
from pypinyin import Style, pinyin

try:
    from opencc import OpenCC
except ImportError:  # pragma: no cover - the release tool reports a clear hint
    OpenCC = None

SOURCE_URL = "https://www.chinesetest.cn/userfiles/file/cihui.pdf"
SOURCE_GUIDE_URL = "https://www.chinesetest.cn/userfiles/file/HSKbyWord.pdf"
SOURCE_DATE = "2026-09-08"
CONTENT_VERSION = "2026.09.0"
_OPENCC = OpenCC("s2t") if OpenCC is not None else None


def traditional_form(hanzi: str) -> str:
    """Convert a simplified lexical form with OpenCC's phrase dictionary.

    The catalogue keeps both forms even when they are identical.  Phrase
    conversion is used for compounds such as 发烧/發燒 and 面包/麵包; copying
    the simplified field would silently claim traditional support for every
    entry while leaving changed characters untouched.
    """
    if _OPENCC is None:
        raise RuntimeError(
            "OpenCC is required to build traditionalHanzi; install "
            "opencc-python-reimplemented or provide it on PYTHONPATH"
        )
    return _OPENCC.convert(hanzi)

# The French glosses are compact, learner-facing editorial text.  They are
# deliberately not used as evidence of a learner's mastery.
_MEANINGS = r"""
1|aimer
2|huit
3|papa
4|tasse ; verre
5|Pékin
6|classificateur des livres
7|ne… pas
8|de rien
9|plat ; légume
10|thé
11|manger
12|taxi
13|téléphoner
14|grand ; gros
15|particule de détermination
16|heure ; point
17|ordinateur
18|télévision
19|film
20|chose ; affaire
21|tous ; tout
22|lire
23|désolé ; pardon
24|beaucoup ; nombreux
25|combien
26|fils
27|deux
28|restaurant
29|avion
30|minute
31|content ; heureux
32|classificateur général
33|travailler ; travail
34|chien
35|chinois (langue)
36|bon ; bien
37|boire
38|et ; avec
39|très
40|derrière ; arrière
41|retourner ; revenir
42|savoir faire ; pouvoir
43|gare
44|combien (petit nombre)
45|maison ; famille
46|s’appeler ; appeler
47|elle
48|aujourd’hui
49|neuf
50|ouvrir ; mettre en marche
51|regarder ; lire
52|voir ; apercevoir
53|yuan ; morceau
54|venir
55|professeur
56|froid
57|intérieur ; dans
58|particule d’accompli ou de changement
59|zéro
60|six
61|maman
62|particule interrogative
63|acheter
64|chat
65|ne pas avoir ; ne pas
66|ce n’est pas grave
67|riz cuit
68|nom ; prénom
69|demain
70|quel ; lequel
71|ce/cette-là ; là-bas
72|particule de relance
73|pouvoir ; être capable
74|tu ; vous
75|année
76|fille
77|ami
78|joli ; beau
79|pomme
80|sept
81|devant ; avant
82|argent
83|prier de ; inviter
84|aller
85|chaud
86|personne ; humain
87|connaître ; faire connaissance
88|jour ; date
89|trois
90|magasin
91|dessus ; monter
92|matin
93|peu ; moins
94|dix
95|quoi ; quel
96|moment ; fois
97|être ; c’est
98|livre
99|qui
100|eau
101|fruit
102|dormir
103|parler
104|quatre
105|ans (âge)
106|il
107|trop ; tellement
108|temps (météo)
109|écouter ; entendre
110|camarade de classe
111|allô
112|je ; moi
113|nous
114|cinq
115|aimer ; apprécier
116|dessous ; descendre
117|après-midi
118|pleuvoir
119|monsieur
120|maintenant
121|vouloir ; penser
122|petit
123|mademoiselle
124|quelques ; certains
125|écrire
126|merci
127|semaine
128|élève ; étudiant
129|étudier ; apprendre
130|école
131|un ; une
132|vêtement
133|médecin
134|hôpital
135|chaise
136|avoir ; il y a
137|mois ; lune
138|au revoir
139|être à ; se trouver
140|comment
141|comment ; de quelle manière
142|ce/cette-ci ; ici
143|Chine
144|midi
145|habiter
146|table
147|caractère ; mot écrit
148|hier
149|s’asseoir ; prendre (un transport)
150|faire
151|particule de suggestion
152|blanc
153|cent
154|aider ; aide
155|journal
156|comparer ; que (comparatif)
157|bon marché
158|ne… pas (impératif)
159|long
160|chanter
161|sortir ; apparaître
162|porter (un vêtement)
163|bateau
164|fois (occurrence)
165|depuis ; de
166|faux ; erreur
167|jouer au basket
168|tout le monde
169|mais
170|arriver ; jusqu’à
171|particule de complément
172|attendre
173|petit frère
174|premier
175|comprendre
176|correct ; envers
177|chambre ; pièce
178|très ; extrêmement
179|serveur ; employé de service
180|haut ; grand
181|dire ; informer
182|grand frère
183|donner ; à (pour)
184|bus
185|kilogramme
186|entreprise
187|cher
188|avoir déjà fait (expérience)
189|enfant
190|délicieux
191|numéro ; jour du mois
192|noir
193|rouge
194|accueillir ; bienvenue
195|encore ; aussi
196|répondre ; réponse
197|aéroport
198|œuf
199|classificateur des vêtements ou affaires
200|salle de classe
201|grande sœur
202|présenter ; introduction
203|proche
204|entrer
205|alors ; justement
206|trouver ; penser
207|café
208|commencer ; début
209|examen ; passer un examen
210|possible ; peut-être
211|pouvoir ; être permis
212|cours ; leçon
213|rapide ; bientôt
214|heureux ; joie
215|fatigué
216|être éloigné de
217|deux (quantité)
218|route ; chemin
219|voyager ; voyage
220|vendre
221|lent
222|occupé
223|chaque
224|petite sœur
225|porte ; entrée
226|homme
227|vous (politesse)
228|lait
229|femme
230|à côté
231|courir
232|billet
233|épouse
234|se lever
235|mille
236|ensoleillé ; beau temps
237|l’année dernière
238|laisser ; faire
239|aller au travail
240|corps ; santé
241|tomber malade
242|anniversaire
243|temps ; durée
244|affaire ; chose
245|montre
246|téléphone portable
247|offrir ; accompagner
248|donc ; c’est pourquoi
249|il/elle (objet ou animal)
250|jouer au football
251|question ; exercice
252|danser
253|extérieur ; dehors
254|finir ; complet
255|jouer ; s’amuser
256|soir ; nuit
257|pourquoi
258|demander
259|question ; problème
260|pastèque
261|espérer ; espoir
262|laver
263|vers ; envers
264|heure (durée)
265|rire ; sourire
266|nouveau
267|nom de famille
268|se reposer
269|neige
270|couleur
271|yeux
272|viande de mouton
273|médicament
274|vouloir ; devoir
275|aussi
276|ensemble
277|déjà
278|sens ; signification
279|parce que
280|couvert ; nuageux
281|nager
282|droite ; côté droit
283|poisson
284|yuan
285|loin
286|sport ; faire du sport
287|encore ; de nouveau
288|matin tôt
289|feuille ; classificateur plat
290|mari
291|chercher ; trouver
292|vraiment ; vrai
293|être en train de
294|savoir
295|préparer ; être prêt
296|particule d’état duratif
297|vélo
298|marcher ; partir
299|le plus
300|gauche ; côté gauche
301|tante ; madame
302|particule exclamative
303|petit (de taille)
304|loisir ; passe-temps
305|calme ; silencieux
306|classificateur de poignée ; construction 把
307|classe ; groupe
308|déménager ; déplacer
309|moyen ; solution
310|bureau
311|moitié ; demi
312|aider ; rendre service
313|sac ; paquet
314|rassasié
315|nord ; région du nord
316|marque du passif ; être recouvert par
317|nez
318|comparer ; relativement
319|compétition ; match
320|devoir ; falloir
321|changement ; changer
322|exprimer ; indiquer
323|spectacle ; jouer
324|autrui ; les autres
325|hôtel
326|réfrigérateur
327|seulement ; alors seulement
328|menu
329|participer
330|herbe
331|étage ; couche
332|mauvais ; différer
333|grandir
334|supermarché
335|chemise
336|résultat ; note
337|ville
338|être en retard
339|apparaître
340|sauf ; en plus de
341|cuisine
342|printemps
343|mot ; expression
344|intelligent
345|nettoyer
346|avoir l’intention de
347|apporter ; emmener
348|s’inquiéter
349|gâteau
350|bien sûr
351|lampe ; lumière
352|bas
353|particule adverbiale
354|endroit
355|métro
356|carte
357|ascenseur
358|courriel
359|est
360|hiver
361|animal
362|court
363|segment ; tranche
364|faire de l’exercice
365|tellement ; si
366|avoir faim
367|en plus ; et
368|oreille
369|avoir de la fièvre
370|découvrir ; constater
371|pratique ; commode
372|poser ; mettre
373|être rassuré
374|diviser ; minute
375|environs ; à proximité
376|réviser
377|propre
378|oser
379|rhume ; être enrhumé
380|à l’instant
381|selon ; d’après
382|avec ; suivre
383|davantage ; plus
384|parc
385|histoire
386|y avoir du vent
387|fermer ; éteindre
388|relation ; rapport
389|se soucier de
390|au sujet de
391|pays ; État
392|jus de fruit
393|passé ; passer
394|avoir peur
395|rivière
396|tableau noir
397|passeport
398|fleur ; dépenser
399|jardin
400|dessiner ; peinture
401|mauvais ; cassé
402|rendre ; rembourser
403|ou bien ; toujours
404|environnement
405|changer ; échanger
406|jaune
407|réunion
408|ou bien
409|occasion ; chance
410|extrêmement ; au plus haut degré
411|presque
412|se souvenir
413|saison
414|vérifier ; examen
415|simple
416|se rencontrer
417|santé ; sain
418|parler ; expliquer
419|coin ; jiao (monnaie)
420|pied
421|enseigner
422|recevoir ; aller chercher
423|rue
424|programme ; émission
425|fête
426|se marier
427|terminer ; fin
428|résoudre
429|emprunter ; prêter
430|souvent
431|passer par ; traverser
432|directeur ; gérant
433|longtemps
434|vieux ; usagé
435|organiser ; tenir (un événement)
436|phrase
437|décider ; décision
438|mignon ; adorable
439|avoir soif
440|quart d’heure
441|invité ; client
442|climatisation
443|bouche ; classificateur
444|pleurer
445|pantalon
446|baguettes
447|bleu
448|vieux ; ancien
449|partir ; quitter
450|cadeau
451|histoire ; passé
452|visage
453|s’exercer ; exercice
454|classificateur des véhicules
455|comprendre ; connaître
456|voisin
457|étage ; immeuble
458|vert
459|cheval
460|tout de suite
461|satisfait
462|chapeau
463|riz ; mètre
464|pain
465|nouilles
466|comprendre ; clair
467|prendre ; tenir
468|grand-mère paternelle
469|sud
470|difficile
471|triste ; malheureux
472|niveau scolaire
473|jeune
474|oiseau
475|travailler dur ; effort
476|faire de la randonnée en montagne
477|assiette
478|gros ; corpulent
479|bière
480|raisin
481|mandarin standard
482|en fait
483|autre ; autres
484|étrange
485|monter (à vélo ou à cheval)
486|crayon
487|clair ; clairement
488|automne
489|jupe
490|ensuite
491|chaleureux ; enthousiasme
492|estimer ; penser
493|sérieux ; attentif
494|facile
495|si
496|parapluie
497|aller sur Internet
498|se fâcher ; en colère
499|son ; voix
500|faire ; rendre
501|monde
502|mince
503|oncle
504|confortable ; se sentir bien
505|arbre
506|mathématiques
507|se brosser les dents
508|paire ; double
509|niveau
510|chauffeur
511|bien que
512|soleil
513|sucre ; bonbon
514|particulièrement ; spécial
515|faire mal ; douloureux
516|améliorer ; augmenter
517|sport ; éducation physique
518|sucré
519|classificateur allongé
520|collègue
521|être d’accord
522|cheveux
523|soudain
524|bibliothèque
525|jambe
526|terminer ; achever
527|bol
528|dix mille
529|oublier
530|pour ; à cause de
531|afin de
532|classificateur honorifique des personnes
533|culture
534|ouest
535|habitude ; s’habituer
536|toilettes
537|prendre une douche ; se baigner
538|été
539|d’abord
540|identique ; pareil
541|croire
542|banane
543|ressembler à ; comme
544|faire attention ; prudent
545|directeur d’école
546|chaussure
547|nouvelles ; actualités
548|frais
549|lettre
550|intérêt
551|valise
552|panda
553|avoir besoin de
554|choisir ; choix
555|lunettes
556|demander ; exiger
557|grand-père paternel
558|général ; ordinaire
559|un côté ; tout en
560|certainement ; devoir
561|au total
562|un moment ; bientôt
563|pareil ; de la même manière
564|sans cesse ; toujours
565|après ; à l’avenir
566|avant ; auparavant
567|croire à tort ; penser
568|musique
569|banque
570|devoir ; être censé
571|influencer ; influence
572|utiliser ; emploi
573|jeu
574|célèbre
575|encore ; de nouveau
576|rencontrer ; tomber sur
577|vouloir bien ; être disposé à
578|lune
579|de plus en plus ; davantage
580|nuage
581|station ; être debout
582|s’occuper de
583|photo
584|appareil photo
585|seulement ; classificateur des animaux
586|milieu ; entre
587|enfin
588|sorte ; espèce
589|important
590|week-end
591|principal ; surtout
592|faire attention ; remarquer
593|souhaiter
594|être pressé ; s’inquiéter
595|dictionnaire
596|soi-même
597|toujours
598|récemment ; le plus proche
599|devoirs scolaires
600|effet ; rôle
"""

# Readings that need the intended HSK sense rather than pypinyin's first
# dictionary reading.  Duplicate source entries remain separate lexemes.
_PINYIN_OVERRIDES = {
    8: "bú kè qi",
    15: "de",
    32: "gè",
    38: "hé",
    42: "huì",
    47: "tā",
    58: "le",
    62: "ma",
    68: "míng zi",
    70: "nǎ",
    71: "nà",
    72: "ne",
    91: "shàng",
    99: "shéi",
    111: "wèi",
    123: "xiǎo jiě",
    131: "yī",
    137: "yuè",
    142: "zhè",
    151: "ba",
    157: "pián yi",
    159: "cháng",
    171: "de",
    188: "guo",
    195: "hái",
    201: "jiě jie",
    205: "jiù",
    214: "kuài lè",
    223: "měi",
    227: "nín",
    237: "qù nián",
    248: "suǒ yǐ",
    257: "wèi shén me",
    276: "yì qǐ",
    277: "yǐ jīng",
    287: "zài",
    293: "zhèng zài",
    296: "zhe",
    301: "ā yí",
    302: "a",
    306: "bǎ",
    316: "bèi",
    318: "bǐ jiào",
    333: "zhǎng",
    353: "de",
    365: "duō me",
    374: "fēn",
    383: "gèng",
    402: "huán",
    410: "jí",
    419: "jiǎo",
    421: "jiāo",
    430: "jīng cháng",
    440: "kè",
    448: "lǎo",
    458: "lǜ",
    482: "qí shí",
    492: "rèn wéi",
    530: "wèi",
    531: "wèi le",
    558: "yì bān",
    559: "yī biān",
    560: "yí dìng",
    561: "yí gòng",
    562: "yí huìr",
    563: "yí yàng",
    564: "yì zhí",
    565: "yǐ hòu",
    566: "yǐ qián",
    567: "yǐ wéi",
    569: "yín háng",
    570: "yīng gāi",
    575: "yòu",
    577: "yuàn yì",
    585: "zhǐ",
    587: "zhōng yú",
    588: "zhǒng",
    594: "zháo jí",
    596: "zì jǐ",
    597: "zǒng shì",
    598: "zuì jìn",
    599: "zuò yè",
    600: "zuò yòng",
}

# A short list of neutral-syllable spellings, kept separate from lexical
# tone changes such as 不客气 and 一起.  `toneNumbers` is derived from the
# authored pinyin below, so it remains auditable.
_NEUTRAL_PINYIN = {
    3: "bà ba", 4: "bēi zi", 26: "ér zi", 35: "Hàn yǔ", 40: "hòu miàn",
    45: "jiā", 55: "lǎo shī", 61: "mā ma", 68: "míng zi", 70: "nǎ",
    71: "nà", 76: "nǚ ér", 81: "qián miàn", 95: "shén me", 96: "shí hou",
    103: "shuō huà", 110: "tóng xué", 113: "wǒ men", 119: "xiān sheng",
    123: "xiǎo jiě", 126: "xiè xie", 128: "xué shēng", 132: "yī fu",
    135: "yǐ zi", 146: "zhuō zi", 182: "gē ge", 189: "hái zi",
    201: "jiě jie", 224: "mèi mei", 233: "qī zi", 256: "wǎn shang",
    290: "zhàng fu", 301: "ā yí", 317: "bí zi", 323: "biǎo yǎn",
    326: "bīng xiāng", 335: "chèn shān", 341: "chú fáng", 344: "cōng ming",
    358: "diàn zǐ yóu jiàn", 368: "ěr duo", 380: "gāng cái", 385: "gù shi",
    399: "huā yuán", 417: "jiàn kāng", 441: "kè rén", 445: "kù zi",
    446: "kuài zi", 462: "mào zi", 468: "nǎi nai", 477: "pán zi",
    489: "qún zi", 503: "shū shu", 522: "tóu fa", 527: "wǎn",
    542: "xiāng jiāo", 551: "xíng lǐ xiāng", 552: "xióng māo",
    557: "yé ye", 562: "yí huìr", 578: "yuè liang", 590: "zhōu mò",
    595: "zì diǎn",
}

# Polyphonic entries receive a short, original sentence so the selected
# reading and the French gloss are reviewed together before lesson authoring.
_AUTHOR_EXAMPLES = {
    159: ("这条路很长。", "zhè tiáo lù hěn cháng.", "Cette route est longue."),
    195: ("我还要喝茶。", "wǒ hái yào hē chá.", "Je veux encore boire du thé."),
    353: ("他认真地学习。", "tā rèn zhēn de xué xí.", "Il étudie sérieusement."),
    402: ("我明天还书。", "wǒ míng tiān huán shū.", "Je rends le livre demain."),
    421: ("老师教学生汉语。", "lǎo shī jiāo xué shēng Hàn yǔ.", "Le professeur enseigne le chinois aux élèves."),
    562: ("我一会儿回来。", "wǒ yí huìr huí lái.", "Je reviens dans un moment."),
}


def parse_official_entries(pdf_path: Path) -> list[tuple[int, str]]:
    text = "\n".join(page.extract_text() or "" for page in PdfReader(str(pdf_path)).pages)
    heading = "新 HSK（三级）词汇（600）"
    start = text.find(heading)
    if start < 0:
        raise ValueError("official PDF does not contain the 600-entry HSK heading")
    end = text.find("新 HSK（四级）", start)
    section = text[start:end if end >= 0 else None]
    entries: list[tuple[int, str]] = []
    for line in section.splitlines():
        match = re.match(r"\s*(\d+)．\s*(.+?)\s*$", line)
        if match:
            rank, word = int(match.group(1)), match.group(2)
            if 1 <= rank <= 600:
                entries.append((rank, word))
    entries.sort()
    if [rank for rank, _ in entries] != list(range(1, 601)):
        raise ValueError(f"expected ranks 1..600, got {len(entries)} entries")
    return entries


def tones(reading: str) -> list[int]:
    # `pypinyin` is used only as an auditable tone extractor for authored
    # accented pinyin.  Neutral syllables are represented by 0.
    syllables = re.findall(r"[A-Za-züÜvV]+[āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ]?[A-Za-züÜvV]*", reading)
    # More reliable: split on spaces after accepting compact pinyin.  The
    # catalog stores compact spellings for the UI but uses per-character
    # pypinyin as a fallback when no override is present.
    result: list[int] = []
    for syllable in reading.replace("'", " ").split():
        if any(ch in syllable for ch in "āēīōūǖ"):
            result.append(1)
        elif any(ch in syllable for ch in "áéíóúǘ"): result.append(2)
        elif any(ch in syllable for ch in "ǎěǐǒǔǚ"): result.append(3)
        elif any(ch in syllable for ch in "àèìòùǜ"): result.append(4)
        else: result.append(0)
    return result


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: build_hsk_legacy_catalog.py OFFICIAL_CIHUI_PDF")
    source_pdf = Path(sys.argv[1])
    entries = parse_official_entries(source_pdf)
    meanings = {int(line.split("|", 1)[0]): line.split("|", 1)[1].strip()
                for line in _MEANINGS.strip().splitlines() if line.strip()}
    if set(meanings) != set(range(1, 601)):
        missing = sorted(set(range(1, 601)) - set(meanings))
        raise ValueError(f"missing French glosses: {missing}")

    output = []
    for rank, source_form in entries:
        hanzi = re.sub(r"（.*?）", "", source_form)
        if rank in _PINYIN_OVERRIDES:
            reading = _PINYIN_OVERRIDES[rank]
        else:
            syllables = [x[0] for x in pinyin(hanzi, style=Style.TONE, heteronym=False, errors="default")]
            reading = " ".join(syllables)
        if rank in _NEUTRAL_PINYIN:
            reading = _NEUTRAL_PINYIN[rank]
        level = 1 if rank <= 150 else 2 if rank <= 300 else 3
        aliases = []
        variants = re.findall(r"（(.*?)）", source_form)
        if variants:
            aliases = [hanzi + variant[len(hanzi):] if variant.startswith(hanzi) else variant for variant in variants]
        entry = {
            "id": f"hsk20-{rank:03d}",
            "rank": rank,
            "level": level,
            "lexemeKey": f"{hanzi}|{reading}|{rank}",
            "sourceForm": source_form,
            "hanzi": hanzi,
            "traditionalHanzi": traditional_form(hanzi),
            "aliases": aliases,
            "pinyin": reading,
            "toneNumbers": tones(reading),
            "meaningFr": meanings[rank],
            "identity": "ranked-lexeme",
        }
        if rank in _AUTHOR_EXAMPLES:
            example_hanzi, example_pinyin, example_fr = _AUTHOR_EXAMPLES[rank]
            entry["example"] = {
                "hanzi": example_hanzi,
                "pinyin": example_pinyin,
                "translationFr": example_fr,
            }
        output.append(entry)

    payload = {
        "schemaVersion": 1,
        "contentVersion": CONTENT_VERSION,
        "id": "hsk-legacy-600",
        "titleFr": "Référentiel HSK classique — 600 entrées",
        "standard": {
            "id": "HSK-legacy-2.0",
            "version": "2.0",
            "levels": [
                {"level": 1, "range": [1, 150], "cumulativeCount": 150},
                {"level": 2, "range": [151, 300], "cumulativeCount": 300},
                {"level": 3, "range": [301, 600], "cumulativeCount": 600},
            ],
        },
        "provenance": {
            "inventorySource": SOURCE_URL,
            "learnerGuideSource": SOURCE_GUIDE_URL,
            "sourceRetrieved": SOURCE_DATE,
            "sourceDescription": "Official 新 HSK vocabulary list; entries and rank boundaries are retained as factual reference.",
            "sourceDocumentSha256": "58471dfd0803281a3a6f85f8cc64360d22d38cfd75880e1c096c2f631b88501b",
            "editorialNote": "French glosses and pinyin presentation are original Polygo editorial metadata; traditionalHanzi is generated with OpenCC s2t phrase conversion; lesson scenes and examples are authored separately.",
            "licenseNote": "Use the official CTI list as a cited factual reference; do not treat this catalog as a copied textbook or lesson passage.",
        },
        "existingCourseMappings": [
            {"existingVocabularyID": "vocab-bu-keqi", "canonicalLexemeID": "hsk20-008"},
            {"existingVocabularyID": "vocab-xiexie", "canonicalLexemeID": "hsk20-126"},
            {"existingVocabularyID": "vocab-zaijian", "canonicalLexemeID": "hsk20-138"},
            {"existingVocabularyID": "vocab-ni", "canonicalLexemeID": "hsk20-074"},
            {"existingVocabularyID": "vocab-wo", "canonicalLexemeID": "hsk20-112"},
            {"existingVocabularyID": "vocab-jiao", "canonicalLexemeID": "hsk20-046"},
            {"existingVocabularyID": "vocab-shenme", "canonicalLexemeID": "hsk20-095"},
            {"existingVocabularyID": "vocab-mingzi", "canonicalLexemeID": "hsk20-068"},
            {"existingVocabularyID": "vocab-shi", "canonicalLexemeID": "hsk20-097"},
            {"existingVocabularyID": "vocab-na", "canonicalLexemeID": "hsk20-070"},
            {"existingVocabularyID": "vocab-zhongguo", "canonicalLexemeID": "hsk20-143"},
            {"existingVocabularyID": "vocab-ren", "canonicalLexemeID": "hsk20-086"},
            {"existingVocabularyID": "vocab-ne", "canonicalLexemeID": "hsk20-072"}
        ],
        "unmatchedExistingVocabularyIDs": [
            "vocab-ni-hao", "vocab-zao", "vocab-guo", "vocab-faguo"
        ],
        "entries": output,
    }
    destination = Path(__file__).resolve().parents[1] / "Content" / "authoring" / "hsk-legacy-600.json"
    destination.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {destination} ({len(output)} ranked lexemes)")


if __name__ == "__main__":
    main()
