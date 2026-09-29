# Syllune — identité et spécification UX

## 1. Décision d’identité

Dans l’application Polygo, **Syllune** est le nom affiché et l’identité pédagogique originale (prononcé « si-lune » en français). Cette appellation ne constitue pas une recherche d’antériorité ni une validation de disponibilité de marque ; une vérification juridique et une recherche de domaine restent nécessaires avant publication.

Signature : **« Le mandarin, une syllabe à la fois. »**

Syllune aide à relier trois gestes : entendre une syllabe, la dire, puis la tracer. L’identité ne reprend aucun code visuel, texte, personnage, exercice ou flux de HelloChinese. Elle utilise une idée propre : trois courbes de ton qui entourent un noyau corail, comme un son qui prend forme.

La voix éditoriale est calme, précise et encourageante. Elle tutoie l’apprenant (« Continue avec 5 minutes »), explique les erreurs sans infantiliser (« Le ton 3 descend puis remonte »), et annonce clairement ce qui est mesuré. Les messages de réussite décrivent une action (« 6 mots revus »), jamais une promesse vague.

Le logo vectoriel original est [Syllune-Logo.svg](../Design/Syllune-Logo.svg) ; [Syllune-Logo-Dark.svg](../Design/Syllune-Logo-Dark.svg) sert au lockup sur surface sombre. Le symbole peut vivre seul dans la navigation ; le mot « Syllune » est rendu avec la police système dans l’application afin de suivre le thème et la taille d’accessibilité.

**Tavi**, le panda roux original, accompagne l’accueil, l’encouragement et la célébration. Visage, oreilles et ventre crème, queue annelée en virgule : les trois poses SVG et leurs PNG transparents se trouvent dans `Design/tavi-*.{svg,png}`. La pièce `Design/polygo-coin.{svg,png}` appartient à la même identité. Ces illustrations restent décoratives : elles ne remplacent ni une consigne, ni un état accessible.

## 2. Système visuel

### Couleurs sémantiques

Les couleurs sont des rôles, pas des valeurs dispersées dans les vues. Chaque couleur a une forme ou un libellé associé : la couleur ne porte jamais seule l’information. Une seule charte sert les cinq onglets : fond crème (indigo en sombre), cartes `surface`, jade comme accent principal, `sun` pour les récompenses, `sky`/`coral` comme accents secondaires et `success`/`error` pour le retour. Aucun écran n’impose son propre thème : tous suivent le réglage Apparence (système, clair ou sombre) à travers les mêmes tokens adaptatifs.

| Token | Clair | Sombre | Usage |
| --- | --- | --- | --- |
| `canvas` | `#FFF8E9` | `#10152D` | Fond crème / indigo |
| `surface` | `#FFFCF5` | `#1A2143` | Cartes et panneaux |
| `surfaceRaised` | `#F2E8D7` | `#242D56` | Champ, tuile secondaire |
| `ink` | `#29233F` | `#FFF8E9` | Texte principal et caractères chinois |
| `inkMuted` | `#6D6681` | `#BFC7E5` | Texte secondaire, métadonnées |
| `border` | `#E2DACC` | `#394365` | Séparateurs et contours |
| `jade` | `#148F7A` | `#47D7C2` | Accent principal : onglet sélectionné, progression, étape actuelle |
| `jadeDeep` | `#176F64` | `#74E7D5` | Liens, surtitres et texte accentué |
| `jadeButton` | `#176F64` | `#47D7C2` | Fond du bouton principal et de l’étape actuelle |
| `coral` | `#BC463B` | `#FF795A` | « Difficile », « Défi de l’unité », avatar |
| `sun` | `#F3C55E` | `#F5C75E` | Récompenses : pièces, série, contour des défis |
| `sky` | `#276096` | `#8CB7FD` | Écoute, audio, Explorer, « Révision » |
| `success` | `#166F49` | `#71DEA7` | Réponse correcte, terminé |
| `error` | `#B53347` | `#FA7A8C` | Erreur corrigeable, permission refusée |

Valeurs hexadécimales arrondies depuis `App/DesignSystem.swift`. Les fonds accentués utilisent leurs premiers plans adaptatifs associés (`inkOnJade`, `inkOnSuccess`, `inkOnSun`) ; `inkOnDeep` (blanc) est réservé aux fonds qui restent foncés dans les deux thèmes : dégradé héros, `coral`, `skyButton`. Les combinaisons doivent atteindre au moins 4,5:1 pour le corps et 3:1 pour les grands titres ou les éléments graphiques porteurs d’information. Les états « juste » et « à revoir » ajoutent toujours une icône et un libellé. Les vues n’ajoutent ni couleur brute, ni dégradé, ni relief propres : seules les ombres légères de `sylluneCard` détachent une surface.

### Typographie

