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

Le contenu actuel utilise réellement `你`, `我` et `国`. Les fichiers sont
originaux et décrivent des chemins de traits dans le même format Codable que
`HandwritingGuide` :

| ID | Caractère | Traits | Chemin à mettre dans `AssetReference.relativePath` | SHA-256 |
| --- | ---: | ---: | --- | --- |
| `guide-hanzi-ni` | 你 | 7 | `assets/handwriting/guide-hanzi-ni.json` | `98b4465294f36f88570a3e89ca10dd1924f773b6448a32f910cc838f46aa42a9` |
| `guide-hanzi-wo` | 我 | 7 | `assets/handwriting/guide-hanzi-wo.json` | `3c8c827dae6b75a1cf21ae6f2d0131034a0e0b8a532a68087b162f6600aed4d7` |
| `guide-hanzi-guo` | 国 | 8 | `assets/handwriting/guide-hanzi-guo.json` | `09615063ef8928bf0c07de2c31965be525f4487b7bcc97c3483a57093f34a782` |

Le chemin est relatif à la racine `Content/`. Pour activer les guides dans
les trois leçons, remplacer seulement les chemins et les valeurs
`pending-writing-guide` des références portant ces IDs par les valeurs du
tableau. Les compteurs `expectedStrokeCount` des leçons sont déjà 7, 7 et 8.
Le loader de contenu vérifiera alors le fichier et son SHA-256 avant qu’une
intégration puisse décoder le guide.

## Vérification et limites

Les trois fichiers JSON ont été validés avec le parseur JSON local et leurs
hashes sont ceux du tableau. La compilation SwiftUI et les tests de gestes
doivent être exécutés sur la CI Apple, puisque l’environnement Linux ne
fournit ni SwiftUI ni les SDK iOS/macOS. Le corpus volontairement réduit
retourne « guide indisponible » pour tout autre caractère ; il n’y a pas de
fallback OCR général.
