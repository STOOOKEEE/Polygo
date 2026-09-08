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

Une release complète du parcours contient une introduction de quatre leçons,
puis les 90 leçons quotidiennes :

~~~text
Content/
  manifest.json
  courses/
    mandarin-starter.json
  lessons/
    lesson-01.json … lesson-04.json   # introduction protégée
    lesson-05.json … lesson-94.json   # jours 1 à 90
  authoring/                           # sources de release conservées dans le dépôt
    90-day-authoring.json              # pack assemblé donné au générateur
    90-day-allocation.json             # allocation et plan de référence
    preview-first-five.json            # jours 1 à 5
    90-day-authoring-days-06-45.json   # jours 6 à 45
    90-day-authoring-days-46-90.json   # jours 46 à 90
    hsk-legacy-600.json                # catalogue partagé
    hsk-legacy-examples-001-400.json   # exemples 1 à 400
    hsk-legacy-examples-401-600.json   # exemples 401 à 600
  assets/
    handwriting/
      guide-hanzi-ni.json
      guide-hanzi-wo.json
      guide-hanzi-guo.json
  media/
    audio/                             # seulement si des enregistrements existent
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
histoires. L'introduction est unit-01 avec lesson-01 à lesson-04. Les modules
du parcours quotidien sont :

| Module | Jours | Leçons |
| --- | ---: | ---: |
| unit-02 — Vie pratique | 1–12 | lesson-05–lesson-16 |
| unit-03 — Temps, études et santé | 13–24 | lesson-17–lesson-28 |
| unit-04 — Achats et déplacements | 25–36 | lesson-29–lesson-40 |
| unit-05 — Maison et communauté | 37–48 | lesson-41–lesson-52 |
| unit-06 — Études et travail | 49–60 | lesson-53–lesson-64 |
| unit-07 — Ville et voyage | 61–72 | lesson-65–lesson-76 |
| unit-08 — Météo, nature et loisirs | 73–82 | lesson-77–lesson-86 |
| unit-09 — Récits et opinions | 83–90 | lesson-87–lesson-94 |

Le jour 30 correspond à lesson-34, le jour 60 à lesson-64 et le jour 90 à
lesson-94. Ces leçons restent des leçons ordinaires dans le bundle ; le statut
de checkpoint vient de CoursePlan et de l'allocation.

## Plan quotidien de 15 minutes

Le champ plan est facultatif pour les anciens cours. Pour le parcours complet,
il contient :

| Champ | Type | Contrat |
| --- | --- | --- |
| targetMinutes | entier | 15 |
| catalogID | chaîne optionnelle | ID du catalogue de progression, ici hsk-legacy-600 |
| catalogVersion | chaîne optionnelle | version du payload, ici 2026.09.0 |
| sessions | tableau | 90 entrées contiguës, jours 1 à 90 |
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
leçon (12 minutes dans les 90 leçons actuellement livrées) et
reviewMinutes vaut 15 moins courseMinutes. Les deux valeurs sont strictement
positives et leur somme vaut targetMinutes. Le budget quotidien est donc
12 + 3 = 15 pour les jours 1 à 90. Ce sont des budgets éditoriaux destinés à
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
[1, 300], peut préciser la frontière contrôlée ; le type Swift ne l'utilise pas,
mais le linter vérifie que les entrées jusqu'au rang annoncé sont effectivement
couvertes.

Les jalons livrés portent les couvertures suivantes :

| Jour | Couverture |
| ---: | --- |
| 30 | rangs 1–300 du catalogue hsk-legacy-600 |
| 60 | consolidation et réemploi, sans nouvelle cible numérique |
| 90 | rangs 1–600 du catalogue hsk-legacy-600 |

claims décrit une planification éditoriale. Une exposition lexicale, une carte
réussie ou une leçon terminée ne doit pas être reformulée en maîtrise, niveau
acquis ou score d'examen.

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
entrées de catalogue suivent vocab-hsk20-001 à vocab-hsk20-600. Les quatre
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

Le générateur abaisse chaque note grammar d'un fragment en un
IntroductionBlock autonome. Son ID suit block-lesson-XX-grammar-01, son titre
reprend le patron et son body conserve l'explication puis, pour chaque exemple,
les caractères, le pinyin et la traduction. Une note de grammaire de séance ne
modifie pas l'entrée lexicale réutilisée.

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

Une activité quotidienne complète contient deux choix (dont la compréhension de
lecture), un ordre de mots, un texte à trous, une écoute et une production
orale. Les leçons d'introduction ajoutent selon le besoin les activités
handwriting et flashcard.

Les noms historiques toneChoose, meaningChoose, sentenceOrder, listenChoose,
speakPrompt, writeCharacter et reviewRecall sont acceptés au décodage comme
alias ; les packs actuels utilisent les noms canoniques du tableau. Les
variantes ouvertes sont explicitement inscrites dans acceptedAnswers,
acceptedTranscripts ou une extension acceptedVariants. Une transcription ou
une auto-évaluation ne devient pas un score de prononciation. L'exercice oral
est required: false lorsqu'aucun service de prononciation n'est configuré et
peut être skipped.

Une écoute utilise promptAudio seulement si un enregistrement livré est
référencé. En l'absence d'un tel fichier, promptText donne le texte Mandarin au
service TTS local. Ce repli permet la tâche d'écoute ; il ne déclare pas un
audio hors ligne.

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
trois milestones, le plan et 90 lignes lessons. Une ligne d'allocation contient
notamment :

~~~json
{
  "day": 6,
  "lessonID": "lesson-10",
  "moduleID": "unit-02",
  "theme": "home",
  "phase": "classic-1-300",
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
  },
  "checkpoint": false
}
~~~

