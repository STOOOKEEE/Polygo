# Statut d’intégration

Le bundle de contenu reste en `2026.10.0`. La refonte Tavi est publiée par
lots sur `feat/mobile-originale` ; sa validation native Mac et iPhone est
consolidée et la refonte est intégrée dans `main`. Le [rapport
QA](QA_REPORT.md) centralise les commits testés, résultats et limites, sans
assimiler une compilation à une validation des parcours.

## Roadmap — refonte Tavi

Les cases cochées ci-dessous désignent du travail implémenté et poussé sur
`feat/mobile-originale` puis intégré dans `main`, pas une version publiée.

### Implémentation poussée

- [x] Mascotte originale Tavi : accueil, encouragement et réussite.
- [x] Palette colorée claire/sombre, parcours sinueux et icônes de leçons.
- [x] Cinq destinations en barre basse sur Mac, iPhone et iPad, sans sidebar.
- [x] Masquage de la barre et du compteur pendant les exercices focalisés.
- [x] Dix pièces par première complétion historique, sans perte au
  recommencement ni second gain au rejeu.
- [x] Conservation des piles de navigation et accès aux réglages depuis Profil.
- [x] Correctif des raccourcis iPad par la chaîne UIKit (`b95438c`).
- [x] Ajustement des gestes de test aux pieds fixes et à la feuille du
  dictionnaire (`b0d065f`).

### Validation et livraison

- [x] Consolider les résultats de la [campagne du dernier lot
  b0d065f](https://github.com/STOOOKEEE/Polygo/actions/runs/36339541346) :
  package 72/72, Mac 9/9, iPhone 11/11. iPad AX5 hors périmètre, non
  bloquant (7/8). Le correctif `1981952` a cassé deux tests iPhone (run
  36344610436, bouton « Réglages » invisible) et a été annulé ; le raccourci
  iPad depuis une leçon reste une limite connue, hors périmètre.
- [x] Mettre à jour le rapport QA et remplacer les captures historiques du
  dépôt par les preuves natives de la refonte validée.
- [x] Intégrer et pousser la refonte sur `main` après validation complète,
  sans écraser le travail existant.

## Bundle et curriculum

| Élément | Compte livré |
| --- | ---: |
| Leçons disponibles dans le cours | 94 |
| Leçons d’introduction protégées | 4 (`lesson-01` à `lesson-04`) |
| Module 0 « Pinyin et tons » | 8 leçons d’écoute (`pinyin-01` à `pinyin-08`), jours 1 à 8 du plan |
| Séances du plan quotidien | 90 : 8 leçons du module 0, 66 leçons (`lesson-05` à `lesson-70`), 8 révisions (`review-01` à `review-08`), 8 défis d’unité (`boss-unit-02` à `boss-unit-09`) |
| Unités du cours final | 10 (`unit-00` à `unit-09`) |
| Exercices | 1 663 (27 introduction + 144 module 0 + 1 188 leçons du jour + 144 révisions + 160 défis) |
| Histoires inline | 70 |
| Paragraphes de lecture | 147 |
| Cartes distinctes | 313 (300 canoniques + 2 mots d’écoute du module 0 de rang supérieur + 11 extras) |
| Associations leçon–carte | 1 038 |
| Guides de tracé livrés | 3 (`你`, `我`, `国`) |

Le catalogue `hsk-legacy-600` contient 600 entrées de référence ; le parcours
n’en enseigne que 300, les rangs 1 à 300 (HSK classique 1–2). La couverture
réelle atteint les 150 premiers rangs au jour 58 (défi de l’unité 6) et les 300
rangs au jour 90 (défi de l’unité 9, dernier jour du parcours). Les 13 mots des
leçons de départ comptent dans les 300 ; les 287 autres sont répartis sur les
66 leçons du jour. Les rangs 301 à 600 ne sont ni enseignés ni comptés : seuls
`绿` et `蓝` (rangs 458 et 447) figurent encore, comme exemples d’écoute du
module 0. Chaque leçon du jour introduit trois à cinq mots nouveaux (4,36 en
moyenne) ; les révisions, les défis et le module 0 n’en introduisent aucun (le
module 0 présente à l’avance des mots que les leçons du jour enseignent).
Chaque séance est budgétée à 12 minutes de cours et 3 minutes de révision
(13 + 2 pour un défi). Le manifeste porte `availableLessonCount: 94`,
`starterLessonCount: 4`, `plannedSessionCount: 90` et
`canonicalVocabularyCount: 300` afin de distinguer le bundle complet du plan.

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

## Contrôles du bundle

Les contrôles de génération ci-dessous appartiennent à la livraison du
contenu ; la refonte ne régénère ni les leçons ni le catalogue.

- `python3 Tools/assemble_90_day_authoring.py` assemble 66 leçons, y insère 8
  révisions et 8 défis d’unité, et écrit 8 fragments de module.
- `python3 Tools/content_tool.py generate --input
  Content/authoring/90-day-authoring.json --root Content` régénère le bundle et
  exécute son contrôle de fermeture.
- `python3 Tools/content_tool.py lint --root Content` passe.
- La couverture indépendante vérifie 150/150 lexèmes aux rangs 1–150 au jour
  58 et 300/300 aux rangs 1–300 au jour 90.
- Les identifiants de paragraphes sont uniques (147/147). Les choix de type
  choix gardent leurs IDs et leurs bonnes réponses ; les 198 exercices
  `choice`/`listeningChoice` ont une position correcte répartie 64/64/70 entre
  les trois options après rotation déterministe.
- La suite portable actuelle compte 95 tests ; les résultats de la campagne
  Apple sont consignés dans le [rapport QA](QA_REPORT.md).
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

La CI exerce le vrai `AppModel` après des erreurs de persistance et les
parcours natifs Mac, iPhone et iPad AX5. Ses artefacts conservent les bundles
xcresult, captures et journaux du probe de récompenses.

## Validation Apple et limites

Les campagnes examinées et les correctifs restant à valider sont distingués
dans la roadmap ci-dessus et dans le [rapport QA](QA_REPORT.md). Une
modification poussée, une compilation réussie et un parcours UI validé sont
trois états distincts ; l’intégration dans `main` reprend le code de
`b0d065f` validé sur Mac et iPhone.

Le conteneur Linux ne fournit ni Xcode, ni SwiftUI, ni SDK Apple. Les preuves
natives proviennent des runners Apple ; les limites d’accessibilité et de
Speech sur appareil sont explicitées dans le rapport QA. CloudKit reste
inactif : progression, pièces, dessins et enregistrements restent locaux.
