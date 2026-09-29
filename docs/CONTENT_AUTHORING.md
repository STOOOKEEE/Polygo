# Authoring du parcours quotidien

Le contenu linguistique est écrit dans un pack d'authoring puis transformé en
JSON embarqué par `Tools/content_tool.py`. Le générateur ne produit aucun
hanzi, pinyin, exemple ou scénario : chaque entrée doit venir du pack fourni
par l'équipe contenu. Il ne remplace pas non plus la validation linguistique.
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
`HSK-legacy-2.0`/`2.0` (libellé utilisateur : HSK classique), avec 300 lexèmes canoniques au jour 48 et 600 au jour
90 ; cela reste distinct des repères HSK 3.0 (500/1000). Le jalon des 300 lexèmes
tombe à la fin de l'unité 5 : avec au plus huit mots nouveaux par séance, les
séances 1 à 29 n'en apportent que 232 avant le jour de bilan 30.

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
* `grammar` est une liste de `{vocabularyID, pattern, explanation, examples}`.
  `examples` contient au moins un exemple `{hanzi, pinyin, translation}` avec
  sa traduction `fr`. La référence `vocabularyID` est vérifiée dans le lexique
  de la leçon, puis le générateur abaisse chaque note en `IntroductionBlock`
  autonome (`block-<lesson>-grammar-01`, etc.) : le titre reprend le pattern et
  le corps affiche l'explication française, puis chaque exemple sur trois
  lignes (hanzi, pinyin, français). Une note de grammaire est donc propre à la
  séance et ne modifie jamais le `VocabularyEntry` réutilisé ; le même lexème
  peut ainsi recevoir une explication différente lors d'une séance ultérieure.
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

Chaque leçon `lesson-05` à `lesson-94` livre entre 15 et 20 exercices (18 dans le
contenu actuel) répartis en trois phases
ordonnées. La phase est portée par le `metadata.stage` de chaque bloc
`exercise` ; les blocs d'introduction, vocabulaire, dialogue, lecture et bilan
gardent leur étape éditoriale.

| Phase (`stage`) | Exercices | Contenu |
| --- | --- | --- |
| `discover` | 5 à 7 | association mot/sens ou mot/pinyin (`matching`), dictée (`dictation`), discrimination des tons (`toneDiscrimination`), reconnaissance du sens et écoute de mots |
| `guided` | 6 à 7 | traduction par tuiles (`translation`), mini-conversation (`conversationChoice`), remise en ordre, phrase à trous, écoute de répliques |
| `reuse` | 5 à 6 | remise en ordre du dialogue (`dialogueOrder`), phrases du texte ou du dialogue (trou, sens), oral, puis l'écoute, l'oral et la lecture écrits dans le pack |

Les six exercices écrits dans le pack (`meaning`, `order`, `fill`, `listen`,
`speak`, `reading`) sont conservés tels quels avec leurs IDs ; `listen`,
`speak` et `reading` ferment toujours la séance. Les autres sont choisis par
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

Une séance présente au plus huit mots nouveaux (six ou sept dans le contenu
actuel), extras hors catalogue compris. Un mot est nouveau dans la première
leçon, par ordre, dont le vocabulaire le liste ; les mots repris d'une leçon
précédente sont réutilisés et ne comptent pas.

L'allocation (`Tools/build_90_day_authoring.py`) est la seule source du
vocabulaire canonique de chaque séance. Elle lit les textes écrits des
fragments (dialogue, lecture, exemples de grammaire, exercices), jamais leurs
listes de vocabulaire, puis :

* répartit les 587 lexèmes hors leçons de départ entre les 87 séances qui ne
  sont pas des bilans (jours 30, 60, 90), à raison de 6 à 8 par séance ; les
  rangs 1 à 300 sont tous introduits au plus tard au jour 48 (`MILESTONE_DAY`) ;
* impose qu'un mot soit introduit au plus tard dans la séance dont il est
  l'ancre de grammaire ou la question de sens ; un tel mot déjà vu reste dans la
  séance comme mot réutilisé ;
* échange ensuite des mots entre séances d'une même phase tant que cela réduit
  le nombre de couples (mot, séance) où un texte emploie un mot avant son
  introduction. Les textes écrits ne sont pas modifiés : une séance peut donc
  encore contenir un mot enseigné plus tard, comme avant ce partage.

Ordre d'exécution : `build_90_day_authoring.py`, puis
`build_authoring_days_06_45.py`, `build_authoring_days_46_90.py` et
`build_preview_authoring.py`, puis `assemble_90_day_authoring.py`, puis
`content_tool.py generate`. Le fragment des jours 1 à 5 n'a pas de liste de
vocabulaire ; l'assembleur la remplit depuis l'allocation et refuse un
fragment des jours 6 à 90 dont le vocabulaire diffère de l'allocation.

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
`translation` uniques avec une tuile en trop et une phrase que la leçon montre,
`dialogueOrder` qui suit le dialogue sans le modifier, `conversationChoice` à
trois réponses dont la bonne suit la réplique lue. Une séance doit utiliser au
moins quatre de ces six familles. Les quatre leçons protégées gardent leurs six exercices
d'origine.

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
    {"vocabularyID": "vocab-example-zai", "pattern": "在 + lieu", "explanation": {"fr": "在 place le lieu après le sujet dans une phrase simple."}, "examples": []}
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
      {"id": "p1", "hanzi": "我问路。", "pinyin": "wǒ wèn lù.", "translation": {"fr": "Je demande mon chemin."}, "segmentation": []}
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
