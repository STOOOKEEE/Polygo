# Audio, synthèse et pratique orale

Le target PolygoApple regroupe l’adaptateur Apple dans
Apple/Audio/AppleAudioService.swift et la vue réutilisable dans
Apple/Audio/SpeechPracticeView.swift. Les contrats portables sont dans
AudioContracts.swift afin que l’app puisse injecter un faux service dans ses
tests et ses previews.

## API d’intégration

AppleAudioService(contentRootURL:) implémente AudioService. Le chemin
contentRootURL doit être la racine Content de l’app ; le service cherche
ensuite le relativePath de chaque AssetReference sans accepter les chemins
absolus, les antislashs ou .. .

```swift
let audio = AppleAudioService(contentRootURL: contentRoot)

try await audio.speak(
    text: "你好",
    localeIdentifier: "zh-CN",
    rate: .normal
)
audio.stopSpeaking()
```

Dans un bloc de leçon ou une fiche phrase, injecte le même service et la
réponse du moteur :

    SpeechPracticeView(
        exercise: exercise,
        audio: model.dependencies.audio,
        answer: $answer,
        pronunciation: model.dependencies.pronunciation
    )

Le callback facultatif onRecordingCreated sert seulement à notifier une
référence éphémère ; il peut rester omis pour respecter la suppression par
défaut.

Les vitesses exposées sont .normal et .slow. SpeechSynthesisRequest conserve
aussi des ToneMarker pour l’affichage pédagogique ; ces marqueurs ne sont pas
ajoutés au texte lu et ne constituent jamais une évaluation de ton.
MandarinToneMarkers.annotated(_:) fournit un repère visuel à partir des
diacritiques pinyin ou d’une liste de tons.

La capture se déroule dans le répertoire temporaire du système :

```swift
let request = AudioRecordingRequest(exerciseID: exerciseID)
let recording = try await audio.record(request)
audio.stopRecording() // bouton « Arrêter », pendant record()
let transcript = try await audio.transcribe(recording, localeIdentifier: "zh-CN")
try await audio.play(recording: recording)
try await audio.delete(recording: recording)
```

record se termine lorsque l’utilisateur appelle stopRecording() ou lorsque la
durée maximale (30 secondes par défaut, bornée à 300) est atteinte. La vue
SpeechPracticeView supprime le fichier lorsqu’elle disparaît et propose une
suppression immédiate ; elle ne conserve donc pas d’audio par défaut. Un appel
onRecordingCreated ne doit pas être interprété comme une conservation
permanente : l’app peut l’omettre si elle ne journalise pas la référence.

## Évaluation de prononciation

La vue accepte un `SpeechPronunciationService` séparé de `AudioService`. Son
protocole reçoit l’enregistrement temporaire et l’exercice, puis renvoie un
`SpeechPronunciationResult`. Un rapport terminé peut fournir un verdict, un
score global et des lignes par mot, son et ton ; les états `unconfigured`,
`unavailable` et `failed` ne contiennent aucun score de remplacement.

La composition livrée utilise `UnconfiguredSpeechPronunciationService` tant
qu’aucun fournisseur n’est choisi et configuré. `OfflineSpeechPronunciationService`
reste un emplacement explicite, mais ne déduit aucun score sans modèle
phonétique. `FixedSpeechPronunciationService` sert uniquement aux tests et aux
prévisualisations ; il permet d’injecter des rapports fixture sans compte,
réseau ou appel payant. Les tests portables couvrent les verdicts fournisseur
réussi, à corriger et incertain, leurs scores, la compatibilité Codable et le
passage `skipped`.

La transcription Apple et sa confiance restent des informations descriptives.
Une transcription seule, même identique à la phrase cible, ne constitue pas
une note de prononciation dans le parcours actuel. La vue ne crée une réponse
évaluable qu’avec un rapport terminé qui contient son score de fournisseur ;
un rapport incertain ou l’absence de fournisseur laisse l’exercice sans note.
Le bouton « Passer sans évaluer » enregistre alors un état `skipped`, qui ne
compte pas comme une réussite et permet de poursuivre la leçon. Dans les quatre
leçons livrées, l’exercice oral est optionnel : `skipped` est compté séparément
dans le bilan (`skippedCount`) et ne bloque ni la complétion fondée sur les
exercices requis ni le déblocage de la leçon suivante.

Les adaptateurs iFlytek ou SpeechSuper pourront implémenter ce protocole
derrière un serveur proxy. Le protocole, l’interface et les fixtures sont prêts
pour cette intégration, mais aucun fournisseur externe n’est activé dans la
composition actuelle : aucun compte, credential ou proxy n’est disponible.
Les clés et secrets ne doivent jamais être embarqués dans l’app.

## TTS Mandarin et disponibilité hors ligne

La lecture de mots ou de phrases passe par AVSpeechSynthesizer et demande la
voix correspondant à localeIdentifier (par exemple zh-CN). La voix doit être
installée sur l’appareil ; si elle est absente, le service renvoie
AudioServiceError.voiceUnavailable et l’interface affiche une erreur
récupérable. La synthèse Apple ne requiert pas de serveur Polygo, mais les
voix, leur qualité et leur disponibilité hors ligne dépendent du système et des
paquets de voix installés par l’utilisateur.

La transcription Apple et sa confiance restent des informations descriptives ;
elles ne sont pas converties en score de phonème ou de ton. Les variantes
`acceptedTranscripts` restent décodables pour les réponses historiques, mais
une transcription seule ne constitue pas une note dans le parcours oral actuel.
Quand Speech n’est pas autorisé, quand le modèle local n’existe pas ou quand
aucune transcription exploitable n’est fournie, `SpeechPracticeView` conserve
l’état non évalué et propose clairement « Passer sans évaluer ».

## Permissions et traitement local

La demande de microphone est déclenchée par le bouton d’enregistrement. Sur
iOS, l’adaptateur configure AVAudioSession uniquement dans les branches
os(iOS) ; aucune référence à AVAudioSession n’est compilée pour macOS.
macOS utilise les autorisations audio de AVCaptureDevice. Le projet doit
fournir à chaque cible Apple une raison française pour
NSMicrophoneUsageDescription et NSSpeechRecognitionUsageDescription dans
la configuration XcodeGen ou l’Info.plist généré ; ces fichiers de configuration
restent sous la responsabilité de l’intégration app.

La transcription utilise exclusivement SFSpeechRecognizer avec
requiresOnDeviceRecognition = true, après vérification de
supportsOnDeviceRecognition. Il n’y a pas de repli réseau silencieux. Les
erreurs transcriptionUnavailable, les permissions refusées et les voix
manquantes laissent l’exercice utilisable avec « Passer sans évaluer » ; elles
ne fabriquent ni note de prononciation ni auto-évaluation positive.

## Validation Apple

Le conteneur Linux ne possède ni SDK Apple ni Xcode. Le [run Apple
34225700577](https://github.com/STOOOKEEE/Polygo/actions/runs/34225700577), sur le
commit `906135d`, a toutefois validé les 47/47 tests portables, les 2/2 tests UI
macOS et les 7/7 tests UI iOS ; il couvre le chemin oral non configuré et le
passage sans évaluation. Les permissions, la disponibilité des voix,
l’interruption audio et le parcours enregistrement/réécoute/transcription avec
un fournisseur configuré restent à vérifier sur appareil. Les fixtures du
protocole vérifient déjà les états terminé, non configuré et sans résultat ; la
correction par fournisseur externe reste à brancher, sans score fabriqué.