Les valeurs de newCount de cet extrait sont illustratives ; le linter
recalcule la couverture à partir des leçons et du catalogue. Les rangs 1–300
sont planifiés au jour 30, puis les rangs 301–600 jusqu'au jour 90. Le jour 60
est un bilan de consolidation. Les mots réutilisés et les mots de contexte
restent distincts des nouvelles entrées canoniques.

## Fragments d'authoring et assemblage

Les sources sont volontairement séparées afin que les scènes et l'allocation
puissent être relues sans reconstruire les phrases :

| Fichier | Contenu |
| --- | --- |
| preview-first-five.json | cours de départ et jours 1–5, leçons lesson-05–lesson-09 |
| 90-day-authoring-days-06-45.json | leçons lesson-10–lesson-49, plage d'allocation 6–45 |
| 90-day-authoring-days-46-90.json | leçons lesson-50–lesson-94, budgets et overrides de la plage 46–90 |
| 90-day-allocation.json | ordre, modules, cibles de rang, jalons et budgets communs |
| 90-day-authoring.json | résultat vérifié de l'assemblage des trois fragments |
| hsk-legacy-examples-*.json | exemples de phrases par plage de rang du catalogue |

Le pack assemblé possède schemaVersion, contentVersion, course, catalog, modules
et lessons. Chaque blueprint de leçon conserve id, moduleID, order, title,
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

Une note de grammaire d'authoring a la forme :

~~~json
{
  "vocabularyID": "hsk20-098",
  "pattern": "在 + lieu",
  "explanation": {"fr": "在 se place après le sujet et avant le lieu."},
  "examples": [
    {
      "hanzi": "手机在桌子上。",
      "pinyin": "shǒu jī zài zhuō zi shàng。",
      "translation": {"fr": "Le téléphone est sur la table."}
    }
  ]
}
~~~

Un blueprint utilise vocabularyIDs pour le catalogue et extraVocabulary pour
les mots de contexte. Le tableau exercises conserve les champs de la famille
choisie ; le générateur ajoute ensuite le header, le kind et l'ExerciseBlock au
document runtime.

La chaîne de release est :

~~~text
python3 Tools/build_90_day_authoring.py
python3 Tools/build_authoring_days_06_45.py
python3 Tools/build_authoring_days_46_90.py
python3 Tools/assemble_90_day_authoring.py
python3 Tools/content_tool.py generate \
  --input Content/authoring/90-day-authoring.json --root Content
python3 Tools/content_tool.py lint --root Content
~~~

Les quatre leçons lesson-01 à lesson-04 sont protégées : le générateur les
conserve et ajoute les leçons quotidiennes dans leurs modules. L'assemblage
échoue si une plage ne contient pas exactement les IDs attendus, si un module
ou un budget diverge de l'allocation, ou si les 90 jours ne sont pas contigus.
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

Le catalogue et les fiches utilisent le pinyin accentué, avec des espaces entre
les syllabes : xué shēng, ěr duo. hsk n'est jamais une valeur de pinyin.
toneNumbers contient un nombre par syllabe : 1 à 4 pour le ton lexical et 0
pour une syllabe neutre. La fiche de vocabulaire conserve la lecture lexicale
de l'entrée, tandis qu'un exemple, un dialogue ou une lecture peut représenter
une réalisation contextuelle.

Le changement de ton de 不 et 一 est donc écrit dans les phrases lorsqu'il est
retenu par l'édition (bú, bù, yí, yì selon le contexte), sans réécrire la fiche
canonique. Le troisième ton de 你好 reste nǐ hǎo [3,3] dans l'entrée lexicale,
même si le premier troisième ton est souvent réalisé comme un deuxième ton en
parole continue. Les syllabes légères sont marquées lexicalement quand la
lecture est relue : 吗 ma [0], 妈妈 mā ma [1,0], 妻子 qī zi [1,0],
故事 gù shi [4,0], 耳朵 ěr duo [3,0]. Le neutre n'est pas produit par une
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
| guide-hanzi-ni | assets/handwriting/guide-hanzi-ni.json | 98b4465294f36f88570a3e89ca10dd1924f773b6448a32f910cc838f46aa42a9 |
| guide-hanzi-wo | assets/handwriting/guide-hanzi-wo.json | 3c8c827dae6b75a1cf21ae6f2d0131034a0e0b8a532a68087b162f6600aed4d7 |
| guide-hanzi-guo | assets/handwriting/guide-hanzi-guo.json | 09615063ef8928bf0c07de2c31965be525f4487b7bcc97c3483a57093f34a782 |

Le lot quotidien n'invente pas de fichiers audio. Ses champs audio sont null
tant qu'un enregistrement et son hash ne sont pas livrés. promptText reste la
source du TTS local pour les exercices d'écoute ; une voix TTS ne devient pas
une AssetReference hors ligne.

## Contrôles avant publication

python3 Tools/content_tool.py lint --root Content vérifie le JSON généré, les
versions, les IDs de cours, modules, leçons, blocs et exercices, les objectifs,
les références lexicales, les cartes, les questions de lecture et les assets.
Lorsqu'un catalogue est présent, il vérifie ses 600 rangs contigus, son
référentiel HSK-legacy-2.0 / 2.0, les sidecars, les formes et les cibles
canoniques du plan. Il vérifie aussi les 90 sessions, la règle
courseMinutes = estimatedMinutes, les budgets de 15 minutes et les frontières
de rang des jours 30 et 90.

Une release peut afficher une référence, une exposition ou une progression
éditoriale. Elle ne doit pas afficher ces champs comme une maîtrise, un niveau
acquis ou un résultat d'examen.
