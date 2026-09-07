# Pédagogie et progression Polygo

Contrat éditorial V1, 7 septembre 2026. Ce document complète ARCHITECTURE.md,
UX.md et CONTENT_SCHEMA.md. Il définit une progression originale, extensible
et mesurable. Le pack `unit-01` est livré en JSON avec quatre leçons, quatre
histoires inline et trois guides de tracé vérifiables ; aucun audio enregistré
n’est déclaré disponible.

Les états utilisés ici sont : spécifié V1 (objectif et séquence définis),
contenu à produire (données, audio ou assets manquants), futur (emplacement
prévu mais non déverrouillable) et validé (relecture pédagogique et contrôle
éditorial effectués).

## Principes

Une unité répond à une tâche quotidienne observable. Une leçon dure quatre à
sept minutes, peut être interrompue après chaque exercice et reprend au
prochain item dû. Le cycle Polygo est :

1. Observer : entendre et lire un exemple avec contrôles séparés pour
   caractères, pinyin, traduction et audio ;
2. Récupérer : rappeler avant d’afficher la réponse ;
3. Produire : choisir, remettre en ordre, écrire ou dire une réponse courte ;
4. Transférer : réutiliser la fonction dans une situation légèrement nouvelle.

L’aide n’enlève pas de crédit ; elle est enregistrée comme condition de
tentative. Une traduction ou une production ouverte accepte les variantes
éditorialement listées. La confiance d’une transcription Speech ne devient
jamais seule un score de prononciation.

## Hiérarchie et contrat de contenu

Les identifiants sont opaques, stables et indépendants de l’ordre des tableaux.

| Élément | Exemple | Données requises |
| --- | --- | --- |
| Cours | mandarin-starter | langues, versions des référentiels, scripts et règles du catalogue |
| Niveau Polygo | level-01 | profil de compétences et alignements versionnés |
| Section | section-01 | famille de situations et prérequis communs |
| Unité | unit-01 | tâche, sujet, prérequis, durée, leçons et critères de sortie |
| Leçon | lesson-01 | intention, au plus 6 entrées lexicales nouvelles, grammaire, exercices, cartes |
| Objectif | obj-u1-identite | verbe observable, compétence, preuve, seuil et caractère requis |
| Mot/caractère | vocab-u1-ni, char-u1-ni | simplifié, traditionnel, pinyin accentué, tons, sens FR, nature, audio, exemple |
| Grammaire | gram-u1-jiao | fonction, patron, contraintes, exemples originaux, erreurs et variantes |
| Exercice | ex-u1-01 | objectif(s), mode, stimulus, réponse, feedback, aide et tags d’erreur |
| Carte | card-u1-ni-meaning | direction de rappel, compétence, source et état SRS |

ARCHITECTURE.md représente actuellement l’unité par ModuleSummary et la leçon
par LessonDocument. Le pack ajoute déjà ces informations sous des clés JSON
optionnelles : levelID, sectionID et unitID, standardID et standardVersion,
GrammarPoint, compétences et preuves, variantes acceptées, tags d’erreur, mode
reconnaissance/production et direction de carte. Le contrat Swift requis reste
inchangé ; une future version pourra décoder ces métadonnées explicitement.

## HSK versionné

Au 7 septembre 2026, le CTI publie encore l’ancien système à six niveaux et le
cadre HSK 3.0 à trois étapes et neuf niveaux. Le syllabus consulté est publié
en novembre 2025 et indique une mise en œuvre en juillet 2026 ; les calendriers
et pilotes montrent une transition opérationnelle. Polygo conserve les deux
références et ne mélange pas leurs listes.

| Référence | Usage et affichage |
| --- | --- |
| HSK-3.0 / 2025-11 | « Aligné HSK 3.0 niveau N » seulement après vérification éditoriale item par item |
| HSK-legacy-2.0 / 2.0 | « Repère HSK 2.0 niveau N (legacy) » pour les ressources historiques |
| Polygo / 2026.09 | « Progression Polygo » pour les décisions propres au produit |
| CEFR / 2020 | Descripteur complémentaire ; aucune conversion HSK–CECR n’est affichée |

Chaque interface montre la référence et sa version. Un alignement non vérifié
reste « repère » ou « à vérifier ». Un niveau Polygo, un compteur de mots ou
une unité terminée ne garantit ni score ni réussite à l’examen.

## Progression débutant-avancé

Seule la première tranche est spécifiée V1 ; tout le reste est futur et ne doit
pas être affiché comme disponible.

