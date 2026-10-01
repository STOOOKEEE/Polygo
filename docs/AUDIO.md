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
la vitesse ou une phrase porteuse ; un mot court (你好, 妈妈, 学习, 电影, 水果…)
sort souvent avec des tons faux. Pour que tous les mots aient la même voix que
les phrases, un mot isolé est façonné : Kokoro le dit, puis WORLD (analyse et
resynthèse, via pyworld) remplace la hauteur de chaque syllabe par le contour
canonique de son ton, le timbre et les durées restant ceux de Kokoro.

- Échelle : niveaux de Chao 1 à 5 posés sur la tessiture de la voix, du 5e au
  95e centile de F0 de 60 répliques (`zf_093` 195–380 Hz, `zm_011` 87–159 Hz).
- Contours (en isolation) : ton 1 = 55 ; ton 2 = 3 → 5 avec un léger creux au
  départ ; ton 3 final = 2,5 → 1 → 4 (creux complet), non final = 2 → 1 (demi
  3e ton) ; ton 4 = 5 → 1 ; ton neutre bref et plat, placé selon le ton
  précédent. Les chaînes de 3e tons suivent le sandhi (你好 = 2-3), 不 et 一
  gardent leur ton écrit dans le pinyin.
- Le contour couvre la partie voisée et sonore de chaque syllabe ; les
  frontières viennent des durées de Kokoro, étirées sur la parole puis
  recalées sur le creux d’énergie le plus proche (consonne), et le contour est
  lissé sur 25 ms.
- Contrôle : chaque clip est décodé tel que l’app le joue, et sa hauteur est
  mesurée par un autre estimateur (DIO + StoneMask) que celui qui l’a façonné
  (Harvest). Ton 1 haut et plat, ton 2 qui monte d’au moins 0,7 niveau (~2 demi-
  tons), ton 3 qui descend sous le niveau 1,8 puis remonte ou reste bas, ton 4
  qui descend d’au moins 0,9 niveau. Si le clip façonné échoue, le clip brut de
  Kokoro est gardé s’il passe le même contrôle (报纸) ; sinon le mot garde la
  voix du système.

Mesures sur les 450 syllabes à ton plein des 332 clips de mots (niveaux de
Chao, 1 niveau ≈ 3 demi-tons) : ton 1 (104) moyenne 5,0, fin − début 0,0 ;
ton 2 (92) moyenne 3,6, +1,7 ; ton 3 (98) moyenne 1,9, creux 0,7 sous le plus
bas des bords puis +0,7 ; ton 4 (156) moyenne 3,2, −3,3. L’écoute humaine
n’a pas été faite dans cette passe.

### Couverture et voix

Un clip existe pour chaque texte en hanzi : répliques de dialogue et de
`dialogueOrder`, paragraphes de lecture, mots, exemples et cartes, invites
`listeningChoice`, `dictation`, `toneDiscrimination`, `conversationChoice` (et
ses réponses) et modèle `speaking`. Est un mot (clip façonné) : une entrée de
vocabulaire et ses cartes, une invite d’écoute, de dictée ou de ton sans
ponctuation de phrase, un modèle oral qui est un mot de la leçon, et tout texte
d’une syllabe. Voix : Mina et Lin → féminine, Tao et An → masculine ; mots,
lectures et invites d’écoute → féminine ; exemples de vocabulaire → masculine
(les deux voix dès la première leçon) ; réponse de conversation → l’autre voix
que la réplique ; modèle oral → voix du personnage qui dit la phrase dans le
dialogue, sinon féminine. Les noms écrits en latin sont dits 米娜 mǐ nà, 涛 tāo,
林 lín, 安 ān. Un clip est nommé par le SHA-256 de (moteur, voix, texte,
pinyin), plus la version du façonnage pour un mot : un texte identique dit par
la même voix n’a qu’un fichier.

Restent en voix système : les tuiles `wordOrder`, les paires `matching`, les
choix `choice`, et 14 mots dont le contrôle échoue (surtout une consonne sourde
suivie d’une voyelle brève) : 不客气, 什么, 一起, 出租车, 对不起, 机场, 时间,
火车站, 学校, 自行车, 西瓜, 踢足球, 鱼, 鸡蛋 (liste imprimée par le
générateur).