- Titres et nombres de progression : **SF Pro Rounded**, Semibold, avec repli SF Pro.
- Texte courant et contrôles : **SF Pro Text**, Regular/Medium/Semibold.
- Chinois simplifié : **PingFang SC**, avec repli système CJK ; ne pas forcer une police latine sur les caractères.
- Pinyin : SF Pro Text ; les tons en diacritique restent dans la même taille que le pinyin. SF Mono est réservé aux exemples techniques éventuels, pas à l’interface courante.

Échelle de départ : `display 32/38`, `title 24/30`, `section 20/26`, `body 17/24`, `callout 15/21`, `caption 13/18`. Toutes les tailles sont liées à Dynamic Type ; aucune carte ne doit dépendre d’une hauteur fixe. Le texte chinois peut passer sur deux lignes sans couper les caractères.

### Formes, rythme et icônes

Espacements : `4, 8, 12, 16, 20, 24, 32, 40`. Rayons : `12` pour les champs et pastilles d’icône, `16`–`18` pour les cartes et lignes internes, `24` pour les panneaux d’accueil et les cartes d’unité du parcours, `999` pour les pastilles. Bordure standard `1 pt`; ombre très légère uniquement sur une surface qui se détache du fond (`sylluneCard`).

Les contrôles interactifs visent au moins `44×44 pt` sur iPhone/iPad. Chaque bouton de navigation basse a un minimum de `64×54 pt`, avant ses marges. Les leçons utilisent des SF Symbols sémantiques associés à leurs identifiants stables ; les illustrations de Tavi et de la pièce sont des ressources originales, sans dépendance réseau.

## 3. Navigation basse commune

L’onboarding précède la navigation principale. iPhone, iPad et Mac partagent ensuite **cinq vrais boutons** dans une barre horizontale basse, sans sidebar :

1. **Aujourd’hui** — activité du jour, reprise et révisions.
2. **Parcours** — unités et leçons.
3. **Explorer** — histoires et dictionnaire.
4. **Cartes** — file de rappel.
5. **Profil** — objectifs, progression et accès explicite aux Réglages.

`RootView` conserve une pile de routes par onglet pendant la session. Passer dans un autre onglet puis revenir conserve le détail ouvert ; retoucher l’onglet actif revient à sa racine. Les fiches ouvertes depuis un mot sélectionné appartiennent à la même pile. La destination principale et les checkpoints de leçon sont persistés localement.

La barre est posée dans la safe area. Si les cinq libellés ne tiennent plus avec Dynamic Type, elle devient défilante horizontalement plutôt que de tronquer les actions. Chaque bouton expose son libellé et son état sélectionné.

La barre basse et l’unique badge global de pièces disparaissent pendant **toute** la leçon — chargement, exercices, feedback et récapitulatif — ainsi que dans les pratiques autonomes Oral et Écriture. Ils reviennent à la sortie ; les contrôles pédagogiques propres à ces écrans restent disponibles.

Sur Mac, les commandes de navigation sont attachées à la scène : `⌘1` Aujourd’hui, `⌘2` Parcours, `⌘3` Explorer, `⌘4` Cartes, `⌘5` Profil, `⌘,` Réglages et `⌘K` dictionnaire. Une commande de navigation doit agir sur la fenêtre active, pas réinitialiser les piles des autres fenêtres. Les commandes audio et la fermeture d’une fiche restent accessibles depuis le menu Syllune ; les champs de saisie conservent leurs touches.

## 4. Onboarding

Quatre écrans, avec indicateur `1 sur 4` et reprise après fermeture. Chaque étape possède une valeur persistée ; aucune action « Ignorer » ne mène à un écran non préparé.

1. **Bienvenue** : Tavi et identité Syllune, promesse, bouton « Commencer ». Lien secondaire « En savoir plus » ouvre une fiche courte sur l’audio hors ligne et la confidentialité.
2. **Point de départ** : champ facultatif « Comment t’appeler ? », puis choix unique « Je commence », « Je connais le pinyin », « Je lis déjà quelques phrases ». Le choix initialise l’unité et le niveau de révision ; il est modifiable dans Profil. « Je commence » ouvre le module 0 (« Pinyin et tons ») ; les deux autres choix ouvrent directement `lesson-01`. Sans prénom, l’accueil utilise simplement « Bonjour ».
3. **Rythme** : durée quotidienne `5`, `10` ou `15 min`, et jours de rappel multiples. Le bouton « Continuer » reste disponible avec une valeur par défaut visible, jamais une validation silencieuse.
4. **Prêt à apprendre** : récapitulatif du choix, bouton « Ouvrir ma première leçon ». La permission microphone n’est demandée qu’au premier exercice oral, jamais à l’installation. Les textes et le pinyin de l’unité 1 sont embarqués ; un audio apparaît comme disponible hors ligne seulement lorsqu’un asset est livré.

État à conserver : `onboardingCompleted`, `displayName` facultatif, niveau de départ, rythme, jours actifs, préférence d’auto-lecture audio et `lastRoute`. Un retour arrière ne perd pas les réponses.

