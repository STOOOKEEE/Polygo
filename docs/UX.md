# Syllune — identité et spécification UX

## 1. Décision d’identité

**Nom de travail : Syllune** (prononcé « si-lune » en français). Le nom est une création de travail pour le produit Polygo ; cette décision ne constitue pas une recherche d’antériorité ni une validation de disponibilité de marque. Une vérification juridique et une recherche de domaine restent nécessaires avant publication.

Signature : **« Le mandarin, une syllabe à la fois. »**

Syllune aide à relier trois gestes : entendre une syllabe, la dire, puis la tracer. L’identité ne reprend aucun code visuel, texte, personnage, exercice ou flux de HelloChinese. Elle utilise une idée propre : trois courbes de ton qui entourent un noyau corail, comme un son qui prend forme.

La voix éditoriale est calme, précise et encourageante. Elle tutoie l’apprenant (« Continue avec 5 minutes »), explique les erreurs sans infantiliser (« Le ton 3 descend puis remonte »), et annonce clairement ce qui est mesuré. Les messages de réussite décrivent une action (« 6 mots revus »), jamais une promesse vague.

Le logo vectoriel original est [Syllune-Logo.svg](../Design/Syllune-Logo.svg) ; [Syllune-Logo-Dark.svg](../Design/Syllune-Logo-Dark.svg) sert au lockup sur surface sombre. Le symbole peut vivre seul dans la navigation ; le mot « Syllune » est rendu avec la police système dans l’application afin de suivre le thème et la taille d’accessibilité.

## 2. Système visuel

### Couleurs sémantiques

Les couleurs sont des rôles, pas des valeurs dispersées dans les vues. Chaque couleur a une forme ou un libellé associé : la couleur ne porte jamais seule l’information.

| Token | Clair | Sombre | Usage |
| --- | --- | --- | --- |
| `canvas` | `#F7F8F4` | `#0F1B1A` | Fond global, papier doux |
| `surface` | `#FFFFFF` | `#172624` | Cartes et panneaux |
| `surfaceRaised` | `#F0F3EE` | `#203330` | Champ, tuile secondaire |
| `ink` | `#16232C` | `#F6F4E9` | Texte principal et caractères chinois |
| `inkMuted` | `#51656A` | `#B6C9C2` | Texte secondaire, métadonnées |
| `border` | `#D8E1DA` | `#36504A` | Séparateurs et contours |
| `jade` | `#196B62` | `#58B1A0` | Action principale, progression, marque |
| `jadeDeep` | `#0E514D` | `#7ED1BE` | État pressé, texte sur fond clair |
| `coral` | `#EF7C61` | `#FF9A7D` | Oral, accent actif, point d’attention |
| `sun` | `#EFCB6A` | `#F4D982` | Rappel, série, repère de ton |
| `sky` | `#6E97C7` | `#8FB9E6` | Écoute et audio |
| `success` | `#2F8D6C` | `#67C397` | Réponse correcte, terminé |
| `error` | `#B94F58` | `#F1878D` | Erreur corrigeable, permission refusée |
| `focus` | `#2E78E6` | `#79AEFF` | Anneau de focus clavier |

Sur `canvas`, les textes `ink` et `jadeDeep` servent aux informations longues. `coral` et `sun` servent avec du texte `ink`, jamais avec du texte blanc. Les combinaisons de texte et de fond doivent atteindre au moins 4,5:1 pour le corps et 3:1 pour les grands titres ou les éléments graphiques porteurs d’information. Les états « juste » et « à revoir » ajoutent toujours une icône et un libellé.

### Typographie

- Titres et nombres de progression : **SF Pro Rounded**, Semibold, avec repli SF Pro.
- Texte courant et contrôles : **SF Pro Text**, Regular/Medium/Semibold.
- Chinois simplifié : **PingFang SC**, avec repli système CJK ; ne pas forcer une police latine sur les caractères.
- Pinyin : SF Pro Text ; les tons en diacritique restent dans la même taille que le pinyin. SF Mono est réservé aux exemples techniques éventuels, pas à l’interface courante.

Échelle de départ : `display 32/38`, `title 24/30`, `section 20/26`, `body 17/24`, `callout 15/21`, `caption 13/18`. Toutes les tailles sont liées à Dynamic Type ; aucune carte ne doit dépendre d’une hauteur fixe. Le texte chinois peut passer sur deux lignes sans couper les caractères.

### Formes, rythme et icônes

