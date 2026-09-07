# Checklist de release

Ce document décrit la mise en release de Syllune. Le fichier
[`project.yml`](../project.yml) est la source du projet Apple ;
`Polygo.xcodeproj` est généré par XcodeGen. Les étapes Apple restent en attente
tant que la CI n’a pas fourni ses logs.

## État vérifié du jalon

- `swift test --parallel` passe avec 34 XCTest du package via la toolchain Swift Linux.
- Le contenu contractuel est vérifié : 3 leçons, 20 exercices, 3 histoires et 16 cartes.
- `Tests/PolygoAppUITests/PolygoAppUITests.swift` est écrit, mais le smoke UI n’est pas encore exécuté.
- Le workflow `.github/workflows/apple.yml` doit encore confirmer la génération XcodeGen et les builds iOS/macOS sur `macos-15`.
- Aucun build iOS, iPadOS ou macOS ne doit être annoncé comme réussi avant cette confirmation.

## Vérification avant intégration

- [ ] Lire `git status` et le diff complet ; ne conserver que les fichiers du jalon.
- [ ] Vérifier qu’aucun secret, certificat, profil de provisioning, base locale ou fichier machine n’entre dans le commit.
- [ ] Lancer `swift test --parallel` et conserver le résultat des 34 tests.
- [ ] Reparser `Content/manifest.json`, le catalogue et les trois leçons ; confirmer les références fermées, les comptes 3/20/3/16 et les hashes des trois guides.
- [ ] Vérifier `git diff --check` sur les documents et les JSON.

Le contenu suit la chaîne `manifest.json` → catalogue du cours → documents de
leçon. Les trois histoires sont inline dans les blocs de lecture et les trois
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

- [ ] Générer le projet sans erreur et vérifier les schemes `PolygoApp` et `PolygoMacApp`.
- [ ] Compiler `PolygoApp` pour un simulateur iOS 17 ; ce target couvre iPhone et iPad.
- [ ] Compiler `PolygoMacApp` pour macOS 14.
- [ ] Vérifier que `Content` et `Design` sont bien copiés dans les deux applications.
- [ ] Déclarer puis exécuter la cible `PolygoAppUITests` sur un simulateur iOS en français avant de fermer la gate UI ; le fichier smoke existe déjà, mais la cible n’est pas encore validée.

La CI doit exécuter ces étapes via le workflow Apple sur `macos-15`. Les
permissions, la disponibilité d’une voix Mandarin, la transcription locale,
le tracé et les comportements de fenêtre ne sont pas démontrés par
`swift test`.

## Contrôles produit et confidentialité

- [ ] Tester l’onboarding, les trois leçons, les 20 exercices, les trois histoires et les 16 cartes sur iPhone et iPad.
- [ ] Tester la navigation, le clavier et le redimensionnement sur macOS 14.
- [ ] Tester une voix Mandarin installée puis absente ; l’absence doit afficher une erreur récupérable.
- [ ] Tester microphone et Speech autorisés, refusés et indisponibles ; l’auto-évaluation doit rester possible.
- [ ] Vérifier que les marqueurs de ton restent visuels et qu’aucun score de ton fictif n’est attribué.
- [ ] Tester les guides `你`, `我` et `国`, puis l’auto-évaluation si un guide n’est pas disponible.
- [ ] Vérifier que les enregistrements temporaires sont supprimés par défaut et que leur contenu n’est pas envoyé à un service Polygo.
- [ ] Vérifier que l’état de réglages reste « Sur cet appareil » : CloudKit/iCloud sync est planifié, mais inactif dans cette version.

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

- [ ] CI verte : package tests, génération XcodeGen, build iOS et build macOS.
- [ ] Smoke UI iOS exécuté et rapport QA mis à jour ; aucun test device ou accessibilité ne doit être décrit comme passé sans log.
- [ ] Diff final relu, fichiers générés/secrets exclus, `git status` propre après commit.
- [ ] Version, notes de release et tag publiés ensemble.