Le bouton principal de chaque étape reste sous la zone défilante dans un pied fixe ; il conserve le même style et l’action propre à l’étape.

## 5. Écrans et comportements

### Aujourd’hui / dashboard

`TodayView` choisit une composition compacte ou large selon l’espace disponible. En largeur compacte, le contenu défile en une colonne dans cet ordre : salutation et série, prochaine leçon, révisions, aperçu du parcours. La carte de reprise expose le bouton réel `home.primaryAction`, libellé « Commencer » ou « Continuer » selon l’état, qui ouvre la leçon de reprise ; sans leçon restante, elle affiche un état de fin au lieu d’une action fictive. La composition large place la reprise à côté des révisions et du parcours.

Le résumé du programme du jour apparaît dans la carte de reprise lorsqu’une séance correspond à la leçon affichée. Les textes et cartes s’adaptent à la largeur ; aucune hauteur fixe ne coupe une consigne.

Une action ouvre une route identifiée (`lessonID`, `reviewQueueID`, `mistakeFilter`). Une carte de contenu ne fonctionne jamais comme simple décoration cliquable.

### Parcours

Le parcours reprend le langage visuel de l’accueil : fond `canvas`, cartes `sylluneCard` de rayon 24, dans une colonne centrée (600 pt max) sur les trois plateformes. Une carte d’en-tête compacte affiche « TON CHEMIN », le compte « N sur M terminées » et une barre de progression ; le palier du programme, le titre complet, la description et les références du cours restent dans « À propos de ce parcours ».

Chaque module du manifeste devient une carte d’unité repliable. Son en-tête est un bouton (`learningPath.unit.<moduleID>`) : pastille du numéro (coche verte une fois l’unité terminée), « UNITÉ n », titre du module, mini-barre et « x/y leçons », chevron. VoiceOver l’annonce comme en-tête « Unité n, titre, x sur y leçons terminées » avec la valeur « Dépliée » ou « Repliée ». Par défaut, seules sont dépliées l’unité de l’étape actuelle et celle de la prochaine leçon du programme principal (le module 0 étant facultatif, un débutant voit donc l’unité 0 et l’unité 1) ; les unités terminées et à venir sont repliées mais gardent leur en-tête. Chaque choix d’ouverture ou de fermeture est mémorisé pour la scène (`@SceneStorage`). Tavi, en petit, se tient dans l’en-tête de l’unité de l’étape actuelle.

Une unité dépliée liste ses leçons en lignes reliées par un trait vertical (vert jusqu’à la dernière leçon terminée, gris ensuite). Chaque ligne affiche toujours le titre de la leçon et son état ; le nœud rond (44 pt, suit Dynamic Type) porte l’icône du thème de la leçon et partage l’iconographie des lignes de l’accueil : terminé = fond `success` et badge coche, actuelle = fond jade plein et anneau de progression des exercices, disponible = contour jade, verrouillé = fond `surfaceRaised` et badge cadenas. Les révisions `review-NN` (flèches circulaires) portent le surtitre « RÉVISION » ; le défi `boss-unit-NN` (couronne) porte « DÉFI DE L’UNITÉ » et un contour `sun`. L’étape actuelle est surlignée en jade et montre « Exercice n sur m » et une pastille « Commencer » ou « Continuer ». Toucher une ligne déverrouillée ouvre la leçon ; une ligne verrouillée n’est pas un bouton et indique « Verrouillée · termine l’étape précédente ».

Le module 0 (unité 0 « Pinyin et tons », leçons `pinyin-01` à `pinyin-08`) ouvre le parcours avec l’icône « onde sonore » (`waveform`). C’est un premier pas recommandé, pas une porte : ses leçons se déverrouillent l’une après l’autre, mais `lesson-01` s’ouvre sans elles. Un apprenant qui a choisi « Je connais le pinyin » ou « Je lis déjà quelques phrases », ou qui a terminé une leçon au-delà du module 0, ne s’y voit plus proposé ; le plan quotidien le compte alors comme dépassé (le premier jour affiché est le jour 9).

À l’ouverture, le parcours défile jusqu’à l’étape actuelle si elle n’est pas déjà visible, sans rouvrir une unité que l’apprenant a repliée ; quand elle sort de l’écran, un bouton flottant « Revenir à l’étape actuelle » (flèche vers elle) déplie son unité si besoin et y ramène. Chaque ligne reste un seul élément d’accessibilité « [type,] titre, statut, progression » (identifiant `learningPath.lesson.<id>`) ; Réduire les animations supprime les transitions de repli et de défilement.

La **cible pédagogique MVP** couvre l’unité 1, « Premiers échanges » (HSK 1 / A1), en trois leçons :

