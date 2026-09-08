# Statut d’intégration

Mis à jour le 2026-09-08 pour le candidat de contenu `2026.10.0`. Le commit
`ac1daee` est publié. Le [run Apple canonique
34261316153](https://github.com/STOOOKEEE/Polygo/actions/runs/34261316153) a
validé le package à **55/55**, les **8 méthodes UI iOS (8/8)** et les **5
méthodes UI macOS (5/5)**.

## Bundle et curriculum

| Élément | Compte livré |
| --- | ---: |
| Leçons disponibles dans le cours | 94 |
| Leçons d’introduction protégées | 4 (`lesson-01` à `lesson-04`) |
| Séances du plan quotidien | 90 (`lesson-05` à `lesson-94`) |
| Unités du cours final | 9 |
| Exercices | 567 (27 introduction + 540 programme) |
| Histoires inline | 94 |
| Paragraphes de lecture | 196 |
| Cartes distinctes | 605 (600 canoniques + 5 extras) |
| Associations leçon–carte | 911 |
| Guides de tracé livrés | 3 (`你`, `我`, `国`) |

Le catalogue `hsk-legacy-600` contient 600 entrées canoniques. La couverture
réelle atteint les 300 premiers rangs au jour 30 et les 600 rangs au jour 90 ;
le jour 30 contient une entrée canonique de rang supérieur pour une scène
naturelle. Chaque séance est budgétée à 12 minutes de cours et 3 minutes de
révision. Le manifeste porte `availableLessonCount: 94`, `starterLessonCount: 4`
et `plannedSessionCount: 90` afin de distinguer le bundle complet du plan.

L’alignement primaire du manifeste et du cours est
`HSK-legacy-2.0` / `2.0` (HSK classique). HSK 3.0 / `2025-11` est conservé
uniquement dans `standardReferences` et dans les champs `comparisonStandard*`,
avec le rôle `design-reference-only`. Il ne modifie ni le plan ni les jalons
livrés. Les exemples corrigés du sidecar comprennent `我今天很快乐。`, la
traduction française de `我的鼻子不舒服。` (« J’ai une gêne au nez. ») et celle
de `这里是一个好地方。` (« C’est un bon endroit. »).

Les quatre fixtures protégées d’introduction ont été comparées au payload HEAD :
identifiants, ordre, objectifs, vocabulaire, blocs, cartes, paires de scripts et
réponses sont identiques. Seule leur `contentVersion` passe de `2026.09.0` à
`2026.10.0`, pour rester compatible avec le manifeste commun.

## Contrôles locaux

- `python3 Tools/assemble_90_day_authoring.py` assemble 90 leçons et 8
  fragments de module.
- `python3 Tools/content_tool.py generate --input
  Content/authoring/90-day-authoring.json --root Content` régénère le bundle et
  exécute son contrôle de fermeture.
- `python3 Tools/content_tool.py lint --root Content` passe.
- La couverture indépendante vérifie 300/300 lexèmes aux rangs 1–300 au jour
  30 et 600/600 aux rangs 1–600 au jour 90.
- Les identifiants de paragraphes sont uniques (196/196). Les choix de type
  choix gardent leurs IDs et leurs bonnes réponses ; les 270 exercices
  `choice`/`listeningChoice` ont une position correcte répartie 92/90/88 entre
  les trois options après rotation déterministe.
- `swift test --parallel` passe à **55/55**, dont 12 contrats de contenu, avec
  le toolchain Swift 6 disponible dans l’environnement Linux.
- `git diff --check` passe. `Tools/__pycache__/` et les fichiers `.pyc` sont
  ignorés ; aucun secret, certificat, profil, base locale ou artefact machine
  n’est destiné au commit.

## Accès et parcours préparés

`AppModel.dailyPlanSession` appelle `CoursePlan.nextSession` à partir des
leçons réellement complétées. `TodayView` relie cette séance à
`home.primaryAction`, de sorte qu’un profil ayant terminé les quatre fixtures
ouvre directement `lesson-05`; après sa complétion, l’accueil propose la
séance du jour 2. Le test iOS
`DailyPlanJourneyTests.testDailyPlanOpensLessonFivePersistsListeningAnswerAndAdvancesToDayTwo`
et son équivalent macOS injectent le journal JSONL, ouvrent cette route,
restaurent l’écoute après relance, passent l’oral optionnel, terminent L5 et
vérifient J2.

Le test macOS
`MacShortReviewSessionJourneyTests.testTodayLimitsReviewThenLeavesRemainingCardsForContinuation`
prépare 16 cartes dues, vérifie la limite de dix cartes maximum liée au budget,
évalue exactement la tranche annoncée et vérifie la file restante. Les tests
résolvent les libellés via `correctChoiceID`, sans supposer une position de
réponse.

Les sources natives contiennent 8 méthodes UI iOS et 5 méthodes UI macOS. Le run
Apple canonique a attaché les captures macOS des parcours quotidiens et de
session courte ; son bundle xcresult conserve aussi les captures iOS du parcours.

## Validation Apple et limites

Le [run Apple canonique 34261316153](https://github.com/STOOOKEEE/Polygo/actions/runs/34261316153)
sur `ac1daee` a validé le package (**55/55**), les **8 méthodes UI iOS (8/8)**
et les **5 méthodes UI macOS (5/5)**. Le [run Apple 34225700577](https://github.com/STOOOKEEE/Polygo/actions/runs/34225700577)
a validé un état antérieur (`906135d`) : 47/47 tests package, 2/2 tests UI
macOS et 7/7 tests UI iOS. Le [run 34222443020](https://github.com/STOOOKEEE/Polygo/actions/runs/34222443020)
a validé deux parcours d’écriture iOS sur `249f6d0`. Ces deux runs restent des
preuves historiques ; le run canonique courant valide le pack Apple complet.

Le conteneur Linux ne fournit ni Xcode, ni SwiftUI, ni SDK Apple. Les builds
Apple, les 8 méthodes iOS, les 5 méthodes macOS, l’audit VoiceOver/Dynamic Type
et Speech avec permission accordée restent à exécuter sur runner ou appareil.
CloudKit est prévu mais inactif ; la progression, les dessins et les
enregistrements temporaires restent locaux.
