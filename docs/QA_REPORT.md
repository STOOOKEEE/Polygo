# Rapport QA Syllune

Contrôle préparé le 7 septembre 2026. Le périmètre de cet agent est limité à
`Tests/PolygoCoreTests/**`, `Tests/PolygoAppUITests/**` et ce rapport.

## Bloquants actuels — revue statique

1. **Le lecteur perd le récapitulatif et le mot-à-mot de la lecture.**
   `LessonView` affiche les blocs pédagogiques seulement avant le premier
   exercice (`App/LessonView.swift:86-92`), alors que chaque JSON place son bloc
   `recap` après le dernier exercice. Ce récapitulatif n’est donc jamais rendu.
   Dans le bloc `reading`, les segments sont encore des `Text` et des
   `NavigationLink` directs (`App/LessonView.swift:271-295`) : ils n’utilisent
   pas `ChineseSelectableText`, ne fournissent pas le bouton audio par mot et
   n’exposent pas son aide VoiceOver. Le mode histoire séparé a été raccordé,
   mais le lecteur intégré à la leçon reste incomplet.

2. **Le bouton de fin d’onboarding n’ouvre pas la première leçon sur iPhone.**
   `OnboardingView` appelle bien `startLesson` après « Ouvrir ma première
   leçon », mais `PhoneTabShell` réduit toute route `.lesson` à l’onglet
   `.today` (`App/OnboardingView.swift:144-149`, `App/Navigation.swift:137-142,
   202-210`). Sur une taille compacte, l’action atterrit donc sur Aujourd’hui
   et oblige l’apprenant à ouvrir Parcours manuellement.

3. **Une annulation orale peut laisser démarrer le microphone.**
   `AppleAudioService.record` annule seulement si `recorder` existe déjà
   (`Apple/Audio/AppleAudioService.swift:227-244`). Si la tâche est annulée
   pendant le saut vers la file principale, la fermeture retourne sans marquer
   la requête ; `beginRecording` peut alors créer l’enregistreur après la
   disparition de `SpeechPracticeView` (`Apple/Audio/AppleAudioService.swift:521-562`,
   `Apple/Audio/SpeechPracticeView.swift:58-70`). Il faut traiter cet état
   « en attente » comme l’annulation Speech déjà corrigée.

4. **Le tracé est écrit sur disque, mais son événement de progression n’est
   jamais appendu.** `HandwritingPracticeView` persiste le JSON via le service
   local (`Apple/Handwriting/HandwritingPracticeView.swift:413-457`), tandis que
   `LessonView` ne fournit aucun callback analogue à `onRecordingCreated`
   (`App/LessonView.swift:102-116`). `AppModel.saveDrawing` existe
   (`App/AppModel.swift:160-163`) mais n’est appelé nulle part : la reprise du
   fichier et l’historique append-only ne décrivent donc pas le même dessin.

## État d’exécution

### PASS exécuté

- Inspection déterministe des JSON embarqués : `manifest.json`, le cours
  `mandarin-starter` et `lesson-01` à `lesson-03` se lisent avec le schéma
  attendu. Le cours référence les trois leçons dans l’ordre.
- Contrôle des quantités du contenu : 5, 5 et 6 entrées lexicales ; 6, 7 et 7
  exercices ; une histoire de quatre paragraphes par leçon, soit 3 histoires
  et 20 exercices.
- Contrôle des paires simplifié/traditionnel, pinyin accentué et numéros de
  tons sur les 16 formes lexicales livrées.
- Relecture statique des corrections déjà présentes : le lecteur de leçon
  extrait tous les blocs `exercise` dans leur ordre et affiche les blocs
  pédagogiques qui précèdent le premier exercice (`App/LessonView.swift:18-22`,
  `App/LessonView.swift:86-92`) ; la fin réussie de la leçon ajoute toutes ses
  cartes (`App/AppModel.swift:131-138`) ; l’ajout d’une carte existante ne
  remplace pas son état (`Sources/PolygoCore/ProgressReducer.swift:112-115`).
- Le bouton oral `Arrêter` appelle désormais `AudioService.stopRecording()` et
  la sortie de l’exercice arrête lecture/capture et supprime l’enregistrement
  temporaire (`Apple/Audio/SpeechPracticeView.swift:58-71,291-295`).

### Tests XCTest ajoutés et vérifiés

`Tests/PolygoCoreTests/ContentContractTests.swift` couvre le décodage réel du
contenu, les références fermées entre blocs/objectifs/mots/cartes/histoires,
les 16 paires de script et pinyin, l’absence honnête d’audio livré et la
réponse canonique acceptée pour chacun des 20 exercices.

`Tests/PolygoCoreTests/ExerciseAndProgressTests.swift` couvre la normalisation
pinyin/ponctuation/casse, les réponses de mauvais type, les scores invalides,
les variantes de transcription, l’auto-évaluation, la progression onboarding →
leçon → exercice → fin → carte, l’idempotence d’un événement, la conservation
d’un état SRS lors d’un ajout répété, la correction d’une tentative et le
rejet d’un événement d’un autre profil.