| Leçon | Notions et exemples | Exercices (dont requis) |
| --- | --- | ---: |
| 1. Dire bonjour | 你好 nǐ hǎo, 早 zǎo, 再见 zàijiàn, 谢谢 xièxie | 6 (5 requis) |
| 2. Dire son nom | 我 wǒ, 叫 jiào, 什么 shénme, 名字 míngzi ; 你叫什么名字？ | 7 (6 requis) |
| 3. Dire d’où l’on vient | 是 shì, 哪 nǎ, 国 guó, 法国 Fǎguó ; 你是哪国人？ | 7 (6 requis) |

Le pack JSON actuellement livré contient ces trois leçons et une extension déjà disponible : **4. Mener un mini-échange**, avec `呢 ne` et **7 exercices (6 requis)**. Cette quatrième leçon porte la sortie « mini-échange » du pack ; elle reste distincte de la cible éditoriale en trois leçons. Les nombres d’exercices du tableau décrivent chaque leçon et ne sont pas un compteur de leçons ; le « 6 cartes » de l’exemple du dashboard désigne la file de rappel du jour.

Chaque leçon présente ses nouveaux mots avant le premier exercice qui en a besoin, puis une barre de progression sur toutes ses étapes. Les exercices requis portent la progression : dans les quatre leçons livrées, l’oral est `required: false` et peut être passé sans évaluation. La composition actuelle enregistre alors la complétion lorsque les exercices requis sont acceptés ; le seuil de 80 % reste le critère éditorial de qualité. Le récapitulatif peut afficher « Leçon enregistrée » et `5 / 6 exercices réussis` avec `skippedCount: 1` : le saut reste exclu des réussites, mais la leçon suivante est déverrouillée. Les exercices ratés restent rejouables depuis l’écran de résultat.

### Pièces de progression

Une première complétion historique de leçon rapporte **10 pièces**, une seule fois par `LessonID`. Le journal existant compte aussi : le solde ne dépend pas uniquement des leçons terminées depuis la refonte. Recommencer une leçon ne retire rien et ne rapporte pas de pièces supplémentaires ; les révisions SRS n’en attribuent pas.

Le récapitulatif affiche `+10` uniquement pour une première complétion confirmée par l’opération courante, jamais au simple rechargement d’un résultat. Une histoire impossible à reconstruire est indiquée comme indisponible, pas présentée comme un solde de zéro. Il n’existe ni portefeuille séparé, ni boutique, ni paiement, ni synchronisation fictive.

### Leçon

Une leçon est une seule suite d’écrans, construite par `LessonFlow` (`Sources/PolygoCore/LessonFlow.swift`) à partir des blocs : il n’y a plus d’écran d’intro séparé. Le contenu d’apprentissage apparaît juste avant l’exercice qui s’en sert :

- la situation (introduction sans point de grammaire) ouvre la leçon ;
- les nouveaux mots suivent, trois par écran : caractère, pinyin, sens, audio (normal et lent) et exemple ; chaque mot est touchable et ouvre sa fiche ;
- une note de grammaire (`metadata.grammarPointID`) s’affiche juste avant le premier exercice qui porte le même `grammarPointID` ;
- le dialogue s’affiche juste avant le premier exercice qui en dépend : question listée dans `comprehensionExerciseIDs`, ou exercice qui fait entendre, dire, compléter ou ordonner une de ses répliques ;
- la lecture s’affiche juste avant sa question de compréhension, qui garde « Relire le texte » ;
- un bloc sans exercice consommateur garde sa place d’auteur, avant l’exercice suivant ; le récapitulatif (« À retenir », mots et objectifs) rejoint le bilan de fin, sous ses boutons.

Une leçon sans dialogue (module pinyin) enchaîne donc situation, mots puis exercices ; une révision ou un boss ouvre sur son introduction et montre son dialogue avant la première question qui le cite.

Toutes les étapes partagent le même cadre : en haut, la fermeture « Quitter la leçon » (`lesson.close`, à la place du retour), le compteur `étape / total` suivi du nom de la phase en cours, puis la barre de progression ; en bas, une seule action. Une étape d’apprentissage n’est pas évaluée : son bouton « Continuer » (`lesson.step.continue`) passe à l’étape suivante. Un exercice garde son cycle « Vérifier », retour, « Continuer » ou « Terminer ». Le compteur annonce le type d’étape et la phase à VoiceOver (« Étape 3 sur 20, Découverte, nouveaux mots ») et porte l’identifiant `lesson.step.teaching.<étape>` (l’ID du bloc, suffixé `.n` pour les cartes de mots) ou `lesson.exercise.<id>`.

Une leçon du jour suit trois phases, lues dans le `metadata.stage` de ses exercices : « Découverte » (`discover`), « Pratique guidée » (`guided`) et « Réemploi » (`reuse`). La barre de progression est découpée en un segment par phase, large à proportion de ses étapes ; une étape d’apprentissage compte dans la phase de l’exercice qu’elle prépare. Une leçon sans phases (L1 à L4) garde une barre d’un seul tenant, sans nom de phase. La barre avance avec une courte animation, supprimée quand « Réduire les animations » est actif ; VoiceOver lit « Progression, 35 pour cent, phase 2 sur 3 : Pratique guidée ». Dès trois bonnes réponses au premier essai d’affilée, une flamme et le compte (`lesson.streak`) s’affichent à droite du compteur. Il n’y a pas de vies : une erreur remet seulement la série à zéro, et la leçon continue.

