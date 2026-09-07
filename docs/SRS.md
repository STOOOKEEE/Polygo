# PolygoSRS

`PolygoSRS` contient le scheduler SM-2 portable. Il importe uniquement
`Foundation` et `PolygoCore` et ne connaît ni SwiftUI, ni la persistance, ni un
framework Apple.

## Transition SM-2

`SM2Scheduler.nextState(for:from:rating:at:)` est une fonction pure. Le `cardID`
et l’instant de révision sont toujours fournis par l’appelant ; le scheduler ne
lit jamais `Date()`.

Les quatre choix de l’interface utilisent les qualités SM-2 suivantes :

| Libellé | Qualité | Effet |
| --- | ---: | --- |
| À refaire | 0 | échec, répétition remise à zéro, échéance à J+1, `lapseCount + 1` |
| Difficile | 3 | réussite, première répétition à J+1 |
| Correct | 4 | réussite, première répétition à J+1 |
| Facile | 5 | réussite, première répétition à J+1 |

Après la première réussite, la deuxième est fixée à six jours. Les suivantes
utilisent `round(intervalDays × easeFactor)`, avec au moins un jour. Le facteur
d’aisance suit la formule SM-2 :

```text
EF' = EF + (0.1 - (5 - q) × (0.08 + (5 - q) × 0.02))
```

Il est borné inférieurement à `1.3` et sa valeur initiale est `2.5`. Une date
Swift `Date` représente un instant absolu ; l’échéance est calculée avec
`86_400` secondes par jour afin de rester déterministe quelle que soit la
timezone de l’appareil.

`ReviewTransition` associe le nouvel état et une `ReviewHistoryEntry`. Le
snapshot peut conserver le nouvel état compact tandis que le journal garde
chaque réponse, sa date, la note, l’intervalle et l’évolution de l’aisance.

## File et suspension

`ReviewDeck` fournit une collection immuable de `ReviewState`, une histoire
optionnelle par carte et un ensemble d’IDs suspendus. `dueCards(at:)` filtre les
échéances à l’instant injecté, exclut les cartes suspendues et trie par
`(dueAt, cardID.rawValue)`. Le second critère est obligatoire pour obtenir la
même file après reconstruction sur deux appareils. `limit` et
`matching:` permettent au dashboard ou à une session ciblée de limiter la
file.

`suspending(cardID:at:)` conserve les statistiques de la carte et place son
échéance à `Date.distantFuture`; `resuming(cardID:at:)` la rend due à la date
passée par l’appelant. `resetting(cardID:at:)` recrée un état neuf, enlève la
suspension et efface l’historique local de cette carte. Ces opérations sont
des transformations de valeur : le store choisit quand écrire le résultat.

## Extension nécessaire du modèle core

La version actuelle de `PolygoCore.ReviewState` est volontairement compacte et
ne porte pas encore la suspension ni l’historique. Pour que ces informations
soient incluses dans le snapshot partagé, l’agent propriétaire de
`Sources/PolygoCore` doit ajouter, avec des valeurs par défaut de décodage pour
la rétrocompatibilité :

- une énumération d’interface limitée aux qualités `0`, `3`, `4` et `5`
  (`again`, `hard`, `good/correct`, `easy`) ; les anciennes valeurs `1` et `2`
  doivent être migrées vers `again` si elles existent dans un journal ;
- `isSuspended: Bool` (ou une valeur équivalente persistée) ;
- `history`/`reviewHistory` sous forme de `[ReviewHistoryEntry]` core, si le
  journal n’est pas la seule source de vérité ;
- une initialisation qui conserve un `easeFactor` supérieur à `2.5` après une
  réponse `Facile` et qui ne le laisse jamais passer sous `1.3`.

Tant que ces champs restent hors du core, `ReviewDeck` garde la suspension et
l’historique en bordure du modèle et encode le comportement de suspension par
`Date.distantFuture`. Le `ProgressReducer` doit appeler la même transition SM-2
ou partager les mêmes constantes afin d’éviter deux règles divergentes.
