# Rapport QA Syllune

Contrôle préparé le 8 septembre 2026. Le périmètre couvre les contrats de
contenu, les tests portables et les parcours UI associés au programme quotidien.

## État de validation

Le pack intégré est en `2026.10.0`. Il contient 94 leçons (`lesson-01` à
`lesson-94`) : les quatre premières restent les fixtures de démarrage et les
90 suivantes (`lesson-05` à `lesson-94`) composent le programme quotidien. Le
plan porte sur 90 séances de 15 minutes avec les jalons J30, J60 et J90.

Le corpus livré contient 567 exercices, 94 lectures, 196 paragraphes et
911 déclarations de vocabulaire/cartes. Les réutilisations ramènent le corpus à
605 identifiants de vocabulaire et de cartes uniques. Les références de blocs,
d’objectifs, de vocabulaire, de cartes, d’histoires et d’assets sont fermées.

Le catalogue `hsk-legacy-600` contient les 600 entrées canoniques attendues.
Les exemples HSK legacy 001–600 sont présents dans les deux lots authoring,
avec Hanzi, pinyin et traduction française. L’audit lexical a contrôlé les
occurrences cibles, les pinyins accentués et les lectures polyphoniques ; les
corrections éditoriales des entrées 214, 317, 354, 410, 413, 448, 457, 462,
494 et 517 sont intégrées. Aucun blocage linguistique ne reste ouvert.

La suite portable courante découvre le corpus réel et compte **55 tests
XCTest**. Le run local `swift test --parallel` avec Swift 6.0.3 a réussi à
**55/55** ; `git diff --check` est également propre. Le conteneur Linux ne
fournit pas Xcode, SwiftUI ni les SDK Apple, donc la campagne native du snapshot
intégré sera relancée sur CI Apple après le push final.

## Contrats de contenu

`ContentContractTests.swift` vérifie notamment :

- la découverte et l’ordre des 94 leçons, la compatibilité des quatre fixtures
  de démarrage et l’unicité des identifiants globaux ;
- les 567 exercices, leurs formes et réponses canoniques, les 94 lectures,
  leurs 196 paragraphes et les 605 cartes uniques ;
- les formes simplifiées et traditionnelles, les pinyins, les numéros de tons
  (y compris le ton neutre), les traductions et la segmentation alignée ;
- les références HSK-legacy 2.0 et HSK-3.0 `2025-11` conservées comme deux
  référentiels distincts, les métadonnées pédagogiques de chaque bloc, la
  progression de réutilisation et les preuves d’exercices pour les objectifs ;
- le plan de 90 séances, son budget de 15 minutes, les jalons J30/J60/J90 et
  la couverture canonique HSK à J30 et J90 ;
- les cartes quotidiennes avec le Hanzi sur le recto et pinyin/traduction sur
  le verso, les assets de tracé locaux et l’activité orale facultative pour la
  progression hors ligne.

`ExerciseAndProgressTests.swift` couvre la normalisation du pinyin, de la
ponctuation et de la casse, les mauvaises formes de réponse, les scores
invalides, les variantes de transcription legacy, les rapports fournisseur de
prononciation, les états incertain et `skipped`, le parcours
onboarding → leçon → exercice → fin → cartes, les checkpoints, l’idempotence
des événements, la correction d’une tentative et le rejet d’un autre profil.
`HSKLegacyCatalogContractTests.swift`, `MandarinSpeechTextTests.swift`,
`PolygoSRSTests` et `PolygoPersistenceTests` complètent les contrôles de
catalogue, TTS, planification SRS et journal JSONL.

## Vérification du parcours

Le lecteur conserve l’ordre des blocs et des exercices, restaure les brouillons
et feedbacks par identifiant stable et réinitialise proprement une fin
incomplète. `completeLesson` ajoute les cartes du document sans remplacer
l’état SRS existant. Une activité orale facultative peut produire `skipped` ;
elle reste exclue du score et les exercices requis suffisent pour enregistrer
la leçon et déverrouiller la suivante.

Le dialogue expose ses seules répliques mandarin à l’écoute, les caractères
interactifs et la réponse contrôlée à partir de la réplique précédente. Le TTS
extrait le mandarin et demande une voix `zh-CN`, sans lire les instructions
françaises. La vue orale restaure les résultats persistés, sépare la
transcription du protocole `SpeechPronunciationService` et propose le passage
sans évaluation quand aucun provider ni credential n’est configuré. La
transcription et sa confiance ne fabriquent pas de score de phonème ou de ton.

La vue d’écriture injecte le service local, persiste le dessin et transmet son
identifiant au journal de progression. Les documents, la progression, les
enregistrements temporaires et les dessins restent locaux ; l’interface affiche
le statut « Sur cet appareil » tant que CloudKit n’est pas assemblé.

## Parcours UI et preuves Apple

Le tree courant contient huit méthodes UI iOS et cinq méthodes UI macOS. Il
couvre l’onboarding et les parcours hors ligne, le plan quotidien J1→J2, la
reprise après validation d’écoute, le passage oral sans évaluation, le dialogue,
les écritures guidée et libre, le retour au parcours et la session courte de
révision.

Les captures déjà présentes dans `docs/screenshots/` et les runs suivants sont
des preuves **historiques**, produites sur des snapshots antérieurs :

- [run Apple 34207957185](https://github.com/STOOOKEEE/Polygo/actions/runs/34207957185),
  vert pour son ancien périmètre (`c30d712`) ;
- [run Apple 34222443020](https://github.com/STOOOKEEE/Polygo/actions/runs/34222443020),
  qui a validé les deux méthodes d’écriture iOS de son snapshot, sans constituer
  une validation globale ;
- [run Apple 34225700577](https://github.com/STOOOKEEE/Polygo/actions/runs/34225700577),
  vert pour le corpus et les parcours UI de son snapshot précédent.

Ces campagnes ne valident pas encore le pack intégré à 94 leçons. La campagne
native complète sera lancée après le push final et devra vérifier le build iOS
et macOS, les huit parcours iOS, les cinq parcours macOS et la nouvelle capture
de la leçon 5 au stade écoute.

## Vérifications hors automatisation

Un audit manuel reste à faire sur iPhone, iPad et Mac pour VoiceOver, Dynamic
Type XXXL, contraste, rendu sombre, réduction des animations, clavier macOS et
fenêtres étroites. La permission Speech accordée et l’analyse avec un provider
configuré restent à exercer sur appareil. Les fixtures couvrent le chemin sans
évaluation en l’absence de provider. CloudKit n’est pas actif ; ses conflits
réseau ne sont donc pas couverts.
