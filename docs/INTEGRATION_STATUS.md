# Statut d’intégration

Mis à jour le 2026-09-08 pour le commit courant
`906135d` (`906135d99a1bc1ee69d16a28f81963a657a58d65`). Le [run Apple
34225700577](https://github.com/STOOOKEEE/Polygo/actions/runs/34225700577) est
terminé avec succès : le job package a validé 47/47 tests portables, le job
macOS le build et 2/2 tests UI, et le job iOS 7/7 tests UI. Les trois jobs sont
verts.

## État

- Le dépôt contient quatre leçons, 27 exercices, quatre histoires et 17 cartes ; les trois guides d’écriture (`你`, `我`, `国`) sont livrés avec leurs références et sommes SHA-256.
- Le package courant contient 47 tests XCTest, dont 7 tests de contrat de contenu ; les 47/47 tests portables passent avec les fixtures courantes. Les targets UI contiennent neuf méthodes au total (7 iOS et 2 macOS), dont les deux parcours d’écriture iOS et le parcours d’oral sans évaluation.
- La leçon conserve et restaure le brouillon, le feedback et les réponses de dialogue par identifiant stable. Une fin incomplète reste réinitialisable.
- L’accueil expose la reprise de leçon, l’état du parcours et l’accès aux flashcards. Le dialogue est compact, propose l’écoute des seules répliques mandarin, des cibles chinoises interactives et une réponse écrite vérifiée à partir de la réplique précédente.
- Les guides d’écriture vérifient chaque trait dans l’ordre, sa direction et sa forme ; un échec reste visible en rouge et peut être retenté. La roadmap relie les nœuds avec un espacement adapté à Dynamic Type ; les cartes conservent leurs choix SM-2.
- L’oral extrait uniquement le mandarin pour le TTS, conserve la cible, le modèle et le microphone compacts, puis sépare transcription Apple et rapport du `SpeechPronunciationService`. Dans les quatre leçons, l’exercice oral est facultatif : tant qu’aucun provider ni credential n’est configuré, l’état est non configuré et « Passer sans évaluer » enregistre `skipped` sans note ni réussite. Le bilan expose `skippedCount` ; les exercices requis seuls déterminent la complétion et le déblocage de la leçon suivante, sans faux score.
- Le protocole, l’UI et les fixtures sont prêts pour un fournisseur externe, mais aucun provider externe, compte, credential ou proxy n’est activé ou disponible dans la composition actuelle.
- Les `Info.plist` iOS et macOS sont séparés ; iOS déclare `UILaunchScreen` et cible iPhone/iPad. Le canevas capture les gestes dans le `ScrollView` via une surface tactile dédiée et les lignes de leçon comme les liens de vocabulaire sont touchables sur toute leur largeur.

## Validation CI

- Hôte de développement : Debian 13 x86_64 ; Swift/Xcode Apple absents, donc aucun build Apple local n’est possible.
- Le contrôle local `git diff --check` des documents modifiés est propre.
- La suite portable actuelle passe à 47/47 ; les fixtures couvrent un rapport fournisseur terminé, les états non configuré/indisponible/en échec, le résultat incertain et le passage sans évaluation. Aucun appel réseau, compte ou credential n’est utilisé.
- Dans le [run Apple 34225700577](https://github.com/STOOOKEEE/Polygo/actions/runs/34225700577), exécuté sur `906135d`, le job package a validé 47/47 tests portables, le job macOS a validé le build, le smoke UI et 2/2 tests UI, et le job iOS a validé 7/7 tests UI. Les trois jobs ont réussi.
- Le run [34222443020](https://github.com/STOOOKEEE/Polygo/actions/runs/34222443020) du commit `249f6d0` a validé les deux parcours d’écriture iOS ; leurs captures sont archivées dans [`docs/screenshots/handwriting-guided-ios.png`](screenshots/handwriting-guided-ios.png) et [`docs/screenshots/handwriting-retry-ios.png`](screenshots/handwriting-retry-ios.png). Ses autres méthodes UI ayant échoué, ce run ne constitue pas une validation globale.
- Le run courant a validé visuellement le parcours et le dialogue ; les captures de référence du jalon sont archivées dans [`docs/screenshots/roadmap-macos-dark.png`](screenshots/roadmap-macos-dark.png) (1600 × 900, SHA-256 `98b21d6cab2d9026341fe49e04b3fdd6def2c2fb527046bc9d1fc3168e40f132`) et [`docs/screenshots/dialogue-macos-dark.png`](screenshots/dialogue-macos-dark.png) (1600 × 900, SHA-256 `0f816f4fe790409c88ca8776d714e0362dd6608cfbab8364b8a3632709391859`).
- Le [run historique 34207957185](https://github.com/STOOOKEEE/Polygo/actions/runs/34207957185) reste réussi sur `c30d712` pour son périmètre antérieur ; il ne couvre pas les changements du commit courant.
- CloudKit reste prévu mais inactif : la progression, les documents, les dessins et les enregistrements temporaires restent locaux. Les conflits réseau ne sont pas testés.

## Suite

1. Relire le diff complet, vérifier les secrets/fichiers locaux et conserver les documents synchronisés avec le résultat CI.
2. Compléter l’audit manuel VoiceOver, Dynamic Type, contraste, rendu sombre, clavier et fenêtres sur iPhone, iPad et Mac ; vérifier Speech avec permission accordée.
3. Activer et tester le client CloudKit seulement lorsque la synchronisation sera effectivement livrée.
