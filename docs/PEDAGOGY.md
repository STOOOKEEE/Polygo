# Pédagogie et progression Polygo
Contrat éditorial V1, 7 septembre 2026. Ce document complète `docs/ARCHITECTURE.md`, `docs/UX.md`, `docs/CONTENT_SCHEMA.md` et `docs/SRS.md`.
Il décrit la cible pédagogique du MVP et indique séparément ce que le pack JSON livre déjà. Il ne modifie aucun contenu ni contrat Swift.
Les états ont un sens précis : **disponible** signifie présent et chargeable dans le pack ; **critère éditorial** signifie règle à vérifier sur les données
et les parcours ; **extension architecture** signifie clé ou comportement facultatif, dont la présence ne prouve pas l’usage par l’UI ; **futur** signifie
prévu mais non déverrouillable. Aucun état ne vaut promesse d’examen.

## Principes et cycle
Une unité répond à une tâche quotidienne observable. Une leçon dure quatre à
sept minutes, s’interrompt après chaque exercice et reprend au prochain item dû.
Le cycle Polygo est toujours :

1. **Observer** : entendre et lire un exemple, avec contrôles séparés pour caractères, pinyin, traduction et audio quand un audio existe.
2. **Récupérer** : rappeler avant d’afficher la réponse.
3. **Produire** : remettre en ordre, écrire ou dire une réponse courte.
4. **Transférer** : réutiliser la fonction dans une situation légèrement nouvelle.
Une aide reste une condition de tentative et ne retire pas de crédit. Les réponses ouvertes déclarent les variantes éditorialement acceptées. La confiance
d’une transcription Speech ne devient jamais seule un score de prononciation.

## Hiérarchie et contrats
Les IDs sont opaques, non vides, stables et indépendants de l’ordre des tableaux.
Le contrat minimal relie le catalogue au document de leçon :

| Élément | Exemple local | Contrat attendu |
| --- | --- | --- |
| Cours | `mandarin-starter` | langues, catalogue et références versionnées |
| Niveau / section | `level-01` / `section-01` | compétences et prérequis |
| Unité | `unit-01` | tâche, durée, leçons et sortie |
| Leçon | `lesson-01` | intention, nouveautés (≤6), grammaire, blocs, cartes |
| Objectif | `l1-greet-understand` | verbe observable, preuve et seuil éditorial |
| Vocabulaire | `vocab-ni-hao` | scripts, pinyin, tons, sens FR, nature, exemple |
| Grammaire | `grammar-vocab-jiao` | fonction, patron, contraintes, exemples, erreurs |
| Exercice | `ex-l1-meaning` | mode, stimulus, réponse, feedback, aide et tags |
| Carte | `card-vocab-ni-hao` | direction, dimension, source et état SRS |
Chaque document conserve `schemaVersion: 1` et `contentVersion: "2026.09.0"`.
`LessonDocument` reste le type Swift de référence : objectifs, vocabulaire, blocs et cartes. Les modes éditoriaux peuvent être `listenChoose`, `toneChoose`,
`meaningChoose`, `sentenceOrder`, `fillBlank`, `speakPrompt`, `writeCharacter`
ou `reviewRecall`; `toneChoose` et `meaningChoose` sont sérialisés comme choix
spécialisés quand le schéma l’exige.
Chaque entrée lexicale porte `hanzi` (simplifié), `traditionalHanzi`, pinyin
accentué, un numéro par syllabe (`1` à `4`, `0` neutre), sens français,
`partOfSpeech`, exemple original et `audio`. Les deux scripts restent associés
au même ID ; le choix d’affichage ne change ni le sens ni la carte.
`standardID`, `standardVersion`, `levelID`, `sectionID`, `unitID`, `stage`, `skill`, `errorTags`, `feedback`, `acceptedVariants`, `reviewDimensions`,
`reviewDirections` et `adaptation` sont des extensions JSON facultatives. Le loader V1 peut les ignorer : elles expriment une intention éditoriale et ne
prouvent donc ni adaptation active, ni score Speech, ni seuil déjà implémenté.
Elles ne remplacent jamais les champs normatifs (`acceptedAnswers`,
`acceptedTranscripts`, formes, tons et traductions).

## Référentiels versionnés
Le catalogue conserve des repères distincts, sans fusionner leurs listes :

| Référence | Affichage autorisé |
| --- | --- |
| `HSK-3.0` / `2025-11` | « Aligné HSK 3.0 niveau N » après contrôle item par item |
| `HSK-legacy-2.0` / `2.0` | « Repère HSK 2.0 niveau N (legacy) » |
| `CEFR` / `2020` | descripteur complémentaire, sans conversion HSK–CECR |
| `Polygo` / `2026.09` | progression et décisions propres au produit |
Une référence non vérifiée reste « repère » ou « à vérifier ». Toute interface montre l’ID et la version ; un niveau, un compteur ou une unité terminée ne
garantit ni couverture d’une liste CTI, ni score, ni réussite à un examen.

