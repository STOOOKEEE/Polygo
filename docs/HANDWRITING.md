# Module d’écriture manuscrite

## Intégration publique

Le point d’entrée est `HandwritingPracticeView`. Il fonctionne avec les
exercices `HandwritingExercise` existants et ne demande aucune dépendance à
PencilKit :

```swift
import PolygoApple
import PolygoCore

HandwritingPracticeView(exercise: exercise, answer: $answer)
```

La vue peut recevoir le service configuré par l’application et un guide déjà
résolu par `ContentStore` :

```swift
HandwritingPracticeView(
    exercise: exercise,
    answer: $answer,
    service: dependencies.handwriting,
    guide: decodedGuide
)
```

`service` et `guide` sont optionnels. L’appel à deux arguments utilise
`LocalHandwritingService.shared` et le catalogue embarqué. Le catalogue ne
retourne un guide que si `guideAsset.kind` vaut `handwritingGuide`, si son hash
n’est plus `pending-writing-guide`, si l’ID correspond au caractère et si le
guide appartient au petit corpus livré. Un contenu encore en attente affiche
le caractère comme repère et propose une auto-évaluation explicite.

## Fonctionnement

Le canevas est un `SwiftUI.Canvas` avec un `DragGesture(minimumDistance: 0)`.
Le même chemin de code reçoit le doigt ou l’Apple Pencil sur iOS/iPadOS et la
souris ou le trackpad sur macOS 14. Les points sont normalisés dans le carré
unitaire, puis encodés dans `DrawingCapture` au format `polygoStrokes`.

Le mode `Guidé` révèle les traits dans l’ordre et place un marqueur sur le
geste courant. `Rejouer l’ordre` relance cette animation. `Indice` révèle
progressivement les premiers traits, y compris en mode `Libre`, où le guide
reste masqué pendant le dessin. `Annuler` supprime le dernier trait et
`Effacer` supprime tout le dessin. Ces actions effacent aussi la capture
persistée quand il y en a une.

Après un dessin réel, `Vérifier le tracé` exécute
`HandwritingGeometryValidator`. Pour les trois guides disponibles, il compare
le nombre de traits, la direction de chaque trait et une forme rééchantillonnée
après ajustement de l’échelle et de la translation. Le résultat est qualifié
de `approximateMatch`, `needsPractice` ou `wrongStrokeCount` et expose des
indicateurs grossiers « proche », « partielle » ou « à revoir ». Il ne fait pas
d’OCR, ne produit jamais de `recognizedText` et ne prétend pas noter une
calligraphie générale. Sans guide, seule l’auto-évaluation est proposée.

La vue ne renseigne `answer` qu’après au moins un geste capturé. La réponse est
un `ExerciseAnswer.handwriting` avec le nombre de traits et, si le service le
permet, le `DrawingID`; `recognizedText` reste toujours `nil`. Le choix
« Enregistrer ce tracé », « À refaire », « Enregistrer comme à refaire » ou
« Je suis à l’aise » est explicite. Une persistance indisponible ne fabrique
pas d’ID : la réponse peut garder `drawingID: nil` et l’interface le signale.

## Persistance et confidentialité

`LocalHandwritingService` implémente le `HandwritingService` déjà déclaré dans
`HandwritingContracts.swift`. Sa politique par défaut est `.memory`, afin de ne
pas conserver silencieusement des dessins après la durée de vie du service.
L’application qui veut restaurer un dessin peut injecter
`LocalHandwritingService(storage: .directory(url))`; un fichier JSON atomique
par `DrawingID` est alors créé. `delete(drawingID:)` retire le fichier ou la
valeur mémoire. `recognize` renvoie toujours `.unsupported` : la validation
locale reste géométrique et ciblée par guide.

## Guides livrés et raccord contenu

Le contenu actuel utilise réellement `你`, `我` et `国`. Les fichiers décrivent
des chemins de traits dans le même format Codable que `HandwritingGuide` (le
champ `notice`, ignoré par le décodeur, porte la mention de provenance) :

| ID | Caractère | Traits | Chemin à mettre dans `AssetReference.relativePath` | SHA-256 |
| --- | ---: | ---: | --- | --- |
| `guide-hanzi-ni` | 你 | 7 | `assets/handwriting/guide-hanzi-ni.json` | `a4f80a7c3afae3f7bf666686bf8df6b42856ae4d9d6b7ce3a81487071cc1eeeb` |
| `guide-hanzi-wo` | 我 | 7 | `assets/handwriting/guide-hanzi-wo.json` | `f5ef08d920b4dc9d394fd8c9a4fbbbbf2309d0092c1ee0976b711055114d9a64` |
| `guide-hanzi-guo` | 国 | 8 | `assets/handwriting/guide-hanzi-guo.json` | `b1273af6e93c964c2ef1ba0a4735e4d0a32552c2957f43b300e43f59ddbb196e` |

Le chemin est relatif à la racine `Content/`. Pour activer les guides dans
les trois leçons, remplacer seulement les chemins et les valeurs
`pending-writing-guide` des références portant ces IDs par les valeurs du
tableau. Les compteurs `expectedStrokeCount` des leçons sont déjà 7, 7 et 8.
Le loader de contenu vérifiera alors le fichier et son SHA-256 avant qu’une
intégration puisse décoder le guide.

### Provenance et licence

Les chemins sont les médianes de traits de
[Make Me a Hanzi](https://github.com/skishore/makemeahanzi) (`graphics.txt`,
commit `bddc96d`, dérivé des polices Arphic PL KaitiM GB et Arphic PL UKai),
distribuées sous l’Arphic Public License. Le texte de la licence est livré sans
modification dans `Content/assets/handwriting/ARPHICPL.TXT`, et chaque fichier
modifié (les trois JSON et le catalogue `HandwritingGuides.swift`) indique
comment et quand il a été transformé, comme l’exige la licence.

`python3 Tools/build_handwriting_guides.py` régénère les trois JSON et le
catalogue embarqué : il télécharge `graphics.txt` au commit épinglé (ou lit
`--graphics <fichier>`), vérifie son SHA-256, projette les coordonnées
(boîte de 1024, y vers le haut, ligne de base 900) dans le carré unitaire avec
une marge fixe de 0,1, conserve l’ordre et le sens des traits, simplifie les
points par Ramer-Douglas-Peucker (crochets et angles conservés) et applique
les noms de traits (横, 竖, 撇, 点, 提, 横钩, 竖钩, 斜钩, 横折) déclarés dans
l’outil. Il affiche les nouveaux SHA-256 à reporter dans les leçons 1 à 3 et
dans les tableaux de cette page et de `CONTENT_SCHEMA.md`.

## Vérification et limites

Les trois fichiers JSON ont été validés par `content_tool.py lint` et leurs
hashes sont ceux du tableau. Une simulation Python du validateur confirme que
les gestes rectilignes des tests UI (premier → dernier point de chaque trait)
passent la porte guidée pour 你 et 我. La compilation SwiftUI et les tests de gestes
doivent être exécutés sur la CI Apple, puisque l’environnement Linux ne
fournit ni SwiftUI ni les SDK iOS/macOS. Le corpus volontairement réduit
retourne « guide indisponible » pour tout autre caractère ; il n’y a pas de
fallback OCR général.
