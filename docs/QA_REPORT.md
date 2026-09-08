# Rapport QA Syllune

Contrôle préparé le 8 septembre 2026. Le périmètre de cet agent couvre
`Tests/PolygoCoreTests/**`, `Tests/PolygoAppUITests/**` et ce rapport.

## État de validation

Le contenu local actuel comprend quatre leçons (`lesson-01` à `lesson-04`),
27 exercices, quatre lectures de quatre paragraphes et 17 cartes. Les tests de
contrat lisent les JSON réels et vérifient les références fermées entre leçons,
blocs, objectifs, vocabulaire, cartes, histoires et guides d’écriture.

Le package courant contient **47 tests XCTest**, dont **7 tests de contrat de
contenu** ; les **47/47 tests portables** passent avec les fixtures courantes.
Le contrôle `git diff --check` des modifications documentaires est propre. Le
code courant est le commit `906135d` (`906135d99a1bc1ee69d16a28f81963a657a58d65`).
Le [run Apple 34225700577](https://github.com/STOOOKEEE/Polygo/actions/runs/34225700577)
a validé les **47/47 tests portables du package**, les **2/2 tests UI macOS** et
les **7/7 tests UI iOS** ; ses trois jobs sont terminés avec succès.
Le [run historique 34207957185](https://github.com/STOOOKEEE/Polygo/actions/runs/34207957185)
reste terminé avec succès pour le périmètre antérieur du commit `c30d712`.

Le commit `c30d712` apporte la refonte de l’accueil Mac et iPhone
ainsi que la conservation de la route de reprise lorsqu’une leçon est ouverte
depuis un lien intégré. Son accueil Mac compose un hero de leçon et sa
progression dans une colonne principale, avec le parcours et les flashcards
dans une colonne secondaire ; la version iPhone empile ces trois surfaces.
Les étapes du parcours sont numérotées et reliées par leur progression, et la
barre latérale macOS vise 240 points pour laisser les libellés respirer. Le
clic explicite sur « Aujourd’hui » recrée la racine du détail avant un éventuel
chargement tardif, tandis que le brouillon, le feedback et la progression
restent repris après redémarrage.

Le run historique 34207957185 est vert pour son périmètre : les 43 tests du
package, les 2 méthodes UI macOS et les 4 méthodes UI iOS ont réussi. Les
captures stables natives extraites de ce run sont conservées dans le dépôt :

- [Accueil macOS en mode sombre](screenshots/home-macos-dark.png) — 1600 × 900, SHA-256 `b511d762e3a23fe4e50c47d4e89e3bc9df2c1300fa9bd38e194d38f4c0dc5ece` ;
- [Accueil iPhone en mode sombre](screenshots/home-ios-dark.png) — 1206 × 2622, SHA-256 `aaeb9113f6fcf4f3205cfc658905faea3df94fae7e68325e8b6a61559e0ca597`.

Le run courant 34225700577 a validé le build et le smoke UI macOS, ainsi que les
7/7 tests UI iOS ; les captures de référence du parcours et du dialogue sont
archivées ici :

- [Parcours macOS en mode sombre](screenshots/roadmap-macos-dark.png) — 1600 × 900, SHA-256 `98b21d6cab2d9026341fe49e04b3fdd6def2c2fb527046bc9d1fc3168e40f132` ;
- [Dialogue macOS en mode sombre](screenshots/dialogue-macos-dark.png) — 1600 × 900, SHA-256 `0f816f4fe790409c88ca8776d714e0362dd6608cfbab8364b8a3632709391859` ;
- [Écriture guidée iOS](screenshots/handwriting-guided-ios.png) et [reprise iOS](screenshots/handwriting-retry-ios.png), validées par les deux tests d’écriture du run [34222443020](https://github.com/STOOOKEEE/Polygo/actions/runs/34222443020) sur le commit `249f6d0`.

## Contrats de contenu

`ContentContractTests.swift` vérifie notamment :

- les quatre identifiants de leçon dans l’ordre du cours, les quantités
  attendues (6, 7, 7 et 7 exercices ; 5, 5, 6 et 1 nouveaux mots) et la
  version `2026.09.0` ;
- les 27 exercices et leurs réponses canoniques, les 17 paires carte–mot,
  les 16 paragraphes de lecture et les quatre histoires ;
- les formes simplifiées et traditionnelles, les pinyins accentués et les
  numéros de tons, y compris le ton neutre ;
- les métadonnées éditoriales HSK-3.0 `2025-11` et HSK legacy `2.0` conservées
  comme deux référentiels distincts, les quatre étapes pédagogiques
  `observer`, `recuperer`, `produire`, `transferer`, le plafond de six
  nouveaux mots par leçon, la réutilisation de mots antérieurs et les preuves
  d’exercices pour les objectifs ;
- l’activité orale présente dans les quatre leçons avec `required: false`, afin
  qu’un passage `skipped` n’empêche pas la progression hors ligne ;
- l’absence honnête d’audio livré et les chemins, sommes SHA-256 et nombre de
  traits des trois guides d’écriture locaux.

`ExerciseAndProgressTests.swift` couvre la normalisation du pinyin, de la
ponctuation et de la casse, les mauvaises formes de réponse, les scores
invalides, les variantes de transcription legacy, les rapports fournisseur de
prononciation, les états incertain et `skipped`, le parcours onboarding → leçon
→ exercice → fin → cartes, la reprise d’un brouillon et du feedback, les
checkpoints de dialogue, l’idempotence des événements, la conservation d’un
état SRS lors d’un ajout répété, la correction d’une tentative et le rejet d’un
événement d’un autre profil. `MandarinSpeechTextTests.swift` vérifie aussi que
le TTS ne reçoit que le texte mandarin utile.

## Vérification statique du parcours

Le lecteur extrait les blocs `exercise` dans leur ordre, affiche les blocs
pédagogiques qui précèdent le premier exercice et présente le récapitulatif
placé après la séquence lorsque le dernier exercice est évalué. Les checkpoints
conservent la réponse en cours, le feedback visible et les brouillons/résultats
de dialogue par identifiant stable ; la relance peut donc reprendre le même
exercice ou réinitialiser proprement une fin incomplète. Une fin réussie appelle
`completeLesson`, qui ajoute toutes les cartes du document sans remplacer l’état
SRS d’une carte déjà connue. Les quatre activités orales sont facultatives :
`Passer sans évaluer` produit `skipped`, le bilan affiche `skippedCount` et les
exercices requis seuls permettent d’enregistrer la complétion et de déverrouiller
la suivante. Le récapitulatif peut donc afficher « Leçon enregistrée » et
`5 / 6 exercices réussis` ; le saut reste exclu des réussites et du score.

L’accueil propose la reprise de la leçon, l’état du parcours et l’accès aux
flashcards. Le dialogue expose une écoute de ses seules répliques mandarin, des
caractères chinois interactifs et une réponse écrite contrôlée à partir de la
réplique précédente. La navigation compacte conserve la route de leçon et
l’onboarding transmet la première leçon au shell.

L’oral extrait le mandarin avant chaque synthèse et utilise une voix `zh-CN` ;
les labels et instructions françaises ne sont pas lus. La vue orale compacte
présente la cible, le modèle et le microphone dans le premier écran, restaure
les résultats persistés sans fabriquer d’enregistrement et sépare la
transcription du protocole `SpeechPronunciationService`. Tant qu’aucun provider
ni credential n’est configuré, elle affiche l’état non configuré et permet
« Passer sans évaluer » ; l’état `skipped` ne porte ni note ni réussite. La
transcription et sa confiance ne produisent aucun score de phonème ou de ton.
Les fixtures vérifient aussi les rapports terminés, les détails par composante
et les états indisponible, en échec et incertain. Le protocole, l’UI et les
fixtures sont prêts pour un fournisseur externe, mais aucun provider, compte,
credential ou proxy n’est activé ou disponible dans la composition actuelle.
L’annulation d’une tâche orale marque aussi une requête encore en attente avant
le saut vers la file principale ; elle ne peut donc plus créer un enregistreur
après la sortie de l’écran.

La vue d’écriture injecte le service local, persiste le dessin et transmet
l’identifiant au journal de progression via `onDrawingCreated`. Le statut de
synchronisation « Sur cet appareil » est cohérent avec l’absence de client
CloudSync dans l’assemblage courant. Les documents, la progression, les
enregistrements temporaires et les dessins sont stockés localement. Aucun
bouton de réinitialisation n’est exposé dans l’interface utilisateur.

## Parcours UI et preuves Apple

Le tree courant contient neuf méthodes UI au total (7 iOS et 2 macOS), avec les
parcours ajoutés pour l’oral sans évaluation et l’écriture guidée :

- le smoke français `PolygoAppUITests.testFrenchOnboardingAndPrimaryOfflineJourneys` pour l’onboarding, le parcours, les cartes, les réglages, une histoire et le dictionnaire ;
- `ZZLessonRegressionJourneyTests.testLessonDraftFeedbackDialogueAndOralJourney` pour le brouillon, le feedback, le dialogue, la réplique précédente interactive, le canevas et l’oral ;
- `ZZLessonRegressionJourneyTests.testLessonDialogueFixtureDeclaresComprehensionAndPreviousReply` pour la cohérence de la participation dialoguée dans le JSON L1 ;
- `ZZLessonRegressionJourneyTests.testAllLessonDialogueFixturesExposeSupportAndPreviousReplyMapping` pour les quatre mappings de dialogue ;
- `LessonReviewJourneyTests.testLessonSkipKeepsOralUnevaluatedAndPersistsWritingPathAcrossRelaunch` pour le passage oral sans évaluation ;
- `LessonReviewJourneyTests.testGuidedWritingRejectsWrongStrokeThenAcceptsRetry` pour le rejet puis la reprise d’un trait guidé ;
- `LessonReviewJourneyTests.testFreeWritingFailureCanBeSelfReportedAndAdvance` pour l’échec libre auto-évalué et la reprise.

Le run historique [34207957185](https://github.com/STOOOKEEE/Polygo/actions/runs/34207957185), exécuté sur `c30d712`, a réussi pour ses quatre méthodes UI d’alors. Le run [34222443020](https://github.com/STOOOKEEE/Polygo/actions/runs/34222443020), sur `249f6d0`, a validé les deux méthodes d’écriture iOS ; ses autres méthodes UI ont échoué et il ne constitue donc pas une validation globale. Le run courant 34225700577 a validé les 2/2 méthodes UI macOS et les 7/7 méthodes UI iOS. Son scénario de passage oral a confirmé le récapitulatif à `5 / 6 exercices réussis` avec un exercice passé sans évaluation, puis la persistance après relance et l’activation de la leçon 2 avec ouverture de son premier exercice.

## Vérifications manuelles restantes

Le conteneur de développement ne fournit ni Xcode, ni SwiftUI, ni SDK iOS ;
les tests UI ne peuvent donc pas y être exécutés localement. Le run Apple
historique 34207957185 a confirmé son périmètre de reprise, dialogue, oral
compact, persistance locale, revue et smoke. Les nouveaux contrats et fixtures
de prononciation, le passage oral sans évaluation et les parcours de traits
sont couverts par la suite portable actuelle ; les deux parcours d’écriture iOS
ont aussi été validés dans le run 34222443020. La validation Apple CI complète
du commit courant est confirmée par le run 34225700577, qui a réussi ses trois
jobs. Les captures natives du Mac et de l’iPhone sont incluses dans ce rapport
pour l’examen visuel.

L’audit VoiceOver, Dynamic Type XXXL, contraste, rendu du mode sombre,
réduction des animations, clavier macOS et fenêtres étroites reste à compléter
par un audit manuel sur iPhone, iPad et Mac. Les labels et groupes sont présents,
mais la langue et la prononciation VoiceOver ainsi que les parcours de toucher
manuel ne sont pas certifiés. Speech avec permission accordée et l’analyse avec
un provider configuré restent à vérifier sur appareil ; le parcours CI a
exercé le chemin sans évaluation après refus du microphone.
CloudKit reste prévu mais inactif : ses conflits réseau ne sont pas testés et
seuls les scénarios du modèle local sont couverts.

## Résultats de la CI

Le run 34207957185 confirme les états observables de reprise après arrière-plan
et relance, le feedback sans double validation, les positions de tuiles, les
cibles audio mandarin, la réplique précédente interactive, le chemin oral
disponible dans son jalon et la disposition compacte de l’oral. Les quatre
méthodes iOS et les deux méthodes macOS de ce run historique ont réussi sans
échec. La composition actuelle ajoute les résultats fournisseur fixture et le
passage explicite sans évaluation ; elle ne doit pas être présentée comme une
correction de prononciation active sans credentials.

Dans le run courant 34225700577, le job package a validé 47/47 tests, le job
macOS a validé le build, le smoke UI et l’export des captures, et le job UI iOS a
validé 7/7 tests. Le fournisseur externe n’est toujours pas activé : le
protocole, l’UI et les fixtures sont prêts, mais aucun compte, credential ou
proxy n’est disponible dans la composition.

Le workflow Apple conserve désormais aussi le bundle xcresult quand le run est
vert. Les captures nommées du parcours sont disponibles avec le résultat de
test pour inspection visuelle, et les deux captures d’accueil validées sont
archivées dans `docs/screenshots/`.
