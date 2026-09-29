# Authoring du parcours quotidien

Le contenu linguistique est écrit dans un pack d'authoring puis transformé en
JSON embarqué par `Tools/content_tool.py`. Le générateur ne produit aucun
hanzi, pinyin, exemple ou scénario : chaque entrée doit venir du pack fourni
par l'équipe contenu, et le dialogue, la lecture et les exercices de clôture des
66 séances du jour viennent des scènes écrites à la main (voir « Situations écrites
à la main »). Il ne remplace pas non plus la validation linguistique.
Les exercices supplémentaires d'une séance (voir « Budget d'exercices ») sont
seulement recombinés à partir de ce matériel.

Le pack contient quatre clés racines, plus un lexique partagé :

```json
{
  "schemaVersion": 1,
  "contentVersion": "2026.10.0",
  "course": { "id": "mandarin-starter", "slug": "mandarin-starter", "title": {"fr": "..."}, "description": {"fr": "..."}, "alignment": [], "plan": {} },
  "catalog": "authoring/hsk-legacy-600.json",
  "modules": [],
  "lessons": []
}
```

`course.plan` est optionnel pour garder les anciens cours valides. Quand il est
présent, `targetMinutes` vaut 15, chaque entrée de `sessions` associe un jour à
une leçon existante et `courseMinutes + reviewMinutes == targetMinutes`. Les
jours commencent à 1 et sont contigus ; pour ce programme, les deux budgets
doivent être strictement positifs. Les révisions sont une tâche SRS réellement
due ; la durée est un budget éditorial, pas une mesure de temps passé.

Les jalons portent la référence et la couverture annoncées. `vocabularyTarget`
compte uniquement les lexèmes canoniques réellement couverts dans le catalogue
référencé ; un mot hors catalogue ne compte pas. `claims` reste
descriptif : aucun claim ne doit déduire l'acquisition d'un niveau du seul jour
du calendrier. Pour le programme actuel, la référence demandée est
`HSK-legacy-2.0`/`2.0` (libellé utilisateur : HSK classique), avec 150 lexèmes canoniques (rangs 1 à 150, HSK
classique 1) à la fin de l'unité 6 puis 300 (rangs 1 à 300, HSK classique 1–2) à la
fin de l'unité 9 ; cela reste distinct des repères HSK 3.0 (500/1000). Le
catalogue garde ses 600 entrées comme référentiel, mais le parcours ne s'engage
que sur les rangs 1 à 300.

Chaque objet de `lessons` contient `id`, `moduleID`, `order`, `title`,
`summary`, `estimatedMinutes`, `objectives`, `vocabularyIDs`, `extraVocabulary`, `grammar`, un
`dialogue` facultatif, un `reading` facultatif, `exercises` et un `recap`.
Le champ `level` facultatif d'une leçon ou d'un module est un libellé de
curriculum destiné à l'index des histoires (par exemple `HSK classique 2` ou
`CECR A1`). Il reste attaché à cette leçon ou ce module et ne reprend pas tout
l'alignement du cours.
Les quatre leçons existantes (`lesson-01` à `lesson-04`) ne doivent pas être
recopiées dans le pack généré : le générateur les conserve et ajoute les
sessions suivantes.

Les champs linguistiques sont les suivants :

* `catalog` pointe vers le fichier versionné fourni par release
  (`authoring/hsk-legacy-600.json`). L'identité du fichier est son `id` et son
  `contentVersion` (utilisés par `course.plan.catalogID/catalogVersion`) ; la
  référence normative reste séparée dans `standard.id/version`. Ses entrées sont identifiées par `id`,
  `rank`, `level`, `lexemeKey`, `sourceForm`, `hanzi`, `aliases`, `pinyin`,
  `toneNumbers` et `meaningFr`; le couple racine `standard.id`/
  `standard.version` prouve le référentiel et `lexemeKey` sert de
  `canonicalID`. Un booléen `canonical: true` isolé ne suffit pas.
* `vocabularyIDs` référence les entrées du catalogue partagé (par `id` ou
  `lexemeKey`) ou un
  `vocabularyID` déjà livré. Le générateur résout chaque référence dans
  l'objet local de la leçon. Si un identifiant existant est réutilisé, son objet
  est recopié exactement, y compris son verso de carte.
* `extraVocabulary` contient les mots hors catalogue, au même format lexical
  mais sans `canonicalID`; ils peuvent être affichés et utilisés dans les
  phrases, mais ne comptent jamais dans `vocabularyTarget`.
* `grammar` est une liste de notes `{pattern, explanation, examples}`, avec en
  option `id`, `formula` et `mistake`. `examples` contient au moins un exemple
  `{hanzi, pinyin, translation}` avec sa traduction `fr`. Le générateur abaisse
  chaque note en `IntroductionBlock` autonome (`block-<lesson>-grammar-01`,
  etc.) : le titre reprend le pattern et le corps affiche l'explication
  française, la formule (`Formule : …`), chaque exemple sur trois lignes (hanzi,
  pinyin, français) puis la faute fréquente (`Attention : …`) ; avec un `id`, le
  bloc porte `metadata.grammarPointID`. Une note de grammaire est donc propre à
  la séance et ne modifie jamais le `VocabularyEntry` réutilisé. Pour les 66
  séances du jour, l'assembleur retire les `grammar` des fragments : la
  grammaire y vient du syllabus (voir « Syllabus de grammaire »).
* `dialogue` contient `{id, lines, participation?}`. Une ligne contient
  `{speaker, hanzi, pinyin, translation, audio?}`.
