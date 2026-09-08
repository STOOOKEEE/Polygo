# Checklist de release

Ce document décrit la mise en release de Syllune. Le fichier
[`project.yml`](../project.yml) est la source du projet Apple ;
`Polygo.xcodeproj` est généré par XcodeGen. Le code validé est le commit
`c30d712`. Sa validation Apple est verte dans
le [run 34207957185](https://github.com/STOOOKEEE/Polygo/actions/runs/34207957185) ;
voir [docs/QA_REPORT.md](QA_REPORT.md) pour le périmètre et les limites. Ce run
valide le package, les builds iOS/macOS, les métadonnées et les six méthodes UI
(2 macOS et 4 iOS).

## État du candidat

- Le package contient actuellement 46 tests XCTest, dont 6 tests de contrat de contenu ; les 46/46 tests portables réussissent avec le contenu et les fixtures courants. Le run Apple 34207957185 correspond au jalon précédent et en validait 43.
- Le contenu livré reste constitué de 4 leçons, 27 exercices, 4 histoires et 17 cartes. Les nouveaux mots par leçon sont 5, 5, 6 et 1 ; les exercices sont au nombre de 6, 7, 7 et 7 ; les cartes sont au nombre de 5, 5, 6 et 1.
- La reprise locale conserve brouillon, feedback et réponses de dialogue ; l’accueil expose la reprise, le parcours et les flashcards.
- Le dialogue est une scène compacte avec écoute complète en mandarin, caractères chinois interactifs et réponse écrite vérifiée à partir de la réplique précédente.
- Les guides d’écriture vérifient l’ordre, la direction et la forme de chaque trait ; un trait rejeté reste à refaire jusqu’à une nouvelle tentative valide. La roadmap relie les étapes par des nœuds et adapte leur espacement à Dynamic Type ; les cartes de révision conservent leurs choix SM-2.
- L’oral extrait uniquement le mandarin pour le TTS, garde la cible, le modèle et le microphone compacts, et restaure les résultats persistés sans créer d’enregistrement. `SpeechPronunciationService` sépare la transcription descriptive du rapport fournisseur : sans provider ni credentials, l’UI affiche l’état non configuré et propose « Passer sans évaluer », sans note ni réussite.
- Les `Info.plist` iOS et macOS sont séparés ; iOS déclare un écran de lancement moderne plein écran (`UILaunchScreen`) et cible iPhone/iPad. Le canevas capture les gestes dans le `ScrollView` via une surface tactile dédiée ; les lignes de leçon et les liens de vocabulaire ont une zone de toucher sur toute leur largeur.

## Vérification avant intégration

- [x] Lire `git status` et le diff complet après l’intégration ; ne conserver que les fichiers du jalon documentaire.
- [x] Vérifier qu’aucun secret, certificat, profil de provisioning, base locale ou fichier machine n’entre dans le commit.
- [x] Obtenir le résultat `46/46` de la suite portable actuelle et vérifier les fixtures de prononciation terminée, non configurée, indisponible, incertaine et passée sans évaluation.
- [x] Conserver le résultat historique `43/43` du package et des 6 tests de contrat dans le run Apple 34207957185 comme référence du jalon précédent.
- [x] Reparser `Content/manifest.json`, le catalogue et les quatre leçons ; confirmer les références fermées, les comptes 4/27/4/17, les quantités par leçon 5/5/6/1 mots, 6/7/7/7 exercices et 5/5/6/1 cartes, ainsi que les hashes des trois guides.
- [x] Vérifier `git diff --check` sur les documents modifiés.

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

- [x] Générer le projet sans erreur et vérifier les schemes `PolygoApp` et `PolygoMacApp` dans le run Apple 34207957185.
- [x] Compiler `PolygoApp` pour un simulateur iOS 17 ; ce target couvre iPhone et iPad.
- [x] Compiler `PolygoMacApp` pour macOS 14.
- [x] Vérifier les métadonnées compilées et que `Content` et `Design` sont bien copiés dans les deux applications.
- [x] Valider les quatre méthodes de test de la cible `PolygoAppUITests` sur un simulateur iOS en français et les deux méthodes UI macOS.

Le workflow Apple exécute ces étapes sur `macos-15` ; le run 34207957185 les a
toutes validées pour le jalon précédent. Le parcours courant couvre la reprise
de brouillon et de feedback, le dialogue compact et la réplique précédente
interactive, l’état oral non évalué et son passage sans note, le tracé guidé,
la persistance et la reprise des cartes. La reconnaissance Speech avec
permission accordée et un fournisseur configuré, les comportements de fenêtre
et l’audit manuel d’accessibilité restent à compléter sur iPhone, iPad et Mac.
Les trois guides `你`, `我` et `国` sont les seuls guides d’écriture livrés ;
CloudKit reste prévu mais inactif et ses conflits réseau ne sont pas testés.

## Contrôles produit et confidentialité

- [ ] Tester l’onboarding, les quatre leçons, les 27 exercices, les quatre histoires et les 17 cartes sur iPhone et iPad.
- [ ] Tester la navigation, le clavier et le redimensionnement sur macOS 14.
- [ ] Tester une voix Mandarin installée puis absente ; l’absence doit afficher une erreur récupérable.
- [ ] Tester microphone et Speech autorisés, refusés et indisponibles ; l’état non évalué et « Passer sans évaluer » doivent rester disponibles.
- [ ] Vérifier que les marqueurs de ton restent visuels et qu’aucun score de ton fictif n’est attribué.
- [ ] Tester les guides `你`, `我` et `国`, puis le chemin sans note si un guide ou un fournisseur n’est pas disponible.
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

- [x] Package (43 tests), métadonnées, génération XcodeGen, build iOS, build macOS et les six méthodes UI (2 macOS et 4 iOS) réussis dans le [run 34207957185](https://github.com/STOOOKEEE/Polygo/actions/runs/34207957185) sur `c30d712`.
- [x] `LessonReviewJourneyTests`, `ZZLessonRegressionJourneyTests` et le smoke UI exécutés ; les résultats restent limités aux états observables du simulateur et aux contrôles décrits.
- [x] Diff final relu, fichiers générés/secrets exclus, `git status` propre après commit.
- [ ] Version, notes de release et tag publiés ensemble.
