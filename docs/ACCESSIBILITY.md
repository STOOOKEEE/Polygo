# Accessibilité Syllune

Ce document décrit les mécanismes de la refonte Tavi. Les parcours natifs
réellement exécutés, leurs appareils et leurs limites figurent dans
[QA_REPORT.md](QA_REPORT.md). Une assertion XCUITest sur un libellé accessible
ne remplace pas un audit VoiceOver manuel.

## Corrections livrées

### Couleurs et apparence

`App/DesignSystem.swift` fournit les tokens crème/indigo et leurs accents
clair/sombre via les couleurs dynamiques UIKit et AppKit. Calcul WCAG sur les
valeurs sRGB nominales, hors profil colorimétrique et composition des vues :

| Paire | Clair | Sombre |
| --- | ---: | ---: |
| `ink` / `canvas` | 14,13:1 | 17,04:1 |
| `inkMuted` / `canvas` | 5,14:1 | 10,72:1 |
| `jadeDeep` / `canvas` | 5,69:1 | 12,12:1 |
| Premier plan / nœud jade | 5,71:1 | 10,08:1 |
| Premier plan / nœud corail | 4,78:1 | 6,98:1 |
| Premier plan / nœud bleu | 6,57:1 | 8,85:1 |
| Premier plan / nœud iris | 8,04:1 | 8,45:1 |

Les nœuds verrouillés conservent ces couleurs et ajoutent un cadenas, un
libellé de condition et l’absence d’action. La couleur seule n’exprime donc
ni le verrouillage ni la réussite. Ces calculs ne certifient pas tous les
états pressés, transparences ou contrôles système de l’application.

`RootView` applique le choix d’apparence à toute la scène avec
`.preferredColorScheme`, sur iOS comme sur macOS. `SettingsView` conserve le
choix dans les préférences du profil et dans `@AppStorage` afin qu’il soit
visible immédiatement après un changement de route ou un redémarrage. Le
mode Système reste le comportement par défaut.

### Réduction des animations

`RootView` combine `accessibilityReduceMotion` avec la préférence utilisateur
persistée. La transaction de la racine désactive les animations descendantes,
et `SyllunePrimaryButtonStyle` supprime aussi sa mise à l’échelle et son
animation de pression. `SettingsView` indique quand le réglage système impose
déjà la réduction et synchronise le choix utilisateur avec le profil.

### Texte adaptable et petites fenêtres

Les statistiques du profil, l’en-tête d’accueil, les badges du parcours, les
actions de l’histoire et les boutons d’audio de la fiche mot utilisent
`ViewThatFits` ou une grille adaptative. Les textes importants peuvent donc
passer en colonne et conservent leur hauteur à grande taille de police. Les
jours de rappel utilisent des cibles d’au moins 44 points et une grille
adaptative.

`SylluneFlowLayout` mesure les tokens et les place sur plusieurs lignes quand
la largeur diminue. La barre de navigation basse utilise cinq boutons
indépendants avec leur état sélectionné ; elle devient défilante si ses
libellés ne tiennent plus. Les poses de Tavi et les illustrations de pièces
sont décoratives et masquées à l’accessibilité ; le solde reste annoncé
textuellement, ou comme indisponible lorsque l’historique est inconnu.

### Langues VoiceOver et interaction par mot

`ChineseSelectableText` conserve son initialiseur historique
`ChineseSelectableText("…", font:speechEnabled:)` et expose aussi :

```swift
ChineseSelectableText(
    hanzi: phrase,
    font: .title3,
    speechEnabled: true,
    vocabulary: lesson.vocabulary,
    segmentation: paragraph.segmentation,
    pinyin: pinyin,
    translation: translation,
    audio: paragraph.audio
)
```

Quand aucune segmentation de contenu n’est fournie, le composant cherche les
entrées chargées dans le dictionnaire par correspondance gloutonne du mot le
plus long. Il compare les formes simplifiées et traditionnelles, conserve la
ponctuation, et rend chaque mot connu comme une cible indépendante. Un tap ou
une activation VoiceOver ouvre `WordDetailView` et lance l’audio de la fiche ;
un asset local est préféré et la synthèse vocale mandarin sert de repli. Une
indisponibilité est affichée dans la fiche au lieu d’annoncer un son fictif.

Les caractères sont marqués `zh-CN`. Le pinyin, les tons, les traductions et
les statuts sont des éléments séparés en `fr-FR`. Les actions audio annoncent
leur état Lecture/Arrêt et affichent les erreurs locales. Les jours affichent
une abréviation compacte mais annoncent leur nom complet (`Lundi`, `Mardi`,
etc.), leur état sélectionné et le trait VoiceOver correspondant. Les choix de
niveau et les statistiques exposent également leur état ou leur valeur.

### Clavier Mac

`App/PolygoApp.swift` ajoute les commandes documentées : `⌘K` ouvre le
dictionnaire et demande le focus de recherche. Les commandes audio et de
fermeture restent disponibles dans le menu Syllune, sans raccourci nu qui
réserve `Espace` ou `Échap` pendant la saisie. `DictionaryView` possède un
`@FocusState`. Les raccourcis des cinq destinations basses `⌘1` à `⌘5`
et `⌘,` sont attachés à la scène focalisée, sans dépendre de l’affichage
de la barre pendant un exercice.

## Audit manuel restant

1. Parcourir l’onboarding, une leçon, une fiche mot, une carte, une histoire
   et les réglages avec VoiceOver ; vérifier `zh-CN`, `fr-FR`, les états et les
   actions d’ouverture/audio.
2. Compléter la couverture Dynamic Type sur un iPhone étroit et dans une
   fenêtre Mac réduite ; la couverture iPad automatisée est documentée dans
   le rapport QA, pas extrapolée à tous les appareils.
3. Vérifier contraste augmenté, focus visible et Réduire les animations avec
   les réglages système, en complément des interactions automatisées.
4. Tester sur matériel réel la voix mandarin absente, l’écoute hors ligne,
   les permissions microphone/transcription accordées et refusées, ainsi
   que l’audio effectivement entendu. Aucun score oral simulé ne constitue
   une validation matérielle.
