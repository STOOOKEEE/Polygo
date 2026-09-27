# Statut d’intégration

Le bundle de contenu reste en `2026.10.0`. La refonte Tavi est publiée par
lots sur `feat/mobile-originale` ; sa validation native Mac et iPhone est
consolidée et son intégration dans `main` reste à faire. Le [rapport
QA](QA_REPORT.md) centralise les commits testés, résultats et limites, sans
assimiler une compilation à une validation des parcours.

## Roadmap — refonte Tavi

Les cases cochées ci-dessous désignent du travail implémenté et poussé sur
`feat/mobile-originale`, pas une version déjà publiée sur `main`.

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
  bloquant (7/8 ; correctif `1981952` non validé).
- [x] Mettre à jour le rapport QA et remplacer les captures historiques du
  dépôt par les preuves natives de la refonte validée.
- [ ] Intégrer et pousser la refonte sur `main` après validation complète,
  sans écraser le travail existant.

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

## Contrôles du bundle

Les contrôles de génération ci-dessous appartiennent à la livraison du
contenu ; la refonte ne régénère ni les leçons ni le catalogue.

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
- La suite portable actuelle compte 72 tests ; les résultats de la campagne
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
trois états distincts ; la publication sur `main` reste conditionnée à la
validation native complète.

Le conteneur Linux ne fournit ni Xcode, ni SwiftUI, ni SDK Apple. Les preuves
natives proviennent des runners Apple ; les limites d’accessibilité et de
Speech sur appareil sont explicitées dans le rapport QA. CloudKit reste
inactif : progression, pièces, dessins et enregistrements restent locaux.