Espacements : `4, 8, 12, 16, 20, 24, 32, 40`. Rayons : `12` pour les champs, `18` pour les cartes, `24` pour les panneaux d’accueil, `999` pour les pastilles. Bordure standard `1 pt`; ombre très légère uniquement sur une surface qui se détache du fond.

Les contrôles interactifs ont une zone minimale de `44×44 pt` sur iPhone/iPad. Sur Mac, la zone visuelle peut être plus compacte, mais la cible clavier/pointeur reste au moins `32×32 pt` et les éléments de la sidebar ont `40 pt` de hauteur. Utiliser SF Symbols avec un poids régulier ou medium et un contour cohérent ; le seul dessin de marque est le SVG fourni.

## 3. Navigation adaptative

L’onboarding précède la navigation principale. Une fois terminé, l’apprenant retrouve toujours son dernier emplacement et sa dernière leçon interrompue.

### iPhone

`TabView` à cinq destinations, dans cet ordre :

1. **Aujourd’hui** — activité du jour, reprise et révisions (`house` ou `sun.max`).
2. **Parcours** — unités et leçons (`list.bullet.rectangle.portrait`).
3. **Explorer** — histoires et dictionnaire (`book.pages`).
4. **Cartes** — file de rappel (`rectangle.stack`).
5. **Profil** — objectifs, progression et accès aux réglages (`person.crop.circle`).

Le titre de l’écran reste visible au défilement. Les sous-écrans sont des `NavigationStack`. Les réglages sont atteints depuis Profil, avec un bouton explicite « Réglages » ; il n’y a pas de bouton d’engrenage décoratif sans destination.

### iPad et Mac

Utiliser une `NavigationSplitView` persistante avec trois groupes :

| Groupe | Destinations |
| --- | --- |
| Apprendre | Aujourd’hui, Parcours, Cartes |
| Explorer | Histoires, Dictionnaire |
| Compte | Profil, Réglages |

La colonne de détail affiche une leçon ou une fiche mot. Sur iPad en largeur réduite, la sidebar devient une pile standard ; aucun contrôle ne doit disparaître, il est seulement déplacé dans la barre de navigation. Sur Mac, les mêmes routes apparaissent dans la sidebar et les actions de leçon restent accessibles à la souris, au clavier et au menu.

Raccourcis Mac proposés : `⌘1` Aujourd’hui, `⌘2` Parcours, `⌘3` Explorer, `⌘4` Cartes, `⌘5` Profil, `⌘,` Réglages, `⌘K` recherche dictionnaire, `Espace` lire/mettre en pause l’audio, `Échap` arrêter un enregistrement ou fermer une fiche. Le focus visible suit `focus` et la sélection de sidebar est annoncée par VoiceOver.

## 4. Onboarding

Quatre écrans, avec indicateur `1 sur 4` et reprise après fermeture. Chaque étape possède une valeur persistée ; aucune action « Ignorer » ne mène à un écran non préparé.

1. **Bienvenue** : symbole Syllune, promesse, bouton « Commencer ». Lien secondaire « En savoir plus » ouvre une fiche courte sur l’audio hors ligne et la confidentialité.
2. **Point de départ** : champ facultatif « Comment t’appeler ? », puis choix unique « Je commence », « Je connais le pinyin », « Je lis déjà quelques phrases ». Le choix initialise l’unité et le niveau de révision ; il est modifiable dans Profil. Sans prénom, l’accueil utilise simplement « Bonjour ».
3. **Rythme** : durée quotidienne `5`, `10` ou `15 min`, et jours de rappel multiples. Le bouton « Continuer » reste disponible avec une valeur par défaut visible, jamais une validation silencieuse.
4. **Prêt à apprendre** : récapitulatif du choix, bouton « Ouvrir ma première leçon ». La permission microphone n’est demandée qu’au premier exercice oral, jamais à l’installation. Les textes et le pinyin de l’unité 1 sont embarqués ; un audio apparaît comme disponible hors ligne seulement lorsqu’un asset est livré.

État à conserver : `onboardingCompleted`, `displayName` facultatif, niveau de départ, rythme, jours actifs, préférence d’auto-lecture audio et `lastRoute`. Un retour arrière ne perd pas les réponses.

## 5. Écrans et comportements

### Aujourd’hui / dashboard

Le premier écran répond à « que faire maintenant ? » en moins de deux secondes de lecture :

