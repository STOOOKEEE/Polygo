# Décisions d’architecture Polygo

Ce document fixe la tranche Apple initiale : une application SwiftUI pour iPhone,
iPad et Mac, avec un noyau de domaine portable, des leçons embarquées, un suivi
local et une synchronisation iCloud préparée mais non requise pour apprendre.
Les signatures et le format de contenu normatifs sont dans
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Décisions retenues

### 1. SwiftUI en façade, Swift Package portable au centre

Le code partagé est un package Swift sans import Apple :

```text
PolygoCore       modèles, décodage de contenu, moteur d’exercices, événements
PolygoSRS        scheduler SM-2 déterministe (données de carte dans le core)
PolygoPersistence store local Codable/JSONL et contrats d’outbox
PolygoApp         SwiftUI, navigation, view models et composition
PolygoApple       adaptateurs AVFoundation/Speech/PencilKit, côté Apple
```

La dépendance va toujours de la façade vers le domaine. `PolygoCore` ne connaît
ni SwiftUI, ni AVFoundation, ni Speech, ni PencilKit, ni CloudKit. Les tests du
core et du scheduler doivent donc fonctionner sur Linux avec Foundation.

L’application cible iOS 17, iPadOS 17 et macOS 14. Ce minimum permet un même
parcours SwiftUI et les APIs de concurrence nécessaires sans exiger les APIs
Speech les plus récentes. Les wrappers de plateforme restent conditionnels dans
`PolygoApple`.

