# Statut d’intégration

Mis à jour le 2026-09-08 pour le commit validé
`c30d712`. La validation Apple est verte dans le
[run 34207957185](https://github.com/STOOOKEEE/Polygo/actions/runs/34207957185).

## État

- Le dépôt contient quatre leçons, 27 exercices, quatre histoires et 17 cartes ; les trois guides d’écriture (`你`, `我`, `国`) sont livrés avec leurs références et sommes SHA-256.
- Le package courant contient 46 tests XCTest, dont 6 tests de contrat de contenu ; les 46/46 tests portables passent avec les fixtures courantes. Les targets UI contiennent sept méthodes, dont les nouveaux parcours d’écriture guidée et d’oral sans évaluation ; le run Apple historique 34207957185 en validait six.
- La leçon conserve et restaure le brouillon, le feedback et les réponses de dialogue par identifiant stable. Une fin incomplète reste réinitialisable.
- L’accueil expose la reprise de leçon, l’état du parcours et l’accès aux flashcards. Le dialogue est compact, propose l’écoute des seules répliques mandarin, des cibles chinoises interactives et une réponse écrite vérifiée à partir de la réplique précédente.
- Les guides d’écriture vérifient chaque trait dans l’ordre, sa direction et sa forme ; un échec reste visible en rouge et peut être retenté. La roadmap relie les nœuds avec un espacement adapté à Dynamic Type ; les cartes conservent leurs choix SM-2.
- L’oral extrait uniquement le mandarin pour le TTS, conserve la cible, le modèle et le microphone compacts, puis sépare transcription Apple et rapport du `SpeechPronunciationService`. Tant qu’aucun provider ni credential n’est configuré, l’état est non configuré et « Passer sans évaluer » enregistre `skipped` sans note ni réussite ; aucun score de phonème ou de ton n’est déduit de la transcription.
- Les `Info.plist` iOS et macOS sont séparés ; iOS déclare `UILaunchScreen` et cible iPhone/iPad. Le canevas capture les gestes dans le `ScrollView` via une surface tactile dédiée et les lignes de leçon comme les liens de vocabulaire sont touchables sur toute leur largeur.

## Validation CI

- Hôte de développement : Debian 13 x86_64 ; Swift/Xcode Apple absents, donc aucun build Apple local n’est possible.
- Le contrôle local `git diff --check` des documents modifiés est propre.
- La suite portable actuelle passe à 46/46 ; les fixtures couvrent un rapport fournisseur terminé, les états non configuré/indisponible/en échec, le résultat incertain et le passage sans évaluation. Aucun appel réseau, compte ou credential n’est utilisé.
- Le [run Apple 34207957185](https://github.com/STOOOKEEE/Polygo/actions/runs/34207957185) est réussi sur `c30d712` : 43/43 tests package, génération XcodeGen, métadonnées, builds iOS/macOS et six méthodes UI sans échec (4 iOS et 2 macOS).
- Les captures nommées `oral-controls` et `oral-result` du run historique ont été extraites des artefacts UI et inspectées visuellement ; la vue compacte conserve la cible, le pinyin, le modèle, la vitesse et le microphone. Le parcours courant ajoute l’état non configuré et le passage sans évaluation ; sa validation Apple reste à confirmer.
- CloudKit reste prévu mais inactif : la progression, les documents, les dessins et les enregistrements temporaires restent locaux. Les conflits réseau ne sont pas testés.

## Suite

1. Relire le diff complet, vérifier les secrets/fichiers locaux et conserver les quatre documents synchronisés avec le résultat CI.
2. Compléter l’audit manuel VoiceOver, Dynamic Type, contraste, rendu sombre, clavier et fenêtres sur iPhone, iPad et Mac ; vérifier Speech avec permission accordée.
3. Activer et tester le client CloudKit seulement lorsque la synchronisation sera effectivement livrée.
