# Statut d’intégration

Mis à jour le 2026-09-08 pour le commit validé
`f7e603ec3a59df4a9a157ad122cce04d68c8b0b1`. La validation Apple est verte dans
le [run 34167951193](https://github.com/STOOOKEEE/Polygo/actions/runs/34167951193).

## État

- Le dépôt contient quatre leçons, 27 exercices, quatre histoires et 17 cartes ; les trois guides d’écriture (`你`, `我`, `国`) sont livrés avec leurs références et sommes SHA-256.
- Le package contient 43 tests XCTest, dont 6 tests de contrat de contenu. Le target UI contient quatre méthodes couvrant le smoke, la reprise de fin/revue et la régression dialogue/oral.
- La leçon conserve et restaure le brouillon, le feedback et les réponses de dialogue par identifiant stable. Une fin incomplète reste réinitialisable.
- L’accueil expose la reprise de leçon, l’état du parcours et l’accès aux flashcards. Le dialogue propose l’écoute des seules répliques mandarin, des cibles chinoises interactives et une réponse écrite vérifiée à partir de la réplique précédente.
- L’oral extrait uniquement le mandarin pour le TTS, conserve la cible, le modèle et le microphone compacts, restaure les résultats persistés sans fabriquer d’enregistrement et n’invente aucun score de phonème ou de ton.
- Les `Info.plist` iOS et macOS sont séparés ; iOS déclare `UILaunchScreen` et cible iPhone/iPad. Le canevas capture les gestes dans le `ScrollView` via une surface tactile dédiée et les lignes de leçon comme les liens de vocabulaire sont touchables sur toute leur largeur.

## Validation CI

- Hôte de développement : Debian 13 x86_64 ; Swift/Xcode Apple absents, donc aucun build Apple local n’est possible.
- Le contrôle local `git diff --check` des quatre documents est propre.
- Le [run Apple 34167951193](https://github.com/STOOOKEEE/Polygo/actions/runs/34167951193) est réussi sur `f7e603ec3a59df4a9a157ad122cce04d68c8b0b1` : 43/43 tests package, génération XcodeGen, métadonnées, builds iOS/macOS et quatre méthodes UI sans échec. La durée cumulée des méthodes UI est de 565,379 s.
- Les captures nommées `oral-controls` et `oral-result` ont été extraites des artefacts UI et inspectées visuellement ; la vue compacte conserve la cible, le pinyin, le modèle, la vitesse, le microphone et le bouton de vérification.
- CloudKit reste prévu mais inactif : la progression, les documents, les dessins et les enregistrements temporaires restent locaux. Les conflits réseau ne sont pas testés.

## Suite

1. Relire le diff complet, vérifier les secrets/fichiers locaux et conserver les quatre documents synchronisés avec le résultat CI.
2. Compléter l’audit manuel VoiceOver, Dynamic Type, contraste, rendu sombre, clavier et fenêtres sur iPhone, iPad et Mac ; vérifier Speech avec permission accordée.
3. Activer et tester le client CloudKit seulement lorsque la synchronisation sera effectivement livrée.