| Niveau | État | Tâches et critère de sortie |
| --- | --- | --- |
| level-00 | onboarding spécifié, assets futurs | distinguer syllabe, initiale, finale, tons 1–4 et neutre ; 8/10 en écoute |
| level-01 | unit-01 disponible V1 | saluer, se nommer, demander une origine et tenir un mini-échange ; reconnaissance, production contrôlée et transfert |
| level-02 | futur | heure, routine, besoins, achats et formulaires ; réponses courtes dans deux contextes |
| level-03 | futur | déplacements, santé, études et travail ; enchaîner plusieurs phrases et réparer un malentendu |
| level-04 | futur | problèmes, technologie, culture et société ; expliquer cause et conséquence |
| level-05 | futur | travail, études et argumentation ; résumer et choisir un registre |
| level-06 | futur | discours denses et situations professionnelles ; expliquer avec précision et reformuler |
| level-07 à 09 | futur, groupe HSK publié | domaines spécialisés, recherche, médias, droit, affaires et écrits académiques |

Les tableaux de bord séparent écoute, oral, lecture, écriture, tons,
vocabulaire, grammaire et interaction. Une sélection correcte ne valide jamais
une compétence productive.

## Unité V1 : Premiers échanges

| Champ | Valeur |
| --- | --- |
| Cours / niveau / section / unité | mandarin-starter / level-01 / section-01 / unit-01 |
| Statut | pack JSON disponible ; audio enregistré absent, TTS de l’adaptateur et guides SHA-256 livrés |
| Intention | commencer une conversation polie, dire son nom, demander et dire un pays |
| Prérequis / durée | aucun / 4 leçons de 4–7 minutes |
| Plafond lexical | au plus 6 entrées nouvelles par leçon ; les reprises ne sont pas recomptées |
| Scripts | simplifié et traditionnel associés ; préférence d’affichage indépendante du sens |

Les objectifs requis sont portés par les leçons : `l1-greet-*` (saluer, tons,
oral et tracé), `l2-name-*` (demander et donner un nom), `l3-country-*`
(demander et dire une origine) et `l4-exchange-*` (observer, récupérer,
produire et transférer un mini-échange). Les preuves sont attachées à des
exercices identifiés ; une sélection correcte ne devient donc pas une preuve
de production.

### Vocabulaire nouveau

Le chiffre de ton 0 désigne le neutre ; les diacritiques sont visibles dans le
pinyin. La graphie nǐ hǎo conserve les tons lexicaux 3,3, même si le premier
est souvent réalisé comme 2 en parole continue.

| Leçon | Entrées nouvelles en simplifié | Traditionnel | Pinyin / tons | Sens français |
| --- | --- | --- | --- | --- |
| 1 (5) | 你好, 早, 再见, 谢谢, 不客气 | 你好, 早, 再見, 謝謝, 不客氣 | nǐ hǎo (3,3), zǎo (3), zàijiàn (4,4), xièxie (4,0), bú kèqi (2,4,0) | salut, bonjour du matin, au revoir, merci, de rien |
| 2 (5) | 你, 我, 叫, 什么, 名字 | 你, 我, 叫, 什麼, 名字 | nǐ (3), wǒ (3), jiào (4), shénme (2,0), míngzi (2,0) | tu/vous, je, s’appeler, quoi, nom |
| 3 (6) | 是, 哪, 国, 法国, 中国, 人 | 是, 哪, 國, 法國, 中國, 人 | shì (4), nǎ (3), guó (2), Fǎguó (3,2), Zhōngguó (1,2), rén (2) | être, quel, pays, France, Chine, personne |
| 4 (1) | 呢 | 呢 | ne (0) | relance : et toi ? |

La couverture est vérifiable : ton 1 dans 中 de 中国, ton 2 dans 国/人/什, ton 3
dans 你/好/早/我/哪, ton 4 dans 再/见/谢/叫/是 et neutre dans 谢谢/什么/
名字/呢. Les 17 entrées nouvelles ont une phrase originale, une nature
grammaticale, les deux graphies, un alignement HSK versionné et `audio: null` ;
la lecture TTS n’est proposée que par l’adaptateur lorsqu’une voix Mandarin est
disponible.

### Grammaire, exercices et preuves

