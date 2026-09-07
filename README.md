# Syllune

Syllune est l’application Polygo d’apprentissage du mandarin : des leçons
courtes, du pinyin et des tons, des caractères, de l’oral, de l’écriture, des
histoires et une révision locale. Le contenu et l’interface sont originaux.

Le dépôt cible iOS/iPadOS 17 et macOS 14. Le package Swift est portable ; les
cibles SwiftUI et les adaptateurs Apple se construisent sur macOS. Le statut
actuel est décrit dans [docs/QA_REPORT.md](docs/QA_REPORT.md) et
[docs/INTEGRATION_STATUS.md](docs/INTEGRATION_STATUS.md). Aucun build Apple
n’est considéré comme validé avant le passage de la CI.

## Démarrage local

Prérequis : Swift 5.9 ou plus récent, Xcode avec les SDK iOS 17 et macOS 14,
macOS pour les cibles Apple, et [XcodeGen](https://github.com/yonaskolb/XcodeGen).

Depuis la racine du dépôt :

```sh
swift test --parallel
command -v xcodegen >/dev/null 2>&1 || brew install xcodegen
xcodegen generate --spec project.yml
open Polygo.xcodeproj
```

Dans Xcode, exécuter `PolygoApp` sur un simulateur iOS 17 (le même target sert
iPhone et iPad) ou `PolygoMacApp` sur macOS 14. Pour une compilation sans
signature depuis le terminal :

```sh
xcodebuild -project Polygo.xcodeproj -scheme PolygoApp \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project Polygo.xcodeproj -scheme PolygoMacApp \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
```

`swift test --parallel` est le contrôle portable à lancer avant les builds
Apple. Le rapport QA confirme 34 tests XCTest réussis avec la toolchain Swift
Linux. Le fichier `Tests/PolygoAppUITests/PolygoAppUITests.swift` fournit un
smoke UI en français, mais il n’a pas encore été exécuté sur simulateur ; les
builds et tests Apple restent à suivre dans
[.github/workflows/apple.yml](.github/workflows/apple.yml).

## Ce qui est livré

La première tranche de contenu est la version `2026.09.0` :

- un cours et l’unité `unit-01` ;
- 3 leçons, 20 exercices, 3 histoires et 16 cartes de révision ;
- 16 entrées lexicales avec pinyin accentué, tons et formes simplifiée/traditionnelle ;
- 3 guides de tracé pour `你`, `我` et `国` sous `Content/assets/handwriting/` ;
- des textes et transcriptions hors ligne en français ; aucun audio de référence n’est embarqué.

Le pipeline de contenu part de
[`Content/manifest.json`](Content/manifest.json), charge le catalogue du cours,
puis les documents de leçon. Les blocs de lecture portent les trois histoires.
Le loader vérifie les versions, les identifiants, les références et les hashes
des assets.

## Organisation du code

| Chemin | Responsabilité |
| --- | --- |
| `Sources/PolygoCore` | modèles `Codable`, contenu, moteur d’exercices et progression |
| `Sources/PolygoSRS` | scheduler SM-2 et file de révision |
| `Sources/PolygoPersistence` | journal JSONL local, snapshot, outbox et sync abstraite |
| `Apple/Audio` | TTS, capture et transcription Apple |
| `Apple/Handwriting` | canevas, guides et validation géométrique locale |
| `App` | application SwiftUI, navigation, leçons, cartes, histoires et réglages |
| `Content` / `Design` | JSON pédagogique, assets de tracé et logos SVG |

Les contrats et décisions sont détaillés dans
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/UX.md](docs/UX.md),
[docs/PEDAGOGY.md](docs/PEDAGOGY.md),
[docs/CONTENT_SCHEMA.md](docs/CONTENT_SCHEMA.md),
[docs/AUDIO.md](docs/AUDIO.md), [docs/HANDWRITING.md](docs/HANDWRITING.md),
[docs/SRS.md](docs/SRS.md), [docs/SYNC.md](docs/SYNC.md) et
[docs/ACCESSIBILITY.md](docs/ACCESSIBILITY.md). Les sources de recherche et
les choix de produit sont dans [RESEARCH_NOTES.md](RESEARCH_NOTES.md) et
[DECISIONS.md](DECISIONS.md).

## Données locales et limites actuelles

La progression est locale et fonctionne sans compte ni réseau. Le journal et
le snapshot sont stockés dans le dossier `Application Support/Polygo`. Les
enregistrements vocaux sont temporaires et supprimés par défaut à la sortie de
l’exercice ; aucun audio n’est conservé par défaut.

La lecture orale utilise `AVSpeechSynthesizer` et nécessite une voix Mandarin
installée sur l’appareil. La transcription utilise `SFSpeechRecognizer` en
mode local lorsque le modèle et les permissions le permettent ; il n’y a pas de
repli réseau silencieux. Une confiance Speech reste une confiance de
transcription : elle ne fabrique ni score de phonème ni score de ton. Les
marqueurs de ton sont visuels et pédagogiques, sans faux signal audio.

Les guides de tracé disponibles couvrent actuellement trois caractères. La
synchronisation CloudKit privée est prévue mais inactive : l’application
affiche donc honnêtement « Sur cet appareil » et ne demande pas de compte
iCloud pour apprendre.

Pour les étapes de signature, d’archive, de distribution et la validation finale,
voir [docs/RELEASE.md](docs/RELEASE.md).
