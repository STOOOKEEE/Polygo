# Pédagogie et progression Polygo

Contrat éditorial du programme **Mandarin au quotidien**, version 2026.10.0.
Ce document décrit les quatre leçons d'introduction et les 120 séances du plan :
les 8 leçons d'écoute du module 0 « Pinyin et tons », 90 leçons du jour,
14 révisions et 8 défis d'unité. Il complète [ARCHITECTURE.md](ARCHITECTURE.md),
[CONTENT_SCHEMA.md](CONTENT_SCHEMA.md), [CONTENT_AUTHORING.md](CONTENT_AUTHORING.md)
et [SRS.md](SRS.md). Les durées, paliers et niveaux sont des décisions
éditoriales ; ils ne mesurent pas le temps réel passé et ne promettent pas un
résultat d'examen.

## Périmètre du parcours

Le module 0, `unit-00` « Pinyin et tons » (`pinyin-01` à `pinyin-08`, `level-00`),
ouvre le parcours et les jours 1 à 8 du plan : huit séances d'écoute pure pour
installer l'oreille avant le premier mot (voir plus bas). Les leçons `lesson-01`
à `lesson-04` forment ensuite l'introduction `unit-01` (`level-01`). Elles
installent les premières salutations, la présentation, le pays d'origine et un
mini-échange. Le programme quotidien de mots commence ensuite au jour 9 avec
`lesson-05` et se termine au jour 120 avec `boss-unit-09`. Le jour est l'unité de
progression ; l'identifiant de leçon reste stable même si un jour est manqué.

| Bloc | Jours | Leçons du jour | Fonction éditoriale |
| --- | ---: | ---: | --- |
| `unit-00` — Pinyin et tons | 1–8 | `pinyin-01`–`08` | écouter les tons, les consonnes, les finales et l'orthographe du pinyin |
| Introduction | avant le jour 9 | 01–04 | installer les premiers échanges |
| `unit-02` — Vie pratique | 9–23 | 05–16 | maison, repas, famille et déplacements simples |
| `unit-03` — Temps, études et santé | 24–38 | 17–28 | routine, études, santé et loisirs |
| `unit-04` — Achats et déplacements | 39–53 | 29–40 | achats, directions et vie quotidienne |
| `unit-05` — Maison et communauté | 54–68 | 41–52 | quartier, maison et relations |
| `unit-06` — Études et travail | 69–83 | 53–64 | études, bureau et consolidation intermédiaire |
| `unit-07` — Ville et voyage | 84–98 | 65–76 | ville, transport et voyage |
| `unit-08` — Météo, nature et loisirs | 99–110 | 77–86 | environnement, météo et activités |
| `unit-09` — Récits et opinions | 111–120 | 87–94 | récits, opinions et bilan final |

Le module 0 est recommandé, pas obligatoire : `lesson-01` s'ouvre sans lui. Un
apprenant qui choisit « Je connais le pinyin » ou « Je lis déjà quelques phrases »
à l'onboarding, ou qui termine une leçon au-delà du module 0, n'y est plus ramené
et le plan le compte comme dépassé (l'écran Aujourd'hui commence alors au jour 9).

Dans chaque unité, une **révision** (`review-NN`) suit chaque série de cinq leçons
du jour et un **défi d'unité** (`boss-unit-NN`) la clôt ; le défi d'une unité dont
la dernière série compte cinq leçons tient lieu de révision. Aucun de ces
séances ne présente de mot nouveau. La révision est un test cumulatif des cinq
leçons précédentes : vocabulaire, phrases et structures, 18 exercices qui
reprennent les six types plus récents, chaque phase commençant par les leçons les
plus anciennes. Le défi couvre toute l'unité en 20 exercices et finit par un
dialogue à mener (écoute, réponse, traduction, mise en ordre, oral). Les révisions
ne remplacent pas le rappel SRS de 3 minutes (2 minutes les jours de défi).

Les sources d'authoring qui portent ce parcours sont
`Content/authoring/preview-first-five.json` pour les jours 1 à 5,
`Content/authoring/90-day-authoring-days-06-45.json` pour les jours 6 à 45,
`Content/authoring/90-day-authoring-days-46-90.json` pour les jours 46 à 90
et `Content/authoring/90-day-allocation.json` pour l'allocation commune. La
release transforme ces fragments en documents chargés sous `Content/`.

### Module 0 : apprendre à entendre