`swift test --parallel` passe avec les 34 tests XCTest du paquet. Le smoke UI
`Tests/PolygoAppUITests/PolygoAppUITests.swift` est écrit contre les labels
français livrés, mais ne peut être compilé ou exécuté dans ce conteneur sans
Xcode, SwiftUI et le SDK iOS.

## Contrôles statiques résolus ou encore ouverts

- **Mot-à-mot hors lecteur de leçon :** `ChineseSelectableText` tokenise les
  phrases quand une segmentation ou un vocabulaire est fourni et ouvre la fiche
  avec lecture locale (`App/DesignSystem.swift:445-475`,
  `App/StoryViews.swift:76-97`, `App/LearningViews.swift:384-414`). Le défaut
  résiduel est limité au bloc `reading` intégré signalé en tête.
- **Écriture live :** `App/Dependencies.swift:43-55` injecte maintenant
  `LocalHandwritingService` dans un dossier `drawings`; les interpolations du
  service local sont correctes (`Apple/Handwriting/LocalHandwritingService.swift:25-29,115-116`).
  Le raccord de l’événement `drawingSaved` reste à faire.
- **Annulation Speech :** `AppleAudioService.transcribe` annule sa tâche,
  termine sa continuation et traite aussi la requête encore en file
  (`Apple/Audio/AppleAudioService.swift:327-479`). La course analogue de
  `record` reste ouverte.
- **Oral sans notation de prononciation :** la comparaison porte sur le texte
  transcrit normalisé ; l’interface nomme la confiance comme confiance de
  transcription et précise qu’aucun phonème ni ton n’est noté
  (`Apple/Audio/SpeechPracticeView.swift:167-185,346-352`).
- **Cartes :** `AppModel.completeLesson` ajoute toutes les cartes après la fin
  réussie (`App/AppModel.swift:131-138`) et `ReviewCardsView` recharge les
  cartes dues après relance (`App/ReviewViews.swift:44-48,107-110`). Le noyau
  possède un reset testé (`Sources/PolygoSRS/ReviewDeck.swift:142-155`), mais
  aucun bouton de réinitialisation de progression ou de carte n’est exposé
  dans l’interface (`App/ReviewViews.swift`, `App/ProfileSettingsViews.swift`).

## Audit statique, sans verdict device

- **Leçon et onboarding :** les routes ont des identifiants opaques et la cible
  iOS/macOS est séparée dans `project.yml`. Le lecteur conserve la progression
  par événement et ajoute les cartes après une fin entièrement réussie. Le
  démarrage, le lancement de la première leçon depuis l’onboarding et la
  réouverture après écriture n’ont pas été exécutés sur un simulateur ; le
  défaut de route compacte décrit en tête est visible par inspection du code.
- **Oral :** le TTS local est utilisé quand la référence audio est absente ; la
  confiance Speech est affichée comme confiance de transcription et ne devient
  pas une note phonétique. Les états refus microphone, refus Speech, absence de
  modèle local et auto-évaluation sont présents dans
  `SpeechPracticeView.swift`. Permissions, interruption, arrêt manuel,
  réécoute et suppression du fichier restent à vérifier sur iOS/macOS.
- **Écriture :** le canevas accepte le doigt, Pencil, souris et trackpad ;
  `Annuler`, `Effacer`, `Vérifier`, guide et auto-évaluation sont exposés. La
  reconnaissance OCR renvoie explicitement `unsupported`. Les trois guides
  JSON (`你`, `我`, `国`) sont livrés sous `Content/assets/handwriting/` et les
  références des leçons portent désormais leurs chemins et SHA-256 réels. Aucun
  tracé Apple n’a été exécuté faute de SDK et de simulateur.
- **Hors ligne/sync :** les documents et la progression locale ont un chemin
  JSON et les tests SRS/persistence existants couvrent déjà rejeu, outbox,
  ordre déterministe et reprise. L’application n’injecte pas de
  `CloudSyncClient`, ce qui rend son statut « Sur cet appareil » exact. Aucun
  réseau, changement de curseur ou conflit CloudKit n’est testé ici.
- **Accessibilité, thème et responsive :** `docs/ACCESSIBILITY.md` contient
  l’audit statique détaillé. Aucun test VoiceOver, Dynamic Type XXXL, contraste,
  mode sombre, réduction des animations, clavier Mac ou fenêtre étroite n’a été
  exécuté faute de SDK et de simulateur.

## Cible UI

Le fichier `Tests/PolygoAppUITests/PolygoAppUITests.swift` fournit le contrat
smoke suivant : lancement en français, nom et choix du niveau/durée pendant
l’onboarding, navigation vers `Parcours` et la première leçon, ouverture de la
fiche `你好` et activation de `Écouter` sans supposer qu’un son est produit,
accès à `Cartes`, `Explorer` et l’histoire `Le premier échange`, puis accès aux
`Réglages` depuis `Profil` avec vérification du statut `Sur cet appareil`.

La cible iOS `PolygoAppUITests` est maintenant déclarée dans `project.yml:78-100`
avec `PolygoApp` comme application hôte, et le workflow CI contient l’étape
`xcodebuild ... test` sur le premier iPhone disponible
(`.github/workflows/apple.yml:46-59`). Aucun run Apple n’est encore disponible
dans cette revue ; le smoke et les builds iOS/macOS restent donc en attente de
logs device.