* `reading` contient `{id, storyID, level?, title, paragraphs, comprehensionExerciseIDs?}`.
* Chaque exercice contient `id`, `kind`, `prompt`, `instruction?`,
  `objectiveIDs?`, `required?`, puis les champs propres à sa famille :
  `choices/correctChoiceID`, `tokens/correctOrder`, `sentence/acceptedAnswers`,
  `promptAudio?` ou `promptText?`/`choices/correctChoiceID`,
  `referenceText/referencePinyin/acceptedTranscripts`, ou `cardID`.
  `promptText` permet l'écoute Mandarin TTS quand aucun asset réel n'est livré.
  Un exercice oral reste facultatif (`required: false`) tant qu'aucun service
  de prononciation n'est configuré.

## Budget d'exercices d'une séance quotidienne

Chaque leçon `lesson-05` à `lesson-70` livre entre 15 et 20 exercices (18 dans le
contenu actuel) répartis en trois phases
ordonnées. La phase est portée par le `metadata.stage` de chaque bloc
`exercise` ; les blocs d'introduction, vocabulaire, dialogue, lecture et bilan
gardent leur étape éditoriale.

| Phase (`stage`) | Exercices | Contenu |
| --- | --- | --- |
| `discover` | 5 à 7 | association mot/sens ou mot/pinyin (`matching`), dictée (`dictation`), discrimination des tons (`toneDiscrimination`), reconnaissance du sens et écoute de mots |
| `guided` | 6 à 7, plus les 2 exercices de la note de grammaire | les deux exercices de la note s'il y en a une, puis traduction par tuiles (`translation`), mini-conversation (`conversationChoice`), remise en ordre, phrase à trous, écoute de répliques |
| `reuse` | 5 à 6 | remise en ordre du dialogue (`dialogueOrder`), phrases du texte ou du dialogue (trou, sens), oral, puis l'écoute, l'oral et la lecture écrits dans le pack |

Une leçon dotée d'une note de grammaire reçoit en plus ses deux exercices
(`ex-l<N>-gram-1` et `-2`), placés en tête de la phase `guided` : ils comptent dans le total de 15 à 20
mais pas dans la part de la phase, et laissent moins de place aux exercices dérivés
(le total reste de 18) sans changer la garantie d'exposition des mots nouveaux.
Les six exercices du pack (`meaning`, `order`, `fill`, `listen`, `speak`,
`reading`) gardent leurs IDs ; `listen`, `speak` et `reading` ferment toujours la
séance, et leur texte est celui de la scène écrite à la main (`meaning`, `order` et `fill`
restent ceux du pack). Les autres sont choisis par
`Tools/exercise_expansion.py` lors de `content_tool.py generate`, à partir des
seules données de la leçon : sens et exemples du vocabulaire, répliques du
dialogue et phrases du texte. Le générateur n'écrit donc aucun hanzi, pinyin ou
traduction. Il produit d'abord tous les exercices possibles (`choice`,
`listeningChoice`, `wordOrder`, `fillBlank`, `speaking`, `matching`, `dictation`,
`toneDiscrimination`, `translation`, `conversationChoice`, `dialogueOrder`), puis en retient assez
pour couvrir les mots nouveaux (voir ci-dessous) et compléter chaque phase. Il
applique ces règles :

* les distracteurs de sens viennent du vocabulaire de la leçon puis des deux
  leçons précédentes, sans recouvrement de sens avec la bonne réponse ; les
  mots nouveaux passent en premier comme mauvaises réponses écrites, car chaque
  choix les représente ; les distracteurs de phrase viennent des phrases de la
  leçon ;
* les tuiles d'un `wordOrder` segmentent la phrase par plus long mot connu du
  catalogue et du vocabulaire ; le pinyin de chaque tuile est repris du pinyin
  de la phrase (une syllabe par hanzi, sinon la phrase est écartée) ;
* un `fillBlank` masque un mot de la leçon de un ou deux caractères, car la UI
  propose cinq choix tirés d'une banque de mots de même longueur ; la
  traduction française est rappelée dans l'énoncé pour lever l'ambiguïté ;
* la bonne réponse d'un choix suit une marche déterministe dans l'ordre final
  de la séance (numéro de leçon et rang), donc sa position varie sans hasard
  non reproductible ;
* `speaking` reste facultatif et ne dépasse pas trois exercices par séance ;
  les écoutes et lectures de phrase demandent au moins quatre hanzi ;
* chaque séance reçoit d'abord un exemplaire de chaque famille récente que sa
  matière permet (`matching`, `dictation`, `toneDiscrimination`, `translation`,
  `conversationChoice`, `dialogueOrder`), puis le reste est choisi comme
  ci-dessus ; chaque famille récente apparaît deux fois au plus, le
  `dialogueOrder` une fois, et les deux `matching` (sens, pinyin) comme les deux
  `dictation` (pinyin, hanzi) diffèrent par ce qu'ils demandent ;
* `matching` groupe quatre ou cinq mots aux sens (ou pinyin) distincts, mots
  nouveaux d'abord ; les mots dont le hanzi apparaît deux fois dans la leçon
  (还 hái / huán) sont écartés de `matching`, `dictation` et
  `toneDiscrimination` ;