| Leçon | Patron et exemple | Exercices requis | Critère |
| --- | --- | --- | --- |
| lesson-01 Saluer (6 exercices) | 你好！谢谢。再见！ | ton, sens, ordre, lecture, oral et tracé | quatre reconnaissances sur cinq et une formule produite |
| lesson-02 Se nommer (7 exercices) | 你叫什么？/ 我叫安。 | ton, sens, ordre, trou, lecture, oral et tracé | question et réponse produites avec deux niveaux d’aide |
| lesson-03 Origine (7 exercices) | 你是哪国人？/ 我是中国人。 | ton, sens, ordre, rappel, lecture, oral et tracé | réponse dans un contexte nouveau et origine reconnue |
| lesson-04 Mini-échange (7 exercices) | 你好！你叫什么名字？你呢？ | graphie, relance, ordre, trou, lecture, interaction et carte | enchaîner quatre tours, puis relancer avec 你呢？ |

Les profils d’exercice sont listenChoose, toneChoose, meaningChoose,
sentenceOrder, fillBlank, speakPrompt, writeCharacter et reviewRecall. toneChoose
et meaningChoose peuvent être sérialisés comme choice avec un profil spécialisé.
Chaque leçon porte les quatre étapes `observer → recuperer → produire →
transferer` dans ses métadonnées de document et d’activité ; les échecs restent
rejouables. Les réponses ouvertes exposent `acceptedVariants` en plus des
réponses canoniques, avec un feedback correctif court et lié au tag d’erreur.

## Adaptation et révision

Les aides sont réversibles et déclarées par le document : H0 masque les aides ; H1 offre réécoute, débit
0,75×, boucle et numéro de ton ; H2 montre pinyin, traduction ou segmentation ;
H3 fournit modèle, premier token ou trace fantôme ; H4 guide puis reprogramme un
rappel. Après deux réussites indépendantes, le niveau redescend. L’apprenant
peut toujours choisir l’aide.

Les tags d’erreur sont tone-1 à tone-4, tone-neutral, initial, final, meaning,
script, character, word-order, grammar, listening, speaking, writing, audio et
transfer. Un échec déclenche feedback immédiat, nouvelle tentative après un à
trois items, puis carte. Les cartes séparent mot, grammaire, ton, caractère,
écoute et oral et proposent plusieurs directions de rappel. Une absence de
microphone, de Speech ou de guide ne fabrique pas de score : l’oral et le tracé
peuvent être `selfReported` ou `unavailable`, tandis que l’audio de référence
reste `null` et passe par le TTS réel de l’adaptateur.

Le scheduler SM-2 de l’architecture programme une première réussite à J+1, une
seconde à J+6 et une erreur à J+1 avec incrément d’oubli. Chaque événement
conserve source, dimension, réponse, aide, note et échéance ; les états sont
idempotents. Le tableau de bord mesure rappel immédiat, J+1, J+7 et J+30.

## Critères vérifiables et feuille de route

Une leçon est terminée quand tous les exercices requis ont une réponse, chaque
objectif requis a une preuve et les tâches évaluables atteignent 80 %. Une
auto-évaluation orale ou manuscrite reste marquée selfReported ou unavailable.
Une unité exige pour chaque objectif une reconnaissance, une production
contrôlée et, lorsqu’il est demandé, un transfert. La recommandation de niveau
requiert au moins deux sessions et un rappel différé ; elle peut rester « à
consolider » sur un axe faible.

Le pack livré contient 27 exercices, 17 cartes sans doublon et quatre histoires
distinctes ; les trois histoires historiques (`story-hello-on-the-corner`,
`story-name-and-smile`, `story-country-on-a-map`) sont conservées et
`story-mini-exchange` est ajouté pour la leçon 04. Les quatre leçons ont
respectivement 5, 5, 6 et 1 entrée nouvelle ; les IDs réutilisés sont listés
dans `metadata.reusedVocabularyIDs` et ne gonflent pas ce compteur.

Avant publication, vérifier : plafond de six nouveautés, pinyin et tons,
simplifié/traditionnel, français, audio, réponses variantes, IDs résolus,
exercices par compétence, cartes sans doublon, accessibilité des aides,
alternative si Speech ou écriture est indisponible, contenu original et
alignements versionnés. Les audios enregistrés restent à produire ; TTS est un
repli d’adaptateur et ne vaut pas asset hors ligne. Les unités 2 et suivantes,
histoires graduées et
niveaux 2–9 sont futurs ; leur nombre de mots et de leçons sera défini avec
leurs propres objectifs plutôt qu’annoncé à l’avance.

Les sources HSK et les décisions de conception sont conservées dans
RESEARCH_NOTES.md. Les versions CTI doivent être revérifiées à chaque
publication.
