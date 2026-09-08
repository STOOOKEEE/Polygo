# Syllune

Syllune est l’application Polygo d’apprentissage du mandarin : des leçons
courtes, du pinyin et des tons, des caractères, de l’oral, de l’écriture, des
histoires et une révision locale. Le contenu et l’interface sont originaux.

Le dépôt cible iOS/iPadOS 17 et macOS 14. Le candidat de contenu est en
version `2026.10.0`. Le manifeste et le cours utilisent comme référence
principale HSK classique / legacy `HSK-legacy-2.0`, version normative `2.0`.
HSK 3.0 `2025-11` reste mentionné séparément comme référence de conception pour
une migration future ; il ne constitue pas l’alignement de ce programme.
L’état détaillé se trouve dans [docs/QA_REPORT.md](docs/QA_REPORT.md),
[docs/INTEGRATION_STATUS.md](docs/INTEGRATION_STATUS.md) et
[docs/RELEASE.md](docs/RELEASE.md).

## Démarrage local

Prérequis : Swift 5.9 ou plus récent, Xcode avec les SDK iOS 17 et macOS 14,
macOS pour les cibles Apple, et [XcodeGen](https://github.com/yonaskolb/XcodeGen).

Depuis la racine du dépôt :

```sh
swift test --parallel
xcodegen generate --spec project.yml
open Polygo.xcodeproj
```

Pour reconstruire le pack et le bundle de contenu :

```sh
python3 Tools/assemble_90_day_authoring.py
python3 Tools/content_tool.py generate --input Content/authoring/90-day-authoring.json --root Content
python3 Tools/content_tool.py lint --root Content
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

La suite portable actuelle compte **55 tests**, dont **12 contrats de contenu** ;
le dernier contrôle local est passé à **55/55**. Le [run Apple canonique
34261316153](https://github.com/STOOOKEEE/Polygo/actions/runs/34261316153) sur
`ac1daee` a validé le package à **55/55**, les **8 méthodes UI iOS (8/8)** et
les **5 méthodes UI macOS (5/5)**. Xcode et les SDK Apple ne sont pas présents
dans l’environnement Linux, donc les tests UI natifs doivent être exécutés sur
un runner Apple.

## Contenu livré

Le bundle contient 94 leçons dans 9 unités :

- 4 leçons d’introduction protégées (`lesson-01` à `lesson-04`) et 90 séances
  planifiées (`lesson-05` à `lesson-94`) ;
- 567 exercices au total : 27 dans l’introduction et 540 dans le programme de
  90 jours ;
- 94 histoires inline et 196 paragraphes de lecture ;
- 605 cartes et entrées lexicales distinctes, soit 600 lexèmes canoniques et
  5 mots supplémentaires de contexte, pour 911 associations leçon–carte ;
- 3 guides de tracé locaux pour `你`, `我` et `国` ; aucun audio de référence
  n’est embarqué.

Chaque séance du programme vise 15 minutes, réparties en 12 minutes de cours et
3 minutes de révision. Le plan couvre les 300 lexèmes de rang 1 à 300 au jour
30 (301 entrées canoniques livrées à ce point, dont un mot de rang supérieur
pour une scène naturelle), puis les 600 lexèmes au jour 90. Une couverture
éditoriale ne prouve ni acquisition ni réussite à un examen.

Les cartes des séances quotidiennes affichent le hanzi seul au recto ; le
pinyin et le sens français sont révélés au verso. Les choix des 270 exercices de
type choix sont tournés de manière déterministe pendant la génération selon le
jour et la position de l’exercice : les identifiants et les bonnes réponses ne
changent pas, mais la première option n’est pas toujours correcte.

Les quatre leçons d’introduction conservent exactement leur contenu apprenant,
leurs identifiants, leurs exercices, leurs cartes et leurs paires simplifié /
traditionnel. Leur seule mise à jour de payload est la version de contenu
`2026.10.0` nécessaire au bundle commun.

## Parcours et reprise

`TodayView` ouvre directement la séance courante via `CoursePlan.nextSession` et
l’action `home.primaryAction`. Le parcours natif préparé injecte les quatre
complétions d’introduction, ouvre `lesson-05`, reprend l’écoute après relance,
passe l’oral facultatif, termine la séance et vérifie que l’accueil affiche le
jour 2. Le parcours macOS exerce le même chemin. La reprise locale conserve le
brouillon, le feedback et les réponses de dialogue par identifiant stable.

La carte de révision accessible depuis Aujourd’hui est limitée à dix cartes au
maximum, selon le budget de la séance ; la route Cartes conserve la file due
complète. Le parcours macOS de session courte prépare 16 cartes dues, en évalue
exactement la tranche annoncée et conserve les cartes restantes pour
« Poursuivre ».

Les captures natives déjà archivées comprennent [le parcours macOS](docs/screenshots/roadmap-macos-dark.png),
[le dialogue macOS](docs/screenshots/dialogue-macos-dark.png), [l’écriture guidée iOS](docs/screenshots/handwriting-guided-ios.png)
et [la reprise iOS](docs/screenshots/handwriting-retry-ios.png). Le run Apple
canonique a produit [l’aperçu macOS de la séance quotidienne J1](docs/screenshots/daily-plan-day-one-macos.png),
ainsi que les captures macOS de la session courte ; les captures iOS de ce
parcours sont conservées dans le bundle xcresult du run.

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
[docs/ACCESSIBILITY.md](docs/ACCESSIBILITY.md).

## Données locales et limites actuelles

La progression est locale et fonctionne sans compte ni réseau. Le journal et
le snapshot sont stockés dans `Application Support/Polygo`. Les enregistrements
vocaux sont temporaires et supprimés par défaut à la sortie de l’exercice ;
aucun audio n’est conservé par défaut.

La lecture orale extrait uniquement le mandarin et utilise
`AVSpeechSynthesizer`. Tant qu’aucun fournisseur et aucune clé ne sont
configurés, la composition affiche l’état non configuré et propose « Passer
sans évaluer », enregistré comme `skipped` sans réussite. La transcription et sa
confiance restent descriptives : elles ne produisent aucune note de
prononciation ou de ton sans rapport fournisseur. Les guides d’écriture sont
validés localement. CloudKit est prévu mais inactif ; l’application affiche
honnêtement « Sur cet appareil ».

Les labels et groupes d’accessibilité sont présents. Le rendu visuel, VoiceOver,
Dynamic Type, les fenêtres étroites, le clavier macOS et Speech avec permission
accordée restent à auditer manuellement sur appareil.
