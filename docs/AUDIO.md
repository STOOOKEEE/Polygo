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

// Joue le clip embarqué ; sans clip lisible, la voix locale lit le texte.
try await audio.speak(
    text: line.hanzi,
    localeIdentifier: "zh-CN",
    rate: .slow,
    asset: line.audio
)
audio.stopSpeaking() // arrête aussi le clip en cours
```

`play(asset:rate:)` rend la main à la fin du clip (ou lève `CancellationError`
s’il est arrêté ou remplacé). `SpeechSynthesisSegment.narration(_:rate:)`
transforme les segments de `MandarinSpeechText.dialogueSegments` /
`readingSegments` : une réplique ou un paragraphe qui a un clip devient un seul
segment qui le porte, les autres restent découpés en propositions pour la
synthèse. `speakSequence` enchaîne clips et synthèse avec les mêmes pauses.

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

Les vitesses exposées sont .normal et .slow. Pour un clip, .slow règle
`AVAudioPlayer.rate` à 0,7 (`enableRate`, hauteur conservée) : un seul fichier
sert les deux vitesses. Pour la synthèse, .slow vaut 0,34 au lieu de 0,50.
SpeechSynthesisRequest conserve aussi des ToneMarker pour l’affichage
pédagogique ; ces marqueurs ne sont pas ajoutés au texte lu et ne constituent
jamais une évaluation de ton. MandarinToneMarkers.annotated(_:) (PolygoCore)
fournit un repère visuel à partir des diacritiques pinyin ou d’une liste de tons,
un chiffre par syllabe, y compris dans un mot écrit d’un bloc (`Běi³jīng¹`).

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

## Audio embarqué : deux voix et mode lent

### Source et licence

Les clips de `Content/assets/audio/` sont synthétisés hors ligne par
[Kokoro-82M v1.1-zh](https://huggingface.co/hexgrad/Kokoro-82M-v1.1-zh)
(révision `01e7505bd6a7a2ac4975463114c3a7650a9f7218`, poids SHA-256
`b1d8410f…`), sous **licence Apache 2.0** ; les locuteurs chinois viennent d’un
jeu de données professionnel cédé librement par LongMaoData. Voix retenues :
`zf_093` (féminine, ~280 Hz) et `zm_011` (masculine, ~115 Hz). Licence et
attribution : `Content/assets/audio/KOKORO-LICENSE.TXT`. Aucun modèle n’est
embarqué dans l’app.

Options écartées : Piper `zh_CN-huayan` (licence du jeu de données inconnue),
`zh_CN-xiao_ya` (BZNSYP, usage non commercial), `zh_CN-chaowen` (données CC0
mais affiné depuis xiao_ya), MeloTTS-Chinese (MIT mais une seule voix
féminine), CosyVoice-300M-SFT (Apache 2.0, mais ~8× le temps réel sur ce
processeur et tons plats pour la voix masculine), et tout service en ligne
(edge-tts…) dont les conditions interdisent la redistribution.

### Contrôle de qualité

Les voix ont été mesurées par une piste de hauteur (autocorrélation) syllabe
par syllabe, les frontières venant des durées prédites par le modèle. Sur 24
textes du cours (répliques et mots de deux syllabes), puis 24 autres, les 100
voix chinoises réalisent 50 à 67 % des tons attendus ; `zf_093` et `zm_011`
sont dans le premier groupe et à une octave l’une de l’autre. La prononciation
n’est pas devinée : le générateur donne au frontal misaki le pinyin authored de
chaque texte (sandhi 3-3, 不 et 一 appliqués ensuite), vérifié par exemple sur
你也想去吗 (ni3 ye2 xiang3), 很好喝 (hen2 hao3), 绿 (lv4).

Une syllabe isolée n’est pas fiable : sur 妈/麻/马/骂 et d’autres quadruplets,
les tons 2 et 3 restent plats ou montent-descendent, quels que soient la voix,
la vitesse ou une phrase porteuse. Les textes d’une seule syllabe (mots d’un
caractère, porteurs du module 0) gardent donc la voix du système, jamais
pire que l’existant. Les invites `toneDiscrimination` de plusieurs syllabes
ne reçoivent un clip que si chaque ton plein y est entendu (niveau, montée,
creux ou descente mesurés) ; sinon elles restent aussi en synthèse locale.

### Couverture et voix

Un clip existe pour chaque texte d’au moins deux syllabes : répliques de
dialogue et de `dialogueOrder`, paragraphes de lecture, mots, exemples et
cartes, invites `listeningChoice`, `dictation`, `toneDiscrimination`,
`conversationChoice` (et ses réponses) et modèle `speaking`. Voix : Mina et Lin
→ féminine, Tao et An → masculine ; mots, lectures et invites d’écoute →
féminine ; exemples de vocabulaire → masculine (les deux voix dès la première
leçon) ; réponse de conversation → l’autre voix que la réplique ; modèle oral →
voix du personnage qui dit la phrase dans le dialogue, sinon féminine. Les noms
écrits en latin sont dits 米娜 mǐ nà, 涛 tāo, 林 lín, 安 ān. Un clip est nommé
par le SHA-256 de (moteur, voix, texte, pinyin) : un texte identique dit par la
même voix n’a qu’un fichier.

Restent en voix système : les textes d’une syllabe, les tuiles `wordOrder`, les
paires `matching`, les choix `choice`, et les invites de ton refusées par le
contrôle ci-dessus. Le clip refusé est celui du mot entier, donc le mot garde
aussi la voix système dans le vocabulaire et les cartes : sur 45 invites de ton
de plusieurs syllabes, 17 ont un clip et 28 sont refusées (par exemple 你好,
妈妈, 学习, 电影, 水果 ; la liste complète est imprimée par le générateur).

Bilan de la génération : 1 404 clips (766 en voix féminine, 638 en voix
masculine), 68 minutes, 22,4 Mo (25 Mo sur disque). Une régénération des
mêmes clips donne des fichiers identiques octet pour octet.

### Format

AAC-LC mono 24 kHz à 40 kb/s dans un conteneur M4A, silences de tête et de
queue coupés (50 ms / 100 ms gardés), niveau ramené à -16 dBFS RMS sur les
trames voisées avec crête ≤ -1 dBFS, fondus de 5 ms. Le dossier `Content` est
copié tel quel dans l’app iOS et macOS (`project.yml`), donc les clips sont
hors ligne.

### Mode lent

Le bouton « Lent » (tortue, `SlowAudioToggle`, mémorisé dans
`@AppStorage("audio.slowMode")`) est présent dans les dialogues, les lectures,
les écoutes, dictées, exercices de ton et conversations ; la fiche mot et le
texte chinois ont un bouton « Lentement ». Le modèle oral garde son sélecteur
Normale / Lente.

### Régénérer

`python3 Tools/content_tool.py generate` rattache les clips existants et ne
demande aucun moteur. Pour créer les clips manquants (Python 3.12, ffmpeg) :

```sh
uv venv --python 3.12 ~/.cache/polygo-tts-venv
VIRTUAL_ENV=~/.cache/polygo-tts-venv uv pip install \
  --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple \
  --index-strategy unsafe-best-match torch "kokoro==0.9.4" "misaki[zh]==0.9.4" soundfile
