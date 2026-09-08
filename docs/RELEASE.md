# Checklist de release

Ce document décrit la préparation du candidat Syllune `2026.10.0`. Le fichier
[`project.yml`](../project.yml) est la source du projet Apple ;
`Polygo.xcodeproj` est généré par XcodeGen. Le bundle final suit HSK classique /
legacy `HSK-legacy-2.0` / `2.0`. HSK 3.0 `2025-11` reste une référence de
conception séparée, explicitement marquée `design-reference-only`.

## État du candidat

- Le cours contient 94 leçons dans 9 unités : 4 leçons d’introduction
  protégées et 90 séances planifiées.
- Le contenu contient 567 exercices (27 introduction + 540 programme), 94
  histoires inline, 196 paragraphes et 605 cartes distinctes (600 canoniques +
  5 extras). Les 911 associations leçon–carte sont fermées par le générateur.
- Chaque séance quotidienne vise 15 minutes : 12 minutes de cours et 3 minutes
  de révision. La couverture vérifiée est 300/300 rangs au jour 30 et 600/600
  rangs au jour 90 ; ces comptes décrivent le contenu planifié, pas une preuve
  d’acquisition.
- Le recto des nouvelles cartes affiche uniquement le hanzi ; pinyin et sens
  français sont au verso. Les 270 exercices à choix conservent IDs et réponses,
  avec une rotation déterministe des options basée sur le jour et la position de
  l’exercice.
- Les quatre fixtures d’introduction conservent exactement leur payload
  apprenant, leurs cartes et leurs réponses par rapport à HEAD ; seule la
  version de contenu commune est actualisée de `2026.09.0` à `2026.10.0`.
- Les sidecars d’exemples couvrent les 600 entrées ; les corrections finales
  comprennent `我今天很快乐。`, « J’ai une gêne au nez. » et « C’est un bon
  endroit. ».
- Les trois guides de tracé livrés sont `你`, `我` et `国`. Aucun audio de
  référence n’est embarqué.

## Contrôles réalisés

- [x] Assembler `Content/authoring/90-day-authoring.json` depuis les fragments
  preview, jours 6–45 et jours 46–90.
- [x] Régénérer le bundle avec `Tools/content_tool.py generate` et passer
  `Tools/content_tool.py lint --root Content`.
- [x] Vérifier les 90 sessions, les budgets 12+3, les jalons J30/J60/J90 et la
  couverture 300/300 puis 600/600 du catalogue `hsk-legacy-600`.
- [x] Vérifier l’unicité des identifiants : 94 histoires et 196 paragraphes,
  sans doublon global.
- [x] Comparer les quatre leçons protégées et leurs cartes avec HEAD ; les
  identifiants, ordre, objectifs, vocabulaire, blocs et réponses sont stables.
- [x] Vérifier les 270 choix : aucune réponse correcte n’est imposée par une
  convention de position, tout en conservant `correctChoiceID`.
- [x] Exécuter `swift test --parallel` : **55/55** tests portables réussis,
  dont 12 contrats de contenu.
- [x] Exécuter `git diff --check`.
- [x] Ajouter `Tools/__pycache__/` et `*.pyc` aux exclusions Git ; vérifier
  l’absence de secrets, certificats, profils, bases locales et artefacts
  machine dans le périmètre.
