# Checklist de release

Ce document décrit la préparation du candidat Syllune `2026.10.0`. Le fichier
[`project.yml`](../project.yml) est la source du projet Apple ;
`Polygo.xcodeproj` est généré par XcodeGen. Le bundle final suit HSK classique /
legacy `HSK-legacy-2.0` / `2.0`. HSK 3.0 `2025-11` reste une référence de
conception séparée, explicitement marquée `design-reference-only`.

## État du candidat

- Le cours contient 94 leçons dans 10 unités : le module 0 « Pinyin et tons »
  (8 leçons d’écoute), 4 leçons d’introduction protégées et 90 séances
  planifiées (8 leçons du module 0, 66 leçons du jour, 8 révisions et
  8 défis d’unité). Le parcours enseigne 300 mots, les rangs 1 à 300 du
  catalogue (HSK classique 1–2), à raison de trois à cinq mots par leçon du jour.
- Le contenu contient 1 663 exercices (27 introduction + 144 module 0 + 1 188
  leçons du jour + 304 révisions et défis), 70 histoires inline, 147 paragraphes
  et 313 cartes distinctes (300 canoniques, 2 mots d’écoute du module 0 de rang
  supérieur et 11 extras). Les 1 038 associations leçon–carte sont fermées par le
  générateur.
- Chaque séance quotidienne vise 15 minutes : 12 minutes de cours et 3 minutes
  de révision. La couverture vérifiée est 150/150 rangs au jour 58 et 300/300
  rangs au jour 90 ; ces comptes décrivent le contenu planifié, pas une preuve
  d’acquisition.
- Le recto des nouvelles cartes affiche uniquement le hanzi ; pinyin et sens
  français sont au verso. Les 198 exercices à choix conservent IDs et réponses,
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
  preview, jours 6–45 et jours 46–66.
- [x] Régénérer le bundle avec `Tools/content_tool.py generate` et passer
  `Tools/content_tool.py lint --root Content`.
- [x] Vérifier les 90 sessions, les budgets 12+3, les jalons J58/J90 et la
  couverture 150/150 puis 300/300 du catalogue `hsk-legacy-600`.
- [x] Vérifier l’unicité des identifiants : 70 histoires et 147 paragraphes,
  sans doublon global.
- [x] Comparer les quatre leçons protégées et leurs cartes avec HEAD ; les
  identifiants, ordre, objectifs, vocabulaire, blocs et réponses sont stables.
- [x] Vérifier les 198 choix : aucune réponse correcte n’est imposée par une
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

Le [run 36339541346](https://github.com/STOOOKEEE/Polygo/actions/runs/36339541346)
sur `b0d065f` a validé le package (72/72), 9/9 méthodes UI Mac et 11/11
méthodes UI iPhone ; l’iPad (7/8) est hors périmètre et non bloquant. Les
captures du dépôt en proviennent (iPhone 16 Pro réduit à 603 × 1311, Mac
1600 × 900) :

| Capture | Dimensions | SHA-256 |
| --- | --- | --- |
| [accueil iPhone](screenshots/home-ios.png) | 603 × 1311 | `7f987f2227d4d998167fe2f02a50ab217c521ef15a2d17f488241f8b4dc03bdf` |
| [parcours iPhone sombre](screenshots/roadmap-ios-dark.png) | 603 × 1311 | `bb913f675648e30b93ac998e9d10b1662dbb0b86cef47e4acae31ca22ffe3b70` |
| [dialogue iPhone](screenshots/dialogue-ios.png) | 603 × 1311 | `5e1fc792faa6143025e3236765a85c92a809e8dca43d1b80478fec3d91e98ac9` |
| [pièces après complétion](screenshots/coins-roadmap-ios.png) | 603 × 1311 | `21026287c38b580406287a56666bfab24d3d796983499d15df23f485ee6d6287` |
| [écriture guidée iPhone](screenshots/handwriting-guided-ios.png) | 603 × 1311 | `fd3b30a7cb7a9fadad35ed8ca93376a9c9f0965c1356020136a8f592e63fa184` |
| [accueil Mac](screenshots/home-macos-dark.png) | 1600 × 900 | `d263f2c133fc7dce38595014a40074fa1f3955e3516ac67c645e221f31240881` |
| [parcours Mac](screenshots/roadmap-macos-dark.png) | 1600 × 900 | `e51f63782e920de68bc98a06a2287dcddde40cdab4af6dd62ebd1197f57eaf99` |
| [dialogue Mac](screenshots/dialogue-macos-dark.png) | 1600 × 900 | `8d708d37774c985bf5380e59df3378b40557c11d42554ca6eb537862c31b2065` |
| [séance J1 Mac](screenshots/daily-plan-day-one-macos.png) | 1600 × 900 | `67bd9b0ce8df676e8faf30d8b9191ef4bba4e3cfec78297cce7d0ca897bcfbe0` |
| [lecture L5 Mac](screenshots/daily-plan-reading-macos.png) | 1600 × 900 | `9f4349e4a0144d2540ae09884d7d5b75e04ce9e1b070c0be64d349eb2194be20` |
| [séance J2 Mac](screenshots/daily-plan-day-two-macos.png) | 1600 × 900 | `18a7d16bf79231ce34eea900b00b5fbc262461ca9cd91b7eba7f0e3692422784` |

Les deux captures de dialogue (écran d’intro, pinyin et traduction masqués par
défaut) proviennent du
[run 36446200223](https://github.com/STOOOKEEE/Polygo/actions/runs/36446200223)
sur `cc01093`.

Le conteneur Linux ne fournit ni Xcode, ni SwiftUI, ni SDK Apple. Les builds
Apple, les méthodes UI, l’audit VoiceOver/Dynamic Type sur appareil, les
permissions Speech et les fenêtres étroites restent des contrôles du runner ou
de l’appareil ; aucun audit manuel sur appareil n’a été réalisé.

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
  `skipped` et « Continuer » doivent rester disponibles.
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
