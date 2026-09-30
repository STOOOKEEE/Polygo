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

La suite portable compte **72 tests XCTest** (72/72 dans le journal du [run
36339541346](https://github.com/STOOOKEEE/Polygo/actions/runs/36339541346)).
La CI Apple compile les deux applications, exerce les parcours natifs sur Mac
(9/9) et iPhone (11/11) et vérifie la reprise du vrai `AppModel` après des
erreurs de persistance ; l’iPad est hors périmètre de validation. Les commits
testés, résultats, captures et limites figurent dans le [rapport QA](docs/QA_REPORT.md).
Xcode et les SDK Apple ne sont pas présents dans l’environnement Linux :
les validations natives sont exécutées sur les runners Apple, pas simulées ici.

## Contenu livré

Le bundle contient 94 leçons dans 10 unités :

- le module 0, « Pinyin et tons » (`unit-00`, `pinyin-01` à `pinyin-08`) : huit
  leçons d’écoute (tons, consonnes, finales, enchaînements, orthographe, bilan)
  bâties sur des paires minimales, sans dialogue ni mot nouveau ;
- 4 leçons d’introduction protégées (`lesson-01` à `lesson-04`) et 90 séances
  planifiées : les 8 leçons du module 0 (jours 1 à 8), 66 leçons du jour
  (`lesson-05` à `lesson-70`), 8 révisions (`review-01` à `review-08`, une après
  la cinquième leçon de chaque unité) et 8 défis de fin d’unité (`boss-unit-02` à
  `boss-unit-09`) ;
- 1 663 exercices au total : 27 dans l’introduction, 144 dans le module 0
  (18 par leçon), 1 188 dans les 66 leçons du jour (18 par séance) et 304 dans
  les révisions (18) et les défis (20) ;
- 70 histoires inline et 147 paragraphes de lecture ; chacune des 66 leçons du jour a un
  dialogue de 8 à 12 répliques et une lecture de 4 à 6 phrases écrits à la main
  (`Content/authoring/situations/`) ;
- 30 notes de grammaire (`Content/authoring/grammar-syllabus.json`), une toutes les
  deux ou trois leçons de `lesson-05` à `lesson-68`, chacune avec trois ou quatre
  exemples, la faute fréquente d’un francophone et deux exercices de manipulation
  (assemblage puis choix du mot) en début de phase guidée ;
- 313 cartes et entrées lexicales distinctes, soit 300 lexèmes canoniques (les
  rangs 1 à 300 du référentiel HSK classique 1–2), 2 mots d’écoute du module 0
  de rang supérieur (`绿`, `蓝`) et 11 mots supplémentaires hors catalogue, pour
  1 038 associations leçon–carte (le module 0 présente à l’avance 55 mots que
  les leçons du jour enseignent) ;
- 3 guides de tracé locaux pour `你`, `我` et `国` ;
- des clips mandarins embarqués en deux voix (féminine pour Mina et Lin,
  masculine pour Tao et An), synthétisés par Kokoro-82M v1.1-zh (Apache 2.0),
  avec un mode « Lent » ; voir [docs/AUDIO.md](docs/AUDIO.md).

Chaque séance du programme vise 15 minutes, réparties en 12 minutes de cours et
3 minutes de révision (13 + 2 pour un défi d’unité). Chaque leçon du jour introduit
trois à cinq mots nouveaux (jamais plus de huit) ; les révisions, les défis et
le module 0 n’en introduisent aucun. Le module 0 est le premier pas recommandé,
pas une porte : `lesson-01` s’ouvre sans lui, et un apprenant qui déclare
connaître le pinyin (ou qui termine une leçon au-delà) n’y est plus ramené.
Le plan couvre les 150 lexèmes de rang 1 à 150 (HSK classique 1) au jour 58, le
défi de l’unité 6, puis les 300 lexèmes de rang 1 à 300 (HSK classique 1–2) au
jour 90, le défi de l’unité 9, qui clôt le parcours. Les rangs 301 à 600 du
catalogue restent un référentiel : certains textes des leçons du jour en
emploient des mots, sans que le parcours les enseigne ni les compte. Une
couverture éditoriale ne prouve ni acquisition ni réussite à un examen.

Les cartes des séances quotidiennes affichent le hanzi seul au recto ; le
pinyin et le sens français sont révélés au verso. Les choix des 198 exercices de
type choix sont tournés de manière déterministe pendant la génération selon le
jour et la position de l’exercice : les identifiants et les bonnes réponses ne
changent pas, mais la première option n’est pas toujours correcte.

Tout le pinyin affiché dans les leçons s’écrit mot par mot selon GB/T 16159
(`Huǒchēzhàn zài xuéxiào pángbiān.`), avec la ponctuation ASCII, une majuscule
en tête de phrase et aux noms propres (`Běijīng`, `Hànyǔ`) et l’apostrophe de
`Xī'ān` ; `content_tool.py generate` l’écrit et `lint` le vérifie (voir
« Pinyin, tons et graphies » dans `docs/CONTENT_SCHEMA.md`).

Les quatre leçons d’introduction conservent leur contenu apprenant, leurs
identifiants, leurs exercices, leurs cartes et leurs paires simplifié /
traditionnel. Leur payload ne change que par la version de contenu `2026.10.0`
nécessaire au bundle commun et par leur pinyin, écrit mot par mot comme partout.

## Interface et pièces

Tavi, le panda roux original, accompagne l’accueil, les encouragements et les
célébrations. Tous les onglets partagent une même charte (fond crème ou indigo,
cartes douces, jade pour l’action principale, or pour les récompenses). Le
parcours reste une carte de jeu : bannières d’unité colorées, piste sinueuse,
nœuds en relief et bulle « Commencer / Continuer » sur l’étape actuelle. Chaque
leçon a une icône adaptée : les révisions portent des flèches circulaires, les
défis de fin d’unité une couronne et les leçons du module 0 une onde sonore.
Les apparences Système, Clair et Sombre restent disponibles,
ainsi que Réduire les animations.

La même barre basse dessert **Aujourd’hui, Parcours, Explorer, Cartes et Profil**
sur iPhone, iPad et Mac ; les Réglages se trouvent sous Profil. Chaque onglet
conserve sa pile pendant la session, et un second appui sur l’onglet actif
revient à sa racine. La barre et le badge global de pièces sont masqués dans
les leçons et les pratiques autonomes Oral/Écriture.

Une première complétion historique de leçon rapporte **10 pièces**, y compris
pour les événements déjà enregistrés avant cette interface. Recommencer une
leçon ne retire ni ne réattribue ce gain. Le solde se reconstruit depuis le
journal local de progression : aucune boutique, aucun paiement et aucun
portefeuille séparé ne sont ajoutés.

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

Les captures natives (provenance détaillée dans `docs/RELEASE.md`) :
[accueil iPhone](docs/screenshots/home-ios.png),
[parcours iPhone sombre](docs/screenshots/roadmap-ios-dark.png),
[parcours iPhone clair](docs/screenshots/roadmap-ios-light.png),
[dialogue iPhone](docs/screenshots/dialogue-ios.png),
[pièces après complétion](docs/screenshots/coins-roadmap-ios.png),
[écriture guidée iPhone](docs/screenshots/handwriting-guided-ios.png),
[accueil Mac](docs/screenshots/home-macos-dark.png),
[parcours Mac](docs/screenshots/roadmap-macos-dark.png),
[dialogue Mac](docs/screenshots/dialogue-macos-dark.png) et la séance
quotidienne Mac ([J1](docs/screenshots/daily-plan-day-one-macos.png),
[lecture](docs/screenshots/daily-plan-reading-macos.png),
[J2](docs/screenshots/daily-plan-day-two-macos.png)).

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

La lecture orale joue le clip embarqué du texte et, à défaut (texte d’une
syllabe), extrait le mandarin pour `AVSpeechSynthesizer`. Tant qu’aucun fournisseur et aucune clé ne sont
configurés, la composition affiche une note d’auto-écoute et propose
« Continuer », enregistré comme `skipped` sans réussite. La transcription et sa
confiance restent descriptives : elles ne produisent aucune note de
prononciation ou de ton sans rapport fournisseur. Les guides d’écriture sont
validés localement. CloudKit est prévu mais inactif ; l’application affiche
honnêtement « Sur cet appareil ».

Les labels et groupes d’accessibilité sont présents. Le rendu visuel, VoiceOver,
Dynamic Type, les fenêtres étroites, le clavier macOS et Speech avec permission
accordée restent à auditer manuellement sur appareil.