- [x] Finaliser le workflow Apple automatique sur `ac1daee` : le [run
  34261316153](https://github.com/STOOOKEEE/Polygo/actions/runs/34261316153) a
  validé le package à **55/55**, les **8 méthodes UI iOS (8/8)** et les **5
  méthodes UI macOS (5/5)**.

## Accès direct et tests natifs préparés

`AppModel.dailyPlanSession` dérive la séance depuis les complétions persistées,
et `TodayView` l’ouvre via `home.primaryAction`. Avec les quatre complétions
fixtures, la route ouvre directement `lesson-05`; après L5 elle affiche le jour
2. Le test iOS `DailyPlanJourneyTests` et le test macOS
`MacDailyPlanJourneyTests` couvrent cette route, l’écoute, la reprise après
relance, le passage oral optionnel et la fin de séance.

`MacShortReviewSessionJourneyTests` prépare 16 cartes dues, vérifie le plafond
de dix cartes, évalue exactement la tranche annoncée et laisse la file
complète accessible par « Poursuivre ». Les réponses de test sont cherchées par
ID correct ; elles ne dépendent pas de leur position dans la liste.

Les sources contiennent 8 méthodes UI iOS et 5 méthodes UI macOS. Elles attachent
les captures de la séance quotidienne et de la session courte avec XCTest. Les
captures déjà archivées sont :

- [parcours macOS](screenshots/roadmap-macos-dark.png) — 1600 × 900,
  SHA-256 `98b21d6cab2d9026341fe49e04b3fdd6def2c2fb527046bc9d1fc3168e40f132` ;
- [dialogue macOS](screenshots/dialogue-macos-dark.png) — 1600 × 900,
  SHA-256 `0f816f4fe790409c88ca8776d714e0362dd6608cfbab8364b8a3632709391859` ;
- [écriture guidée iOS](screenshots/handwriting-guided-ios.png) et
  [reprise iOS](screenshots/handwriting-retry-ios.png).

Le run Apple canonique a produit les captures macOS de la séance quotidienne
(J1, écoute, lecture, retour au parcours et J2) et de la session courte. Le
bundle xcresult iOS du même run conserve les captures du parcours. Le conteneur
Linux ne fournit ni Xcode, ni SwiftUI, ni SDK Apple. Les builds Apple,
les méthodes UI, l’audit VoiceOver/Dynamic Type, les permissions Speech et les
fenêtres étroites restent des contrôles du runner ou de l’appareil.

## Génération et builds Apple

Sur un Mac équipé des SDK iOS 17 et macOS 14 :

```sh
xcodegen generate --spec project.yml
xcodebuild -list -project Polygo.xcodeproj

xcodebuild -project Polygo.xcodeproj -scheme PolygoApp \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project Polygo.xcodeproj -scheme PolygoMacApp \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
```

Le [run Apple 34261316153](https://github.com/STOOOKEEE/Polygo/actions/runs/34261316153)
sur `ac1daee` a exécuté `PolygoMacUITests` (**5/5**) et le package (**55/55**).
`PolygoAppUITests` a exécuté les **8 méthodes iOS (8/8)** ; le bundle xcresult et
ses captures sont disponibles. Les runs historiques
[34225700577](https://github.com/STOOOKEEE/Polygo/actions/runs/34225700577) et
[34222443020](https://github.com/STOOOKEEE/Polygo/actions/runs/34222443020)
restent documentés comme preuves de commits antérieurs, sans être présentés
comme la validation de ce candidat.

## Contrôles produit restants

- [ ] Tester onboarding, leçons, histoires, cartes et navigation sur iPhone et
  iPad.
- [ ] Tester navigation, clavier et redimensionnement sur macOS 14.
- [ ] Tester une voix Mandarin installée puis absente ; l’absence doit rester
  récupérable.
- [ ] Tester microphone et Speech autorisés, refusés et indisponibles ;
  `skipped` et « Passer sans évaluer » doivent rester disponibles.
- [ ] Vérifier VoiceOver, Dynamic Type, contraste, mode sombre et toucher manuel
  sur iPhone, iPad et Mac.
- [x] Vérifier que l’état des réglages reste « Sur cet appareil » : CloudKit est
  planifié mais inactif.

## Signature et distribution futures

Avant une archive distribuable, il faut encore définir le numéro de build,
renseigner l’équipe Apple et les identifiants de signature hors Git, confirmer
les bundle IDs, vérifier les descriptions microphone/Speech, choisir le canal
macOS, puis tester TestFlight ou la notarisation. Les entitlements CloudKit ne
devront être ajoutés qu’avec une synchronisation effectivement livrée et testée.
