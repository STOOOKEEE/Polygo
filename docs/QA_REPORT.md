# Rapport QA Syllune

Contrôle mis à jour le 7 septembre 2026. Le périmètre de cet agent couvre
`Tests/PolygoCoreTests/**`, `Tests/PolygoAppUITests/**` et ce rapport.

## Résultat de la vérification

Le contenu local actuel comprend quatre leçons (`lesson-01` à `lesson-04`),
27 exercices, quatre lectures de quatre paragraphes et 17 cartes. Les tests
de contrat lisent les JSON réels et vérifient les références fermées entre
leçons, blocs, objectifs, vocabulaire, cartes, histoires et guides d’écriture.

La suite portable `swift test --disable-sandbox --parallel` passe avec **41/41
tests**. Le filtre `ContentContractTests` passe avec **6/6 tests**. La
vérification `git diff --check` ne relève aucune erreur de formatage.

Le dernier run Apple **34131645170**, sur le commit
`baed98864a06dd53eb81d1f916a17cc9c7240394`, a réussi les jobs `package`
(35/35 tests) et `build-macos`, la compilation iOS, la vérification des
métadonnées de l’application et les tests UI iOS. Les deux tests UI ont passé
avec zéro échec.

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

Le run Apple 34131645170 a exécuté les deux tests UI sur un iPhone 16 Pro,
iOS 18.5. Le parcours ajouté est passé en 181,393 secondes et le smoke
existant en 108,208 secondes :

- `LessonReviewJourneyTests.testLessonCompletionAddsFiveCardsAndPersistsFirstReviewAcrossRelaunch` : **PASS**, avec zéro échec ;
- `PolygoAppUITests.testFrenchOnboardingAndPrimaryOfflineJourneys` : **PASS**, avec zéro échec.

Le journal confirme le chemin oral de secours après le refus explicite de la
permission microphone. Le test a ensuite émis les sept gestes du guide de `你`,
validé puis enregistré le tracé localement, et poursuivi jusqu’à la fin de L1.
Ses assertions successives ont confirmé les cinq cartes dues, la révélation et
la note « Bien » de la première carte, puis quatre cartes dues après relance et
la ligne L1 « Terminé ». Le log contient bien sept actions `Press ... then drag`
sur la zone de tracé et le test s’est terminé avec zéro échec ; ces résultats
valident donc les états observables vérifiés par le test, sans dépendre d’un
backend ou d’une réinitialisation des données.

Le smoke existant avait échoué après l’ouverture de la ligne de leçon terminée,
avant ses vérifications de fiche mot, cartes, lecture et réglages. Le commit
candidat ajoute une zone de toucher à toute la ligne de vocabulaire dans
`LessonView.swift`. Le run 34131645170 confirme ensuite la navigation complète
du smoke et toutes ses vérifications de fiche mot, cartes, lecture et réglages.

## Vérifications manuelles restantes

Le conteneur de développement ne fournit ni Xcode, ni SwiftUI, ni SDK iOS ;
les tests UI ne peuvent donc pas y être exécutés localement. Le run Apple
34131645170 valide le nouveau parcours E2E, y compris le fallback oral,
l’écriture, la persistance locale, la revue et la relance, ainsi que le smoke
existant jusqu’aux fiches vocabulaire, cartes, lecture et réglages. Le réglage
Sombre a été sélectionné et confirmé par le smoke ; son rendu visuel reste à
examiner manuellement.

L’audit VoiceOver, Dynamic Type XXXL, contraste, rendu du mode sombre,
réduction des animations, clavier macOS et fenêtres étroites reste à compléter
par un audit manuel sur iPhone, iPad et Mac. Les labels et groupes sont présents,
mais la langue et la prononciation VoiceOver ainsi que les parcours de toucher
manuel ne sont pas certifiés. Speech avec permission accordée reste à vérifier
sur appareil ; le parcours CI a exercé le fallback après refus du microphone.
CloudKit reste prévu mais inactif : ses conflits réseau ne sont pas testés et
seuls les scénarios du modèle local sont couverts.

## Régressions du parcours en cours

Tests/PolygoAppUITests/ZZLessonRegressionJourneyTests.swift couvre le
parcours ajouté autour de la reprise :

- une réponse choisie est conservée après passage en arrière-plan, retour au
  premier plan et relance du processus ;
- le feedback validé reste affiché et ne crée pas une seconde validation avant
  Continuer ;
- la sélection partielle des tuiles est restaurée avec ses positions ;
- le dialogue expose une écoute complète, des cibles audio chinoises,
  l’exercice de compréhension et l’écriture de la réplique précédente ;
- l’écran oral expose cible, pinyin, modèle, arrêt, vitesse,
  enregistrement et auto-évaluation sans score de phonèmes ou de tons.

Le même fichier vérifie dans le JSON L1 la référence de compréhension, la
réplique audio et les réponses acceptées. Cette couverture attend le prochain
run Apple après intégration ; elle n’est pas exécutable dans ce conteneur sans
Xcode, SwiftUI et le SDK iOS.

Le workflow Apple conserve désormais aussi le bundle xcresult quand le run est
vert. Les captures nommées du parcours pourront ainsi être téléchargées pour
inspection visuelle avec le résultat de test.