* `dictation` demande le pinyin (mot ou phrase du dialogue ou d'un exemple) ou
  les hanzi d'un mot ; les mauvaises réponses ont la même longueur que le mot ;
* `toneDiscrimination` lit `toneNumbers` après l'avoir confronté aux diacritiques
  du pinyin ; un mot dont le ton peut varier à l'oral (3-3, 不, 一, polyphones)
  n'est jamais posé ;
* `translation` réutilise la segmentation de `wordOrder` (3 à 6 tuiles) et
  ajoute une ou deux tuiles en trop prises au vocabulaire, dont le sens n'est
  pas dans la phrase française ;
* `dialogueOrder` prend trois ou quatre répliques consécutives et distinctes du
  dialogue ; `conversationChoice` ne part que d'une question du dialogue, dont
  la bonne réponse est la réplique suivante et les mauvaises d'autres répliques.

## Mots nouveaux par séance

Une séance présente au plus huit mots nouveaux, extras hors catalogue compris.
L'allocation en vise trois à cinq (quatre ou cinq dans le contenu actuel). Un mot est nouveau dans la première
leçon, par ordre, dont le vocabulaire le liste ; les mots repris d'une leçon
précédente sont réutilisés et ne comptent pas.

L'allocation (`Tools/build_90_day_authoring.py`) est la seule source du
vocabulaire canonique de chaque séance. Elle lit les textes écrits des
fragments (dialogue, lecture, exemples de grammaire, exercices), jamais leurs
listes de vocabulaire, puis :

* répartit les 287 lexèmes de rang 1 à 300 hors leçons de départ entre les 66
  séances du jour (`DAYS`), à raison de 3 à 5 par séance (`MIN_NEW_PER_LESSON`,
  `MAX_NEW_PER_LESSON`) ; les rangs 1 à 150 sont tous introduits au plus tard à
  la dernière leçon de l'unité 6 (`HSK1_LAST_DAY`, jour 40). Aucun mot de rang
  supérieur à 300 n'est planifié ;
* impose qu'un mot soit introduit au plus tard dans la séance dont il est
  l'ancre de grammaire ou la question de sens ; un tel mot déjà vu reste dans la
  séance comme mot réutilisé ;
* échange ensuite des mots entre séances d'une même phase tant que cela réduit
  le nombre de couples (mot, séance) où un texte emploie un mot avant son
  introduction, en préférant introduire un mot dans une séance dont le texte
  l'emploie. Les textes écrits ne sont pas modifiés : une séance peut donc encore
  contenir un mot enseigné plus tard ou hors du parcours (rang supérieur à 300) ;
* désigne l'ancre de grammaire de chaque séance (`grammarTarget`) : l'ancre écrite
  si elle est enseignée, sinon un mot de la séance qu'emploient les exemples de la
  note. Les notes `grammar` des fragments ne servent qu'à cette allocation :
  l'assembleur les retire du pack, et `generate` pose à leur place celles du
  syllabus de grammaire.

Ordre d'exécution : `build_90_day_authoring.py`, puis
`build_authoring_days_06_45.py`, `build_authoring_days_46_66.py` et
`build_preview_authoring.py`, puis `assemble_90_day_authoring.py`, puis
`content_tool.py generate`. Le fragment des jours 1 à 5 n'a pas de liste de
vocabulaire ; l'assembleur la remplit depuis l'allocation et refuse un
fragment des jours 6 à 66 dont le vocabulaire diffère de l'allocation.
`content_tool.py generate` pose ensuite les scènes de `Content/authoring/situations/`
sur les leçons du pack (voir « Situations écrites à la main »).

Le dialogue, la lecture et les exercices `listen`, `speak` et `reading` des
fragments ne sont donc plus ce que voit l'apprenant : la scène les remplace à
`generate`. Ils restent pourtant l'entrée de l'allocation, qui y lit quels mots
chaque séance emploie pour décider où les introduire ; les supprimer déplacerait
des mots d'une séance à l'autre et ferait échouer les scènes déjà écrites, puisque
leur vocabulaire autorisé suit cette allocation. Changer l'allocation, c'est donc
récrire les scènes concernées.

Chaque mot nouveau est présenté par au moins trois exercices de la séance, d'au
moins trois familles différentes (`choice`, `listeningChoice`, `wordOrder`,
`fillBlank`, `speaking`, `matching`, `dictation`, `toneDiscrimination`,
`translation`, `conversationChoice`, `dialogueOrder`). Un exercice présente un mot quand son hanzi figure
dans l'énoncé, dans une phrase (le trou rempli par la réponse), dans les
tuiles, dans les répliques ou les paires, dans une phrase à écouter ou à dire, ou dans un choix. Un exercice de
phrase compte pour chaque mot nouveau qu'il contient, et un choix de mots écrits
compte pour chacun de ses libellés.

`content_tool.py` refuse la génération, et `lint` refuse le bundle, si une
leçon quotidienne sort du budget de 15 à 20 exercices, si un exercice n'a pas de
phase, si les phases ne se suivent pas dans l'ordre, si deux exercices posent la
même question, si un choix a deux libellés identiques, si elle présente plus de
huit mots nouveaux, si `metadata.newVocabularyIDs` diffère des mots qu'aucune
leçon précédente ne liste, ou si un mot nouveau n'a pas ses trois exercices de
trois familles. `lint` vérifie aussi chaque exercice récent contre sa leçon :
paires de `matching` prises au vocabulaire de la leçon (sens ou pinyin exact),
correcte réponse de `dictation` égale au texte lu ou à son pinyin attesté, choix
de `toneDiscrimination` dont l'ID suit les `toneNumbers` du mot, tuiles de
`translation` uniques avec une tuile en trop et une phrase que la leçon montre (les
autres ordres acceptés réarrangent les mêmes tuiles),
`dialogueOrder` qui suit le dialogue sans le modifier, `conversationChoice` à
trois réponses dont la bonne suit la réplique lue. Une séance doit utiliser au
moins quatre de ces six familles. Les quatre leçons protégées gardent leurs six exercices
d'origine.

## Situations écrites à la main

Le dialogue, la lecture et les trois exercices de clôture (`listen`, `speak`,
`reading`) d'une séance quotidienne s'écrivent à la main, une scène concrète par
leçon, dans `Content/authoring/situations/unit-NN.json` ; `Tools/situations.py` les
lit, les contrôle et les pose sur la leçon à `content_tool.py generate`, à la place du
texte assemblé. Les 66 séances du jour (`lesson-05` à `lesson-70`) ont
toutes leur scène : `generate` refuse un pack qui liste une séance du jour sans scène, et `lint`
refuse un bundle où l'une manque.

`NN` est le rang de l'unité parmi les huit unités quotidiennes (l'unité `unit-02` du
parcours s'écrit dans `unit-01.json`) : `unit-01` leçons 5–12, `unit-02` 13–20,
`unit-03` 21–28, `unit-04` 29–36, `unit-05` 37–44, `unit-06` 45–52, `unit-07` 53–61,
`unit-08` 62–70. Une leçon écrite dans un autre fichier est refusée.

### Format

Le fichier associe un ID de leçon à sa scène. Tous les textes visibles sont des objets
`{"fr": "…"}` ; le pinyin s'écrit une syllabe par hanzi (`mǐ fàn`) ou mot par mot (`mǐfàn`,
`nǚ'ér`) : seules les syllabes comptent, `generate` l'écrit ensuite par mots avec les majuscules
et la ponctuation du bundle (voir « Pinyin, tons et graphies » dans `CONTENT_SCHEMA.md`).

