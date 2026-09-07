# Rapport QA Syllune

Contrôle préparé le 8 septembre 2026. Le périmètre de cet agent couvre
`Tests/PolygoCoreTests/**`, `Tests/PolygoAppUITests/**` et ce rapport.

## État de validation

Le contenu local actuel comprend quatre leçons (`lesson-01` à `lesson-04`),
27 exercices, quatre lectures de quatre paragraphes et 17 cartes. Les tests de
contrat lisent les JSON réels et vérifient les références fermées entre leçons,
blocs, objectifs, vocabulaire, cartes, histoires et guides d’écriture.

Le package courant contient **43 tests XCTest**, dont **6 tests de contrat de
contenu**. Le contrôle `git diff --check` est propre. Le code validé est le
commit `f7e603ec3a59df4a9a157ad122cce04d68c8b0b1` ; le
[run 34167951193](https://github.com/STOOOKEEE/Polygo/actions/runs/34167951193)
est terminé avec succès. Il valide les **43/43 tests** package, la génération
XcodeGen, les métadonnées, les builds iOS/macOS et les quatre méthodes UI.

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
- l’absence honnête d’audio livré et les chemins, sommes SHA-256 et nombre de
  traits des trois guides d’écriture locaux.

`ExerciseAndProgressTests.swift` couvre la normalisation du pinyin, de la
ponctuation et de la casse, les mauvaises formes de réponse, les scores
invalides, les variantes de transcription, l’auto-évaluation, le parcours
onboarding → leçon → exercice → fin → cartes, la reprise d’un brouillon et du
feedback, les checkpoints de dialogue, l’idempotence des événements, la
conservation d’un état SRS lors d’un ajout répété, la correction d’une tentative
et le rejet d’un événement d’un autre profil. `MandarinSpeechTextTests.swift`
vérifie aussi que le TTS ne reçoit que le texte mandarin utile.

## Vérification statique du parcours

Le lecteur extrait les blocs `exercise` dans leur ordre, affiche les blocs
pédagogiques qui précèdent le premier exercice et présente le récapitulatif
placé après la séquence lorsque le dernier exercice est évalué. Les checkpoints
conservent la réponse en cours, le feedback visible et les brouillons/résultats
de dialogue par identifiant stable ; la relance peut donc reprendre le même
exercice ou réinitialiser proprement une fin incomplète. Une fin réussie appelle
`completeLesson`, qui ajoute toutes les cartes du document sans remplacer l’état
SRS d’une carte déjà connue.

L’accueil propose la reprise de la leçon, l’état du parcours et l’accès aux
flashcards. Le dialogue expose une écoute de ses seules répliques mandarin, des
caractères chinois interactifs et une réponse écrite contrôlée à partir de la
réplique précédente. La navigation compacte conserve la route de leçon et
l’onboarding transmet la première leçon au shell.

L’oral extrait le mandarin avant chaque synthèse et utilise une voix `zh-CN` ;
les labels et instructions françaises ne sont pas lus. La vue orale compacte
présente la cible, le modèle et le microphone dans le premier écran, restaure
les résultats persistés sans fabriquer d’enregistrement et maintient une
auto-évaluation explicite. La transcription et sa confiance ne produisent
aucun score de phonème ou de ton. L’annulation d’une tâche orale marque aussi
une requête encore en attente avant le saut vers la file principale ; elle ne
peut donc plus créer un enregistreur après la sortie de l’écran.

La vue d’écriture injecte le service local, persiste le dessin et transmet
l’identifiant au journal de progression via `onDrawingCreated`. Le statut de
synchronisation « Sur cet appareil » est cohérent avec l’absence de client
CloudSync dans l’assemblage courant. Les documents, la progression, les
enregistrements temporaires et les dessins sont stockés localement. Aucun
bouton de réinitialisation n’est exposé dans l’interface utilisateur.

## Parcours UI validé par le run Apple

La cible `PolygoAppUITests` contient quatre méthodes de test :

- le smoke français `PolygoAppUITests.testFrenchOnboardingAndPrimaryOfflineJourneys` pour l’onboarding, le parcours, les cartes, les réglages, une histoire et le dictionnaire ;
- `LessonReviewJourneyTests.testLessonCompletionAddsFiveCardsAndPersistsFirstReviewAcrossRelaunch` pour la fin de leçon, les cinq cartes dues, la revue et la relance ;
- `ZZLessonRegressionJourneyTests.testLessonDraftFeedbackDialogueAndOralJourney` pour le brouillon, le feedback, le dialogue, la réplique précédente interactive, le canevas et l’oral ;
- `ZZLessonRegressionJourneyTests.testLessonDialogueFixtureDeclaresComprehensionAndPreviousReply` pour la cohérence de la participation dialoguée dans le JSON L1.

Ces quatre tests ont réussi dans le [run Apple 34167951193](https://github.com/STOOOKEEE/Polygo/actions/runs/34167951193), exécuté sur le commit `f7e603ec3a59df4a9a157ad122cce04d68c8b0b1`. Aucun test UI n’a échoué ; la durée cumulée affichée est de **565,379 s** : 224,033 s pour la fin/revue, 67,947 s pour le smoke français, 5,272 s pour le fixture de dialogue et 268,115 s pour le parcours brouillon/feedback/dialogue/oral. Les captures nommées `oral-controls` et `oral-result` ont été extraites des artefacts UI et inspectées visuellement ; la vue orale compacte expose bien la cible, le pinyin, le modèle, la vitesse, le microphone et le bouton de vérification.

## Vérifications manuelles restantes

Le conteneur de développement ne fournit ni Xcode, ni SwiftUI, ni SDK iOS ;
les tests UI ne peuvent donc pas y être exécutés localement. Le run Apple
34167951193 a confirmé le nouveau parcours de reprise, le dialogue, l’oral
compact, l’écriture, la persistance locale, la revue et le smoke jusqu’aux
fiches vocabulaire, cartes, lecture et réglages. Le rendu visuel du mode sombre
reste à examiner manuellement.

L’audit VoiceOver, Dynamic Type XXXL, contraste, rendu du mode sombre,
réduction des animations, clavier macOS et fenêtres étroites reste à compléter
par un audit manuel sur iPhone, iPad et Mac. Les labels et groupes sont présents,
mais la langue et la prononciation VoiceOver ainsi que les parcours de toucher
manuel ne sont pas certifiés. Speech avec permission accordée reste à vérifier
sur appareil ; le parcours CI a exercé le fallback après refus du microphone.
CloudKit reste prévu mais inactif : ses conflits réseau ne sont pas testés et
seuls les scénarios du modèle local sont couverts.

## Résultats de la CI

Le run 34167951193 confirme les états observables de reprise après arrière-plan
et relance, le feedback sans double validation, les positions de tuiles, les
cibles audio mandarin, la réplique précédente interactive, le fallback oral et
la disposition compacte de l’oral. Les quatre méthodes UI ont réussi sans
échec.

Le workflow Apple conserve désormais aussi le bundle xcresult quand le run est
vert. Les captures nommées du parcours sont disponibles avec le résultat de
test pour inspection visuelle.