Après chaque exercice évalué, Tavi apparaît en petit dans le retour (`lesson.feedback`), sous le verdict et l’explication : pose de célébration et courte réplique variée après une bonne réponse (« Bien joué ! »), pose d’encouragement et invitation douce à relire la bonne réponse puis réessayer après une erreur, « 3 bonnes réponses d’affilée, quelle série ! » aux séries de 3, 5, 10, 15 et 20, et, sur le dernier exercice d’une phase, l’annonce de la suivante (« Pratique guidée : on assemble des phrases ! »). Les répliques viennent de listes fixes du Core (`TaviReaction`), choisies par position d’étape : une même leçon se lit toujours de la même façon. Un exercice passé sans évaluation n’a pas de réaction. L’illustration est décorative ; verdict, explication et réplique forment un seul élément VoiceOver, lu une fois.

Structure d’un exercice : un seul exercice à la fois dans une zone défilante, retour après réponse, et barre d’action fixe en bas. Les actions haute et basse restent visibles pendant le défilement. Le libellé principal suit l’état : « Vérifier », « Continuer », « Réécouter » ou « Terminer » ; il change avec son effet. La colonne de contenu, la barre haute et la barre d’action partagent une largeur maximale d’environ 720 pt, centrée sur les grandes fenêtres.

La progression reste enregistrée par exercice (`currentExerciseIndex`/`currentExerciseID`) : une étape d’apprentissage est enregistrée comme l’exercice qu’elle prépare. À la reprise, une réponse en cours ou un retour affiché rouvre l’exercice lui-même ; sinon la leçon reprend aux étapes d’apprentissage qui le précèdent immédiatement. « Recommencer cette leçon » revient à la première étape.

L’écran de fin garde son en-tête (Tavi, « Leçon terminée » ou « Leçon enregistrée », `x / y exercices réussis`) et ajoute : la précision au premier essai (une réponse juste après « Réessayer » ne compte pas), le temps passé quand l’ouverture et la complétion tiennent en une séance de moins de deux heures, la meilleure série, puis les pièces gagnées. « Mots appris » liste les mots nouveaux de la leçon (`metadata.newVocabularyIDs`) en pastilles caractère, pinyin et sens ; toucher une pastille lit le mot et ouvre sa fiche. Une révision, un défi ou une leçon pinyin, qui n’introduisent aucun mot, affichent « Mots revus » avec les mots de leur récapitulatif. Suivent « Revoir les mots » (file de cartes, où la complétion vient d’ajouter ceux de la leçon) et « Recommencer cette leçon », puis le récapitulatif. En bas, une barre fixe propose « Continuer vers la leçon suivante » (la leçon suivante du cours, affichée une fois la leçon enregistrée comme terminée) et « Retour au parcours ».

Le dialogue s’affiche en bulles de conversation : premier locuteur à gauche, l’autre à droite, avec nom, caractères et petit bouton audio ; la réplique en cours de lecture est surlignée. Chaque mot d’une réplique est touchable et ouvre sa fiche. Le pinyin et la traduction sont masqués par défaut : toucher la bulle hors d’un mot, ou son œil (`dialogue.line.<i>`), les affiche ou les masque, et « Tout afficher »/« Tout masquer » (`dialogue.revealAll`) agit sur toutes les répliques. La réplique manquante de la participation ne se dévoile qu’une fois trouvée. « Écouter le dialogue » (`dialogue.play`) lit tout l’échange avec ses pauses. La participation facultative « À toi » masque une réplique (« Réplique manquante ») et propose d’écouter la réponse puis de choisir parmi trois répliques du même dialogue (`dialogue.choice.<n>`) : un bon choix dévoile la bulle, un mauvais permet de réessayer et affiche l’indice. Aucune saisie n’est demandée et la participation ne bloque pas la suite de la leçon.

Contrat commun d’un exercice : `id` stable, `kind`, consigne française, contenu chinois/pinyin, réponses ou chemin attendu, explication, médias optionnels, `required`, tentative et état de correction. Les types utilisés dans l’unité 1 sont :

- `listenChoose` : écouter un mot puis choisir parmi trois réponses ; audio rejouable et transcript accessible ;
- `toneChoose` : sélectionner le contour/numéro du ton, avec un libellé textuel pour l’accessibilité ;
- `meaningChoose` : associer caractère/pinyin et sens français ;
- `sentenceOrder` : remettre des tuiles dans l’ordre, avec déplacement clavier ;
- `fillBlank` : choisir le mot manquant dans une phrase courte ;
- `speakPrompt` : écouter, enregistrer, réécouter puis demander l’analyse du
  fournisseur ; si aucun fournisseur n’est configuré, « Continuer » passe sans évaluer ;
