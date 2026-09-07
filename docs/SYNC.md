# Synchronisation locale et différée

Syllune est utilisable sans compte réseau et sans configuration iCloud. La
progression locale est la source de vérité ; le snapshot et l’état de l’outbox
sont des caches reconstruisibles.

## Fichiers locaux

`JSONFileProgressStore(rootURL:reducer:)` crée un dossier par profil :

```text
<rootURL>/
└── profiles/<profile-id>/
    ├── events.jsonl
    ├── snapshot.json
    └── outbox.json
```

Chaque ligne de `events.jsonl` contient un `ProgressEvent` complet. Les
événements sont immuables et identifiés par `eventID`. `snapshot.json` est
réécrit de façon atomique après chaque ajout ; il accélère les inspections et
reste remplaçable par un rejeu intégral. `outbox.json` contient uniquement les
IDs dont le serveur a confirmé l’acceptation. Un accusé perdu provoque donc un
renvoi sans perdre de progression.

L’ajout est sérialisé par un actor. Le journal est réécrit dans un fichier
temporaire puis remplacé atomiquement, afin qu’un arrêt pendant l’écriture
laisse l’ancien ou le nouveau journal complet. Si un ancien journal contient
une dernière ligne JSON non terminée, cette ligne est copiée dans un fichier
`events.jsonl.partial.<uuid>` puis retirée du journal actif. Les lignes
terminées mais invalides lèvent `ProgressStoreError.corruptedJournal` ; elles
ne sont jamais ignorées. Un snapshot ou un outbox illisible est conservé dans
un fichier `*.corrupt.<uuid>` avant reconstruction ou reprise sûre.

## Rejeu déterministe

Au chargement, les lignes valides sont dédupliquées par `eventID`, puis triées
par la clé totale suivante :

```text
(lamport, deviceID.rawValue, eventID.rawValue)
```

Le reducer reçoit cette séquence depuis `ProgressSnapshot.empty()`. L’ordre
d’arrivée réseau n’a donc pas d’effet sur la progression, notamment pour les
révisions SRS. Le même `eventID` avec une charge différente est rejeté par
`ProgressStoreError.duplicateEvent`.

Le profil, ses réglages, les cartes ajoutées, les états de deck, les exercices,
les leçons et les révisions restent dans ce flux d’événements. Les captures
audio et dessin sont référencées par leurs IDs ; leurs octets vivent dans le
stockage média des adaptateurs et ne sont jamais placés dans le journal.

## Contrat réseau

`CloudSyncClient` est une abstraction volontairement petite : `push` renvoie
les IDs acceptés ou déjà présents et `pull(after:)` renvoie une page ainsi qu’un
curseur opaque. `SyncCoordinator` pousse par lots bornés, marque l’outbox après
la réponse du serveur, puis tire et trie les événements avant de les ajouter.

Le curseur n’avance qu’après l’écriture locale de toute la page. Une erreur de
réseau, d’I/O ou de réduction laisse les événements non acquittés et le curseur
précédent ; la relance est idempotente. Un transport qui renvoie une page non
vide sans faire progresser son curseur est arrêté avec
`SyncError.cursorDidNotAdvance` pour éviter une boucle infinie.

CloudKit privé pourra implémenter ce protocole en nommant ses records
`ProgressEvent/<eventID>` et en encodant son change token dans `SyncCursor`.
Cette intégration reste optionnelle : le mode local ne crée pas de faux client
réseau et l’ouverture d’une leçon ne dépend jamais d’une synchronisation.