- en-tête `Bonjour, [prénom]` si un prénom a été renseigné, sinon `Bonjour`, et série actuelle avec nombre de jours, si la série existe ;
- carte principale « Reprendre — Unité 1, leçon 2 », état `4/7 exercices`, bouton « Reprendre » ; pour un nouvel apprenant, « Commencer l’unité 1 » ;
- carte « Révisions dues — 6 cartes », bouton « Réviser » ; absente si la file est vide, remplacée par « Rien à revoir pour le moment » ;
- aperçu de l’objectif du jour avec temps effectué/objectif ;
- lien « Mes erreurs récentes » vers une liste filtrée, affiché seulement si une tentative existe.

Une action ouvre directement une route identifiée (`lessonID`, `reviewQueueID`, `mistakeFilter`). Une carte de contenu ne fonctionne jamais comme simple décoration cliquable.

### Parcours

Vue en chemin vertical avec cercles reliés sur iPhone, iPad et Mac ; sur iPad et Mac, la sidebar accompagne le parcours. Une unité affiche son thème, le nombre de leçons terminées et le bouton de reprise. Une leçon verrouillée explique sa condition (« Termine la leçon 3 ») et n’est pas interactive.

La **cible pédagogique MVP** couvre l’unité 1, « Premiers échanges » (HSK 1 / A1), en trois leçons :

| Leçon | Notions et exemples | Exercices (dont requis) |
| --- | --- | ---: |
| 1. Dire bonjour | 你好 nǐ hǎo, 早 zǎo, 再见 zàijiàn, 谢谢 xièxie | 6 (5 requis) |
| 2. Dire son nom | 我 wǒ, 叫 jiào, 什么 shénme, 名字 míngzi ; 你叫什么名字？ | 7 (6 requis) |
| 3. Dire d’où l’on vient | 是 shì, 哪 nǎ, 国 guó, 法国 Fǎguó ; 你是哪国人？ | 7 (6 requis) |

Le pack JSON actuellement livré contient ces trois leçons et une extension déjà disponible : **4. Mener un mini-échange**, avec `呢 ne` et **7 exercices (6 requis)**. Cette quatrième leçon porte la sortie « mini-échange » du pack ; elle reste distincte de la cible éditoriale en trois leçons. Les nombres d’exercices du tableau décrivent chaque leçon et ne sont pas un compteur de leçons ; le « 6 cartes » de l’exemple du dashboard désigne la file de rappel du jour.

Chaque leçon montre les mots utiles avant le premier exercice, puis une barre de progression avec `répondu / total`. Les exercices requis portent la progression : dans les quatre leçons livrées, l’oral est `required: false` et peut être passé sans évaluation. La composition actuelle enregistre alors la complétion lorsque les exercices requis sont acceptés ; le seuil de 80 % reste le critère éditorial de qualité. Le récapitulatif peut afficher « Leçon enregistrée » et `5 / 6 exercices réussis` avec `skippedCount: 1` : le saut reste exclu des réussites, mais la leçon suivante est déverrouillée. Les exercices ratés restent rejouables depuis l’écran de résultat.

### Leçon

Structure : titre et progression en haut, un seul exercice à la fois, explication après réponse, action principale en bas. L’action principale est nommée selon l’état : « Vérifier », « Continuer », « Réécouter » ou « Terminer » ; elle ne garde jamais le même libellé quand son effet change.

Contrat commun d’un exercice : `id` stable, `kind`, consigne française, contenu chinois/pinyin, réponses ou chemin attendu, explication, médias optionnels, `required`, tentative et état de correction. Les types utilisés dans l’unité 1 sont :

- `listenChoose` : écouter un mot puis choisir parmi trois réponses ; audio rejouable et transcript accessible ;
- `toneChoose` : sélectionner le contour/numéro du ton, avec un libellé textuel pour l’accessibilité ;
- `meaningChoose` : associer caractère/pinyin et sens français ;
- `sentenceOrder` : remettre des tuiles dans l’ordre, avec déplacement clavier ;
- `fillBlank` : choisir le mot manquant dans une phrase courte ;
- `speakPrompt` : écouter, enregistrer, réécouter puis demander l’analyse du
  fournisseur ; si aucun fournisseur n’est configuré, passer sans évaluer ;
- `writeCharacter` : tracer un caractère avec ordre de traits fourni ;
- `reviewRecall` : révéler le verso, puis choisir `À refaire`, `Difficile`, `Bien` ou `Facile`.

Après une erreur, afficher la réponse et une explication courte (« 你 est le pronom tu ; le ton 3 descend puis remonte »), puis `Réessayer` ou `Continuer`. Une réponse correcte est confirmée par texte, icône et couleur. Un exercice sans audio local affiche une erreur de chargement avec `Réessayer` et `Continuer sans audio` seulement si le texte suffit réellement à le faire.