```json
{
  "lesson-05": {
    "situation": {"fr": "Mina reçoit Tao à déjeuner : …"},
    "title": {"fr": "Un déjeuner chez Mina"},
    "dialogue": [
      {"speaker": "Mina", "hanzi": "你好！你饿吗？", "pinyin": "nǐ hǎo! nǐ è ma?", "translation": {"fr": "Salut ! Tu as faim ?"}}
    ],
    "reading": {
      "title": {"fr": "Un mot pour le professeur"},
      "paragraphs": [
        {"hanzi": "我有茶和水。你喝茶吗？", "pinyin": "wǒ yǒu chá hé shuǐ. nǐ hē chá ma?", "translation": {"fr": "J’ai du thé et de l’eau. Vous buvez du thé ?"}}
      ]
    },
    "readingQuestion": {
      "prompt": {"fr": "Que demande la personne au professeur ?"},
      "choices": [{"id": "a", "label": {"fr": "…"}}, {"id": "b", "label": {"fr": "…"}}, {"id": "c", "label": {"fr": "…"}}],
      "correctChoiceID": "a"
    },
    "listenSentence": {"hanzi": "我不吃鱼，我吃菜和米饭。", "pinyin": "wǒ bù chī yú, wǒ chī cài hé mǐ fàn.", "translation": {"fr": "…"}},
    "speakSentence": {"hanzi": "你有水吗？", "pinyin": "nǐ yǒu shuǐ ma?", "translation": {"fr": "Tu as de l’eau ?"}},
    "extraVocabulary": [
      {"hanzi": "饿", "traditionalHanzi": "餓", "pinyin": "è", "meaning": {"fr": "avoir faim"}, "partOfSpeech": "adjective"}
    ]
  }
}
```

`situation` (une phrase) devient le `summary` de la leçon, `title` son titre (40 signes
au plus). `dialogue` compte 8 à 12 répliques (`speaker` : `Mina`, `Tao`, `An` ou `Lin`,
au moins deux et trois au plus par dialogue). `reading` compte 1 à 3 paragraphes et 4 à 6 phrases
en tout ; chaque paragraphe finit par `。`, `！` ou `？` et donne autant de phrases en
hanzi, en pinyin et en français (une phrase française finit par `.`, `?` ou `!` ; pas
d'autre point suivi d'une espace). `readingQuestion` propose trois choix `a`, `b`, `c`,
dont l'un est juste et que le texte permet de départager. `listenSentence` et
`speakSentence` reprennent mot pour mot une réplique du dialogue ou une de ses phrases
(hanzi et pinyin), sans nom latin, de quatre hanzi au moins, et diffèrent l'une de l'autre.
`extraVocabulary` (facultatif) glose les mots hors du vocabulaire enseigné :
`{hanzi, traditionalHanzi, pinyin, meaning: {fr}, partOfSpeech}`.

### Ce que la pose modifie

La pose remplace le titre, le résumé, les répliques du dialogue, le titre et les paragraphes
de la lecture (identifiants `p1`, `p2`…, `audio: null` ; comme pour tout texte, la
`segmentation` est écrite à la génération, voir CONTENT_SCHEMA.md, « Segmentation des
textes », et une segmentation écrite dans un pack est remplacée), l'`extraVocabulary`
de la leçon, et les exercices `ex-lNN-listen`, `ex-lNN-speak` et celui que la lecture
référence : les IDs des blocs, de l'histoire, de l'exercice et
`comprehensionExerciseIDs` restent ceux du pack, et `metadata.situationAuthored` vaut
`true`. Les distracteurs de l'écoute sont les traductions d'autres répliques (les plus
proches en longueur) : deux répliques ne se traduisent donc pas par la même phrase. La bonne
réponse de l'écoute et celle de la question de lecture passent en tête (les IDs `a`, `b`, `c` restent
ceux de la scène), puis la rotation déterministe des exercices de choix fait varier leur position. Un mot
glosé prend l'ID `vocab-x-<code hexadécimal du hanzi>` (`vocab-x-997f` pour 饿) ; un
même mot glosé dans deux leçons doit l'être de la même façon. Les exercices `meaning`,
`order` et `fill` du pack et les révisions dérivées ne changent pas de source (les
révisions et défis reprennent les nouvelles répliques et les notes de grammaire à la
génération) ; la grammaire vient du syllabus.

