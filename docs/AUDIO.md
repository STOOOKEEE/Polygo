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
        answer: $answer
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

## TTS Mandarin et disponibilité hors ligne

La lecture de mots ou de phrases passe par AVSpeechSynthesizer et demande la
voix correspondant à localeIdentifier (par exemple zh-CN). La voix doit être
installée sur l’appareil ; si elle est absente, le service renvoie
AudioServiceError.voiceUnavailable et l’interface affiche une erreur
récupérable. La synthèse Apple ne requiert pas de serveur Polygo, mais les
voix, leur qualité et leur disponibilité hors ligne dépendent du système et des
paquets de voix installés par l’utilisateur.

La comparaison orale porte uniquement sur le texte renvoyé par la transcription
et les variantes acceptedTranscripts du contenu. Une confiance éventuelle est
la confiance de transcription fournie par Apple ; elle n’est pas convertie en
score de phonème ou de ton. Quand Speech n’est pas autorisé, quand le modèle
local n’existe pas ou quand aucune transcription exploitable n’est fournie,
SpeechPracticeView propose clairement l’auto-évaluation.

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
manquantes laissent l’exercice utilisable par auto-évaluation.

## Validation Apple

Le conteneur Linux ne possède ni SDK Apple ni Xcode : la compilation du target,
les permissions, la disponibilité des voix, l’interruption audio et le parcours
enregistrement/réécoute/transcription doivent être vérifiés sur un runner
iOS 17+ et macOS 14+ avec XcodeGen puis Xcode. Le test manuel doit vérifier que
le bouton Arrêter termine réellement record, que Réécouter lit le fichier
temporaire, que quitter l’exercice le supprime et qu’un appareil sans modèle
Speech local présente l’auto-évaluation sans faux score de ton.