cd Tools && ~/.cache/polygo-tts-venv/bin/python build_audio.py --root ../Content
```

Le script télécharge le modèle à la révision figée, vérifie son SHA-256,
synthétise uniquement les clips absents (graine fixe par phrase), supprime les
clips inutilisés, rattache et lance le lint. Le lint refuse une référence
périmée ou manquante et un clip qu’aucune leçon n’utilise.

## Sons de réponse

`Sounds/answer-correct.m4a` (carillon montant do6 → sol6, 0,34 s) et
`Sounds/answer-incorrect.m4a` (deux notes graves mi4 → do4, 0,36 s) sont des
sons originaux synthétisés pour Syllune avec ffmpeg (`aevalsrc` : sinus et
harmonique avec décroissance exponentielle), crête vers −3 dBFS, AAC mono
64 kbit/s, environ 4 Ko chacun. Ils relèvent de la licence du projet. Le
dossier est une ressource des deux apps (`project.yml`).

`AnswerSounds` (App) joue le son quand une réponse est vérifiée : « Vérifier »
d’une leçon, participation au dialogue, pratique orale et écriture.
`ExerciseEvaluation.feedbackSound` (PolygoCore) choisit le son : aucun pour une
réponse passée, incomplète ou auto-évaluée. Le réglage « Sons de réponse »
(`syllune.answerSounds`, activé par défaut) les coupe.

La lecture passe par `AudioService.playEffect(at:)`, sur un lecteur distinct
du clip mandarin : un clip ou une voix en cours n’est jamais arrêté, le son
s’y mélange. Sinon, sur iOS, la session passe en `.ambient` : le son se mêle
à la musique d’une autre app et respecte le mode silencieux. Rien n’est joué
pendant un enregistrement.

## Évaluation de prononciation

La vue accepte un `SpeechPronunciationService` séparé de `AudioService`. Son
protocole reçoit l’enregistrement temporaire, l’exercice et la transcription
locale de la même prise (nil sans dictée), puis renvoie un
`SpeechPronunciationResult`. Un rapport terminé fournit un verdict, un score
global et son détail ; les états `unconfigured`, `unavailable` et `failed` ne
contiennent aucun score de remplacement.

### Analyse hors ligne

La composition livrée (iOS et macOS) utilise
`OfflineSpeechPronunciationService` : gratuite, sans réseau, sans modèle
téléchargé. Le service lit l’enregistrement avec AVAudioFile, le convertit en
mémoire en 16 kHz mono (`SpeechAudioConverter.monoSamples16k`) et appelle
`PronunciationAnalyzer` (PolygoCore, Swift portable testé sous Linux). Rien ne
quitte l’appareil et aucun fichier supplémentaire n’est écrit.

1. **Tons attendus** (`MandarinToneTargets`) : les tons du `referencePinyin`,
   alignés sur les caractères, puis le sandhi de la parole : chaîne de 3e tons
   → 2e ton avant le dernier (les deux sont acceptés en tête d’une chaîne de
   trois), 不 devant un 4e ton → bú, 一 → yí devant un 4e ton et yì devant les
   autres (1er ton gardé après 第/十 et en fin de groupe). Un ton neutre n’est
   pas noté. La ponctuation coupe les chaînes.
2. **Hauteur** (`PitchTracker`) : YIN sur le signal ramené à 8 kHz, trame de
   10 ms, 60–500 Hz, voisement par apériodicité et niveau (35 dB sous la
   trame la plus forte), réparation des sauts d’octave, médiane glissante.
   Les hauteurs sont exprimées en demi-tons autour de la médiane du locuteur :
   une voix grave ou aiguë est traitée pareil.
3. **Syllabes** : les pauses et les creux d’intensité sont des frontières
   candidates ; une programmation dynamique en choisit autant qu’il y a de
   syllabes attendues en gardant des durées plausibles. Trop de frontières
   devinées, de longues pauses en trop ou trop peu de voix donnent « Résultat
   incertain », sans score.
4. **Ton entendu** : sur chaque syllabe (début et fin rognés), niveau,
   niveau par rapport aux voisines, pente, courbure, départ, arrivée et creux
   alimentent une régression logistique à quatre classes, entraînée sur les
   clips Kokoro et sur des contours de manuel (parole lente d’apprenant).
5. **Mots** : la transcription locale est comparée caractère par caractère
   (plus longue sous-suite commune, `TextNormalizer`, chiffres ramenés aux
   caractères) ; les caractères manquants et en trop sont listés.
6. **Verdict** : score = part des tons mesurés entendus comme attendu, moyennée
   avec le score des mots quand une transcription existe. Réussi si au moins la
   moitié des tons (`minimumToneScore` 0,5) et 75 % des caractères
   (`minimumWordScore`) sont justes ; sinon à corriger. Sans transcription, le
   score porte sur les tons seuls et la carte l’indique, avec le chemin pour
   activer la dictée en mandarin (iOS : Réglages › Général › Clavier ›
   Claviers › Chinois simplifié, puis Dictée ; macOS : Réglages Système ›
   Clavier › Dictée).

La carte de résultat affiche verdict et score sur 100, une pastille par
syllabe (ton attendu → entendu, vert ou orange), une petite courbe par
syllabe (forme attendue en pointillés, voix de l’apprenant en trait), les
corrections en français (« hǎo : attendu ton 3 (bas, descend-remonte),
entendu ton 2 (monte) ») et le contrôle des mots.

### Précision mesurée

Mesure sur les 1 388 clips Kokoro embarqués d’au moins deux syllabes
(12 186 syllabes à ton plein, clips décodés en 16 kHz mono). Précision par
ton en validation croisée (classifieur entraîné sur une moitié des clips,
mesuré sur l’autre, puis l’inverse) :

| Ton attendu | Ensemble | Voix féminine `zf_093` | Voix masculine `zm_011` |
|---|---|---|---|
| 1 | 66 % | 60 % | 76 % |
| 2 | 59 % | 51 % | 72 % |
| 3 | 48 % | 49 % | 47 % |
| 4 | 63 % | 58 % | 71 % |
| Total | 58,9 % | 54,5 % | 66,2 % |

Le modèle livré, entraîné sur tous les clips et exécuté en Swift (build
release, environ 260 fois plus vite que le temps réel sous Linux), obtient
59,1 % : l’écart avec la validation croisée est négligeable.

Ce chiffre borne l’analyseur *et* la voix de synthèse : le contrôle qualité
ci-dessus trouvait déjà que Kokoro ne réalise que 50 à 67 % des tons attendus.
Avec les frontières de syllabes prédites par Kokoro au lieu de la
segmentation acoustique (223 clips), la précision n’augmente pas (59 % contre
62 %) : la segmentation n’est pas le facteur limitant. Le sandhi calculé
concorde avec celui du frontal Kokoro sur 98,6 % des syllabes. Un bruit blanc
à 20 dB de rapport signal/bruit ne dégrade pas le résultat (400 clips). Au
niveau de la phrase, 76 % des clips obtiennent « réussi », 23 % « à
corriger », 1,4 % « incertain » ; des tons tirés au hasard ne réussissent que
dans 12 % des cas. Sur des contours synthétiques nets (tests unitaires, voix
à 110 et 220 Hz, bruit), les quatre tons sont reconnus.

### Limites

- Seuls les tons et les mots sont évalués : ni consonnes, ni voyelles, ni
  aspiration (b/p, z/zh…). Un ton juste sur une syllabe mal articulée passe.
- Environ quatre tons sur dix peuvent être mal reconnus sur une parole
  naturelle, surtout les 3e tons (souvent réalisés bas et courts) : le seuil
  est volontairement bas et le résultat reste indicatif. L’exercice oral reste
  `required: false` dans le contenu.
- Une syllabe isolée n’a pas de repère de niveau : le ton 1 et un 3e ton bas
  se distinguent mal.
- La comparaison des mots dépend de la dictée Apple : un homophone mal
  transcrit (他/她, 在/再) compte comme une erreur.

`FixedSpeechPronunciationService` et `UnconfiguredSpeechPronunciationService`
servent uniquement aux tests et aux prévisualisations.

La transcription seule, même identique à la phrase cible, ne constitue pas une
note. La vue ne crée une réponse évaluable qu’avec un rapport terminé qui
contient son score ; un rapport incertain laisse l’exercice sans note. Le
bouton « Continuer » enregistre alors un état `skipped`, qui ne compte pas
comme une réussite, et passe directement à l’exercice suivant. L’exercice oral
est optionnel : `skipped` est compté séparément dans le bilan
(`skippedCount`) et ne bloque ni la complétion fondée sur les exercices requis
ni le déblocage de la leçon suivante.

Des adaptateurs iFlytek ou SpeechSuper pourraient implémenter le même
protocole derrière un serveur proxy ; aucun n’est activé et les clés ne
doivent jamais être embarquées dans l’app.

## TTS Mandarin de repli et disponibilité hors ligne

Sans clip embarqué (voir plus haut), la lecture passe par AVSpeechSynthesizer et demande la
voix correspondant à localeIdentifier (par exemple zh-CN). La voix doit être
installée sur l’appareil ; si elle est absente, le service renvoie
AudioServiceError.voiceUnavailable et l’interface affiche une erreur
récupérable. La synthèse Apple ne requiert pas de serveur Polygo, mais les
voix, leur qualité et leur disponibilité hors ligne dépendent du système et des
paquets de voix installés par l’utilisateur.

La transcription Apple sert au contrôle des mots de l’analyse hors ligne ;
elle n’est jamais convertie en score de phonème ou de ton. Les variantes
`acceptedTranscripts` restent décodables pour les réponses historiques et une
transcription identique à l’une d’elles compte comme tous les mots justes.
Quand Speech n’est pas autorisé, quand le modèle local n’existe pas ou quand
aucune transcription n’est fournie, l’analyse note les tons seuls et
`SpeechPracticeView` explique comment activer la dictée en mandarin.

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
manquantes laissent l’exercice utilisable avec « Continuer » ; elles
ne fabriquent ni note de prononciation ni auto-évaluation positive.

## Validation Apple

Le conteneur Linux ne possède ni SDK Apple ni Xcode. Le [run Apple
34225700577](https://github.com/STOOOKEEE/Polygo/actions/runs/34225700577), sur le
commit historique `906135d`, a validé 47/47 tests portables, 2/2 tests UI
macOS et 7/7 tests UI iOS ; il couvre le chemin oral non configuré et le
passage sans évaluation, mais ne valide pas le bundle final de 94 leçons. Les
permissions, la disponibilité des voix,
l’interruption audio et le parcours enregistrement/réécoute/transcription avec
un fournisseur configuré restent à vérifier sur appareil. Les fixtures du
protocole vérifient déjà les états terminé, non configuré et sans résultat ; la
correction par fournisseur externe reste à brancher, sans score fabriqué.
