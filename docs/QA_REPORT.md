# Rapport QA Syllune

Contrôle mis à jour le 7 septembre 2026. Le périmètre de cet agent couvre
`Tests/PolygoCoreTests/**`, `Tests/PolygoAppUITests/**` et ce rapport.

## Résultat de la vérification

Le contenu local actuel comprend quatre leçons (`lesson-01` à `lesson-04`),
27 exercices, quatre lectures de quatre paragraphes et 17 cartes. Les tests
de contrat lisent les JSON réels et vérifient les références fermées entre
leçons, blocs, objectifs, vocabulaire, cartes, histoires et guides d’écriture.

La suite portable `swift test --disable-sandbox --parallel` passe avec **35/35
tests**. Le filtre `ContentContractTests` passe avec **6/6 tests**. La
vérification `git diff --check` ne relève aucune erreur de formatage.

Le run Apple `34116224643` sur le commit `28128b5` est vert pour le paquet,
le build iOS, le smoke UI iOS et le build macOS. Il valide l’état alors suivi
par CI. Le contenu curriculum courant et le nouveau parcours UI décrit
ci-dessous sont encore dans l’arbre de travail et doivent être inclus dans un
prochain run Apple.

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
onboarding → leçon → exercice → fin → cartes, l’idempotence des événements,
la conservation d’un état SRS lors d’un ajout répété, la correction d’une
tentative et le rejet d’un événement d’un autre profil.

## Vérification statique du parcours

Le lecteur extrait les blocs `exercise` dans leur ordre, affiche les blocs
pédagogiques qui précèdent le premier exercice et présente le récapitulatif
placé après la séquence lorsque le dernier exercice est évalué. Les blocs de
lecture intégrés utilisent `ChineseSelectableText`, leur segmentation et la
fiche mot locale. Une fin réussie appelle `completeLesson`, qui ajoute toutes
les cartes du document sans remplacer l’état SRS d’une carte déjà connue.

La navigation compacte conserve la route de leçon et l’onboarding transmet la
première leçon au shell. L’annulation d’une tâche orale marque aussi une
requête encore en attente avant le saut vers la file principale ; elle ne peut
donc plus créer un enregistreur après la sortie de l’écran. La vue d’écriture
injecte le service local, persiste le dessin et transmet l’identifiant au
journal de progression via `onDrawingCreated`.

Le statut de synchronisation « Sur cet appareil » est cohérent avec l’absence
de client CloudSync dans l’assemblage courant. Les documents, la progression,
les enregistrements temporaires et les dessins sont stockés localement. Aucun
bouton de réinitialisation n’est exposé dans l’interface utilisateur.

## Parcours UI ajouté

`Tests/PolygoAppUITests/LessonReviewJourneyTests.swift` ajoute un test UI
indépendant du smoke existant. Il :

1. charge les réponses correctes et les cinq cartes depuis
   `Content/lessons/lesson-01.json` ;
2. complète les six exercices L1 avec les contrôles visibles ;
3. enregistre l’oral par auto-évaluation explicite lorsque le microphone ou la
   transcription locale ne sont pas disponibles, en vérifiant que l’interface
   ne prétend pas noter les phonèmes ou les tons ;
4. trace les sept traits de `你` par gestes de coordonnées sur le vrai canevas,
   vérifie le tracé et exige son enregistrement local ;
5. vérifie les cinq cartes dues, révèle et note la première, relance
   l’application, puis vérifie les quatre cartes restantes et la ligne L1
   marquée « Terminé ».

Ce test ne remplace pas le smoke `PolygoAppUITests.swift`, n’efface pas les
données utilisateur et n’injecte ni backend ni réponse de test. Il est compilé
par la cible `PolygoAppUITests` puisque `project.yml` inclut tout le dossier
`Tests/PolygoAppUITests`.

## Vérifications en attente sur appareil Apple

Le conteneur de développement ne fournit ni Xcode, ni SwiftUI, ni SDK iOS ;
aucun test UI ne peut donc y être exécuté. Le nouveau parcours E2E est en
attente d’un run Apple CI avec le contenu courant. Ce run devra confirmer les
permissions microphone et reconnaissance vocale, l’auto-évaluation de
secours, les sept gestes du canevas, la persistance du dessin, la relance et
la conservation de l’état SRS.

L’audit VoiceOver, Dynamic Type XXXL, contraste, mode sombre, réduction des
animations, clavier macOS, fenêtres étroites et conflits de synchronisation
reste statique tant qu’un appareil ou simulateur Apple n’est pas disponible.
