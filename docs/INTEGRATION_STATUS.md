# Statut d’intégration

Mis à jour le 2026-09-08 pour le commit validé
`c30d712`. La validation Apple est verte dans le
[run 34207957185](https://github.com/STOOOKEEE/Polygo/actions/runs/34207957185).

## État

- Le dépôt contient quatre leçons, 27 exercices, quatre histoires et 17 cartes ; les trois guides d’écriture (`你`, `我`, `国`) sont livrés avec leurs références et sommes SHA-256.
- Le package contient 43 tests XCTest, dont 6 tests de contrat de contenu. Les targets UI contiennent six méthodes : quatre iOS couvrant le smoke, la reprise de fin/revue et la régression dialogue/oral, ainsi que deux macOS pour l’accueil et le retour à sa racine.
- La leçon conserve et restaure le brouillon, le feedback et les réponses de dialogue par identifiant stable. Une fin incomplète reste réinitialisable.
- L’accueil expose la reprise de leçon, l’état du parcours et l’accès aux flashcards. Le dialogue propose l’écoute des seules répliques mandarin, des cibles chinoises interactives et une réponse écrite vérifiée à partir de la réplique précédente.
- L’oral extrait uniquement le mandarin pour le TTS, conserve la cible, le modèle et le microphone compacts, restaure les résultats persistés sans fabriquer d’enregistrement et n’invente aucun score de phonème ou de ton.
- Les `Info.plist` iOS et macOS sont séparés ; iOS déclare `UILaunchScreen` et cible iPhone/iPad. Le canevas capture les gestes dans le `ScrollView` via une surface tactile dédiée et les lignes de leçon comme les liens de vocabulaire sont touchables sur toute leur largeur.

## Validation CI

- Hôte de développement : Debian 13 x86_64 ; Swift/Xcode Apple absents, donc aucun build Apple local n’est possible.
- Le contrôle local `git diff --check` des quatre documents est propre.
- Le [run Apple 34207957185](https://github.com/STOOOKEEE/Polygo/actions/runs/34207957185) est réussi sur `c30d712` : 43/43 tests package, génération XcodeGen, métadonnées, builds iOS/macOS et six méthodes UI sans échec (4 iOS et 2 macOS).
- Les captures nommées `oral-controls` et `oral-result` ont été extraites des artefacts UI et inspectées visuellement ; la vue compacte conserve la cible, le pinyin, le modèle, la vitesse, le microphone et le bouton de vérification.
- CloudKit reste prévu mais inactif : la progression, les documents, les dessins et les enregistrements temporaires restent locaux. Les conflits réseau ne sont pas testés.

## Suite

1. Relire le diff complet, vérifier les secrets/fichiers locaux et conserver les quatre documents synchronisés avec le résultat CI.
2. Compléter l’audit manuel VoiceOver, Dynamic Type, contraste, rendu sombre, clavier et fenêtres sur iPhone, iPad et Mac ; vérifier Speech avec permission accordée.
3. Activer et tester le client CloudKit seulement lorsque la synchronisation sera effectivement livrée.
