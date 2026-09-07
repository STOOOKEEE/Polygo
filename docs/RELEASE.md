# Checklist de release

Ce document décrit la mise en release de Syllune. Le fichier
[`project.yml`](../project.yml) est la source du projet Apple ;
`Polygo.xcodeproj` est généré par XcodeGen. Le run Apple final
[34131645170](https://github.com/STOOOKEEE/Polygo/actions/runs/34131645170), sur le
commit [baed988](https://github.com/STOOOKEEE/Polygo/commit/baed98864a06dd53eb81d1f916a17cc9c7240394),
est entièrement vert : package (35/35 tests), métadonnées de l’application,
builds iOS/macOS et deux tests UI sur iPhone 16 Pro sous iOS 18.5. Le parcours
E2E a duré 181,393 s et le smoke 108,208 s ; voir
[docs/QA_REPORT.md](QA_REPORT.md) pour les assertions et les limites manuelles.

## État vérifié du jalon

- `swift test --disable-sandbox --parallel` passe avec 35/35 XCTest du package via la toolchain Swift Linux ; le filtre `ContentContractTests` passe avec 6/6 tests.
- Le contenu contractuel est vérifié : 4 leçons, 27 exercices, 4 histoires et 17 cartes. Les nouveaux mots par leçon sont 5, 5, 6 et 1 ; les exercices sont au nombre de 6, 7, 7 et 7 ; les cartes sont au nombre de 5, 5, 6 et 1.
- `Tests/PolygoAppUITests/PolygoAppUITests.swift` et `LessonReviewJourneyTests.swift` sont déclarés ; les deux tests UI sont verts dans le run Apple final. Le parcours E2E a validé le fallback oral après refus du microphone, les sept gestes du guide, la persistance locale, les cinq cartes dues, la première réponse et la reprise après relance.
- La génération XcodeGen, la vérification des métadonnées, les étapes de build iOS et macOS et les deux tests UI sont réussies dans le run Apple final [34131645170](https://github.com/STOOOKEEE/Polygo/actions/runs/34131645170) sur [baed988](https://github.com/STOOOKEEE/Polygo/commit/baed98864a06dd53eb81d1f916a17cc9c7240394).
- Les `Info.plist` iOS et macOS sont séparés ; iOS déclare un écran de lancement moderne plein écran (`UILaunchScreen`) et cible iPhone/iPad. Le canevas capture les gestes dans le `ScrollView` via une surface tactile dédiée, avec contrôle de visibilité complète avant les gestes ; les lignes de leçon et les liens de vocabulaire ont une zone de toucher sur toute leur largeur.

## Vérification avant intégration

- [x] Lire `git status` et le diff complet ; ne conserver que les fichiers du jalon.
- [x] Vérifier qu’aucun secret, certificat, profil de provisioning, base locale ou fichier machine n’entre dans le commit.
- [x] Lancer `swift test --disable-sandbox --parallel` et conserver le résultat des 35 tests.
- [x] Reparser `Content/manifest.json`, le catalogue et les quatre leçons ; confirmer les références fermées, les comptes 4/27/4/17, les quantités par leçon 5/5/6/1 mots, 6/7/7/7 exercices et 5/5/6/1 cartes, ainsi que les hashes des trois guides.
- [x] Vérifier `git diff --check` sur les documents et les JSON.

Le contenu suit la chaîne `manifest.json` → catalogue du cours → documents de
leçon. Les quatre histoires sont inline dans les blocs de lecture et les trois
guides sont sous `Content/assets/handwriting/`.

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

- [x] Générer le projet sans erreur et vérifier les schemes `PolygoApp` et `PolygoMacApp` dans le run Apple final.
- [x] Compiler `PolygoApp` pour un simulateur iOS 17 ; ce target couvre iPhone et iPad.
- [x] Compiler `PolygoMacApp` pour macOS 14.
- [x] Vérifier les métadonnées compilées et que `Content` et `Design` sont bien copiés dans les deux applications.
- [x] Valider `PolygoAppUITests` et `LessonReviewJourneyTests` sur un simulateur iOS en français ; les deux tests sont verts dans le run Apple final.

Le workflow Apple exécute ces étapes sur `macos-15`. Le parcours E2E couvre le
fallback oral après refus du microphone, le tracé local et la reprise des cartes.
La reconnaissance Speech avec permission accordée, les comportements de fenêtre
et l’audit manuel d’accessibilité restent à compléter sur iPhone, iPad et Mac.
Les trois guides `你`, `我` et `国` sont les seuls guides d’écriture livrés ;
CloudKit reste prévu mais inactif et ses conflits réseau ne sont pas testés.

## Contrôles produit et confidentialité

- [ ] Tester l’onboarding, les quatre leçons, les 27 exercices, les quatre histoires et les 17 cartes sur iPhone et iPad.
- [ ] Tester la navigation, le clavier et le redimensionnement sur macOS 14.
- [ ] Tester une voix Mandarin installée puis absente ; l’absence doit afficher une erreur récupérable.
- [ ] Tester microphone et Speech autorisés, refusés et indisponibles ; l’auto-évaluation doit rester possible.
- [ ] Vérifier que les marqueurs de ton restent visuels et qu’aucun score de ton fictif n’est attribué.
- [ ] Tester les guides `你`, `我` et `国`, puis l’auto-évaluation si un guide n’est pas disponible.
- [ ] Vérifier que les enregistrements temporaires sont supprimés par défaut et que leur contenu n’est pas envoyé à un service Polygo.
- [x] Vérifier que l’état de réglages reste « Sur cet appareil » : CloudKit/iCloud sync est planifié, mais inactif dans cette version.
- [ ] Vérifier les labels et groupes VoiceOver ; l’API `.accessibilityLanguage` n’est pas utilisée car incompatible avec les cibles actuelles, et la langue/prononciation VoiceOver, le toucher manuel et Speech sur appareil restent à tester manuellement.

## Signature et distribution futures

Avant une archive distribuable, l’intégration doit :

- [ ] définir la version marketing et le numéro de build ;
- [ ] renseigner l’équipe Apple et les identifiants de signature dans la configuration de release ou le trousseau CI, sans les écrire dans Git ;
- [ ] conserver `CODE_SIGNING_ALLOWED=NO` pour les builds de vérification et l’activer seulement pour l’archive de release signée ;
- [ ] vérifier les bundle IDs `com.syllune.Polygo` et `com.syllune.PolygoMac` dans Apple Developer et App Store Connect ;
- [ ] confirmer `NSMicrophoneUsageDescription` et `NSSpeechRecognitionUsageDescription` dans les Info.plist générées ;
- [ ] choisir le canal de distribution macOS (App Store ou Developer ID), archiver les schemes concernés et appliquer les étapes d’export/signature correspondantes ;
- [ ] envoyer un build iOS/iPadOS à TestFlight, puis valider l’installation et le parcours hors ligne ;
- [ ] si macOS est distribué hors App Store, signer, notariser et tester l’ouverture sur une machine propre ;
- [ ] n’ajouter les entitlements et le conteneur CloudKit privé que lorsque la synchronisation sera effectivement livrée et testée.

## Gate finale

- [x] Package tests, métadonnées, génération XcodeGen, build iOS, build macOS et les deux tests UI réussis dans le run Apple final [34131645170](https://github.com/STOOOKEEE/Polygo/actions/runs/34131645170) sur [baed988](https://github.com/STOOOKEEE/Polygo/commit/baed98864a06dd53eb81d1f916a17cc9c7240394).
- [x] `LessonReviewJourneyTests` et le smoke UI exécutés, avec rapport QA mis à jour ; les résultats sont limités aux états observables du simulateur et aux contrôles décrits.
- [x] Diff final relu, fichiers générés/secrets exclus, `git status` propre après commit.
- [ ] Version, notes de release et tag publiés ensemble.
