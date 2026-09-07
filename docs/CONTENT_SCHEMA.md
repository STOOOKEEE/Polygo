# Schéma de contenu Syllune

Ce document décrit le JSON embarqué de la première tranche de Polygo. Il complète les types CourseManifest, LessonDocument, LessonBlock, ExerciseSpec, VocabularyEntry, ReviewCard et AssetReference de docs/ARCHITECTURE.md. Le contenu est original et versionné ; il n'est pas copié d'une application existante.

## Arborescence et versions

Les ressources sont chargées depuis la racine Content/ du bundle :

~~~text
Content/
  manifest.json
  courses/mandarin-starter.json
  lessons/lesson-01.json
  lessons/lesson-02.json
  lessons/lesson-03.json
  media/audio/                  # réservé aux audios réellement livrés
  media/handwriting/            # guides réservés à l'agent écriture
~~~

Tous les documents JSON ont schemaVersion: 1 et contentVersion: "2026.09.0" à leur racine. Les dates ne sont pas nécessaires dans le contenu pédagogique de cette version. Les IDs sont des chaînes stables, opaques et indépendantes de l'ordre des tableaux : mandarin-starter, unit-01, lesson-01 à lesson-03, puis les familles vocab-*, ex-*, card-*, story-* et guide-*.

Le fichier Content/manifest.json est un ContentIndex et ne contient que les cours disponibles :

~~~json
{
  "schemaVersion": 1,
  "contentVersion": "2026.09.0",
  "courseIDs": ["mandarin-starter"],
  "defaultCourseID": "mandarin-starter"
}
~~~

Le cours est un catalogue. Son module unit-01 référence les trois documents de leçon dans leur ordre pédagogique. Les leçons sont chargées à la demande, sans index de tableau utilisé comme identifiant.

## Texte et mandarin

Un texte localisé est un objet de langue, par exemple { "fr": "Bonjour !" }. La version actuelle est éditorialisée en français ; une clé en ou une autre langue peut être ajoutée sans changer les IDs.

Chaque VocabularyEntry contient les formes suivantes :

| Champ | Règle |
| --- | --- |
| hanzi | forme simplifiée canonique |
| traditionalHanzi | forme traditionnelle correspondante, même si elle est identique |
| pinyin | pinyin accentué, avec un espace entre les syllabes quand cela aide la lecture |
| toneNumbers | un numéro par syllabe : 1 à 4, ou 0 pour le ton neutre |
| segmentation | une ou plusieurs unités sélectionnables avec surface, vocabularyID, pinyin et nature |
| partOfSpeech | valeur de l'enum d'architecture, par exemple verb, noun ou measureWord |
| meaning | sens français court et contextualisé |
| grammarNotes | patrons et explications utilisables dans la fiche mot |
| example | phrase originale avec caractères, pinyin et traduction |

Les tons lexicaux écrits et les réalisations en parole sont distingués. Ainsi, 你好 est écrit nǐ hǎo et porte [3, 3], avec une note signalant le sandhi habituel du premier troisième ton. 不客气 est présenté bú kèqi avec [2, 4, 0], car 不 change devant le quatrième ton et la dernière syllabe est neutre. Les cartes et les exercices affichent aussi les numéros afin que le pinyin ne soit pas la seule aide.

La préférence ChineseScript du profil choisit la graphie affichée. Le sens, le pinyin et l'ID restent les mêmes entre simplifié et traditionnel.

## Leçon et blocs

Chaque LessonDocument porte id, moduleID, order, un titre, un résumé, une durée estimée, des objectives, vocabulary, blocks et cards. Les objectifs ont un ID stable, une formulation observable et required.

Les variantes de LessonBlock utilisent un discriminant kind au même niveau que l'ID :

| kind | Champs principaux | Fonction |
| --- | --- | --- |
| introduction | title, body, audio | situation et point de langue |
| vocabulary | vocabularyIDs | mots montrés avant la récupération |
| dialogue | lines[] | mini-dialogue original, chaque ligne étant traduisible |
| reading | storyID, title, paragraphs[], comprehensionExerciseIDs | histoire courte lisible et questions |
| exercise | spec | une activité évaluée par le moteur |
| recap | vocabularyIDs, objectiveIDs | reprise de fin de leçon |

Un bloc exercice contient lui-même une spec discriminée par spec.kind. La forme normative est :

~~~json
{
  "kind": "exercise",
  "id": "block-l1-ex-meaning",
  "spec": {
    "kind": "choice",
    "header": {
      "id": "ex-l1-meaning",
      "prompt": {"fr": "Que signifie 你好 ?"},
      "instruction": {"fr": "Relie la forme chinoise à son sens."},
      "objectiveIDs": ["l1-greet-understand"],
      "required": true
    },
    "choices": [
      {"id": "meaning-hello", "label": {"fr": "Bonjour ; salut"}, "audio": null},
      {"id": "meaning-thanks", "label": {"fr": "Merci"}, "audio": null}
    ],
    "correctChoiceID": "meaning-hello"
  }
}
~~~

