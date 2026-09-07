# Statut d’intégration

Mis à jour le 2026-09-07 pendant l’intégration locale.

## État

- `main` part de `cae1db9`, synchronisée avec `origin/main` au démarrage de cette intégration.
- Le graphe SwiftPM, les cibles XcodeGen iOS/macOS, les vues Apple, le contenu et
  les tests sont présents dans l’arbre de validation.
- Les trois références d’écriture pointent vers les guides JSON livrés et leurs
  SHA-256; le service local est injecté dans les dépendances de l’application.
- Le rapport d’accessibilité et les vues concernées ont été livrés; la
  validation d’appareil reste une responsabilité de la CI et des essais Apple.

## Validation

- Hôte: Debian 13 x86_64; Swift/Xcode Apple absents, donc aucun build Apple local possible.
- `swift test --disable-sandbox --parallel` passe avec les 34 tests XCTest du
  graphe portable via Swift 6.0.3.
- XcodeGen génère `Polygo.xcodeproj` sans erreur; le projet généré est ignoré
  par Git et ne doit pas être ajouté au commit.
- La compilation SwiftUI iOS/macOS et XcodeGen sera validée sur GitHub Actions avec le runner versionné `macos-15`.

## Suite

1. Vérifier les deux correctifs ciblés de parcours et d’annulation dans la
   branche de validation.
2. Inspecter le diff complet, les secrets/fichiers locaux et `git diff --check`.
3. Pousser la branche de validation pour obtenir les logs macOS, puis reporter
   les erreurs Apple aux agents concernés avant le merge vers `main`.