Les exercices du module 0 (leçons `pinyin-*`) dont l’invite ou le modèle oral
est une seule syllabe (妈/麻/马/骂, 爸, 七…, en `toneDiscrimination`,
`dictation`, `listeningChoice` ou `speaking`) n’ont pas de clip non plus et
passent par la voix système : à l’écoute sur iPhone, le Kokoro façonné y
sonnait moins bien que la voix système. Cela touche 75 invites. Dans l’app,
une invite d’écoute, de dictée ou de ton réduite à une syllabe sans clip est
lue par le même appel que la réponse touchée (texte mandarin extrait, voix
zh-CN, vitesse normale) et n’a pas de bouton « Lent » : la voix système
ralentie déformait la syllabe isolée. Le vocabulaire de ces leçons (canonique
d’une leçon à l’autre), leurs mots de plusieurs syllabes et tous les mots d’une
syllabe des autres leçons (早…) gardent Kokoro.

Bilan de la génération : 1 583 clips (944 en voix féminine, 639 en voix
masculine), dont 308 mots (163 d’une syllabe), 70 minutes, 23,2 Mo, contre
1 404 clips et 22,4 Mo quand les mots d’une syllabe et 28 mots de deux
syllabes gardaient la voix du système. Une régénération des mêmes clips donne
des fichiers identiques octet pour octet (vérifié sur 40 mots).

### Format

AAC-LC mono 24 kHz à 40 kb/s dans un conteneur M4A, silences de tête et de
queue coupés (50 ms / 100 ms gardés), niveau ramené à -16 dBFS RMS sur les
trames voisées avec crête ≤ -1 dBFS, fondus de 5 ms. Le dossier `Content` est
copié tel quel dans l’app iOS et macOS (`project.yml`), donc les clips sont
hors ligne.

### Mode lent

Le bouton « Lent » (tortue, `SlowAudioToggle`, mémorisé dans
`@AppStorage("audio.slowMode")`) est présent dans les dialogues, les lectures,
les écoutes, dictées, exercices de ton (sauf sur une syllabe isolée sans clip)
et conversations ; la fiche mot et le texte chinois ont un bouton
« Lentement ». Le modèle oral garde son sélecteur Normale / Lente.

### Régénérer

`python3 Tools/content_tool.py generate` rattache les clips existants et ne
demande aucun moteur. Pour créer les clips manquants (Python 3.12, ffmpeg) :

```sh
uv venv --python 3.12 ~/.cache/polygo-tts-venv
VIRTUAL_ENV=~/.cache/polygo-tts-venv uv pip install \
  --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple \
  --index-strategy unsafe-best-match torch "kokoro==0.9.4" "misaki[zh]==0.9.4" soundfile \
  "pyworld==0.3.5" "setuptools<81"
cd Tools && ~/.cache/polygo-tts-venv/bin/python build_audio.py --root ../Content
```

pyworld (licence MIT) enveloppe le vocodeur WORLD de Masanori Morise (licence
BSD modifiée) ; il sert seulement à la génération et n’est jamais embarqué.
Il importe encore `pkg_resources`, d’où `setuptools<81`.

Le script télécharge le modèle à la révision figée, vérifie son SHA-256,
synthétise uniquement les clips absents (graine fixe par phrase), façonne et
contrôle les mots, supprime les clips inutilisés, rattache et lance le lint. Le
lint refuse une référence périmée ou manquante et un clip qu’aucune leçon
n’utilise. Un mot refusé n’a pas de fichier : il est réessayé (et de nouveau
refusé) à chaque passe.

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

Le conteneur Linux ne possède ni SDK Apple ni Xcode : l’analyseur y est testé
en Swift portable (`PronunciationAnalyzerTests`), le service et la carte de
résultat sont compilés par la CI Apple. Le [run
36706007488](https://github.com/STOOOKEEE/Polygo/actions/runs/36706007488)
(commit `5b0fae7`) a compilé iOS et macOS, passé les tests UI macOS, le
parcours oral enregistrement → analyse → « Continuer » sur iPhone
(`LessonReviewJourneyTests`) et sur iPad (`ZZLessonRegressionJourneyTests`).
Ces tests UI acceptent « Résultat incertain » ou « Analyse impossible » et
vérifient qu’aucun faux « Correct » n’apparaît. La précision sur une vraie voix
d’apprenant, les permissions, la dictée en mandarin et l’interruption audio
restent à vérifier sur appareil.
