# Syllune

Syllune est l’application Polygo d’apprentissage du mandarin : des leçons
courtes, du pinyin et des tons, des caractères, de l’oral, de l’écriture, des
histoires et une révision locale. Le contenu et l’interface sont originaux.

Le dépôt cible iOS/iPadOS 17 et macOS 14. Le package Swift est portable ; les
cibles SwiftUI et les adaptateurs Apple se construisent sur macOS. Le statut
actuel est décrit dans [docs/QA_REPORT.md](docs/QA_REPORT.md) et
[docs/INTEGRATION_STATUS.md](docs/INTEGRATION_STATUS.md). Le code validé est le
commit `c30d712` ; sa validation Apple est verte dans le [run
34207957185](https://github.com/STOOOKEEE/Polygo/actions/runs/34207957185). Ce
run valide les 43 tests du package, la génération XcodeGen, les métadonnées, les
builds iOS/macOS et les six méthodes UI (2 macOS et 4 iOS).

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
Apple. Le package courant contient 46 tests XCTest, dont 6 tests de contrat de
contenu ; les 46/46 tests portables passent avec les fixtures courantes. Le run
Apple indiqué plus haut valide le jalon précédent ainsi que ses builds,
métadonnées et six méthodes UI (2 macOS et 4 iOS). La cible UI
contient le smoke français, le parcours de reprise et le parcours de fin/revue.
Ces parcours couvrent notamment la reprise du brouillon et du feedback, le
dialogue avec réplique précédente interactive, l’état oral non évalué et son
passage sans note, les gestes du canevas, la persistance locale, le parcours et
les cartes.

## Ce qui est livré

La première tranche de contenu est la version `2026.09.0` :

- un cours et l’unité `unit-01` ;
- 4 leçons, 27 exercices, 4 histoires et 17 cartes de révision ;
- 17 entrées lexicales avec pinyin accentué, tons et formes simplifiée/traditionnelle ;
- 3 guides de tracé pour `你`, `我` et `国` sous `Content/assets/handwriting/` ;
- des textes et transcriptions hors ligne en français ; aucun audio de référence n’est embarqué ;
- une reprise locale des brouillons, du feedback et des réponses de dialogue ;
- un accueil avec reprise de leçon, parcours visible et accès aux flashcards.

### Accueil adaptatif Mac et iPhone

Le commit `c30d712` livre un accueil qui met la prochaine leçon en avant dans
un hero coloré avec progression et action principale. Sur Mac, deux colonnes
placent le hero à côté du parcours numéroté et des flashcards ; sur iPhone, ces
surfaces s’empilent. La barre latérale vise 240 points (plage 210–280), et le
choix explicite d’« Aujourd’hui » recrée la racine malgré un chargement tardif.
Une leçon ouverte depuis l’accueil conserve sa route, son brouillon et son
feedback au redémarrage.

Le [run Apple 34207957185](https://github.com/STOOOKEEE/Polygo/actions/runs/34207957185)
est vert : 43/43 tests package, 2 méthodes UI macOS et 4 méthodes UI iOS ont
réussi. Les captures natives validées sont disponibles ici :

- [Accueil macOS en mode sombre](docs/screenshots/home-macos-dark.png) — 1600 × 900, SHA-256 `b511d762e3a23fe4e50c47d4e89e3bc9df2c1300fa9bd38e194d38f4c0dc5ece` ;
- [Accueil iPhone en mode sombre](docs/screenshots/home-ios-dark.png) — 1206 × 2622, SHA-256 `aaeb9113f6fcf4f3205cfc658905faea3df94fae7e68325e8b6a61559e0ca597`.

Le workflow vérifie les `Info.plist` séparés pour iOS et macOS, la déclaration
de lancement iOS moderne plein écran (`UILaunchScreen`) et les familles iPhone et
iPad. Le canevas capture les gestes dans le défilement de la leçon grâce à une
surface tactile dédiée ; les lignes de leçon et les liens de vocabulaire ont une
zone de toucher sur toute leur largeur. Le dialogue propose une écoute complète
en mandarin, des mots chinois interactifs et une réponse écrite contrôlée à
partir de la réplique précédente.

Le pipeline de contenu part de
[`Content/manifest.json`](Content/manifest.json), charge le catalogue du cours,
puis les documents de leçon. Les blocs de lecture portent les quatre histoires.
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

La lecture orale extrait uniquement le mandarin et utilise `AVSpeechSynthesizer`;
elle nécessite une voix Mandarin installée sur l’appareil. Les labels et
instructions françaises ne sont jamais envoyés au TTS. Après un enregistrement,
`SpeechPracticeView` lance la transcription Apple et le protocole injecté
`SpeechPronunciationService` séparément. La confiance et le texte transcrit
restent descriptifs : une transcription seule ne produit aucune note de
prononciation ou de ton. Tant qu’aucun fournisseur et aucune clé ne sont
configurés, la composition utilise l’état `unconfigured` et propose « Passer
sans évaluer », enregistré comme `skipped` sans réussite. Un rapport fixture
terminé peut afficher le verdict, le score et les lignes par mot, son et ton ;
le rapport doit venir du fournisseur pour que l’exercice soit évalué.

Le protocole prévoit des adaptateurs iFlytek ou SpeechSuper derrière un serveur
proxy, mais aucun moteur externe n’est activé dans cette composition. Les clés
et secrets ne sont jamais embarqués dans l’app. Les fixtures du protocole
couvrent les états terminé, non configuré, indisponible et sans conclusion.
Les marqueurs de ton restent visuels et pédagogiques, sans faux signal audio.
L’interface orale compacte garde la cible, le modèle et le microphone
accessibles sur un écran iPhone standard ; la validation sur appareil avec un
fournisseur configuré reste à effectuer.

Les guides de tracé disponibles couvrent actuellement trois caractères. La
synchronisation CloudKit privée est prévue mais inactive : l’application
affiche donc honnêtement « Sur cet appareil » et ne demande pas de compte
iCloud pour apprendre. Les conflits CloudKit ne sont donc pas testés ; les
scénarios de fusion et de reprise couverts concernent le modèle local.

Les labels et groupes d’accessibilité sont présents. L’API
`.accessibilityLanguage`, incompatible avec les cibles actuelles, n’est pas
utilisée ; le réglage Sombre est exercé par le smoke, mais le rendu visuel,
la langue et la prononciation effectives de VoiceOver et les parcours de toucher
manuel restent à compléter par un audit sur iPhone, iPad et Mac.

Pour les étapes de signature, d’archive, de distribution et la validation finale,
voir [docs/RELEASE.md](docs/RELEASE.md).
