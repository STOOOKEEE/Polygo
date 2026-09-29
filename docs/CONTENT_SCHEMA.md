# Schéma de contenu Polygo

Ce document décrit le JSON que PolygoCore charge et le lien avec les sources
d'authoring du programme **Mandarin au quotidien**. Il complète
[ARCHITECTURE.md](ARCHITECTURE.md), [CONTENT_AUTHORING.md](CONTENT_AUTHORING.md),
[PEDAGOGY.md](PEDAGOGY.md) et [SRS.md](SRS.md).

Le dépôt contient deux niveaux de données :

- les fragments d'authoring portent les textes, l'allocation et les décisions
  éditoriales ;
- le générateur les abaisse en documents Content conformes aux types Swift
  ContentIndex, CourseManifest, LessonDocument, LessonBlock, ExerciseSpec,
  VocabularyEntry, ReviewCard et AssetReference.

Le générateur ne fabrique aucun caractère, pinyin, exemple, traduction, scène,
réponse ou audio. Il résout les références, ajoute les métadonnées de catalogue
nécessaires aux contrôles et vérifie les liens avant d'écrire le bundle.

## Bundle chargé par l'application

Une release complète du parcours contient le module 0 « Pinyin et tons » (huit
leçons d'écoute), une introduction de quatre leçons, puis les 66 leçons
quotidiennes et les 16 révisions et défis d'unité qui s'y intercalent :

~~~text
Content/
  manifest.json
  courses/
    mandarin-starter.json
  lessons/
    pinyin-01.json … pinyin-08.json   # module 0, unit-00 : pinyin et tons à l'oreille
    lesson-01.json … lesson-04.json   # introduction protégée
    lesson-05.json … lesson-70.json   # 66 leçons du jour
    review-01.json … review-08.json   # une révision après la cinquième leçon de chaque unité
    boss-unit-02.json … boss-unit-09.json  # un défi à la fin de chaque unité
  authoring/                           # sources de release conservées dans le dépôt
    pinyin-module.json                 # module 0 écrit à la main, lu par le générateur
    90-day-authoring.json              # pack assemblé donné au générateur
    90-day-allocation.json             # allocation et plan de référence
    preview-first-five.json            # jours 1 à 5
    90-day-authoring-days-06-45.json   # jours 6 à 45
    90-day-authoring-days-46-66.json   # jours 46 à 66
    hsk-legacy-600.json                # catalogue partagé (référentiel de 600 entrées, 300 enseignées)
    hsk-legacy-examples-001-400.json   # exemples 1 à 400
    hsk-legacy-examples-401-600.json   # exemples 401 à 600
  assets/
    handwriting/
      ARPHICPL.TXT                     # licence des médianes Make Me a Hanzi
      guide-hanzi-ni.json
      guide-hanzi-wo.json
      guide-hanzi-guo.json
    audio/
      KOKORO-LICENSE.TXT               # licence Apache 2.0 et attribution Kokoro
      <sha256-24>.m4a                  # un clip par (voix, texte, pinyin), voir AUDIO.md
~~~

JSONContentStore lit manifest.json, les cours, les leçons et les assets
référencés. Les fichiers authoring sont des entrées de la chaîne de release ;
ils ne sont pas des documents de leçon chargés directement par l'application.
Aucun dossier stories n'est requis : en son absence, le store dérive l'index
des histoires à partir des ReadingBlock inline.

Tous les documents runtime utilisent schemaVersion: 1. Leur contentVersion doit
être identique à celui de manifest.json. Le pack complet est éditorialisé en
2026.10.0. Le catalogue hsk-legacy-600 possède sa propre version de payload
2026.09.0 ; cette version est référencée par le plan et les métadonnées de
vocabulaire, et ne remplace pas la version du bundle runtime.

Les IDs sont des chaînes stables, non vides et indépendantes de la position dans
un tableau. Une release ne renumérote pas une leçon parce qu'un jour a été
manqué ou qu'une nouvelle leçon est ajoutée.

## Index et manifeste de cours

Le fichier manifest.json est un ContentIndex :

~~~json
{
  "schemaVersion": 1,
  "contentVersion": "2026.10.0",
  "courseIDs": ["mandarin-starter"],
  "defaultCourseID": "mandarin-starter"
}
~~~

courseIDs doit contenir chaque cours présent sous courses/, et
defaultCourseID doit être l'un de ces IDs. Des clés de release comme metadata
peuvent accompagner cet objet ; elles sont ignorées par le type runtime V1 et ne
remplacent pas les quatre champs normatifs.

Un fichier courses/{courseID}.json est un CourseManifest :

~~~json
{
  "schemaVersion": 1,
  "contentVersion": "2026.10.0",
  "id": "mandarin-starter",
  "slug": "mandarin-starter",
  "title": {"fr": "Mandarin au quotidien — parcours de 90 jours"},
  "description": {"fr": "Un parcours de 90 séances ..."},
  "alignment": [
    {
      "framework": "HSK",
      "level": "classic 2.0 / legacy",
      "standardID": "HSK-legacy-2.0",
      "standardVersion": "2.0",
      "status": "reference-transition"
    }
  ],
  "modules": [
    {
      "id": "unit-02",
      "order": 2,
      "title": {"fr": "Vie pratique"},
      "lessonIDs": ["lesson-05", "lesson-06"]
    }
  ],
  "plan": {
    "targetMinutes": 15,
    "catalogID": "hsk-legacy-600",
    "catalogVersion": "2026.09.0",
    "sessions": [],
    "milestones": []
  }
}
~~~

LocalizedText est sérialisé comme une mappe plate de langues, par exemple
{"fr": "Bonjour !"}. Le décodeur accepte aussi la forme interne
{"values": {"fr": "Bonjour !"}} pour compatibilité ; les nouvelles sources
utilisent la forme plate.

Chaque CurriculumTag contient framework, level, standardID, standardVersion et
éventuellement status. Le parcours quotidien compte les lexèmes selon
HSK-legacy-2.0 / 2.0. Les repères HSK 3.0 et CECR peuvent être conservés
séparément dans l'alignement d'une release, avec leur version ; aucune liste
n'est fusionnée et aucun compteur de jours ne constitue une conversion de
niveau ou une promesse d'examen.

Un ModuleSummary contient id, order, title et lessonIDs. Les champs optionnels
displayName et level servent aux surfaces de navigation et à l'index des
histoires. Le module 0 est unit-00 (order 0, les seuls IDs `pinyin-01` à
`pinyin-08`), placé avant l'introduction unit-01 (lesson-01 à lesson-04). Les
modules du parcours quotidien sont :

| Module | Jours | Leçons du jour | Révisions | Défi |
| --- | ---: | --- | --- | --- |
| unit-00 — Pinyin et tons | 1–8 | pinyin-01–pinyin-08 | — | — |
| unit-02 — Vie pratique | 9–18 | lesson-05–lesson-12 | review-01 | boss-unit-02 |
| unit-03 — Temps, études et santé | 19–28 | lesson-13–lesson-20 | review-02 | boss-unit-03 |
| unit-04 — Journées bien remplies | 29–38 | lesson-21–lesson-28 | review-03 | boss-unit-04 |
| unit-05 — Achats et déplacements | 39–48 | lesson-29–lesson-36 | review-04 | boss-unit-05 |
| unit-06 — Études, travail et voyage | 49–58 | lesson-37–lesson-44 | review-05 | boss-unit-06 |
| unit-07 — Quartier et communauté | 59–68 | lesson-45–lesson-52 | review-06 | boss-unit-07 |
| unit-08 — Travail et habitudes | 69–79 | lesson-53–lesson-61 | review-07 | boss-unit-08 |
| unit-09 — Voyages, nature et loisirs | 80–90 | lesson-62–lesson-70 | review-08 | boss-unit-09 |

Les IDs des leçons du jour ne changent pas : la progression est indexée par ID.
Les révisions et les défis ont leurs propres IDs (`review-NN`, `boss-<unité>`).
Dans chaque module, `lessonIDs` suit l'ordre du parcours et le champ `order` des
leçons est leur position 1-based sur le parcours (unités par `order`, leçons dans
l'ordre de `lessonIDs`) : les huit leçons du module 0, puis les quatre
introductions, puis un jour de plan = un `order`, sans rapport avec le numéro de
l'ID. Le générateur réécrit cet `order` dans chaque leçon, protégées comprises, et
le linter le vérifie. Les leçons `lesson-34` et `lesson-64` (« Bilan » dans leur
titre) sont des leçons du jour ordinaires, avec leurs mots nouveaux ; les jours de
l'allocation (1 à 66) désignent les jours des 66 leçons avant l'insertion des
révisions et du module 0. Les jalons du plan sont replacés sur le défi qui clôt
l'unité de leur leçon puis décalés de huit jours : la couverture ne change pas
puisque révisions, défis et module 0 n'ajoutent aucun mot. Le jalon des 150
lexèmes tombe au jour 58 (`boss-unit-06`, après lesson-44) et celui des 300
lexèmes au jour 90 (`boss-unit-09`, après lesson-70).

## Plan quotidien de 15 minutes

Le champ plan est facultatif pour les anciens cours. Pour le parcours complet,
il contient :

| Champ | Type | Contrat |
| --- | --- | --- |
| targetMinutes | entier | 15 |
| catalogID | chaîne optionnelle | ID du catalogue de progression, ici hsk-legacy-600 |
| catalogVersion | chaîne optionnelle | version du payload, ici 2026.09.0 |
| sessions | tableau | 90 entrées contiguës, jours 1 à 90 (8 leçons du module 0, 66 leçons, 8 révisions, 8 défis) |
| milestones | tableau | jalons uniques dont le jour reste dans le plan |

Chaque entrée sessions a quatre champs :

~~~json
{
  "day": 1,
  "lessonID": "lesson-05",
  "courseMinutes": 12,
  "reviewMinutes": 3
}
~~~

Pour chaque jour du parcours, courseMinutes reprend estimatedMinutes de la
leçon (12 minutes dans les 66 leçons du jour et les révisions, 13 dans les défis
d'unité) et reviewMinutes vaut 15 moins courseMinutes. Les deux valeurs sont
strictement positives et leur somme vaut targetMinutes. Le budget quotidien est
donc 12 + 3 = 15, ou 13 + 2 = 15 pour un défi. Ce sont des budgets éditoriaux destinés à
cadrer la séance ; ils ne mesurent pas le temps réellement passé. Les
révisions sont choisies parmi les cartes SRS effectivement dues.

CoursePlan calcule le prochain jour à partir des IDs de leçons terminées ;
manquer une date ne valide ni la leçon ni le jalon suivant. CoursePlanSession
expose day, lessonID, courseMinutes, reviewMinutes et plannedMinutes. Les
fonctions orderedSessions, nextSession, currentDay, completedSessionCount et
milestone servent à la navigation ; elles ne créent pas d'état de contenu.

Un CourseMilestone contient day, id, title, reference optionnelle, coverage
optionnelle et claims. La référence du programme complet est :

~~~json
{
  "framework": "HSK",
  "level": "classic 2.0 / legacy",
  "standardID": "HSK-legacy-2.0",
  "standardVersion": "2.0"
}
~~~

VocabularyCoverage contient vocabularyTarget, éventuellement
newVocabularyTarget, catalogID, catalogVersion et canonicalOnly.
canonicalOnly doit être true. La clé éditoriale requiredRankRange, par exemple
[1, 150] ou [1, 300], peut préciser la frontière contrôlée ; le type Swift ne l'utilise pas,
mais le linter vérifie que les entrées jusqu'au rang annoncé sont effectivement
couvertes.

Les jalons livrés portent les couvertures suivantes :

| Jour | Couverture |
| ---: | --- |
| 58 | rangs 1–150 du catalogue hsk-legacy-600 (HSK classique 1) |
| 90 | rangs 1–300 du catalogue hsk-legacy-600 (HSK classique 1–2) |

claims décrit une planification éditoriale. Une exposition lexicale, une carte
réussie ou une leçon terminée ne doit pas être reformulée en maîtrise, niveau
acquis ou score d'examen.

## Révisions et défis d'unité

Dans chaque unité du plan, une révision suit chaque série de cinq leçons du jour
et un défi (« boss ») clôt l'unité ; un défi qui termine une série de cinq tient
lieu de révision. `unit-00` (module 0) et `unit-01` (les quatre introductions) n'ont
ni révision ni défi : la première est traitée à part (voir plus bas), la seconde
n'est pas planifiée. Ce sont des leçons ordinaires pour le décodeur Swift, avec
les IDs `review-NN` et `boss-<unité>` (`boss-unit-02`) ; la CI Swift et le linter
les reconnaissent à `metadata.lessonKind` (`review` ou `boss`) :

| Clé de `metadata` | Contrat |
| --- | --- |
| lessonKind | `review` ou `boss` (`pinyin` pour le module 0, voir plus bas) |
| reviewedLessonIDs | les 5 leçons qui précèdent la révision ; toutes les leçons du jour de l'unité pour un défi |
| newVocabularyIDs | toujours vide (`newVocabularyCount` vaut 0) |

Leur `vocabulary` reprend, sans les modifier, les entrées introduites par les
leçons couvertes (toutes pour une révision, cinq par leçon pour un défi) avec leurs
cartes ; leur bloc `dialogue` enchaîne de courts extraits (trois répliques) des
dialogues couverts, séparés pour les exercices de dialogue ; leur bloc
`introduction` liste les structures de grammaire couvertes avec l'exemple de
chaque note (`Exemple N : …`). Aucun texte chinois, pinyin ni traduction n'est
nouveau. Une révision compte 18 exercices et reprend les six types plus récents
(`matching`, `dictation`, `toneDiscrimination`, `translation`,
`conversationChoice`, `dialogueOrder`) ; un défi en compte 20, et sa dernière
phase est un dialogue à mener : écoute de répliques, choix de réponses,
traduction, mise en ordre et oral. Chaque bloc d'exercice porte
`metadata.sourceLessonID`, la plus ancienne leçon couverte qu'il interroge, et
chaque phase (`discover`, `guided`, `reuse`) commence par les leçons les plus
anciennes. Un défi dure 13 minutes de cours et 2 de révision SRS (une révision,
12 + 3).

## Module 0 : pinyin et tons

`unit-00` (« Pinyin et tons », `order` 0) compte huit leçons `pinyin-01` à
`pinyin-08` : les quatre tons et le ton neutre, les consonnes de base (b/p, d/t,
g/k, m f n l h), j q x et z c s, zh ch sh r, les voyelles et les finales
(-n / -ng), les enchaînements de tons (3e ton devant 3e ton, 不 et 一),
l'orthographe du pinyin (y, w, ü, iu ui un, apostrophe) et un bilan d'écoute.
Elles occupent les jours 1 à 8 du plan (12 + 3 minutes) et sont écrites à la main
dans `Content/authoring/pinyin-module.json` ; `content_tool.py generate` les
produit avec `Tools/pinyin_module.py`, à côté du pack des leçons du jour, sans le
modifier. Ce sont des leçons ordinaires pour le décodeur Swift, reconnues par
`metadata.lessonKind` = `pinyin` :

| Clé de `metadata` | Contrat |
| --- | --- |
| lessonKind | `pinyin` |
| newVocabularyIDs | toujours vide (`newVocabularyCount` vaut 0) : les mots sont enseignés par les leçons du jour |
| previewVocabularyIDs | les 6 à 8 mots que la leçon présente à l'avance, identiques (objet et carte) à ceux des leçons du jour |
| carriers | table `hanzi → pinyin` de tous les textes que la leçon fait entendre ou afficher (les « porteurs ») |

Chaque leçon a une ou plusieurs `introduction` (explication courte en français,
conseils concrets pour un francophone), un bloc `vocabulary`, 15 à 20 exercices
(18 dans les leçons livrées) répartis dans les trois phases `discover`, `guided` et
`reuse`, et un `recap`. Elle emploie au moins quatre types d'exercice
(`toneDiscrimination`, `dictation`, `listeningChoice`, `matching`, `choice`,
`speaking` auto-évalué), dont au moins 60 % d'écoute pure, et au moins quatre
exercices de paires minimales : `metadata.contrast` (`initial`, `final` ou
`tone`) d'un bloc d'exercice déclare que chaque distracteur ne diffère de la
bonne réponse que par ce trait. Aucun dialogue, aucune lecture ; aucun mot
nouveau : le module ne compte donc pas dans `newVocabularyIDs` des leçons du
jour ni dans la couverture des jalons.

Tout texte chinois lu par la synthèse vocale est un porteur : un caractère ou un
mot réel, avec son pinyin, listé une fois dans la table `carriers` du fichier
d'écriture. Les exercices nomment des porteurs sans jamais épeler de pinyin ;
le générateur en déduit les réponses (le ton d'un mot, le pinyin d'un
caractère). Le linter rejoue chaque réponse à partir de `metadata.carriers`
seul : tons lus sur les signes, 3e ton devant 3e ton dit comme un 2e ton
(`nǐ hǎo` s'entend `ní hǎo`), signes de ton bien placés, chaque syllabe proposée
attestée par un porteur (aucune syllabe inexistante n'est offerte), paires
minimales exactes, caractères à lectures multiples refusés comme texte lu.
`不` et `一` sont notés avec leur ton réel dans la phrase (`bú shì`, `yí ge`).

`check_structure` vérifie que le premier module du parcours ne contient que
ces huit leçons, dans l'ordre, et qu'elles sont les huit premiers jours du plan.

## Document de leçon généré

Chaque lessons/lesson-XX.json est un LessonDocument :

~~~json
{
  "schemaVersion": 1,
  "contentVersion": "2026.10.0",
  "id": "lesson-05",
  "moduleID": "unit-02",
  "order": 5,
  "level": "HSK classique 2",
  "title": {"fr": "Boire et manger"},
  "summary": {"fr": "Nommer une boisson et un plat."},
  "estimatedMinutes": 12,
  "objectives": [],
  "vocabulary": [],
  "blocks": [],
  "cards": []
}
~~~

level est optionnel et reste un libellé éditorial court, par exemple HSK
classique 2 ou HSK classique 3. Il n'est pas une preuve de couverture.

Un objectif généré contient id, statement et required. Dans un fragment
d'authoring, la clé équivalente est text ; le générateur la normalise vers
statement. Une phrase d'objectif doit décrire une action observable. Les
objectifs de compréhension, d'ordre, de production orale et d'écriture restent
des preuves distinctes.

Le tableau vocabulary contient les entrées locales de la leçon. Une entrée
réutilisée est recopiée avec le même ID et le même objet ; elle ne reçoit pas
une nouvelle carte parce qu'elle apparaît dans une phrase ultérieure. Les
entrées de catalogue suivent vocab-hsk20-001 à vocab-hsk20-600 ; le parcours
n'utilise que 001 à 300. Les quatre
leçons protégées gardent leurs IDs historiques et leurs cartes historiques.

## Blocs et textes

Le tableau blocks est une séquence ordonnée. La forme émise est plate, avec
kind au même niveau que id et les champs de la variante :

| kind | Champs | Rôle |
| --- | --- | --- |
| introduction | id, title, body, audio? | explication ou point de grammaire |
| vocabulary | id, vocabularyIDs | présentation du lexique de la séance |
| dialogue | id, lines, participation?, comprehensionExerciseIDs? | scène dialoguée |
| reading | id, storyID, level?, title, paragraphs, comprehensionExerciseIDs | lecture inline et question(s) |
| exercise | id, spec | activité évaluée par le moteur |
| recap | id, vocabularyIDs, objectiveIDs | rappel de fin de séance |

Le décodeur conserve la compatibilité avec une forme enveloppée sous value,
mais les documents générés utilisent la forme plate. Les IDs de blocs et
d'exercices sont uniques dans le bundle.

Une DialogueLine contient speaker, hanzi, pinyin, translation et audio?.
Une participation facultative porte prompt, audioLineIndex, acceptedResponses
et éventuellement hint.

Une ReadingParagraph contient id, hanzi, pinyin, translation, segmentation et
audio?. Les histoires du parcours quotidien sont complètes et inline dans les
ReadingBlock ; un storyID stable permet leur affichage dans l'explorateur sans
dupliquer un fichier de récit.

Le générateur abaisse chaque note grammar en un IntroductionBlock autonome. Son
ID suit block-lesson-XX-grammar-01, son titre est « Grammaire — » suivi du
patron et son body conserve l'explication, la formule (`Formule : …`), pour
chaque exemple `Exemple N : hanzi`, le pinyin et la traduction, puis la faute
fréquente (`Attention : …`). Une note de grammaire de séance ne modifie pas
l'entrée lexicale réutilisée.

Pour les 66 séances du jour, les notes viennent d'un syllabus unique,
`Content/authoring/grammar-syllabus.json` (30 notes, une toutes les deux ou trois
leçons de `lesson-05` à `lesson-68`) : voir CONTENT_AUTHORING.md, « Syllabus de
grammaire ». Le bloc de grammaire porte `metadata.grammarPointID` (l'ID de la note,
par exemple `gram-ma-question`) et la leçon un `grammarPoints` d'un élément
`{id, pattern, function, markers, errors}` (`pattern` est la formule, `function` le titre,
`markers` les mots qui portent la structure, `errors` la faute fréquente). Les deux
exercices de la note, `ex-l<N>-gram-1` (assemblage : `wordOrder` ou `translation`) et
`ex-l<N>-gram-2` (choix du mot : `fillBlank` ou `choice`), sont des blocs `exercise`
de la phase `guided` dont `metadata.grammarPointID` renvoie à la même note ; leur
réponse emploie un des `markers`. Ces clés de métadonnées sont, comme les autres, ignorées
par le décodeur Codable ; le contrat de contenu les vérifie.

## Exercices

Chaque ExerciseSpec possède un kind et un header. Le header contient id,
prompt, instruction, objectiveIDs et required. Les familles et leurs champs
sont :

| kind | Champs propres |
| --- | --- |
| choice | choices (id, label, audio?), correctChoiceID |
| wordOrder | tokens (id, hanzi, pinyin?, audio?), correctOrder |
| fillBlank | sentence, acceptedAnswers, caseSensitive |
| listeningChoice | promptAudio? ou promptText?, choices, correctChoiceID, replayLimit? |
| speaking | referenceText, referencePinyin, referenceAudio?, acceptedTranscripts, allowSelfRating |
| handwriting | targetHanzi, guideAsset, expectedStrokeCount?, allowSelfRating |
| flashcard | cardID |
| matching | pairs (id, left, pinyin?, right) |
| dictation | script (`pinyin` ou `hanzi`), promptAudio? ou promptText?, choices, correctChoiceID, replayLimit? |
| toneDiscrimination | promptAudio? ou promptText?, choices (id `t<tons>`), correctChoiceID, replayLimit? |
| translation | tokens (id, hanzi, pinyin?, audio?), correctOrder, acceptedOrders? |
| dialogueOrder | lines (id, speaker?, hanzi, pinyin?, audio?), correctOrder |
| conversationChoice | speaker?, promptAudio? ou promptText?, replies (id, hanzi, pinyin?, audio?), correctReplyID, replayLimit? |

Une activité quotidienne de départ contient deux choix (dont la compréhension de
lecture), un ordre de mots, un texte à trous, une écoute et une production
orale ; le générateur y ajoute les familles ci-dessous. Les leçons
d'introduction ajoutent selon le besoin les activités handwriting et flashcard.

Les six familles `matching`, `dictation`, `toneDiscrimination`, `translation`,
`dialogueOrder` et `conversationChoice` se décodent comme les autres, à plat
(`kind` + `header` + champs propres) :

* `matching` : 4 ou 5 paires. `left` est un mot chinois, `right` son sens
  français ou son pinyin ; `pinyin` accompagne `left` quand la paire ne le
  demande pas. La colonne de droite est mélangée de façon stable (rang dérivé de
  l'ID de l'exercice et de la paire) et n'est jamais dans l'ordre d'écriture. La
  réponse `ExerciseAnswer.matching(pairs:)` associe l'ID de chaque `left` à l'ID
  de la paire choisie à droite ; elle est correcte si toutes les paires sont
  bonnes, `partial` (score proportionnel, refusée) si certaines le sont, et
  `incorrect` sinon ;
* `dictation` : on écoute `promptText` (TTS local), puis on choisit comment il
  s'écrit : `script: "pinyin"` propose des pinyin, `script: "hanzi"` des
  caractères. La réponse est un `choice` ;
* `toneDiscrimination` : on écoute un mot d'une ou deux syllabes, puis on choisit
  son ton (1 à 4) ou son motif de deux tons. L'ID d'un choix épelle le motif
  (`t4`, `t42`, `t40` pour un ton neutre final) et doit être celui des
  `toneNumbers` du mot lu. Les mots dont la voix pourrait varier sont exclus :
  suite 3-3 (sandhi), 不, 一, syllabe neutre isolée, caractères polyphones ;
* `translation` : le `header.prompt` donne la phrase française ; `tokens`
  contient les tuiles de la phrase et au moins une tuile en trop ;
  `correctOrder` ne cite que les tuiles de la phrase et `acceptedOrders` d'autres
  suites complètes acceptées. La réponse est un `wordOrder` (mêmes tuiles et
  même évaluation que `wordOrder`, qui reste l'ordre sans distracteur) ;
* `dialogueOrder` : 2 à 4 `lines` consécutives du dialogue de la leçon,
  présentées mélangées ; `correctOrder` donne l'ordre du dialogue. Réponse
  `wordOrder` ;
* `conversationChoice` : on écoute la réplique `promptText` de `speaker`, puis
  on choisit parmi trois `replies` celle que le dialogue donne ensuite. Chaque
  réponse peut être écoutée avant d'être choisie (`audio`, sinon TTS). Réponse
  `choice` sur l'ID de la réponse.

Les noms historiques toneChoose, meaningChoose, sentenceOrder, listenChoose,
speakPrompt, writeCharacter et reviewRecall sont acceptés au décodage comme
alias ; les packs actuels utilisent les noms canoniques du tableau. Les
variantes ouvertes sont explicitement inscrites dans acceptedAnswers,
acceptedTranscripts ou une extension acceptedVariants. Une transcription ou
une auto-évaluation ne devient pas un score de prononciation. L'exercice oral
est required: false lorsqu'aucun service de prononciation n'est configuré et
peut être skipped.

Une écoute joue promptAudio, le clip embarqué de promptText. Sans clip (texte
d'une syllabe, invite de ton refusée par le contrôle de tons), promptText est
lu par le TTS local.

## Vocabulaire, scripts et cartes

Une VocabularyEntry générée contient :

| Champ | Règle |
| --- | --- |
| id | ID local stable, par exemple vocab-hsk20-010 |
| hanzi | forme simplifiée canonique |
| traditionalHanzi? | forme traditionnelle correspondante |
| pinyin | lecture accentuée de l'entrée |
| toneNumbers | un numéro par syllabe : 1–4 ou 0 neutre |
| segmentation | surfaces sélectionnables et vocabularyID? |
| partOfSpeech? | valeur de l'enum Polygo, par exemple noun, verb, measureWord |
| grammarNotes | notes lexicales facultatives |
| meaning | sens localisé, actuellement en français |
| audio? | AssetReference réel ou null |
| example? | caractères, pinyin, traduction et audio éventuel |
| memoryStory? | aide mnémotechnique localisée |

Les lignes issues du catalogue portent en plus canonicalID et metadata dans le
JSON de release. metadata reprend catalogID, catalogVersion, standardID,
standardVersion, rank et level. Ces clés sont des extensions de contrôle que le
décodeur Codable V1 ignore ; elles permettent au linter de relier un objet local
à son rang canonique. Une entrée extraVocabulary ne porte jamais canonicalID
et ne compte jamais dans les cibles de couverture.

Chaque carte est un ReviewCard avec id, vocabularyID, front, back et tags.
Une CardSide peut porter hanzi, pinyin, text et audio. Le générateur dérive une
nouvelle carte comme card- suivi de l'ID local, garde l'objet des cartes
protégées et évite les doublons globaux. Le JSON de contenu ne contient aucun
état SRS : date d'échéance, qualité, intervalle, facteur d'efficacité et lapses
appartiennent au journal de progression décrit dans SRS.md.

## Catalogue partagé et allocation

Le fichier Content/authoring/hsk-legacy-600.json est un catalogue de
progression, pas un document de cours copié. Il contient :

~~~json
{
  "schemaVersion": 1,
  "contentVersion": "2026.09.0",
  "id": "hsk-legacy-600",
  "titleFr": "Référentiel HSK classique — 600 entrées",
  "standard": {
    "id": "HSK-legacy-2.0",
    "version": "2.0",
    "levels": [
      {"level": 1, "range": [1, 150], "cumulativeCount": 150},
      {"level": 2, "range": [151, 300], "cumulativeCount": 300},
      {"level": 3, "range": [301, 600], "cumulativeCount": 600}
    ]
  },
  "provenance": {},
  "entries": []
}
~~~

Chaque entrée canonique contient id, rank, level, lexemeKey, sourceForm, hanzi,
traditionalHanzi, aliases, pinyin, toneNumbers, meaningFr et identity. Les
rangs sont contigus de 1 à 600. lexemeKey rend l'identité lexicale explicite ;
le générateur crée canonicalID à partir de cette clé et le préfixe local
vocab-hsk20- à partir de id.

existingCourseMappings relie les 13 entrées canoniques déjà représentées par
les quatre leçons d'introduction à leurs IDs historiques, par exemple :

~~~json
{
  "existingVocabularyID": "vocab-ni",
  "canonicalLexemeID": "hsk20-074"
}
~~~

Les IDs historiques sans correspondance exacte dans le catalogue restent des
entrées de la leçon et ne sont pas artificiellement renommés. Une référence
d'authoring peut utiliser l'ID catalogue (hsk20-010), le lexemeKey ou un ID de
vocabulaire déjà livré ; le générateur résout ces trois formes.

L'allocation 90-day-allocation.json est une source indépendante et lisible par
revue. Elle conserve courseID, le catalogue et ses frontières de rang, les
13 baselineCanonicalIDs, allocationPolicy, les huit modules quotidiens, les
deux milestones, le plan et 66 lignes lessons. Une ligne d'allocation contient
notamment :

~~~json
{
  "day": 6,
  "lessonID": "lesson-10",
  "moduleID": "unit-02",
  "theme": "home",
  "phase": "classic-1-150",
  "newVocabularyIDs": ["hsk20-006", "hsk20-013"],
  "reusedVocabularyIDs": ["hsk20-095"],
  "newCanonicalIDs": ["hsk20-006", "hsk20-013"],
  "reusedCanonicalIDs": ["hsk20-095"],
  "newCount": 2,
  "reusedCount": 1,
  "grammarTarget": {
    "patterns": ["在 + lieu"],
    "anchorCanonicalID": "hsk20-098",
    "reviewable": true
  }
}
~~~

Les valeurs de newCount de cet extrait sont illustratives ; le linter
recalcule la couverture à partir des leçons et du catalogue. Une séance
introduit trois à cinq mots nouveaux : les rangs 1–150 sont planifiés au plus
tard au jour 40 de l'allocation (phase `classic-1-150`, jours 1 à 40), puis le
reste des rangs 151–300 jusqu'au jour 66 (phase `classic-151-300`). Aucune
entrée de rang supérieur à 300 n'est planifiée. Dans `grammarTarget`,
`anchorCanonicalID` est un mot de la séance. Les mots réutilisés et les mots de
contexte restent distincts des nouvelles entrées canoniques.

## Fragments d'authoring et assemblage

Les sources sont volontairement séparées afin que les scènes et l'allocation
puissent être relues sans reconstruire les phrases :

| Fichier | Contenu |
| --- | --- |
| preview-first-five.json | cours de départ et jours 1–5, leçons lesson-05–lesson-09 |
| 90-day-authoring-days-06-45.json | leçons lesson-10–lesson-49, plage d'allocation 6–45 |
| 90-day-authoring-days-46-66.json | leçons lesson-50–lesson-70, budgets et overrides de la plage 46–66 |
| 90-day-allocation.json | ordre, modules, cibles de rang, jalons et budgets communs |
| 90-day-authoring.json | résultat vérifié de l'assemblage des trois fragments |
| hsk-legacy-examples-*.json | exemples de phrases par plage de rang du catalogue |

Le pack assemblé possède schemaVersion, contentVersion, course, catalog, modules,
lessons et reviewLessons. `Tools/assemble_90_day_authoring.py` y insère les
révisions et les défis d'unité (voir `Tools/review_lessons.py`) : il ajoute leurs
séances au plan, renumérote les jours et les `order`, replace les jalons et
recalcule les compteurs du cours. reviewLessons ne contient que les blueprints
des leçons dérivées ; `content_tool.py generate` en écrit les leçons à partir des
leçons du jour générées. Chaque blueprint de leçon conserve id, moduleID, order, title,
summary, estimatedMinutes, objectives, vocabularyIDs, grammar, dialogue,
reading, exercises et recap. level, extraVocabulary et metadata sont
facultatifs selon le fragment. metadata décrit l'allocation
(allocationDay, allocationRange, thème, nouveautés et réemploi) pour la revue ;
le générateur la conserve dans le document et l'enrichit avec les IDs locaux,
les compteurs de nouveautés, le référentiel et l'unité. Il ajoute aussi un
metadata éditorial à chaque bloc (étape, compétence et jour). Ces clés sont des
extensions lisibles par les outils de release ; le décodeur Codable V1 les
ignore. Les clés linguistiques restent dans le blueprint : le générateur ne
peut pas compléter un champ manquant à partir d'une glose.

Pour les 66 séances du jour (`lesson-05` à `lesson-70`), le `dialogue`, le `reading`,
l'`extraVocabulary` et les exercices `listen`, `speak` et `reading` du blueprint sont
remplacés à `generate` par la scène écrite à la main de
`Content/authoring/situations/unit-NN.json` ; le document généré porte alors
`metadata.situationAuthored: true` et compte 8 à 12 répliques de dialogue et 4 à 6
phrases de lecture (voir CONTENT_AUTHORING.md, « Situations écrites à la main »). Une
séance du jour sans scène est refusée par `generate` et par `lint`.

Une note de grammaire d'authoring (pack) a la forme :

~~~json
{
  "id": "gram-zai-location",
  "pattern": "在 : dire où l’on se trouve",
  "formula": "Sujet + 在 + lieu",
  "explanation": {"fr": "在 se place après le sujet et avant le lieu."},
  "examples": [
    {
      "hanzi": "手机在桌子上。",
      "pinyin": "shǒu jī zài zhuō zi shàng.",
      "translation": {"fr": "Le téléphone est sur la table."}
    }
  ],
  "mistake": {"fr": "Ne traduis pas « être » par 是 devant un lieu."}
}
~~~

`id`, `formula` et `mistake` sont facultatifs ; `pattern`, `explanation` et
`examples` sont obligatoires. Les notes des séances du jour s'écrivent dans le
syllabus, pas dans le pack.

Un blueprint utilise vocabularyIDs pour le catalogue et extraVocabulary pour
les mots de contexte. Le tableau exercises conserve les champs de la famille
choisie ; le générateur ajoute ensuite le header, le kind et l'ExerciseBlock au
document runtime. Il complète aussi les six exercices écrits par des exercices
dérivés du matériel de la leçon (`Tools/exercise_expansion.py`), pour un total de
15 à 20 exercices par leçon quotidienne, choisis pour que chaque mot nouveau
(huit au plus par leçon) soit présenté par trois exercices de trois familles, et
que chaque leçon utilise au moins quatre des six familles ci-dessus (six dans
le contenu actuel, cinq quand le dialogue n'a pas de question). Le `metadata.stage` de chaque bloc
d'exercice vaut `discover`, `guided` ou `reuse` et les phases se suivent dans
cet ordre ; voir CONTENT_AUTHORING.md, « Budget d'exercices » et « Mots
nouveaux par séance ».

La chaîne de release est :

~~~text
python3 Tools/build_90_day_authoring.py
python3 Tools/build_authoring_days_06_45.py
python3 Tools/build_authoring_days_46_66.py
python3 Tools/build_preview_authoring.py
python3 Tools/assemble_90_day_authoring.py
python3 Tools/content_tool.py generate \
  --input Content/authoring/90-day-authoring.json --root Content
python3 Tools/content_tool.py lint --root Content
~~~

Les quatre leçons lesson-01 à lesson-04 sont protégées : le générateur les
conserve et ajoute les leçons quotidiennes dans leurs modules. L'assemblage
échoue si une plage ne contient pas exactement les IDs attendus, si un module
ou un budget diverge de l'allocation, ou si les 66 jours ne sont pas contigus.
content_tool.py prépare une copie temporaire, la génère et la valide avant de
recopier les fichiers modifiés dans Content/.

## Exemples de catalogue en sidecar

Les exemples des 600 entrées sont relus dans deux sidecars, sans être déduits du
sens français. Chaque sidecar porte la version du catalogue et sa plage :

~~~json
{
  "schemaVersion": 1,
  "contentVersion": "2026.10.0",
  "catalog": {
    "id": "hsk-legacy-600",
    "contentVersion": "2026.09.0",
    "standardID": "HSK-legacy-2.0",
    "standardVersion": "2.0"
  },
  "range": [1, 400],
  "examples": {
    "hsk20-034": {
      "hanzi": "那只狗在门外。",
      "pinyin": "nà zhī gǒu zài mén wài。",
      "translation": {"fr": "Ce chien est devant la porte."}
    }
  }
}
~~~

Le générateur découvre les fichiers hsk-legacy-examples-*.json, les trie par
nom, vérifie qu'un ID n'apparaît qu'une fois et fusionne l'exemple dans la
ligne de catalogue avant de produire les entrées de leçon. Une clé audio ne
peut être ajoutée que si elle désigne un fichier livré.

## Pinyin, tons et graphies

Les fichiers d'écriture (catalogue, exemples, scènes, syllabus, module 0) notent
la lecture en pinyin accentué, une syllabe par hanzi (xué shēng, ěr duo) ou mot
par mot, au choix : seules comptent les syllabes. La clé `lexemeKey` /
`canonicalID` (`学生|xué shēng|128`) garde la forme syllabique du catalogue :
c'est un identifiant de progression, jamais affiché. hsk n'est jamais une
valeur de pinyin. toneNumbers contient un nombre par syllabe : 1 à 4 pour le
ton lexical et 0 pour une syllabe neutre. La fiche de vocabulaire conserve la
lecture lexicale de l'entrée, tandis qu'un exemple, un dialogue ou une lecture
peut représenter une réalisation contextuelle.

Tout pinyin que l'apprenant lit dans les leçons générées s'écrit comme le
prescrit GB/T 16159 ; `content_tool.py generate` le produit avec
`Tools/pinyin_format.py` à partir du hanzi et de ses syllabes, et `lint` refuse
tout autre forme :

* les syllabes d'un mot sont jointes, les mots séparés : `Huǒchēzhàn zài
  xuéxiào pángbiān.` Un mot est la plus longue entrée connue (catalogue,
  vocabulaire des leçons, `EXTRA_WORDS`), un nombre (`shíwǔ`, `yìbǎi`), 第 et
  son nombre (`dì-yī`) ; quelques expressions du catalogue s'écrivent en
  plusieurs mots (`PHRASES` : `nǐ hǎo`, `bú kèqi`, `dǎ diànhuà`). Les
  particules 的 了 吗 呢 吧 着 过 restent séparées (`kàn le`, `qù guo`), 们
  rejoint son nom (`péngyoumen`), un hanzi redoublé son double (`kànkan`), et
  une syllabe finale en r (erhua) son hanzi 儿 (`yíhuìr`) ;
* dans un mot, une syllabe qui commence par a, o ou e prend une apostrophe :
  `Xī'ān`, `nǚ'ér`, `shí'èr` ;
* la ponctuation est ASCII, sans espace avant et avec une espace après :
  ，、→ `,`, 。→ `.`, ？→ `?`, ！→ `!`, ：→ `:`, ；→ `;`, guillemets → `"` ;
* une phrase (texte qui finit par 。？！) commence par une majuscule, comme
  chaque phrase qui suit ; les noms propres (`PROPER_NOUNS` : `Běijīng`,
  `Zhōngguó`, `Fǎguó`, `Hànyǔ`…) et les prénoms (`Mina`, `Tao`, `An`, `Lin`)
  en prennent une partout. Un mot, une tuile, une carte ou un porteur du
  module 0 reste en minuscules.

Cela vaut pour le vocabulaire (et sa segmentation), ses exemples, les cartes
(`nǐ hǎo · 3-3` garde ses chiffres de ton), les dialogues, les lectures, les
tuiles, les paires, les répliques, `referencePinyin`, les choix de dictée en
pinyin (écrits comme le texte dont ils sont la lecture dans le cours), les
porteurs du module 0, et le pinyin cité dans le français : `学校 (xuéxiào)`,
`xuéxiào (学校, école)` et la ligne de pinyin sous chaque `Exemple N : …`. Un
pinyin cité sans hanzi dans une explication s'écrit directement mot par mot.
Les réponses acceptées (`acceptedVariants`, `acceptedTranscripts`) ne sont pas
réécrites : l'app compare une saisie sans espaces, accents, apostrophes, tirets
ni majuscules.

Le changement de ton de 不 et 一 est donc écrit dans les phrases lorsqu'il est
retenu par l'édition (bú, bù, yí, yì selon le contexte), sans réécrire la fiche
canonique. Le troisième ton de 你好 reste nǐ hǎo [3,3] dans l'entrée lexicale,
même si le premier troisième ton est souvent réalisé comme un deuxième ton en
parole continue. Les syllabes légères sont marquées lexicalement quand la
lecture est relue : 吗 ma [0], 妈妈 māma [1,0], 妻子 qīzi [1,0],
故事 gùshi [4,0], 耳朵 ěrduo [3,0]. Le neutre n'est pas produit par une
substitution globale.

Les formes traditionnelles sont conservées dans traditionalHanzi et produites
par conversion OpenCC phrase-aware s2t, puis contrôlées. Une paire
simplifiée/traditionnelle conserve le même ID canonique et le même rang. Le
choix ChineseScript modifie la graphie affichée, jamais le sens, le pinyin ou
la carte.

## Assets et audio

Une AssetReference contient id, kind, relativePath, sha256 et éventuellement
durationMilliseconds. kind vaut audio, image ou handwritingGuide. Le chemin est
relatif à Content/, reste dans cette racine et le store vérifie l'existence ainsi
que le SHA-256 avant de le fournir.

Les trois guides livrés sont :

| ID | Chemin | SHA-256 |
| --- | --- | --- |
| guide-hanzi-ni | assets/handwriting/guide-hanzi-ni.json | a4f80a7c3afae3f7bf666686bf8df6b42856ae4d9d6b7ce3a81487071cc1eeeb |
| guide-hanzi-wo | assets/handwriting/guide-hanzi-wo.json | f5ef08d920b4dc9d394fd8c9a4fbbbbf2309d0092c1ee0976b711055114d9a64 |
| guide-hanzi-guo | assets/handwriting/guide-hanzi-guo.json | b1273af6e93c964c2ef1ba0a4735e4d0a32552c2957f43b300e43f59ddbb196e |

Les champs audio sont gérés par `Tools/build_audio.py` et rattachés par
`content_tool.py generate` : chaque texte d'au moins deux syllabes (répliques,
paragraphes, mots, exemples, cartes, invites d'écoute, de dictée, de ton, de
conversation et modèles oraux) pointe vers `assets/audio/<hash>.m4a` avec son
SHA-256 et sa durée ; les autres restent null et utilisent le TTS local. Le
lint refuse une référence périmée ou absente et un clip orphelin. Voir
[AUDIO.md](AUDIO.md) pour les voix, la licence et la régénération.

## Contrôles avant publication

python3 Tools/content_tool.py lint --root Content vérifie le JSON généré, les
versions, les IDs de cours, modules, leçons, blocs et exercices, les objectifs,
les références lexicales, les cartes, les questions de lecture et les assets.
Lorsqu'un catalogue est présent, il vérifie ses 600 rangs contigus, son
référentiel HSK-legacy-2.0 / 2.0, les sidecars, les formes et les cibles
canoniques du plan. Il vérifie aussi les 90 sessions, les budgets de
15 minutes, les frontières de rang des jalons de 150 et 300 lexèmes, l'`order`
de chaque leçon (sa position sur le parcours) et les
révisions : une révision après chaque série de cinq leçons du jour, un défi à
la fin de chaque unité planifiée, aucun mot nouveau, 15 à 20 exercices pour une
révision et 18 à 20 pour un défi, tous les types plus récents dans une révision
et le dialogue à mener dans la dernière phase d'un défi, chaque phase
commençant par les leçons les plus anciennes. Pour le module 0, il rejoue les
réponses de chaque leçon `pinyin-NN` (voir « Module 0 : pinyin et tons »).

Une release peut afficher une référence, une exposition ou une progression
éditoriale. Elle ne doit pas afficher ces champs comme une maîtrise, un niveau
acquis ou un résultat d'examen.
