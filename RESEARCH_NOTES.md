# Polygo — notes de recherche produit et pédagogie

État de la recherche : 7 septembre 2026 (Europe/Paris)

## Périmètre et méthode

Cette note prépare la conception originale de Polygo pour iPhone, iPad et macOS. La recherche porte sur les informations accessibles publiquement concernant HelloChinese et sur des références officielles ou académiques utiles à l’apprentissage du mandarin.

Les pages publiques de l’éditeur, les fiches App Store/Google Play, les documents du ministère chinois de l’Éducation et de Chinese Testing International (CTI), ainsi que des articles scientifiques ont été consultés. Les captures de la page publique HelloChinese servent uniquement à observer des familles d’interactions ; aucun texte de leçon, audio, vidéo, illustration, code, contenu d’application ou contenu derrière un paywall n’est repris. Les nombres annoncés par l’éditeur sont identifiés comme des déclarations marketing, et les avis d’utilisateurs comme des observations anecdotiques.

Les sections « Vérifié », « Observation », « Hypothèse » et « Décision Polygo » sont séparées afin que l’équipe ne transforme pas une impression en exigence produit.

## Sources principales

| Source | Nature | Usage dans cette note |
| --- | --- | --- |
| [HelloChinese — page officielle française](https://www.hellochinese.cc/fr) | Page produit publique | Positionnement, micro-leçons, lecture/écriture/oral, reconnaissance vocale, vidéos, SRS, langues de caractères, disponibilité annoncée |
| [HelloChinese — App Store](https://apps.apple.com/us/app/hellochinese-learn-chinese/id1001507516) | Fiche publique iPhone/iPad, version et avis | Fonctionnalités annoncées, historique de version 7.6.3 (28 août 2026), 430+ points de grammaire et 2 500+ mots annoncés pour Main Course 2.0, limites des avis |
| [HelloChinese — Google Play](https://play.google.com/store/apps/details/?hl=en-US&id=com.hellochinese) | Fiche publique Android | Recoupement des fonctionnalités, hors-ligne et synchronisation, mise à jour indiquée début septembre 2026 |
| [Analyse académique de HelloChinese par Li, Liu et Cao, 2025](https://www.hssonline.cn/rc-pub/front/front-article/download/87075222/lowqualitypdf/%E7%A7%BB%E5%8A%A8%E5%BE%AE%E5%AD%A6%E4%B9%A0%E7%90%86%E8%AE%BA%E8%A7%86%E8%A7%92%E4%B8%8B%E7%9A%84%E4%B8%AD%E6%96%87App%E6%95%99%E5%AD%A6%E8%AE%BE%E8%AE%A1%E5%88%86%E6%9E%90%E2%80%94%E2%80%94%E4%BB%A5HelloChinese%E4%B8%BA%E4%BE%8B.pdf) | Article académique, analyse d’une version observée en mars 2024 | Structure de cours, types d’exercices, histoires et immersions, points de vigilance. L’article signale lui-même que des mises à jour peuvent rendre certains détails obsolètes |
| [Ministère chinois de l’Éducation — GF0025-2021](https://www.moe.gov.cn/jyb_xwfb/gzdt_gzdt/s5987/202103/t20210329_523304.html) | Standard officiel | Trois étapes/neuf niveaux, quatre éléments linguistiques, cinq compétences |
| [CTI — page HSK](https://www.chinesetest.cn/HSK) | Page officielle actuelle | Coexistence annoncée de l’ancien système à six niveaux et du nouveau cadre HSK 3.0, cinq composantes du syllabus |
| [CTI — page du syllabus HSK 3.0](https://www.chinesetest.cn/syllabus) | Page officielle actuelle | Niveaux 1–6 et groupe 7–9, liens vers le syllabus et profils de compétences |
| [Syllabus HSK 3.0 officiel, PDF](https://hsk.cn-bj.ufileos.com/3.0/%E6%96%B0%E7%89%88HSK%E8%80%83%E8%AF%95%E5%A4%A7%E7%BA%B21219.pdf) | PDF CTI, couverture « 11/2025 publié, 07/2026 mis en œuvre » | Tâches, sujets, listes quantitatives et progression de difficulté |
| [CTI — deuxième épreuve mondiale pilote HSK 3.0](https://admin.chinesetest.cn/gonewcontent.do?id=51236758) | Avis officiel, 2026 | Statut de transition au 7 septembre 2026, oral couplé aux niveaux 3–6 du pilote |
| [CTI — calendrier officiel 2026](https://admin.chinesetest.cn/gonewcontent.do?id=50278989) | Avis officiel | Vérification que le calendrier publié continue de proposer HSK 1–6 et HSK 7–9 |
| [Conseil de l’Europe — CEFR Companion Volume 2020](https://www.coe.int/en/web/common-european-framework-reference-languages/cefr-companion-volume-and-its-language-versions) | Référentiel public de compétences | Réception, production, interaction et médiation comme axes d’activité ; complément, pas équivalence HSK |

Références expérimentales supplémentaires : [Karpicke & Roediger, *Science* 2008](https://doi.org/10.1126/science.1152408) sur le rappel actif, [Cepeda et al., *Psychological Bulletin* 2006](https://pubmed.ncbi.nlm.nih.gov/16719566/) sur l’espacement, [Orthographic effects on the perception and production of L2 Mandarin tones](https://doi.org/10.1016/j.specom.2017.11.003), [Hsiung et al., *Computers in Human Behavior* 2017](https://doi.org/10.1016/j.chb.2017.04.022) sur la pratique d’écriture, [Knell & West, *Foreign Language Annals* 2017](https://doi.org/10.1111/flan.12281) sur le moment d’introduction des caractères, [Lu, Ostrow & Heffernan, *AERA Open* 2019](https://doi.org/10.1177/2332858419890326) sur le coût de la copie manuscrite, [Zhou & Day, programme de lecture extensive en chinois L2](https://doi.org/10.64152/10125/67448), et [les résultats Hsiung et al. dans le dépôt de la National Taiwan Normal University](https://scholar.lib.ntnu.edu.tw/zh/publications/effect-of-stroke-order-learning-and-handwriting-exercises-on-reco-2/).

## HelloChinese : faits vérifiés dans les sources publiques

### Positionnement, niveaux et sections

La page officielle présente HelloChinese comme une application de mandarin destinée à partir de zéro, avec des leçons courtes, un parcours ludique et un apprentissage de la lecture, de l’écriture, de l’expression orale, du vocabulaire et de la grammaire. Les fiches de magasins annoncent un parcours systématique associé aux niveaux HSK, une initiation au pinyin, des conversations pratiques, plus de 1 000 histoires graduées et plus de 2 000 vidéos de locuteurs natifs. La fiche Google Play mentionne aussi l’accès hors ligne après téléchargement d’un cours et le suivi de progression sur plusieurs appareils.

La fiche App Store consultée autour de la version 7.6.3 (28 août 2026) indique que Main Course 2.0 a reçu des sections de niveau intermédiaire supérieur et annonce « 430+ » points de grammaire et « 2 500+ » mots pour le cours complet. Ce sont des compteurs déclarés par l’éditeur, sans détail public permettant de vérifier leur définition (mot, entrée, sens ou occurrence ; point de grammaire ou exemple). Ils ne doivent pas être pris comme mesure de maîtrise.

La page publique contient sept captures de marketing. Elles montrent notamment un parcours vertical de cartes de cours avec progression, une navigation en cinq destinations nommées en français « Apprendre », « Pratiquer », « S’entraîner », « Immersion » et « Moi », ainsi que des écrans de pinyin/hanzi, de construction de phrase, de microphone et de lecture. Les visuels peuvent être issus de versions différentes de la version actuelle ; ils servent à repérer des patterns d’interaction, pas à spécifier l’interface de Polygo.

### Pinyin, tons et audio

Le pinyin est présenté comme un cours distinct pour débutants. Les supports publics montrent du pinyin au-dessus des caractères, un bouton de lecture, des exercices de production orale et une forme de visualisation de la voix. La fiche produit revendique une reconnaissance vocale qui corrige la prononciation. La page officielle revendique aussi des vidéos de locuteurs natifs et la fiche magasin décrit une pratique des quatre compétences.

L’analyse académique de 2025, fondée sur la version de mars 2024, décrit un traitement simplifié des syllabes : construction de la syllabe, initiales, finales et tons, avec 35 syllabes de répétition dans la partie Pronunciation observée. Ce chiffre est historique et ne doit pas être attribué à la version de septembre 2026. Le même article rapporte que l’apprenant peut réécouter sa production et la comparer à un modèle, mais signale une stabilité imparfaite de la notation vocale. Ce dernier point est une observation datée, non un audit de la version actuelle.

### Caractères, vocabulaire et grammaire

Les pages produit annoncent une pratique de l’écriture manuscrite. Les captures publiques montrent un caractère avec animation de traits, une zone de tracé et des commandes de lecture/affichage. L’analyse académique indique qu’une section séparée de caractères a été ajoutée ou fortement révisée début 2024 ; elle décrit des parcours de reconnaissance, d’écriture, d’écoute et de saisie, ainsi que des exercices de radicaux, de caractères courants et de caractères issus du nouvel HSK observé à cette date. Ces éléments sont à revalider avant toute affirmation de parité avec la version 2026.

Les exercices visibles ou décrits publiquement relient mot, pinyin, caractère, image, audio et phrase. Le cours est donc plus riche qu’un simple dictionnaire, mais les compteurs de mots et de points de grammaire ne précisent pas la couverture active, la fréquence, les variantes de sens ni le niveau de production demandé.

### Exercices, révision et adaptation

L’article de 2025 décrit une forte utilisation de la réponse contrôlée : choix, choix à trou, appariement, vrai/faux, remise en ordre de mots, traduction, répétition/imitation orale et saisie du pinyin. Il décrit aussi une répétition espacée qui fait réapparaître les erreurs après quelques autres items et une personnalisation basée sur les réponses antérieures. La page officielle revendique un système de répétition espacée, et la fiche magasin revendique des jeux adaptatifs.

L’étude rapporte deux risques de qualité à surveiller dans tout produit de ce type : une traduction parfois évaluée contre une seule réponse alors que plusieurs formulations sont valides, et une reconnaissance orale susceptible de marquer incorrecte une production acceptable. Ces risques sont cohérents avec les limites générales d’un exercice fermé et ne prouvent pas que la version 2026 présente toujours ces défauts.

### Histoires, immersion et interaction

L’analyse académique décrit, pour la version étudiée, six familles d’histoires : culture chinoise, récits/paraboles anciens, histoires humoristiques, vie quotidienne, langue et communication, et séries. Le lecteur pouvait afficher caractères, pinyin ou les deux, toucher un mot pour obtenir pinyin/niveau/partie du discours/traduction, écouter chaque phrase à une vitesse réglable, afficher la traduction et répondre à un quiz de compréhension. La fiche officielle actuelle confirme l’existence d’un grand catalogue d’histoires graduées, sans publier sa matrice détaillée de niveaux.

Pour « Immerse », l’étude décrit un enchaînement vidéo courte, mots/grammaire clés, cours audio, dialogue puis exercice. Elle rapporte des scènes de vie et un échange entre deux enseignants dans la version observée. Elle note également un espace de commentaires avec peu d’activité et des notifications limitées. Ces détails sont historiques et ne justifient pas de reproduire un module ou un nom de marque.

### Gamification et navigation

Les documents publics montrent un parcours par étapes, une progression, des étoiles ou récompenses et des objectifs personnels. L’étude décrit un modèle principalement auto-comparatif : objectifs quotidiens, barre de progression, badges et récompenses après plusieurs jours ; elle estime que des jeux peu hiérarchisés peuvent devenir répétitifs. Les captures montrent aussi un bouton d’arrêt pendant une activité et une progression d’items dans une session.

La fiche App Store actuelle signale une refonte du système de séries et des succès en avril 2026. Le nom et la forme exacte du système pouvant encore évoluer, Polygo doit retenir la fonction pédagogique de la progression et non le dessin d’une barre, le vocabulaire ou les couleurs de HelloChinese.

## HSK et difficulté : état au 7 septembre 2026

### Ce qui est stable

Le standard officiel GF0025-2021 du ministère de l’Éducation, applicable depuis le 1er juillet 2021, décrit trois étapes et neuf niveaux. Il organise la progression avec quatre éléments linguistiques (syllabe, caractère, vocabulaire, grammaire), trois dimensions d’évaluation (compétences communicatives, tâches/sujets et indicateurs quantitatifs) et cinq compétences (écouter, parler, lire, écrire, traduire). La traduction est surtout pertinente aux niveaux avancés.

La page CTI actuelle indique que le HSK 3.0 passe du système courant à six niveaux à un cadre « trois étapes, neuf niveaux ». Elle mentionne cinq composantes du syllabus HSK 3.0 : tâches, sujets, vocabulaire, grammaire et caractères. Le syllabus officiel est consultable par niveau et par type de donnée sur la page CTI.

### Transition à ne pas masquer

La couverture du PDF du syllabus HSK 3.0 indique une publication en novembre 2025 et une mise en œuvre en juillet 2026. Cependant, au 7 septembre 2026, CTI continue de publier un calendrier HSK 1–6 et HSK 7–9, et son avis officiel annonce une deuxième épreuve mondiale pilote HSK 3.0 le 20 septembre 2026. Dans cet avis, les niveaux HSK 3 à 6 du pilote doivent être inscrits avec l’oral correspondant. Cela prouve une phase de transition opérationnelle ; cela ne permet pas de conclure qu’un ancien score, un ancien manuel ou chaque centre est déjà basculé.

L’ancien barème public HSK 2.0 reste utile pour comprendre des contenus existants : 150 mots au niveau 1, 300 au niveau 2, 600 au niveau 3, 1 200 au niveau 4, 2 500 au niveau 5 et au moins 5 000 au niveau 6. Il ne faut pas le mélanger aux listes du syllabus HSK 3.0 publié fin 2025.

### Quantités du syllabus HSK 3.0 publié fin 2025

Le tableau ci-dessous est une transcription des compteurs des sections du PDF officiel : les mots et les caractères de lecture sont cumulés par niveau ; les caractères d’écriture sont cumulés, avec les niveaux 1 et 2 groupés dans le document. Le groupe 7–9 est volontairement conservé comme un groupe, car le PDF ne le ventile pas en trois listes indépendantes.

| Niveau HSK 3.0 | Capacité synthétique du profil CTI | Mots cumulés | Caractères à reconnaître cumulés | Caractères à écrire cumulés | Sujets (niveau 1 / 2 / 3) |
| --- | --- | ---: | ---: | ---: | ---: |
| 1 | échanges simples dans des situations de vie | 300 | 246 | 100 | 5 / 15 / 30 |
| 2 | échanges de base dans la vie, les études et le travail | 500 | 371 | 100 | 5 / 18 / 34 |
| 3 | échanges efficaces dans la vie, les études et le travail | 1 000 | 655 | 250 | 6 / 22 / 54 |
| 4 | échanges complets et cohérents dans ces contextes | 2 000 | 1 096 | 400 | 7 / 31 / 77 |
| 5 | échanges précis et appropriés au travail et aux études | 3 600 | 1 527 | 550 | 7 / 29 / 72 |
| 6 | échanges riches et fluides au travail, dans les études et des situations professionnelles générales | 5 400 | 1 940 | 700 | 7 / 25 / 68 |
| 7–9 | échanges normés, puis appropriés et enfin précis dans des contextes professionnels, spécialisés et académiques | 11 000 | 3 088 | 1 200 | 5 / 29 / 92 |

Les tâches du PDF sont des objectifs observables et non seulement des listes de mots. Au niveau 1, elles portent sur les informations personnelles, les objets, la météo, les besoins quotidiens, l’alimentation, les déplacements, les achats, la santé, les loisirs, les études, le travail et quelques traditions. Aux niveaux 2 et 3, elles ajoutent formulaires, étiquettes, démarches, expériences de déplacement, relations familiales, vie scolaire, travail, santé et environnement. Le niveau 4 ouvre fortement les situations de problème, d’éducation, d’emploi, de technologie, d’économie, de société, d’histoire et de culture ; les niveaux 5–6 développent ces domaines en analyse et en explication ; le groupe 7–9 ajoute notamment droit, médias, politique/économie, recherche, affaires, relations internationales et écrits professionnels/academiques.

La difficulté Polygo doit donc être définie à la fois par niveau HSK, type de tâche, densité lexicale, vitesse et compétence. Un niveau ne doit pas être présenté comme une promesse automatique de réussite à l’examen.

## Références pédagogiques et implications

Le rappel actif est plus utile pour la rétention différée que la simple relecture dans l’expérience de Karpicke et Roediger sur le vocabulaire étranger ([*Science*, 2008](https://doi.org/10.1126/science.1152408)). La méta-analyse de Cepeda et al. ([*Psychological Bulletin*, 2006](https://pubmed.ncbi.nlm.nih.gov/16719566/)) montre que l’espacement doit être relié à l’intervalle de rétention visé. Polygo doit donc demander une récupération avant d’afficher la solution, planifier des retours distribués et mesurer la réussite après délai.

Pour les tons, l’étude sur les effets de l’orthographe dans la perception et la production de tons mandarin L2 ([*Speech Communication*](https://doi.org/10.1016/j.specom.2017.11.003)) montre que l’utilité relative du pinyin et des caractères dépend de la tâche et du niveau. L’étude sur l’entraînement perceptif des tons sandhi mandarin ([*Speech Communication*, 2022](https://doi.org/10.1016/j.specom.2022.02.008)) montre que le transfert vers la production dépend du profil linguistique de l’apprenant et du contexte phonologique. Cela justifie une boucle perception → production → réécoute, avec plusieurs locuteurs et plusieurs contextes, plutôt qu’un unique score de hauteur.

Pour les caractères, Knell et West ([*Foreign Language Annals*, 2017](https://doi.org/10.1111/flan.12281)) ont trouvé, chez des débutants adolescents, un avantage de l’introduction précoce sur la compréhension écrite et l’écriture, sans différence significative sur les évaluations orales. Hsiung et al. ([*Computers in Human Behavior*, 2017](https://doi.org/10.1016/j.chb.2017.04.022)) ont observé chez 91 apprenants que la pratique d’écriture améliorait la production écrite et la mémorisation du sens, alors que l’accent particulier mis sur l’ordre des traits n’avait pas d’effet significatif dans leur expérience. À l’inverse, Lu et al. ([*AERA Open*, 2019](https://doi.org/10.1177/2332858419890326)) soulignent le temps élevé de la copie manuscrite quand le but prioritaire est l’acquisition des mots et la communication. La décision raisonnable est une écriture régulière, courte et optionnellement approfondie, synchronisée avec la reconnaissance, sans en faire un goulot d’étranglement.

Le programme de lecture extensive de Zhou et Day ([2023](https://doi.org/10.64152/10125/67448)) fournit un cas documenté de lecture graduée en chinois L2 et de perceptions positives de la fluidité et de l’attitude de lecture. Le résultat n’est pas une preuve que n’importe quelle histoire suffit : les textes doivent rester accessibles, intéressants et accompagnés d’un suivi de compréhension. Le [CEFR Companion Volume 2020](https://www.coe.int/en/web/common-european-framework-reference-languages/cefr-companion-volume-and-its-language-versions) est utile pour modéliser séparément réception, production, interaction et médiation ; ses niveaux ne doivent pas être présentés comme une conversion officielle HSK.

## Observations et risques utilisables pour Polygo

1. Le parcours court et scénarisé réduit la friction de démarrage : une session peut avoir un objectif communicatif unique, une durée courte et une action « reprendre » évidente.
2. L’association immédiate du son, du pinyin, du caractère et du sens facilite l’entrée dans le mandarin, mais peut conduire à reconnaître sans savoir produire. La progression doit distinguer reconnaissance, saisie, écriture et oral.
3. Les histoires et les dialogues donnent un contexte aux points de grammaire et aux mots. Le risque documenté dans des avis publics est un décalage entre l’ancien parcours principal et des histoires alignées sur des consignes HSK plus récentes ; Polygo doit relier explicitement chaque texte à la version de standard et à ses prérequis.
4. Une réponse unique est adaptée à un exercice de discrimination ou de remise en ordre, pas à toute traduction ou production libre. Les exercices ouverts doivent accepter des variantes validées, donner une explication et distinguer « compréhensible », « naturel » et « conforme à la cible ».
5. La reconnaissance vocale est une aide et non un juge infaillible. Une erreur de micro, d’accent, de bruit ou de modèle ne doit pas bloquer une leçon ni dégrader artificiellement la série de l’apprenant.
6. Les récompenses personnelles peuvent soutenir l’habitude ; la compétition et la répétition mécanique doivent rester optionnelles. Une métrique de maîtrise retardée est plus informative que des points d’XP.
7. La présence d’un onglet d’interaction ou de commentaires ne garantit pas une communauté active. Pour un premier périmètre, mieux vaut un guidage local et des retours clairs que d’ajouter un réseau social non modéré.
8. Les listings HelloChinese revendiquent hors-ligne et progression multi-appareils alors que l’exposition macOS varie selon la vitrine App Store. Polygo doit viser une vraie expérience universelle iPhone/iPad/macOS, avec le même modèle de données et des commandes adaptées au clavier, au trackpad et au stylet.

## Hypothèses à valider par prototype et tests utilisateurs

- Une session de 3 à 7 minutes avec une seule intention communicative augmente le taux de reprise sans réduire la compréhension.
- Un dosage constant de 2 à 4 caractères nouveaux par micro-leçon, avec reconnaissance obligatoire et écriture facultative, équilibre mieux charge et motivation qu’une piste « tout pinyin » ou qu’une copie longue. Ce dosage est une proposition de conception, pas un résultat HSK.
- Les rappels de tons mélangés à des mots connus, avec plusieurs locuteurs et une courte comparaison audio, transfèrent mieux vers la parole qu’un exercice de ton isolé répété.
- Afficher un diagnostic par dimension (initiale, finale, ton, rythme, intelligibilité) sera plus utile et plus digne de confiance qu’un verdict binaire.
- Les histoires dont la majorité des mots est déjà rencontrée, mais qui ajoutent une petite quantité de vocabulaire, produisent une meilleure lecture autonome qu’un classement HSK seul. Il faut mesurer les recherches, le taux d’abandon et la compréhension.
- Un plan de révision basé sur rappel différé, interleaving et erreurs récentes sera préféré à une relecture de toutes les cartes ; il faut mesurer le rappel à J+1, J+7 et J+30.

## Décisions originales proposées pour Polygo

### Modèle de niveaux et de contenu

1. Stocker un `standardID` et une `standardVersion` sur chaque objectif, mot, point de grammaire, caractère, activité et texte. Première version : `HSK-legacy-2.0` et `HSK-3.0-2025-11`.
2. Conserver un tableau de correspondance révisable entre les deux systèmes. L’interface affichera « aligné HSK 3.0 niveau 2 » ou « repère HSK 2.0 niveau 2 » avec la version, au lieu de fusionner les nombres.
3. Organiser le parcours par tâche communicative et sujet HSK, puis en micro-leçons. Chaque unité déclare une intention (« demander un prix », « comprendre une heure », « expliquer un problème »), les prérequis et les compétences pratiquées.
4. Une micro-leçon suit le cycle original `Observer → Récupérer → Produire → Transférer` : exemple compréhensible, rappel guidé, production courte, puis variation dans un nouveau contexte. Le bouton de reprise revient au prochain item dû, pas seulement au prochain écran.

### Pinyin, tons, caractères et vocabulaire

1. Faire un onboarding séparé sur syllabe, initiale, finale et tons, puis revoir ces éléments dans des mots et phrases. Inclure perception, imitation et contraste de tons ; ne pas masquer les caractères pendant toute la phase débutant.
2. Associer chaque lexème à ses formes simplifiée et traditionnelle lorsqu’elles diffèrent, à un audio licencié ou produit par Polygo, à la partie du discours, aux sens actifs, aux collocations et à la source de niveau. Les listes HSK servent de métadonnées ; les exemples et dialogues sont écrits spécialement pour Polygo.
3. Introduire les caractères tôt à faible dose. Distinguer quatre maîtrises : reconnaître à l’écran, sélectionner/saisir, écrire au stylet ou au doigt, et produire dans une phrase. Le tracé donne une aide graduelle ; il ne bloque pas la progression de communication.
4. Utiliser composants/radicaux et règles de tracé comme aide explicative, avec la possibilité d’ignorer la calligraphie détaillée. Une variante traditionnelle doit réutiliser l’audio et le sens sans supposer que les deux graphies sont interchangeables dans chaque contexte.

### Grammaire et exercices

1. Introduire une seule fonction grammaticale à la fois dans un dialogue, donner une explication courte, puis faire varier personne, temps, polarité et contexte. La carte de grammaire reste accessible depuis chaque exemple.
2. Mélanger discrimination auditive, sélection, trou, remise en ordre, dictée courte, traduction contextualisée, reformulation, réponse orale et rôle simulé. Les exercices fermés vérifient une cible ; les exercices ouverts donnent des critères et des exemples de formulation.
3. Enregistrer plusieurs réponses acceptées et des règles d’équivalence avant d’utiliser un modèle génératif. Tout feedback automatique incertain doit offrir « vérifier », « réécouter » et « passer avec signalement », puis être analysable par l’équipe éditoriale.

### Révision, audio et reconnaissance

1. La file de révision sépare mots, grammaire, tons, caractères, écoute et oral, tout en permettant une session mixte. La planification suit le rappel réussi, l’oubli et l’intervalle de rétention visé ; une nouvelle leçon ne remplace pas les items échus.
2. Donner un rappel avant révélation, puis une explication d’erreur et un second rappel différé. Mesurer rappel immédiat et différé plutôt que seulement vitesse ou XP.
3. Chaque audio propose lecture normale, lente, boucle de phrase, comparaison de locuteurs et affichage contrôlable des caractères/pinyin. Les textes et audios Polygo doivent être originaux ou correctement licenciés.
4. Pour l’oral, enregistrer localement lorsque possible, demander le consentement, montrer une confiance et un diagnostic par composante, et ne jamais faire dépendre la continuité d’un seuil automatique. Prévoir un mode silencieux de saisie ou d’écoute équivalente.

### Histoires graduées

1. Créer une bibliothèque de récits originaux liés aux objectifs et aux mots déjà maîtrisés, avec un niveau de standard explicite, un indice de densité lexicale et une longueur adaptée. Le niveau HSK est un repère de sélection, pas l’unique difficulté.
2. Dans le lecteur : afficher caractères, pinyin et traduction selon trois réglages indépendants ; toucher un mot pour une fiche courte ; écouter une phrase ou le récit ; masquer progressivement les aides ; répondre à des questions de compréhension et de reformulation.
3. Relier chaque nouveau mot d’une histoire à sa carte de révision et à une occurrence de dialogue. Ne pas envoyer l’apprenant vers une histoire dont le vocabulaire est largement absent du parcours sans l’indiquer.

### Gamification, interaction et navigation

1. Utiliser des objectifs personnels, des jalons de compétence et des séries souples. Récompenser la récupération différée et la régularité, pas la simple accumulation de clics. Garder défis entre pairs et classements hors du premier périmètre.
2. Choisir une architecture de navigation originale : `Aujourd’hui` (prochaine action), `Parcours` (unités et niveaux), `Bibliothèque` (histoires/audio), `Réviser` (files dues), puis `Profil/Réglages`. Sur iPad et Mac, exposer ces destinations dans une barre latérale ou un menu adapté au grand écran ; sur iPhone, conserver une barre compacte.
3. Dans une activité, garder une seule action primaire, un indicateur de progression accessible, une sortie sûre et une reprise. Les informations de pinyin, caractères, traduction et audio doivent être contrôlables sans multiplier les écrans modaux.
4. Prévoir une interaction locale de type « note de difficulté » ou « signaler un item » afin d’améliorer le contenu sans lancer une communauté publique. Les données de progression et les événements de révision doivent fonctionner hors ligne puis se synchroniser de façon idempotente.

## Garde-fous d’originalité et qualité

- Ne pas reprendre la marque HelloChinese, ses noms d’onglets, couleurs, mascottes, illustrations, captures, textes, enregistrements, vidéos, dialogues, traductions, exercices ou code.
- Utiliser HSK comme référentiel public de classement et de compétences, tout en rédigeant les exemples, récits et explications Polygo de manière originale et en conservant la version de la source.
- Revoir les tables de correspondance HSK à chaque publication CTI ; afficher la date de consultation et la version dans les données éditoriales.
- Faire relire les phrases par un enseignant ou un locuteur compétent, tester les réponses ouvertes et auditer les faux positifs/faux négatifs de l’oral avant de transformer un score en recommandation.
- Évaluer le produit par compétence : rappel différé, discrimination/production des tons, compréhension auditive, reconnaissance des caractères, écriture si choisie, compréhension de lecture, interaction et production. Le nombre de leçons terminées ne suffit pas.

## Résumé opérationnel pour l’intégration

Le rapport recommande un parcours HSK versionné et orienté tâches, avec pinyin/tons au début puis en contexte, caractères introduits tôt mais écriture non bloquante, exemples et histoires alignés par prérequis, révision fondée sur rappel actif et espacement, audio contrôlable, oral avec diagnostic prudent, et navigation universelle adaptée aux trois plateformes. La période HSK 3.0 reste transitoire au 7 septembre 2026 : aucune logique ne doit supposer que les listes 2.0 et 3.0 sont identiques ou qu’un niveau garantit un score d’examen.