Références Apple : [SwiftUI](https://developer.apple.com/documentation/swiftui),
[PackageDescription](https://developer.apple.com/documentation/swift_packages) et
[SupportedPlatform](https://developer.apple.com/documentation/packagedescription/supportedplatform).

### 2. Le repository reste la source de vérité du projet Apple

Le dépôt contiendra un `project.yml` XcodeGen pour les targets Apple ; le fichier
`.xcodeproj` est généré sur macOS. Le package peut être testé directement avec
`swift test`. XcodeGen n’est pas installé dans l’environnement Linux actuel ; sa
présence doit être vérifiée dans le runner macOS ou installée par Homebrew avant
la génération. Il n’est donc pas honnête de prétendre ici qu’un build iOS/macOS
a été exécuté.

Commandes attendues sur un runner macOS, lorsque les sources de l’application
seront présentes :

```sh
brew install xcodegen
xcodegen generate
swift test
xcodebuild -project Polygo.xcodeproj -scheme Polygo \
  -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project Polygo.xcodeproj -scheme Polygo \
  -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
```

Le package partagé ne doit pas prendre de dépendance binaire ou de service
externe uniquement pour rendre le build Apple possible. La CI macOS est la
seule preuve de compilation des targets SwiftUI et Apple.

### 3. Local-first avec événements append-only

Une réponse à un exercice est écrite localement avant toute tentative de réseau.
Le store garde un journal JSONL d’événements immuables, un snapshot reconstruit
et une outbox. Un événement possède un UUID global, un identifiant d’appareil et
un compteur logique ; le serveur pourra dédupliquer par `eventID`.

La première implémentation utilise Foundation et des fichiers JSON atomiquement
remplacés. Elle est adaptée à la petite base locale de la tranche initiale et
reste remplaçable derrière `ProgressStore`. Une migration vers SQLite ou une
autre base ne doit toucher ni le moteur, ni les écrans, ni le format d’événement.

La hiérarchie de fichiers normative est :

```text
Application Support/Polygo/
  store/v1/profiles/<profile-id>/events.jsonl
  store/v1/profiles/<profile-id>/snapshot.json
  sync/v1/profiles/<profile-id>/outbox.jsonl
  media/recordings/<recording-id>.m4a
  media/drawings/<drawing-id>.pkdrawing
```

Les fichiers restent privés à l’utilisateur et ne sont pas ajoutés au dépôt.
Une écriture doit passer par un actor et `Data.write(options: .atomic)` (ou un
remplacement équivalent validé) ; aucune vue ne modifie directement un fichier.

### 4. Contenu immuable, versionné et embarqué

Les cours de la tranche initiale sont des ressources JSON originales livrées
avec l’application. Les textes, illustrations, audio et exercices doivent être
créés pour Polygo ou disposer d’une licence explicite. Le contenu n’est jamais
construit à partir d’un scraping.

Le loader valide `schemaVersion`, `contentVersion`, les IDs référencés et les
chemins de médias avant d’exposer un cours. Une leçon malformée est rejetée avec
une erreur localisée ; elle ne doit pas faire planter le catalogue entier.

Chemin source recommandé :

```text
Content/
  manifest.json
  courses/<course-id>.json
  lessons/<lesson-id>.json
  media/audio/<asset-id>.m4a
  media/images/<asset-id>.*
  media/handwriting/<asset-id>.png
```

À l’exécution, le `ContentStore` reçoit une racine de bundle (`Bundle.module`
pour une ressource de package, ou `Bundle.main` pour la cible d’application) et
ne dépend jamais d’un chemin absolu de machine.

### 5. Moteur d’exercices indépendant des contrôles UI

Chaque exercice est un `ExerciseSpec` codable et discriminé par `kind`. Le
moteur reçoit une réponse de valeur (`option`, `tokens`, `text`, `speech`,
`handwriting`, `selfRating` ou `skipped`) et renvoie une `ExerciseEvaluation`
déterministe.
Les contrôles SwiftUI rendent le spec et convertissent leurs interactions vers
ces valeurs ; ils ne décident pas eux-mêmes si la réponse est juste.

Le speaking et l’écriture ont donc un chemin hors ligne explicite :

- audio de référence et enregistrement sont locaux ;
- la transcription Speech est facultative et peut échouer sans bloquer la leçon ;
- la tranche initiale n’annonce pas de score phonétique à partir de la
  transcription : un `SpeechPronunciationService` distinct doit fournir un
  verdict et un score ; sans fournisseur configuré, l’UI permet `skipped` sans
  note ni réussite ;
- le tracé chinois est conservé dans le format PencilKit sur iOS/iPadOS et dans
  le format de traits Polygo sur macOS natif ; il peut être auto-évalué ; la
  reconnaissance automatique des caractères n’est pas une condition de réussite.

Références Apple : [AVAudioEngine](https://developer.apple.com/documentation/avfaudio/avaudioengine),
[Speech](https://developer.apple.com/documentation/speech),
[SFSpeechRecognizer](https://developer.apple.com/documentation/speech/sfspeechrecognizer)
et [PKCanvasView](https://developer.apple.com/documentation/pencilkit/pkcanvasview).

### 6. SM-2 isolé et auditable

`PolygoSRS` implémente le SM-2 classique avec une note entière de 0 à 5,
`easeFactor` borné à 1,3, intervalles initiaux 1 puis 6 jours et remise à zéro
pour une note inférieure à 3. La fonction est pure : même état, même note et
même date donnent le même nouvel état. Les tests couvrent les bornes, les
lapses, l’idempotence de lecture et les dates de due.

Les cartes et les réponses sont des événements séparés du snapshot. Si deux
appareils révisent une même carte hors ligne, les événements sont ordonnés par
`(lamport, deviceID, eventID)` avant reconstruction. Cela garantit la
convergence déterministe ; la date murale sert à l’affichage, pas à résoudre
seule un conflit.

### 7. Synchronisation future par CloudKit privé, jamais obligatoire

Le premier livrable ne demande pas de compte et n’appelle aucun réseau. Le
contrat `CloudSyncClient` est toutefois défini autour d’événements immuables :
un futur adaptateur pourra écrire un record privé `ProgressEvent` dont le nom
est `eventID`, puis tirer les nouveaux records avec un curseur CloudKit.
Les médias audio enregistrés et les dessins ne sont pas synchronisés dans cette
tranche ; les assets de cours sont des ressources versionnées.

CloudKit est le choix Apple naturel pour la suite car ses bases privées sont
liées au compte iCloud et son service couvre iOS, iPadOS et macOS. Cette décision
ne signifie pas que l’entitlement, le conteneur iCloud ou les migrations de
schéma sont déjà configurés.

Référence : [CloudKit](https://developer.apple.com/icloud/cloudkit/) et
[CloudKit framework](https://developer.apple.com/documentation/cloudkit).

### 8. Permissions et confidentialité sont dans les adaptateurs

Le core ne demande jamais une permission. `PolygoApple` demande séparément le
microphone et la reconnaissance vocale, expose l’état `denied`/`restricted`/
`unavailable` et fournit un résultat récupérable à l’UI. L’écriture fonctionne
au touch, au Pencil, à la souris ou au trackpad ; les données brutes restent
locales jusqu’à une action future explicitement définie.

Les clés `NSMicrophoneUsageDescription` et
`NSSpeechRecognitionUsageDescription` devront être présentes dans l’Info.plist
de la cible Apple. Aucun secret, token, compte ou base locale ne doit être
commité.

## Ce qui est volontairement hors de la tranche initiale

La première version ne promet pas une correction phonétique acoustique, une
reconnaissance de caractères chinoise parfaite, un mode conversationnel ouvert,
un backend Polygo, une synchronisation des enregistrements/dessins, ni des
notifications de rappel. Ces fonctionnalités pourront utiliser les mêmes
protocoles sans imposer un réseau ou une API propriétaire au noyau.

## État vérifié de l’environnement

Vérifié le 2026-09-07 dans le conteneur de travail : Debian GNU/Linux 13
(trixie), x86_64, dépôt propre sur `main`, Git disponible ; `swift`, `swiftc`,
`xcodebuild`, `xcodegen` et Tuist absents. Cette machine permet de relire les
documents et de lancer des contrôles texte, mais pas de compiler ou signer une
cible Apple. La compilation Apple reste une étape obligatoire du runner macOS.