- `writeCharacter` : tracer un caractère avec ordre de traits fourni ;
- `reviewRecall` : révéler le verso, puis choisir `À refaire`, `Difficile`, `Bien` ou `Facile`.

Les séances quotidiennes ajoutent six familles, rendues par `App/ExerciseKindViews.swift` et `LessonView` :

- `matching` : deux colonnes, mots chinois à gauche numérotés, sens ou pinyin mélangés à droite (`lesson.exercise.<id>.left.<pair>` / `.right.<pair>`). Toucher un mot puis son correspondant crée la paire (le numéro du mot s’affiche à droite) ; toucher une paire la défait. « Vérifier » s’active quand tout est associé ; le retour colore chaque paire ;
- `dictation` : bouton « Écouter l’audio » (`lesson.exercise.<id>.listen`), puis choix du pinyin ou des caractères ;
- `toneDiscrimination` : même écoute, puis choix du ton (ou de deux tons) avec libellé textuel et contour (¯ ˊ ˇ ˋ) ;
- `translation` : la phrase française en consigne, tuiles chinoises avec pinyin dont certaines sont en trop, même interaction que l’ordre de mots ;
- `dialogueOrder` : répliques (locuteur, caractères, pinyin) touchées dans l’ordre de la conversation, pastille de position, toucher pour retirer (`lesson.exercise.<id>.line.<id>`) ;
- `conversationChoice` : réplique de l’interlocuteur avec son bouton audio (`.prompt.play`), puis trois réponses écoutables une à une avant d’être choisies (`.reply.<id>` et `.reply.<id>.play`).

Après une erreur, afficher la réponse et une explication courte (« 你 est le pronom tu ; le ton 3 descend puis remonte »), puis `Réessayer` ou `Continuer`. Une réponse correcte est confirmée par texte, icône et couleur. Un exercice sans audio local affiche une erreur de chargement avec `Réessayer` et `Continuer sans audio` seulement si le texte suffit réellement à le faire.

### Fiche mot

La fiche affiche, dans cet ordre : caractère chinois large, pinyin accentué et numéro de ton secondaire, sens français, bouton audio avec état (`Disponible hors ligne`, `Téléchargement`, `Indisponible`), phrase d’exemple, bouton « Voir les traits », et « Ajouter aux cartes »/« Déjà dans mes cartes ». Un tap sur un mot chinois dans une phrase ouvre sa fiche sans perdre la position de lecture.

La fiche conserve `wordID`, niveau de maîtrise, date de dernière réponse et prochaine date de rappel. Le bouton d’ajout écrit réellement dans la file de cartes et change d’état immédiatement ; il n’est pas affiché pour un mot déjà présent.

### Oral

Écran centré sur une seule phrase : caractère/pinyin, bouton d’écoute, bouton microphone. À la première utilisation, demander `AVAudioSession` avec une raison française claire. Pendant l’enregistrement : chronomètre, amplitude simple, « Arrêter ». Après : « Réécouter », « Refaire » et l’analyse. `SpeechPracticeView` transmet l’enregistrement temporaire à un `SpeechPronunciationService` injecté ; un rapport terminé peut afficher le verdict, le score et les détails par mot, son et ton. La transcription Apple et sa confiance restent descriptives et ne deviennent jamais une note de prononciation. Tant qu’aucun fournisseur et aucune clé ne sont configurés, une note « Auto-écoute » invite à comparer le modèle et sa voix, et « Continuer » enregistre l’exercice comme `skipped` et passe à la suite en un seul geste, sans réussite ni score. Une permission refusée affiche le chemin Réglages et permet de continuer la leçon avec le même passage sans évaluation.

Le protocole, l’UI et les fixtures sont prêts pour un fournisseur externe, mais
aucun compte, credential ou proxy n’est disponible ou activé dans la
composition actuelle. Un oral passé est affiché séparément dans le bilan via
`skippedCount` ; il ne devient jamais une réussite et ne bloque pas la
complétion fondée sur les exercices requis ni le déblocage de la leçon suivante.

### Écriture

Le caractère est affiché en fantôme léger dans une grille carrée, avec l’ordre de traits en aperçu « Voir le modèle ». Le mode guidé contrôle chaque trait dans l’ordre, sa direction et sa forme ; le point de départ orange et la flèche indiquent le geste attendu. Un trait refusé reste visible en rouge avec une explication et peut être recommencé. `Annuler`, `Effacer` et `Vérifier le tracé` restent sous le canevas, dans le contenu défilant ; le pied fixe est réservé à la validation pédagogique. La vérification libre conserve le tracé `PKDrawing` et permet une auto-évaluation (`À refaire`, `Bien`) quand le guide n’est pas disponible. La progression est enregistrée après `Continuer`.

### Cartes

