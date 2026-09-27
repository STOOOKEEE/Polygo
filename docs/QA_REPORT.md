# Rapport QA Syllune

Le périmètre couvre le contenu livré, les tests portables, la refonte Tavi,
la navigation basse et les pièces issues du journal de progression.

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

La suite portable compte **72 tests XCTest**. La campagne de référence est le
[run Apple 36339541346](https://github.com/STOOOKEEE/Polygo/actions/runs/36339541346)
sur `b0d065f` (Swift 6.1.2, Xcode 16.4) : package **72/72**, Mac **9/9**,
iPhone **11/11**. L’iPad est hors périmètre de validation ; son résultat
(7/8) est consigné ci-dessous à titre non bloquant.

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

La projection des pièces conserve les premières complétions historiques
distinctes : première récompense, rejeu, restart, isolation de profil et
reconstruction depuis un ancien journal. Les tests de persistance couvrent
aussi l’échec du cache après écriture durable et distinguent un historique
inconnu d’un solde nul.

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

La CI sélectionne **11 méthodes sur iPhone**, **8 sur iPad AX5** et **9 sur
Mac**. Les huit méthodes iPad constituent un sous-ensemble avec le raccourci
clavier propre à iPad ; il ne faut pas additionner ces comptes comme des
scénarios distincts.

La couverture comprend :

- onboarding d’un nouveau profil malgré une ancienne route de leçon ;
- progression J1→J2, reprise des réponses et pièces historiques 40→50 ;
- première complétion, relance et nouvelle complétion sans second gain ;
- conservation des piles inactives, remise à zéro par retouche de l’onglet
  actif, fiche de mot, histoire, recherche et réglages ;
- raccourcis ⌘1–⌘5, ⌘, et ⌘K sur Mac, fenêtre focalisée et raccourcis
  iPad depuis une leçon ou un champ de recherche ;
- absence du chrome pendant leçon, récapitulatif et pratiques autonomes,
  puis restauration à la sortie ;
- écritures guidée/libre, brouillons, dialogue, contrôles audio et oral
  facultatif sans fournisseur d’évaluation ;
- captures réelles claires/sombres, orientations iOS et gros caractères iPad.

Résultats de `b0d065f`, [run
36339541346](https://github.com/STOOOKEEE/Polygo/actions/runs/36339541346),
relevés dans les journaux du run :

| Surface | Résultat observé |
| --- | --- |
| Package | 72/72 (`[72/72] Testing …`, étape « Run portable package tests » réussie) |
| Mac | Build, « Executed 9 tests, with 0 failures » et probe `AppModel` réussis |
| iPhone 16 Pro | Build, « Executed 11 tests, with 0 failures » |
| iPad Pro 11 pouces AX5 | Hors périmètre, non bloquant : « Executed 8 tests, with 1 failure » |

Le job `build-ios` est marqué en échec uniquement par l’étape iPad. Le seul
échec est `testIPadKeyboardShortcutsReachTabsAndSettingsFromFocusedContent` :
⌘1 n’a pas quitté une leçon. Le correctif `1981952` (résolution des raccourcis
dans la scène SwiftUI active) est poussé mais n’est pas validé. L’iPad ne fait
pas partie du périmètre de validation de la refonte.

Le probe Mac charge le vrai `AppModel` compilé et conserve ses journaux JSONL :
échec avant append, complétion durable suivie d’un échec de cache, reload,
retry et reconstruction du modèle sans réannoncer un ancien gain. Il ne
substitue pas un modèle de test à l’application.

Les images de `docs/screenshots` proviennent des artefacts
`PolygoAppUITests-36339541346` (iPhone 16 Pro, réduites à 603 × 1311) et
`PolygoMacUITests-36339541346` (Mac, 1600 × 900) de ce run : accueil,
parcours clair/sombre, dialogue, pièces après complétion, écriture guidée et
séance quotidienne J1/J2/lecture. Les autres pièces jointes restent dans les
artefacts GitHub.

## Vérifications hors automatisation

Aucun audit manuel sur appareil n’a été réalisé. Les parcours automatisés et
l’inspection des captures ne remplacent pas un audit VoiceOver sur appareil,
les contrastes mesurés et les fenêtres Mac étroites. Dynamic Type AX5 n’est
exercé que sur simulateur iPad, hors périmètre. La réduction des animations et
Speech avec permission accordée restent à exercer manuellement. Aucun
fournisseur d’évaluation de prononciation n’est configuré.

Le runner Mac signale un doublon Objective-C de `JSONContentStore` entre le
framework du package et la bibliothèque de l’application. Les scénarios
ci-dessus réussissent, mais la refonte ne corrige pas ce linkage existant.
CloudKit reste inactif : aucune synchronisation ni résolution de conflit
réseau n’est présentée comme validée.