### Fiche mot

La fiche affiche, dans cet ordre : caractère chinois large, pinyin accentué et numéro de ton secondaire, sens français, bouton audio avec état (`Disponible hors ligne`, `Téléchargement`, `Indisponible`), phrase d’exemple, bouton « Voir les traits », et « Ajouter aux cartes »/« Déjà dans mes cartes ». Un tap sur un mot chinois dans une phrase ouvre sa fiche sans perdre la position de lecture.

La fiche conserve `wordID`, niveau de maîtrise, date de dernière réponse et prochaine date de rappel. Le bouton d’ajout écrit réellement dans la file de cartes et change d’état immédiatement ; il n’est pas affiché pour un mot déjà présent.

### Oral

Écran centré sur une seule phrase : caractère/pinyin, bouton d’écoute, bouton microphone. À la première utilisation, demander `AVAudioSession` avec une raison française claire. Pendant l’enregistrement : chronomètre, amplitude simple, « Arrêter ». Après : « Réécouter », « Refaire » et l’analyse. `SpeechPracticeView` transmet l’enregistrement temporaire à un `SpeechPronunciationService` injecté ; un rapport terminé peut afficher le verdict, le score et les détails par mot, son et ton. La transcription Apple et sa confiance restent descriptives et ne deviennent jamais une note de prononciation. Tant qu’aucun fournisseur et aucune clé ne sont configurés, l’état indique que l’analyse n’est pas configurée et « Passer sans évaluer » permet de poursuivre sans réussite ni score. Une permission refusée affiche le chemin Réglages et permet de continuer la leçon avec le même passage sans évaluation.

Le protocole, l’UI et les fixtures sont prêts pour un fournisseur externe, mais
aucun compte, credential ou proxy n’est disponible ou activé dans la
composition actuelle. Un oral passé est affiché séparément dans le bilan via
`skippedCount` ; il ne devient jamais une réussite et ne bloque pas la
complétion fondée sur les exercices requis ni le déblocage de la leçon suivante.

### Écriture

Le caractère est affiché en fantôme léger dans une grille carrée, avec l’ordre de traits en aperçu « Voir le modèle ». Le mode guidé contrôle chaque trait dans l’ordre, sa direction et sa forme ; le point de départ orange et la flèche indiquent le geste attendu. Un trait refusé reste visible en rouge avec une explication et peut être recommencé. `Annuler`, `Effacer` et `Vérifier le tracé` restent accessibles dans le pied de l’écran ; la vérification libre conserve le tracé `PKDrawing` et permet une auto-évaluation (`À refaire`, `Bien`) quand le guide n’est pas disponible. La progression est enregistrée après `Continuer`.

### Cartes

L’écran d’entrée indique « 6 cartes dues » et propose « Commencer ». Chaque carte a une face caractère, un tap ou bouton « Révéler », puis pinyin/sens/audio/phrase. Les quatre réponses SM-2 sont explicites : `À refaire`, `Difficile`, `Bien`, `Facile`. Le scheduler partagé garde des intervalles déterministes (1 puis 6 jours au démarrage, remise à zéro sous la note 3) ; l’interface affiche l’échéance calculée plutôt qu’une promesse de progression. Les états sans carte montrent le prochain rappel et un lien vers le parcours.

### Histoires

Bibliothèque locale filtrée par niveau et durée. La cible éditoriale MVP couvre trois histoires originales : **« Le premier échange »**, **« Un nom, un sourire »** et **« Deux pays sur une carte »**. Le pack livré en contient quatre et ajoute **« Deux présentations »** (`story-mini-exchange`), l’histoire de l’extension L4. La fiche indique le nombre de mots connus et l’état des médias disponibles hors ligne. En lecture : phrase courante, audio phrase lorsqu’un asset est livré, précédent/suivant, barre de progression et bouton d’affichage du pinyin. Chaque mot sélectionnable ouvre sa fiche. Quand aucune histoire ne correspond au filtre, afficher « Effacer le filtre » ; ne pas afficher des vignettes vides.

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
- Le focus clavier est visible avec `focus`, l’ordre suit la lecture, et aucune action n’est uniquement dépendante d’un glissement ou d’un son.
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
8. Les mêmes routes sont accessibles sur iPhone, iPad et Mac ; la sidebar, les raccourcis et VoiceOver ne dépendent pas d’un écran tactile.
9. Les états de sync et hors ligne sont vrais, persistés et compréhensibles ; aucun bouton présenté dans cette spécification ne reste fictif.