L’écran d’entrée indique « 6 cartes dues » et propose « Commencer ». Chaque carte a une face caractère, un tap ou bouton « Révéler », puis pinyin/sens/audio/phrase. Les quatre réponses SM-2 sont explicites : `À refaire`, `Difficile`, `Bien`, `Facile`. Le scheduler partagé garde des intervalles déterministes (1 puis 6 jours au démarrage, remise à zéro sous la note 3) ; l’interface affiche l’échéance calculée plutôt qu’une promesse de progression. Les états sans carte montrent le prochain rappel et un lien vers le parcours.

### Histoires

Bibliothèque locale filtrée par niveau et durée. La cible éditoriale MVP couvre trois histoires originales : **« Le premier échange »**, **« Un nom, un sourire »** et **« Deux pays sur une carte »**. Le pack livré en contient quatre et ajoute **« Deux présentations »** (`story-mini-exchange`), l’histoire de l’extension L4. La fiche indique le nombre de mots connus et l’état des médias disponibles hors ligne. En lecture, les paragraphes défilent en cartes et chaque mot chinois reste sélectionnable. Un pied fixe regroupe l’affichage du pinyin et la commande d’écoute ; l’état de lecture ou d’indisponibilité audio est annoncé. Il n’y a pas de commandes précédent/suivant ni de barre de progression dans la vue de lecture actuelle.

### Dictionnaire

Le MVP est un dictionnaire de **tout le vocabulaire embarqué de l’unité 1**, clairement indiqué sous le champ de recherche. Il accepte caractère chinois, pinyin avec ou sans accents et sens français, avec correspondance exacte puis préfixe. La recherche est locale et disponible hors ligne. Un résultat ouvre la fiche mot ; aucun résultat affiche la requête et un lien vers « Parcourir l’unité 1 ». Une extension à une base plus large pourra garder la même route sans promettre une couverture qui n’existe pas.

### Profil

Afficher prénom modifiable, niveau courant, unité atteinte, cartes maîtrisées, minutes apprises sur 7 jours et série. Actions réelles : « Modifier mon objectif », « Revoir les mots difficiles », « Gérer les téléchargements », « Réglages ». Les chiffres viennent des tentatives persistées ; une donnée absente montre `—` plutôt qu’un zéro trompeur.

### Réglages

Sections :

- **Apprentissage** : durée quotidienne, jours de rappel, lecture automatique, affichage du pinyin ;
- **Audio et oral** : volume de prévisualisation, vitesse `0,75×/1×`, permission microphone et suppression des enregistrements ;
- **Apparence** : système/clair/sombre, taille du texte renvoyée à Dynamic Type, réduction des animations ;
- **Hors ligne** : taille de l’unité téléchargée, supprimer les médias téléchargés avec confirmation ;
- **Compte et données** : état iCloud, synchroniser maintenant, exporter les progrès, réinitialiser les progrès avec confirmation destructive ;
- **À propos** : version, crédits des voix et des contenus originaux, politique de confidentialité.

Chaque interrupteur persiste avant de quitter l’écran et annonce son nouvel état. « Réinitialiser » demande une confirmation explicite et décrit la portée exacte.

### Synchronisation

L’état de sync est visible dans Profil et Réglages : `Sur cet appareil` tant qu’iCloud n’est pas configuré, puis `À jour`, `Synchronisation…`, `Hors ligne — 3 éléments en attente`, ou `Impossible de synchroniser — Réessayer`. Le bouton « Synchroniser maintenant » apparaît uniquement quand un `CloudSyncClient` est effectivement disponible, lance la tâche et se désactive pendant celle-ci ; le MVP local n’affiche pas un bouton de réseau fictif.

La source de vérité locale reste disponible sans réseau. Les tentatives et les événements de cartes sont append-only et fusionnés par `id` stable ; après réception, ils sont rejoués dans l’ordre déterministe du `ProgressReducer` et du scheduler partagé. Les réglages qui ne peuvent pas être fusionnés exposent les deux valeurs et « Garder cet appareil »/« Garder iCloud ». Ne jamais remplacer silencieusement une série ou une tentative locale.

## 6. Contrat de contenu et d’architecture SwiftUI

Le design n’ajoute aucune dépendance tierce. Le contrat attendu pour l’architecture est : SwiftUI pour les surfaces, `PolygoCore`/`PolygoPersistence` pour les modèles et le journal local JSONL, `PolygoSRS` pour les rappels, `AVFoundation`/Speech pour les médias et l’oral, `PencilKit` pour les traits, et CloudKit privé derrière le `CloudSyncClient` futur. Les noms de frameworks restent des choix d’implémentation révisables ; l’expérience doit conserver les états décrits ici.