Chaque leçon du module 0 alterne une explication courte, avec des conseils
concrets pour un francophone, puis 18 exercices d'écoute : discriminer (paires
minimales sur une seule différence : le ton, la consonne initiale ou la finale),
reconnaître un mot entier, relier un son à son pinyin, dire à voix haute avec
auto-évaluation. Les six premières leçons vont du plus simple au plus fin (tons
isolés, `b/p d/t g/k`, `j q x` et `z c s`, `zh ch sh r`, finales et `-n / -ng`,
enchaînements et 3e ton devant 3e ton) ; la septième pose l'orthographe (`y`,
`w`, `ü`, `iu ui un`, apostrophe) et la huitième est un bilan sans règle
nouvelle. Les mots portés par les exercices (« porteurs ») sont des caractères
ou des mots réels et courants, dont le pinyin est vérifié ; les mots de
vocabulaire de chaque leçon sont ceux que les leçons du jour enseigneront
(aperçu, sans mot nouveau et sans compter dans les jalons).

## Une séance de 15 minutes

Chaque entrée de `course.plan.sessions` porte un budget de 15 minutes :
`courseMinutes + reviewMinutes == 15`. Ce budget aide à cadrer la séance ; il
ne devient ni une minuterie obligatoire ni une mesure d'engagement.

| Période | Cours nouveau | Rappel SRS | Total |
| --- | ---: | ---: | ---: |
| Jours 1–120 | `lesson.estimatedMinutes` (12 min, 13 min pour un défi d'unité) | `15 - courseMinutes` (3 min, 2 min pour un défi) | 15 min |

Pour chacune des 120 sessions, `courseMinutes` reprend la durée de la leçon
associée et `reviewMinutes` complète ce budget jusqu'à 15 minutes. Les leçons
quotidiennes et les révisions valent 12 minutes, donc 12 + 3 ; un défi vaut
13 + 2. Les bilans de l'allocation (jours 30, 60 et 90 avant l'insertion des
révisions : `lesson-34`, `lesson-64`, `lesson-94`) restent des checkpoints
éditoriaux ; leur budget ne change pas.

Le cycle d'apprentissage reste le même dans chaque séance :

1. **Observer** : lire une phrase ou un dialogue et écouter le texte quand un
   audio est disponible ; le pinyin, les caractères et la traduction sont des
   aides distinctes.
2. **Récupérer** : répondre avant d'afficher la solution et rappeler les
   cartes effectivement dues.
3. **Produire** : remettre des groupes dans l'ordre, compléter, écrire ou dire
   une phrase courte.
4. **Transférer** : reprendre la même fonction dans une situation légèrement
   différente, avec un guidage qui diminue lorsque le rappel réussit.

Les fragments quotidiens contiennent une scène, une lecture de deux paragraphes,
une note de grammaire et six activités : choix de sens, ordre des mots, trou,
écoute, production orale et compréhension de lecture. L'oral reste
`required: false` quand aucun service de prononciation n'est configuré. Une
réponse parlée ou une auto-évaluation ne devient jamais un score de
prononciation.

## Progression lexicale et paliers

Le catalogue de progression est `hsk-legacy-600`, version `2026.09.0`, avec le
référentiel `HSK-legacy-2.0` version `2.0`. Les 13 entrées canoniques déjà
présentes dans les quatre introductions constituent la base initiale. Les cinq
premiers jours sont la route d'authoring fixée ; les jours 6 à 29 introduisent
8 à 10 nouvelles entrées canoniques par séance. Les jours 31 à 59 introduisent
5 ou 6 entrées, puis les jours 61 à 89 en introduisent 5. Les jours 30, 60 et
90 sont des bilans sans nouveau seuil de catalogue et rappellent chacun dix
entrées choisies.

Les paliers de couverture sont vérifiés sur les identifiants canoniques et non
sur le nombre de cartes affichées :

| Jalon | Ce qui est planifié | Ce que cela ne dit pas |
| --- | --- | --- |
| Jour 68 | les rangs 1 à 300 du catalogue sont planifiés ; des entrées déjà vues peuvent s'y ajouter | qu'un apprenant connaît ou sait produire ces 300 lexèmes |
| Jour 83 | consolidation et réemploi, sans nouvelle cible numérique | qu'un niveau ou une liste est validé |
| Jour 120 | les rangs 1 à 600 sont planifiés | qu'un apprenant maîtrise le catalogue ou réussira un examen |