## Cible MVP : `unit-01` en trois leçons
La cible de ce document est une unité courte `mandarin-starter / level-01 / section-01 / unit-01`, en trois leçons concrètes. Chaque leçon réutilise les
mots antérieurs, introduit au plus six entrées et fait passer par les quatre étapes du cycle. Les trois leçons et leur plafond lexical sont :

| Leçon cible | Fonction | Nouveautés |
| --- | --- | ---: |
| L1 — Saluer | saluer, remercier, prendre congé | 5 |
| L2 — Nom | demander et donner son nom | 5 |
| L3 — Origine | demander et dire un pays | 6 |
Le mot « cible » est important : ces trois leçons définissent le périmètre éditorial MVP, elles ne déclarent pas que chaque critère est déjà mesuré par
l’application. L’unité vise une courte interaction après L3 ; les preuves de
reconnaissance et de production restent distinctes.

### Lexique, scripts, tons et exemples
Dans les lignes suivantes, la forme est `simplifié / traditionnel — pinyin accentué [tons] — sens FR`. Les phrases sont originales et affichent toujours
les caractères, la lecture accentuée, les numéros et la traduction.

| Leçon | Entrées nouvelles |
| --- | --- |
| L1 (5) | `你好 / 你好 — nǐ hǎo [3,3] — salut`; `早 / 早 — zǎo [3] — bonjour (matin)`; `再见 / 再見 — zàijiàn [4,4] — au revoir`; `谢谢 / 謝謝 — xièxie [4,0] — merci`; `不客气 / 不客氣 — bú kèqi [2,4,0] — de rien` |
| L2 (5) | `你 / 你 — nǐ [3] — tu/vous`; `我 / 我 — wǒ [3] — je`; `叫 / 叫 — jiào [4] — s’appeler`; `什么 / 什麼 — shénme [2,0] — quoi/quel`; `名字 / 名字 — míngzi [2,0] — nom` |
| L3 (6) | `是 / 是 — shì [4] — être`; `哪 / 哪 — nǎ [3] — quel`; `国 / 國 — guó [2] — pays`; `法国 / 法國 — Fǎguó [3,2] — France`; `中国 / 中國 — Zhōngguó [1,2] — Chine`; `人 / 人 — rén [2] — personne` |
Exemples de référence :

| Fonction | Simplifié | Traditionnel | Pinyin [tons] | Français |
| --- | --- | --- | --- | --- |
| L1 | 你好！ | 你好！ | nǐ hǎo! [3,3] | Bonjour ! |
| L2 | 你叫什么名字？ | 你叫什麼名字？ | nǐ jiào shénme míngzi? [3,4,2,0,2,0] | Comment t’appelles-tu ? |
| L3 | 你是哪国人？ | 你是哪國人？ | nǐ shì nǎ guó rén? [3,4,3,2,2] | De quel pays es-tu ? |
| L3 réponse | 我是法国人。 | 我是法國人。 | wǒ shì Fǎguó rén. [3,4,3,2,2] | Je suis français(e). |
La couverture attendue est : ton 1 dans `中`; ton 2 dans `国`, `人`, `什`; ton 3 dans `你`, `好`, `早`, `我`, `哪`; ton 4 dans `再`, `见`, `谢`,
`叫`, `是`; ton neutre dans la seconde syllabe de `谢谢`, `什么`, `名字`,
et dans `呢`. On écrit `nǐ hǎo` [3,3] (`ni3 hao3`), même si le premier ton 3 est souvent réalisé comme 2 en parole continue ; `bú kèqi` [2,4,0] note les réalisations
éditoriales de `不` et de la dernière syllabe légère.
L1 travaille `你好！谢谢。再见！`; L2 `你叫什么？/ 我叫安。`; L3 `你是哪国人？/ 我是中国人。`. Chaque entrée doit garder une nature
grammaticale, une phrase, les deux graphies, le français et son repère
versionné. Dans le pack actuel, les champs audio sont `null` : aucun audio
enregistré n’est déclaré ; le TTS n’est qu’un repli de l’adaptateur. Les guides
locaux livrés sont `guide-hanzi-ni`, `guide-hanzi-wo` et `guide-hanzi-guo`.

### Objectifs et critères observables
Les objectifs MVP suivent les familles d’IDs `l1-greet-*`, `l2-name-*` et `l3-country-*`. Un critère éditorial exige une preuve attachée à un exercice ;
une sélection correcte ne valide jamais une compétence productive.