Les modèles de contenu suivent les contrats partagés `CourseManifest`, `ModuleSummary`, `LessonDocument`, `LessonBlock`, `ExerciseSpec`, `VocabularyEntry`, `ReviewCard` et `AssetReference`. La progression utilise `LearnerProfile`, `LessonProgress`, `ProgressSnapshot`, `ProgressEvent` et `ReviewState`. Les identifiants de contenu sont stables et séparés des identifiants de vue. Un `ContentStore` et un `ProgressStore` locaux fournissent les lectures et écritures aux vues ; le moteur de sync écoute les événements sans bloquer l’interface. Les médias de l’unité 1 sont dans le bundle, avec un état de téléchargement pour les éventuelles unités futures.

Correspondance UI/noyau : `listenChoose` rend `ListeningChoiceExercise`, `toneChoose` et `meaningChoose` rendent `ChoiceExercise`, `sentenceOrder` rend `WordOrderExercise`, `fillBlank` rend `FillBlankExercise`, `speakPrompt` rend `SpeakingExercise`, `writeCharacter` rend `HandwritingExercise`, et `reviewRecall` rend `FlashcardExercise`. Le `LessonPlayer` transmet les réponses au `ExerciseEngine` et ne recalcule pas la correction.

Les routes à rendre partageables sont `today`, `unit(unitID)`, `lesson(lessonID)`, `word(wordID)`, `oral(exerciseID)`, `writing(exerciseID)`, `cards`, `story(storyID)`, `dictionary(query)`, `profile` et `settings(section)`. Une notification ou un bouton du dashboard transmet un identifiant plutôt qu’une position d’index.

Découpage recommandé : `DesignSystem` (tokens, composants, assets), `Onboarding`, `LearningPath`, `LessonPlayer`, `WordDetail`, `PracticeOral`, `PracticeWriting`, `ReviewCards`, `Stories`, `Dictionary`, `Profile`, `Settings`, `Sync`. Les composants reçoivent un état et des intentions ; ils ne calculent pas les règles de progression. Cela permet de tester le moteur de leçon sans dépendre de SwiftUI.

## 7. Accessibilité et qualité de sortie

- VoiceOver lit le caractère en chinois (`zh-CN`) puis le pinyin et le sens en français (`fr-FR`) ; les boutons audio annoncent lecture, pause et disponibilité hors ligne.
- Chaque contrôle a un nom d’accessibilité orienté action (« Vérifier la réponse »), jamais uniquement une icône. Les tuiles réordonnables exposent un ordre et des actions clavier alternatives.
- Dynamic Type jusqu’à la taille accessibilité conserve le contenu, avec défilement et retour à la ligne. Les chiffres de progression ont un texte équivalent.
- Réduire les animations supprime les ondulations de ton, confettis et déplacements ; garder un changement de couleur accompagné d’un libellé et d’une icône.
- Le focus clavier reste visible avec les contrôles système, l’ordre suit la lecture, et aucune action n’est uniquement dépendante d’un glissement ou d’un son.
- Audio : transcript ou pinyin disponible, vitesse réglable, retours d’erreur compréhensibles. Oral : le bouton arrêter est distinct de recommencer.
- Tester au minimum en clair/sombre, VoiceOver, Dynamic Type XXXL, réduction des animations, hors ligne, permission microphone refusée et fenêtre Mac étroite.

## 8. Checklist d’acceptation MVP

1. Après l’onboarding, un nouvel apprenant ouvre l’unité 1 et commence la leçon 1 sans compte ni réseau.
2. La cible pédagogique porte sur les trois leçons L1–L3 de l’unité 1, qui contiennent respectivement 6, 7 et 7 exercices (5, 6 et 6 requis) ; le pack livré ajoute la leçon d’extension L4 avec 7 exercices (6 requis). Chaque tentative est sauvegardée après validation.
3. Une erreur affiche une correction ; une leçon terminée apparaît dans le parcours et alimente le dashboard.
4. Un mot peut être ouvert depuis une leçon ou une histoire, lu hors ligne et ajouté aux cartes ; l’état du bouton suit la donnée.
5. Un oral peut être enregistré, relu et soumis à un fournisseur ; sans provider configuré, permission ou analyse exploitable, il peut être passé sans évaluation ni note. Dans ce cas, le bilan affiche `skippedCount` et les exercices requis seuls déterminent la complétion et le déblocage de la leçon suivante.
6. Les cartes dues suivent des intervalles déterministes et disparaissent de la file uniquement après une réponse enregistrée.
7. Le dictionnaire de l’unité 1 fonctionne hors ligne pour caractère, pinyin et français.
8. Les mêmes routes sont accessibles sur iPhone, iPad et Mac ; les cinq boutons bas, les raccourcis et les libellés accessibles ne dépendent pas d’un écran tactile.
9. Les états de sync et hors ligne sont vrais, persistés et compréhensibles ; aucun bouton présenté dans cette spécification ne reste fictif.
10. Une première complétion historique rapporte 10 pièces ; reprise, relance, nouvelle tentative et Recommencer ne créent pas de deuxième gain pour la même leçon.
11. La barre basse et le badge global restent absents pendant toute leçon et toute pratique autonome Oral/Écriture, puis reviennent à la sortie.
