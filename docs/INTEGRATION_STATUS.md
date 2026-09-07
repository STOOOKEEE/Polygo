# Statut d’intégration

Mis à jour le 2026-09-07 après le run Apple final
[34131645170](https://github.com/STOOOKEEE/Polygo/actions/runs/34131645170).

## État

- Le code applicatif validé est au checkpoint `baed988`, qui contient les quatre
  leçons et le parcours E2E validé.
- Le graphe SwiftPM, les cibles XcodeGen iOS/macOS, les vues Apple, le contenu et
  les tests sont présents dans l’arbre de validation.
- Le contenu comprend quatre leçons, 27 exercices, quatre histoires et 17
  cartes ; chaque leçon apporte respectivement 5, 5, 6 et 1 nouveaux mots,
  6, 7, 7 et 7 exercices, ainsi que 5, 5, 6 et 1 cartes.
- Les trois références d’écriture pointent vers les guides JSON livrés et leurs
  SHA-256; le service local est injecté dans les dépendances de l’application.
- Les `Info.plist` iOS et macOS sont séparés ; iOS déclare `UILaunchScreen` et
  cible iPhone/iPad. Le canevas capture les gestes dans le `ScrollView` via une
  surface tactile dédiée, reste entièrement visible avant les gestes et les
  lignes de leçon comme les liens de vocabulaire sont touchables sur toute leur
  largeur.

## Validation

- Hôte: Debian 13 x86_64; Swift/Xcode Apple absents, donc aucun build Apple local possible.
- `swift test --disable-sandbox --parallel` passe avec 35/35 tests XCTest du
  graphe portable via Swift 6.0.3 ; `ContentContractTests` passe avec 6/6 tests.
- XcodeGen génère `Polygo.xcodeproj` sans erreur; le projet généré est ignoré
  par Git et ne doit pas être ajouté au commit.
- Dans le run Apple final [34131645170](https://github.com/STOOOKEEE/Polygo/actions/runs/34131645170), sur le commit [baed988](https://github.com/STOOOKEEE/Polygo/commit/baed98864a06dd53eb81d1f916a17cc9c7240394), le job package (35/35), la génération XcodeGen, la vérification des métadonnées, les builds iOS/macOS et les deux tests UI sont réussis. `LessonReviewJourneyTests` a duré 181,393 s et le smoke 108,208 s sur iPhone 16 Pro sous iOS 18.5 ; le [rapport QA](QA_REPORT.md) décrit les assertions.
- Le smoke a confirmé le réglage Sombre et le statut local « Sur cet appareil ». L’API `.accessibilityLanguage` n’est pas utilisée car incompatible avec les cibles actuelles ; le rendu manuel, la langue et la prononciation VoiceOver, le toucher manuel et Speech sur appareil restent à compléter sur iPhone, iPad et Mac.
- CloudKit reste prévu mais inactif : les conflits réseau ne sont pas testés et seuls les scénarios de fusion du modèle local sont couverts. Les trois guides d’écriture (`你`, `我`, `国`) sont les seuls guides livrés ; aucun audio de référence n’est embarqué et le TTS dépend d’une voix Mandarin installée.

## Suite

1. Compléter l’audit manuel VoiceOver, Dynamic Type, contraste, rendu sombre,
   clavier et fenêtres sur iPhone, iPad et Mac.
2. Inspecter le diff complet, les secrets/fichiers locaux et `git diff --check`.
3. Conserver CloudKit derrière son futur client et tester ses conflits quand la
   synchronisation sera livrée.