Les choix toneChoose et meaningChoose de la pédagogie sont représentés par kind: choice, avec une consigne et des labels qui donnent le profil de la tâche. wordOrder utilise des IDs de tuiles dans correctOrder ; fillBlank normalise le texte selon le contrat du moteur ; speaking donne une phrase de référence et des transcriptions acceptées ; handwriting donne un caractère, un nombre de traits attendu et l'auto-évaluation ; flashcard référence un cardID sans recopier la carte.

L'unité fournit les quantités prévues pour la tranche courante : 6 exercices dans lesson-01, 7 dans lesson-02 et 7 dans lesson-03. Chaque leçon a une activité de compréhension, une production orale, un tracé manuscrit, un dialogue, une introduction grammaticale et un récapitulatif. Les cartes sont disponibles depuis le parcours même quand la leçon ne contient pas une activité flashcard dédiée.

## Histoires

Les trois histoires sont inline dans leur ReadingBlock afin que le lecteur puisse fonctionner hors ligne sans catalogue de récits supplémentaire. Leur storyID est stable et chaque paragraphe possède hanzi, pinyin, traduction, segmentation et un id local. Les questions sont de vrais exercices choice référencés par comprehensionExerciseIDs et résolus dans les blocs de la même leçon.

| storyID | Titre | Situation |
| --- | --- | --- |
| story-hello-on-the-corner | Le premier échange | quatre formules de salutation |
| story-name-and-smile | Un nom, un sourire | demander et donner un nom |
| story-country-on-a-map | Deux pays sur une carte | demander et dire un pays |

Une segmentation peut laisser vocabularyID: null pour une ponctuation, un nom propre ou un mot de reprise encore hors du vocabulaire actif. Elle conserve alors le pinyin et la nature quand ils sont connus. Aucun paragraphe n'est un résumé ou un faux extrait : le chinois, sa lecture et sa traduction forment un texte complet, même très court.

## Cartes et réemploi

Chaque entrée nouvellement introduite a une ReviewCard dans sa leçon, avec vocabularyID, une face caractère et un verso pinyin/sens. Les IDs de carte sont dérivés du contenu (card-vocab-*) et non d'une position. Les tags unit-01, l'ID de leçon et le domaine (greetings, country, etc.) permettent les filtres de révision. Les mots réapparaissent dans les dialogues, histoires, phrases d'exemple et exercices des leçons suivantes ; un nouvel exemplaire de carte n'est pas créé pour une simple reprise.

La note de révision est choisie par l'interface parmi again, hard, good et easy, puis traitée par le scheduler SM-2 de l'architecture. Le JSON de contenu ne contient aucun état apprenant.

## Médias et repli audio

Un audio n'est référencé que lorsqu'un fichier réellement livré possède un AssetReference complet et son SHA-256. Dans cette première livraison, tous les champs audio sont null : aucun hash ou nom de fichier audio fictif n'est embarqué. Les textes, pinyin et transcriptions rendent les activités lisibles hors ligne. Le service audio pourra fournir une voix TTS réelle ou un asset enregistré plus tard ; cette substitution appartient à l'adaptateur audio et ne transforme pas une absence d'audio en promesse d'écoute hors ligne.

Les exercices manuscrits contiennent les IDs et chemins réservés guide-hanzi-ni, guide-hanzi-wo et guide-hanzi-guo sous media/handwriting/. L'agent écriture fournira ultérieurement les guides et remplacera sha256: "pending-writing-guide" par le hash du fichier livré. Cette sentinelle ne désigne aucun fichier et doit être signalée comme ressource en attente par le loader ; elle n'est jamais utilisée pour un audio. L'exercice reste praticable au MVP avec le canevas, le caractère cible et l'auto-évaluation quand le guide n'est pas encore disponible.

## Référentiel et honnêteté de difficulté

Le cours porte les tags HSK 1 et CEFR A1 comme repères de conception. Le cadre HSK est en transition au 7 septembre 2026 ; ces tags ne garantissent ni la couverture d'une liste CTI particulière ni un score d'examen. L'interface peut afficher « repère HSK 1 / A1 » et doit conserver le numéro de version du contenu. Les caractères et mots hors de la séquence immédiate sont soit signalés par une segmentation sans carte, soit gardés dans une phrase modèle courte ; ils ne gonflent pas le compteur de nouveautés de la leçon.

## Contrôles effectués

Le contrôle local de la livraison parse manifest.json, le cours et les trois leçons avec le parseur JSON de Node.js. Il vérifie ensuite :

- correspondance du cours par défaut, des IDs de leçons et du module unit-01 ;
- unicité des blocs et exercices dans chaque leçon ;
- existence des objectifs référencés par les exercices et les récapitulatifs ;
- existence des mots référencés par les blocs et des cartes ;
- résolution des questions de chaque histoire ;
- trois storyID distincts et les compteurs 6/7/7.

Résultat attendu et obtenu : lesson-01 (5 mots, 6 exercices, 1 histoire), lesson-02 (5 mots, 7 exercices, 1 histoire) et lesson-03 (6 mots, 7 exercices, 1 histoire), soit trois leçons et trois histoires valides. Les seules ressources non matérialisées sont les guides manuscrits explicitement réservés à l’agent écriture ; aucune ressource audio n’est déclarée disponible.