| Leçon | Reconnaissance | Production / transfert |
| --- | --- | --- |
| L1 | identifier salutation, sens et ton ; cible 4 réussites sur 5 | dire bonjour et prendre congé, puis adapter au matin |
| L2 | reconnaître question, nom et ordre des mots | produire `我叫 + nom`, puis demander le nom après une salutation |
| L3 | reconnaître `哪国` et le patron `是…人` | dire une origine dans un contexte nouveau et relancer l’échange |
Pour toute leçon, le seuil de 80 % et la présence d’une preuve par objectif sont des critères éditoriaux à contrôler ; ce document ne prétend pas qu’ils
sont tous implémentés dans les écrans ou les données actuelles. Une réponse
ouverte utilise une canonique et ses `acceptedVariants`, avec feedback court et
lié à une erreur (`tone`, `meaning`, `script`, `word-order`, `grammar`,
`listening`, `speaking`, `writing` ou `transfer`).

## Adaptation et SRS
L’adaptation éditoriale prévoit H0 sans aide ; H1 réécoute, débit 0,75×, boucle et numéro de ton ; H2 pinyin, traduction ou segmentation ; H3 modèle, premier
token ou trace fantôme ; H4 guidage puis rappel reprogrammé. Un échec donne un
feedback immédiat, une nouvelle tentative après un à trois items, puis une
carte. Deux réussites indépendantes peuvent diminuer l’aide d’un niveau ;
l’apprenant peut toujours la choisir. Sans micro ou sans fournisseur de
prononciation, la transcription reste descriptive et l’exercice oral peut être
`skipped` sans note ni réussite. Dans les quatre leçons livrées, cet exercice
est facultatif (`required: false`) : le bilan l’expose via `skippedCount`, tandis
que les exercices requis validés suffisent à enregistrer la complétion de la
leçon et à déverrouiller la suivante. Le récapitulatif peut donc afficher
« Leçon enregistrée » et `5 / 6 exercices réussis` avec un oral `skipped` ; ce
saut reste exclu des réussites et du score. Un résultat `selfReported` reste
réservé aux cartes et au chemin
d’écriture qui l’autorise ; jamais un score de prononciation ne doit être
fabriqué.
Le protocole `SpeechPronunciationService`, l’UI et les fixtures sont prêts pour
un fournisseur externe, mais aucun provider, compte, credential ou proxy n’est
activé dans la composition actuelle.
Le scheduler `PolygoSRS.SM2Scheduler` applique le SM-2 déterministe. Pour une
qualité `q`, `EF' = EF + (0.1 - (5-q) × (0.08 + (5-q) × 0.02))`, avec EF initial
2,5 et plancher 1,3. L’interface expose `again` (q=0), `hard` (q=3), `good`
(q=4) et `easy` (q=5) ; q<3 remet la répétition à zéro, incrémente le lapse et
programme J+1. Une première réussite programme J+1, la deuxième J+6, puis
`round(intervalle × EF)` avec au moins un jour ; un jour vaut 86 400 secondes.
Chaque transition conserve carte, date, qualité, intervalle, EF et lapse dans
l’historique, et l’événement est idempotent. `dueCards` trie par échéance puis
ID ; la suspension conserve les statistiques et utilise `Date.distantFuture`.
`CoreReviewPlanner` et `PolygoSRS` doivent garder ces constantes alignées.
Cette règle SRS est disponible ; l’adaptation détaillée ci-dessus reste une
spécification éditoriale tant que les métadonnées et l’UI ne la démontrent pas.

## Disponible, extensions et futur
Le document vise trois leçons, mais le pack `Content` actuellement livré en
`2026.09.0` compte quatre leçons dans `unit-01` : `lesson-01` à `lesson-04`.
Il contient 27 exercices (6/7/7/7), 17 cartes sans doublon et quatre histoires.
`lesson-04` est une extension déjà présente : mini-échange avec `呢`, une
nouvelle entrée, `story-mini-exchange` et sept exercices. Elle reste livrée et
n’est pas supprimée par ce document ; l’écart cible/pack est intentionnel.
Le niveau `level-01` et les trois premières leçons sont le périmètre éditorial
MVP. L’onboarding `level-00` est spécifié avec les tons 1–4 et neutre, mais ses
assets sont futurs. `level-02` et les niveaux avancés, leurs leçons, histoires
et volumes lexicaux sont futurs ; aucun compteur ou calendrier n’est promis.

## Contrôle avant publication
Vérifier dans `Content/manifest.json`, `Content/courses/mandarin-starter.json`
et les leçons que les IDs se résolvent, que les nouveautés restent ≤6, que les
cartes ne doublonnent pas, et que les exercices portent leurs objectifs et
preuves. Vérifier aussi scripts simplifié/traditionnel, pinyin accentué et
numérique, tons 0–4, français, variantes, audio réellement présent ou `null`,
guides et contenu original.
Recontrôler les repères `HSK-3.0/2025-11`, `HSK-legacy-2.0/2.0`, `CEFR/2020`,
les critères reconnaissance/production, l’adaptation et la transition SM-2 à
chaque publication. Les références locales de ce contrat sont
`ARCHITECTURE.md`, `CONTENT_SCHEMA.md`, `UX.md`, `SRS.md` et `RESEARCH_NOTES.md`.