Les révisions et les défis d'unité n'introduisent aucun mot : les jalons se posent
sur le défi qui clôt l'unité de la leçon qui portait le jalon dans l'allocation
(jours 48, 60 et 90 avant l'insertion des révisions et du module 0).

Une entrée rencontrée est une exposition éditoriale. La maîtrise demande des
rappels et des productions observables, et reste indépendante du jour atteint.
Les mots de contexte hors de la cible du jour peuvent apparaître dans une
phrase ; ils ne comptent pas comme nouveauté canonique.

## Références et sources

Le jalonnement du programme utilise la liste HSK classique conservée dans le
catalogue. Le fichier de référence officiel est la liste CTI
[新 HSK（三级）词汇（600）](https://www.chinesetest.cn/userfiles/file/cihui.pdf),
complétée pour le contrôle des niveaux par le
[guide officiel HSK](https://www.chinesetest.cn/userfiles/file/HSKbyWord.pdf).
Les documents ont été récupérés le 8 septembre 2026 ; le catalogue conserve le
SHA-256 `58471dfd0803281a3a6f85f8cc64360d22d38cfd75880e1c096c2f631b88501b` de
la liste d'inventaire.

Le programme conserve séparément les autres repères présents dans le cours :
`HSK-3.0` / `2025-11` reste une référence de transition, et `CEFR` / `2020`
un repère complémentaire. Leurs listes ne sont pas fusionnées avec
`HSK-legacy-2.0` et aucun compteur du calendrier ne constitue un alignement
HSK 3.0 ou une conversion CECR.

Les rangs et les frontières de niveau viennent de la source officielle. Les
gloses françaises, les exemples, les scènes, les exercices et la présentation
du pinyin sont des textes originaux Polygo. La forme traditionnelle est
produite par conversion phrase-aware OpenCC puis contrôlée ; elle partage le
même identifiant canonique que la forme simplifiée.

## Caractères, pinyin et audio

Le catalogue porte le pinyin accentué avec des espaces entre les syllabes. Le
champ `toneNumbers` contient un nombre par syllabe : `1` à `4` pour un ton
lexical et `0` pour une syllabe neutre. La fiche mot conserve la lecture
lexicale de l'entrée ; une phrase ou un dialogue peut représenter une
réalisation contextuelle, notamment le changement de ton de `不` et `一`, ou
une syllabe légère. Le sandhi courant du premier troisième ton dans `你好`
n'altère pas l'écriture de référence `nǐ hǎo` `[3,3]`.

Les tons neutres ne sont pas déduits par une substitution globale. Ils sont
marqués mot par mot lorsqu'ils ont été relus ; `耳朵` peut apparaître comme
`ěr duo` ou `ěr duǒ` selon la convention de lecture retenue. La lecture
`xué shēng` `[2,1]` de `学生` et les autres valeurs du catalogue sont les
formes éditoriales vérifiées. Une variante de prononciation recevable ne crée
pas un nouvel identifiant lexical.

Tous les champs `audio` du lot quotidien sont `null` tant qu'un fichier livré,
son chemin et son SHA-256 n'existent pas. Le TTS éventuel est un repli de
l'adaptateur audio ; il ne transforme pas l'absence d'un enregistrement en
ressource hors ligne. Les guides manuscrits des quatre leçons d'introduction
restent des assets séparés et vérifiables.

## Objectifs, aide et SRS

Chaque objectif indique une action observable, par exemple reconnaître une
information, réutiliser un patron, écrire un caractère ou tenir un tour de
parole. Une activité de choix ne valide pas à elle seule une compétence de
production. Les variantes ouvertes sont inscrites dans `acceptedAnswers` ou
`acceptedTranscripts` ; le feedback doit rester lié à une erreur identifiable
(`tone`, `meaning`, `script`, `word-order`, `grammar`, `listening`, `speaking`
ou `transfer`).

L'aide peut progresser de H0 (aucune aide) à H4 (guidage puis rappel
reprogrammé) : réécoute et tons, pinyin ou traduction, modèle partiel, puis
rappel différé. Deux réussites indépendantes peuvent réduire l'aide ; un échec
programme un rappel sans retirer la possibilité de retenter.

Le scheduler SM-2 conserve la carte, la date, la qualité, l'intervalle, l'EF et
le nombre de lapses. `again`, `hard`, `good` et `easy` correspondent aux
qualités 0, 3, 4 et 5 ; une qualité inférieure à 3 remet l'intervalle à zéro.
Les détails déterministes et les transitions sont spécifiés dans [SRS.md](SRS.md)
et dans `PolygoSRS.SM2Scheduler`. Le contenu ne contient aucun état apprenant.

## Contrôle avant publication

La release vérifie les IDs, la résolution du catalogue, l'unicité des cartes,
les objectifs et les exercices, les références de lecture, les deux scripts,
les tons, les traductions et les assets réellement présents. Elle vérifie aussi
que les 120 sessions sont contiguës, que chaque budget vaut 15 minutes, que
les couvertures des jalons de 300 et 600 lexèmes portent sur les rangs canoniques
annoncés et que chaque unité suit le rythme révision / défi décrit plus haut.
Une publication peut afficher un repère de curriculum, une exposition ou une
progression ; elle ne doit pas présenter ces éléments comme une maîtrise ou un
score d'examen.