### Règles de vocabulaire

`lint` (et `generate`, avant d'écrire quoi que ce soit) refuse une scène si :

* un mot n'est ni enseigné jusqu'à cette leçon incluse (leçons de départ, aperçu du module 0
  et séances du jour, d'après le bundle généré), ni un prénom (`Mina`, `Tao`, `An`, `Lin`), ni
  un extra glosé. Les mots sont trouvés par découpage en plus court chemin de mots
  enseignés ; le contrôle voit les hanzi, pas le sens. Le message nomme chaque mot refusé
  et la leçon qui l'enseigne ;
* un mot nouveau de la leçon (`metadata.newVocabularyIDs` hors extras) manque au dialogue
  et à la lecture, ou la lecture en contient moins de deux ;
* les mots nouveaux, extras nouveaux compris, dépassent cinq (le contrat Swift veut trois à
  cinq mots nouveaux par leçon) : avec quatre mots du plan, un extra au plus ; avec cinq,
  aucun. Un extra n'est jamais un mot du plan (rangs 1 à 300, enseigné plus tard) ni un mot
  déjà enseigné ; un extra doit servir, et pèse au plus 8 % des mots d'un texte (un au minimum) ;
* le dialogue ou la lecture sort de sa longueur, une réplique dépasse 22 hanzi, deux répliques
  consécutives sont identiques (sauf une salutation), plus de deux répliques portent un nom latin
  (une ligne à nom latin n'alimente pas les exercices générés) ;
* le hanzi contient autre chose que des hanzi, `，。！？、；：` et des prénoms ; le pinyin autre
  chose que des syllabes bien écrites (marque de ton bien placée), seules ou jointes en mots
  (apostrophe seulement devant une syllabe qui commence par a, o ou e), et `, . ? ! ; :` ;
  le pinyin ne suit pas le hanzi (une syllabe par hanzi une fois les mots coupés, la même
  ponctuation au même endroit ; 儿 s'écrit `r` collé à la syllabe précédente, `nǎr`).

### Commandes

```sh
python3 Tools/content_tool.py situation-brief --lesson lesson-NN   # tout ce qu'il faut pour écrire une leçon
python3 Tools/content_tool.py situations-lint --file Content/authoring/situations/unit-NN.json
python3 Tools/content_tool.py situations-lint --file … --pinyin-check   # facultatif : pypinyin
python3 Tools/content_tool.py generate --input Content/authoring/90-day-authoring.json --root Content
python3 Tools/content_tool.py lint --root Content   # exige les 66 scènes
```

`situation-brief` affiche l'unité et le fichier, le thème et le résumé actuels, les mots
nouveaux et repris, la note de grammaire, les personnages et les scènes déjà écrites, les
règles, le vocabulaire autorisé (hanzi, pinyin, sens, par leçon) et un squelette JSON.
`situations-lint` ne régénère rien et signale tous les défauts d'un fichier. Avec
`--pinyin-check`, chaque syllabe est comparée aux lectures de `pypinyin` s'il est installé
(sinon une note l'indique) ; les formes neutres et les variantes de 不 et 一 passent. Ce contrôle
est pour les rédacteurs et la relecture : `lint` n'en dépend pas. Le bundle
régénéré est aussi comparé aux fichiers de scènes : modifier une scène sans régénérer fait échouer
`lint`. Le générateur copie le bundle dans un dossier temporaire (`TMPDIR`) : le libérer s'il est plein.

### Guide du rédacteur

* Une leçon, une situation concrète et située (un repas, un achat, une rencontre) que Mina et Tao
  vivent ; le lecteur doit pouvoir la résumer en une phrase, celle de `situation`.
* Registre : le chinois parlé de tous les jours, des répliques courtes qu'on dirait vraiment ;
  jamais de phrase de manuel (« Je suis un étudiant. Tu es un étudiant. ») ni de liste de mots
  déguisée en dialogue. Une question appelle sa réponse dans la réplique suivante.
* Mina et Tao mènent le dialogue et s'alternent (le premier locuteur est à gauche dans l'application) ;
  `An` et `Lin` peuvent apparaître, à trois voix au plus. Le lecteur a déjà rencontré Mina et Tao :
  reprenez leurs goûts et leurs habitudes (voir « Personnages » du brief) sans les contredire.
* Les prénoms s'écrivent en lettres latines, à l'identique dans le hanzi et dans le pinyin
  (`你好，Tao！` / `nǐ hǎo, Tao!`, `Tao的生日` / `Tao de shēngrì`), au plus deux répliques par
  dialogue ; jamais dans `listenSentence` ni `speakSentence`, lus à voix haute en mandarin.
* Continuité : la famille de Tao compte une grande sœur (médecin), un grand frère (en France),
  une petite sœur et un petit frère ; Mina a un grand frère (en Chine) et une grande sœur, ses
  parents et le chat Baibai (白白) sont en France ; An est un ami et Lin une amie de Tao. Les autres rôles
  (vendeur, médecin, serveur, chauffeur) prennent le nom de `An` ou de `Lin` sans reprendre leur histoire.
* Employez tous les mots nouveaux, et réemployez des mots vus plus tôt : c'est ce qui les fait vivre.
  Les mots enseignés plus tard, même très courants (好, 很, 的), sont interdits : contournez-les.
* La lecture n'est pas le dialogue récrit : un petit texte à part (un message, une note, un récit
  de deux ou trois phrases) qui reprend le lexique de la leçon. La question de lecture porte sur le
  sens du texte, avec deux mauvaises réponses plausibles.
* Traductions françaises naturelles (pas de mot à mot), avec les apostrophes typographiques `’` et
  les espaces avant `? ! :` ; une note culturelle brève peut trouver place dans `situation`.
* Vérifiez chaque ligne avec un dictionnaire ou un locuteur : l'outil ne juge ni le naturel du
  chinois, ni l'exactitude du pinyin, ni celle du français.

## Révisions et défis d'unité

Les révisions et les défis ne s'écrivent pas : `Tools/review_lessons.py` les
dérive des leçons qu'ils reprennent, dans le même esprit que l'expansion des
exercices (aucun hanzi, pinyin ni traduction nouveau).

* **Placement** (`derive_layout`, appelé par `assemble_90_day_authoring.py`) :
  dans chaque unité planifiée, `review-NN` suit chaque série de cinq leçons du
  jour, sauf quand la série termine l'unité ; `boss-<unité>` clôt l'unité. Les
  huit unités de huit ou neuf leçons (`UNITS`) donnent 8 révisions et 8 défis :
  avec les 66 leçons et les 8 leçons du module 0, le plan compte 90 séances. Le
  plan gagne ces séances (12 + 3 minutes pour une révision, 13 + 2 pour un
  défi), les jours et les `order` des leçons sont renumérotés dans l'ordre du
  parcours (les IDs des leçons du jour ne changent pas), les jalons suivent
  leur leçon, ou le défi de son unité quand elle la termine, et la description du
  cours reprend les totaux. Pour changer le rythme, modifier `REVIEW_EVERY`.
* **Contenu** (`build_derived_lessons`, appelé par `generate`) : le vocabulaire est
  celui que les leçons couvertes ont introduit (toutes les entrées d'une
  révision, cinq par leçon pour un défi) ; le bloc `dialogue` reprend un extrait
  de trois répliques consécutives par leçon (un défi prend six leçons réparties
  sur l'unité, plus celles qui n'enseignent aucun mot) ; le bloc `introduction`
  cite les structures de grammaire couvertes avec l'exemple de chaque note. Les
  exercices sont construits par le `SessionBuilder` de `exercise_expansion.py`
  sur ce matériel : chaque leçon couverte est interrogée, chaque type récent
  est utilisé, un défi consacre sa dernière phase à un dialogue à mener.
* **Ordre** : sans historique d'apprenant à la génération, « les items les plus
  faibles d'abord » se lit comme « les plus anciens d'abord » : chaque phase
  commence par les leçons les plus anciennes (`metadata.sourceLessonID`). Les
  rappels SRS de la séance traitent la faiblesse propre à chaque apprenant.
* **Contrôles** : `lint` refuse une série de plus de cinq leçons sans révision,
  une unité sans défi final, un mot nouveau dans une révision ou un défi, un
  budget hors de 15–20 exercices (18–20 pour un défi), une révision sans les six
  types récents, un défi sans son dialogue final, ou un ordre qui ne commence pas
  par les leçons les plus anciennes.

Le générateur supprime les révisions que le pack ne liste plus. Il ne supprime
pas une leçon du jour retirée du pack : supprimer son fichier avant de
régénérer, faute de quoi le contrôle du bundle la retrouve dans son ancienne unité.

## Syllabus de grammaire

La grammaire des 66 séances du jour s'écrit à la main dans un seul fichier,
`Content/authoring/grammar-syllabus.json` : 30 notes, une toutes les deux ou trois
leçons (`lesson-05`, 07, 09, 11, 13, 15, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40,
43, 45, 47, 49, 51, 54, 57, 59, 62, 64, 66, 68), du plus simple au plus composé : la question en `吗`,
`在` + lieu, `想`/`会`, `也`/`都`, `要`, `的`, `不`/`没`, `了`, l'heure en `点`, `有`, `能`/`可以`, les
classificateurs, les mots de lieu, `很`, `比`, `过`, la date, l'âge, `几`/`多少`, `就`, `但是`,
`因为…所以…`, `最`, `得`, `吧`, `还`/`再`, `着`, `离`, `别`, `给`/`让`. Chaque structure est illustrée de
préférence par le dialogue ou la lecture de sa leçon ; les exemples écrits pour l'occasion
n'emploient que des mots déjà enseignés. Une leçon sans note n'a aucun bloc de grammaire.

```json
{
  "schemaVersion": 1,
  "notes": [
    {
      "id": "gram-ma-question",
      "lessonID": "lesson-05",
      "title": "吗 : poser une question oui/non",
      "formula": "Phrase affirmative + 吗 ?",
      "markers": ["吗"],
      "explanation": {"fr": "2 à 6 phrases, 600 caractères au plus, sur une ligne."},
      "examples": [{"hanzi": "你饿吗？", "pinyin": "nǐ è ma?", "translation": {"fr": "Tu as faim ?"}}],
      "mistake": {"fr": "La faute fréquente d'un francophone et la forme correcte (260 caractères au plus)."},
      "exercises": [
        {"kind": "wordOrder", "answer": {"hanzi": "你是中国人吗？", "pinyin": "nǐ shì zhōng guó rén ma?", "translation": {"fr": "Es-tu chinois ?"}}, "tiles": ["你", "是", "中国", "人", "吗"]},
        {"kind": "choice", "answer": {"hanzi": "你渴吗？", "pinyin": "nǐ kě ma?", "translation": {"fr": "Tu as soif ?"}}, "blank": "吗", "wrong": ["和", "是"]}
      ]
    }
  ]
}
```

* `markers` : les mots enseignés qui portent la structure. Chaque exemple et chaque réponse
  d'exercice en contient un au moins, chaque marqueur figure dans un exemple, et le mot
  masqué d'un exercice de trou ou de choix est un marqueur qui n'apparaît qu'une fois dans la
  phrase.
* `examples` : trois ou quatre phrases simples (sans ponctuation intérieure, 22 hanzi au plus, sans
  prénom), aux mots enseignés jusqu'à la leçon (les extras glosés des leçons jusqu'à celle-ci
  comptent), en pinyin écrit comme dans les scènes. `title`, `formula`,
  `explanation` et `mistake` ne citent, eux aussi, que des mots enseignés.
* `exercises` : exactement deux. Le premier assemble la structure (`wordOrder`, un seul ordre
  possible, ou `translation`, dont la réponse est l'un des exemples, avec une ou deux tuiles en
  trop `extraTiles` et, au besoin, les autres phrases correctes `alternatives` faites des mêmes
  tuiles) ; le second choisit le bon mot (`fillBlank`, dont `alternatives` liste les mots
  équivalents, ou `choice`, dont `wrong` donne deux ou trois mots faux, jamais valides dans la
  phrase). Le générateur écrit les énoncés (`Construis « … ».`, `Traduis en chinois : « … »`,
  `Complète : … (« … »)`, `Quel mot complète la phrase : …`), mélange les tuiles de façon
  reproductible et donne aux exercices les identifiants `ex-l<N>-gram-1` et `-2`.

`generate` refuse un syllabus qui manque à ces règles ou dont une leçon n'est pas au
programme ; `lint` le contrôle aussi, avec le bundle généré. Il refuse :

* moins de 25 ou plus de 30 notes, une première note après `lesson-07`, une dernière avant `lesson-68`,
  ou deux notes séparées de moins de deux ou de plus de trois leçons (au plus deux leçons de suite
  sans note) ;
* une explication de moins de deux ou de plus de six phrases, ou de plus de 600 caractères ;
* moins de trois exemples ; un mot non enseigné jusqu'à la leçon, dans un exemple, un exercice, la
  formule, le titre, l'explication ou la faute fréquente ; un pinyin qui ne suit pas le hanzi ;
* des exercices qui ne sont pas deux (assemblage puis choix du mot), dont la réponse n'emploie pas un
  marqueur, ou dont les tuiles ne composent pas la réponse ;
* dans le bundle : un bloc de grammaire ailleurs qu'à une leçon désignée, un bloc ou un exercice
  qui diffère de sa note (`metadata.grammarPointID`, phase `guided`, réponse et marqueur
  recalculés depuis la spécification générée), une leçon désignée sans `grammarPoints`.

Le bloc généré est l'`IntroductionBlock` `block-lesson-NN-grammar-01`, dont le titre est
`Grammaire — <title>` et dont le corps suit l'ordre : explication, `Formule : …`, `Exemple N : …`
(hanzi, pinyin, français) puis `Attention : …` ; la leçon porte aussi
`grammarPoints: [{id, pattern, function, markers, errors}]`. Les révisions et défis reprennent, pour
chaque note des leçons couvertes, son titre et son premier exemple.

```sh
python3 Tools/content_tool.py grammar-brief --lesson lesson-NN   # phrases de la leçon employables, vocabulaire enseigné
python3 Tools/content_tool.py grammar-lint --file notes.json --pinyin-check   # des notes seules, avec pypinyin s'il est installé
python3 Tools/content_tool.py grammar-lint   # tout le syllabus
```

## Module 0 : pinyin et tons

Les huit leçons `pinyin-01` à `pinyin-08` s'écrivent à la main dans
`Content/authoring/pinyin-module.json` ; `Tools/pinyin_module.py` les expand et
les contrôle, et `content_tool.py generate` les ajoute au cours, sans passer par
le pack des leçons du jour (l'assembleur reste inchangé). Le fichier contient :

* `module` : `unit-00`, `order` 0 ; `course` : titre et description du cours, avec
  les totaux `{total}`, `{pinyin}`, `{daily}`, `{reviews}`, `{bosses}`, `{words}` calculés
  à la génération ;
* `carriers` : la table `hanzi → pinyin` des textes que les exercices font
  entendre. Un porteur est un caractère ou un mot réel et courant, à la lecture
  non ambiguë (les caractères à lectures multiples de `POLYPHONES` sont refusés
  comme texte lu) ; vérifier chaque entrée avec un dictionnaire avant de l'ajouter.
  `不` et `一` s'y notent avec leur ton réel dans le mot (`bú shì`, `yì qǐ`) ; les
  mots du vocabulaire d'une leçon doivent y porter le même pinyin que leur
  entrée.
  Le générateur écrit ces porteurs, les choix et les paires qui en viennent par
  mots comme tout le bundle (`māma`, `Xī'ān`) ; le pinyin cité dans une
  introduction ou un choix sans hanzi entre parenthèses (`lǎoshī, Měiguó`)
  s'écrit directement ainsi ;
* `lessons` : `id`, `title`, `summary`, deux `objectives` (le premier pour les
  exercices d'écoute, le second pour les autres), des blocs `introduction`
  (`title`, `body`), `vocabulary` (références du catalogue ou de l'existant,
  six à huit mots, présentés à l'avance) et `exercises`.

Un exercice s'écrit par porteurs, jamais par pinyin : `tone` (`say`, `options`
= schémas de tons, la réponse est déduite du porteur), `pinyin` (`say`,
`choices` en pinyin), `hear` (`say`, `choices` en hanzi), `match` (`pairs`,
`mode` `pinyin` ou `meaning`), `choice` (`prompt`, `choices`, `answer`) et `speak`
(`say`). Chacun porte sa phase (`stage` : `discover`, `guided`, `reuse`), et
`pinyin` / `hear` un `contrast` (`initial`, `final`, `tone`) quand tous les
distracteurs ne diffèrent de la réponse que par ce trait. Le générateur tourne
la position des bonnes réponses de façon déterministe.

`lint` refuse un module 0 hors de 6 à 8 leçons, un exercice hors du budget de
15 à 20, moins de quatre types, moins de 60 % d'écoute, moins de quatre paires
minimales, une phase manquante ou dans le désordre, un objectif sans exercice,
une réponse qui ne correspond pas aux porteurs (ton, pinyin, paire), un signe de
ton mal placé, une syllabe proposée qu'aucun porteur n'atteste, un mot nouveau ou
plus de huit mots aperçus, et un `order` qui n'est pas la position de la leçon sur
le parcours. Le générateur réécrit cet `order` dans chaque leçon, protégées comprises.

Voici une séance complète illustrative, marquée « non livrable » et non utilisée
comme contenu du cours. Elle montre vocabulaire, grammaire, dialogue, choix,
ordre, trou, oral, écoute TTS, lecture, puis bilan ; les traductions et le
contenu chinois sont des exemples à remplacer par les textes validés de release.

```json
{
  "id": "lesson-05",
  "moduleID": "unit-02",
  "order": 5,
  "title": {"fr": "Demander une direction"},
  "summary": {"fr": "Comprendre une demande simple et répondre brièvement."},
  "estimatedMinutes": 12,
  "objectives": [
    {"id": "l5-understand", "text": {"fr": "Comprendre la question de direction."}, "required": true},
    {"id": "l5-produce", "text": {"fr": "Répondre avec une formule courte."}, "required": true}
  ],
  "vocabularyIDs": ["hsk20-example-zai", "hsk20-example-lu"],
  "extraVocabulary": [{"id": "vocab-example-near", "hanzi": "附近", "pinyin": "fùjìn", "toneNumbers": [4, 4], "meaning": {"fr": "à proximité"}, "partOfSpeech": "adverb"}],
  "grammar": [
    {"pattern": "在 + lieu", "explanation": {"fr": "在 place le lieu après le sujet dans une phrase simple."}, "examples": [{"hanzi": "我在这里。", "pinyin": "wǒ zài zhè lǐ.", "translation": {"fr": "Je suis ici."}}]}
  ],
  "dialogue": {
    "id": "block-l5-dialogue",
    "lines": [
      {"speaker": "Mina", "hanzi": "请问，地铁站在哪里？", "pinyin": "qǐngwèn, dìtiě zhàn zài nǎlǐ?", "translation": {"fr": "Excusez-moi, où est la station de métro ?"}},
      {"speaker": "Tao", "hanzi": "在那边。", "pinyin": "zài nàbiān.", "translation": {"fr": "Par là."}}
    ]
  },
  "reading": {
    "id": "block-l5-reading", "storyID": "story-l5-direction", "title": {"fr": "Dans la rue"},
    "paragraphs": [
      {"id": "p1", "hanzi": "我问路。", "pinyin": "wǒ wèn lù.", "translation": {"fr": "Je demande mon chemin."}}
    ],
    "comprehensionExerciseIDs": ["ex-l5-reading"]
  },
  "exercises": [
    {"id": "ex-l5-choice", "kind": "choice", "prompt": {"fr": "Que signifie 路 ?"}, "objectiveIDs": ["l5-understand"], "choices": [{"id": "a", "label": {"fr": "route"}}, {"id": "b", "label": {"fr": "eau"}}], "correctChoiceID": "a"},
    {"id": "ex-l5-order", "kind": "wordOrder", "prompt": {"fr": "Remets la phrase dans l'ordre."}, "objectiveIDs": ["l5-produce"], "tokens": [{"id": "t1", "hanzi": "我"}, {"id": "t2", "hanzi": "在"}, {"id": "t3", "hanzi": "这里"}], "correctOrder": ["t1", "t2", "t3"]},
    {"id": "ex-l5-fill", "kind": "fillBlank", "prompt": {"fr": "Complète la phrase."}, "sentence": "我 __ 这里。", "acceptedAnswers": ["在"], "objectiveIDs": ["l5-produce"]},
    {"id": "ex-l5-speaking", "kind": "speaking", "prompt": {"fr": "Dis la réponse."}, "referenceText": "在那边。", "referencePinyin": "zài nàbiān.", "acceptedTranscripts": ["在那边"], "required": false, "objectiveIDs": ["l5-produce"]},
    {"id": "ex-l5-listen", "kind": "listeningChoice", "prompt": {"fr": "Écoute puis choisis le sens."}, "promptText": "在那边。", "choices": [{"id": "a", "label": {"fr": "par là"}}, {"id": "b", "label": {"fr": "demain"}}], "correctChoiceID": "a", "objectiveIDs": ["l5-understand"]},
    {"id": "ex-l5-reading", "kind": "choice", "prompt": {"fr": "Que fait la personne ?"}, "choices": [{"id": "a", "label": {"fr": "Elle demande son chemin."}}, {"id": "b", "label": {"fr": "Elle dort."}}], "correctChoiceID": "a", "objectiveIDs": ["l5-understand"]}
  ],
  "recap": {"id": "block-l5-recap", "vocabularyIDs": ["vocab-example-zai", "vocab-example-lu"], "objectiveIDs": ["l5-understand", "l5-produce"]}
}
```

Exécution locale : `python3 Tools/content_tool.py lint --root Content` vérifie
le bundle actuel. Après livraison d'un pack :
`python3 Tools/content_tool.py generate --input path/to/pack.json --root Content`
écrit les documents générés, puis relancer `lint`. Le générateur échoue avant
d'écrire si une clé est inconnue, une référence manque, un ID est dupliqué, un
jour ou un budget est incohérent, ou si une couverture canonique ne peut pas
être calculée.
