# Accessibilité Syllune

Mise à jour statique du 7 septembre 2026. Les corrections ci-dessous sont
présentes dans le tree, mais le conteneur ne fournit ni Xcode ni SDK Apple :
aucun parcours VoiceOver, Dynamic Type, contraste, clavier Mac, mode sombre ou
réduction des animations n’a été exécuté sur un appareil ou un simulateur.

## Corrections livrées

### Couleurs et apparence

`App/DesignSystem.swift` fournit désormais des tokens clair/sombre via les
couleurs dynamiques UIKit et AppKit. Les valeurs de texte et de contrôle ont
été assombries ou éclaircies pour conserver un contraste utile dans chaque
apparence. Les calculs statiques donnent notamment environ 8,9:1 pour
`inkMuted` sur blanc, 8,8:1 pour `jade` sur blanc, 7,5:1 pour `sky` sur blanc,
7,5:1 pour `success` sur le canvas clair et 3,9:1 pour la bordure sur blanc.
Les boutons utilisent les variantes `jadeButton` et `skyButton`, avec un
premier plan adapté à leur fond sombre ou clair.

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

`SylluneFlowLayout` est une `Layout` SwiftUI portable. Il mesure les tokens et
les place sur plusieurs lignes quand la largeur disponible diminue. L’histoire
l’utilise directement ; le composant est public pour que le lecteur de leçon
remplace ses `HStack` de phrase lors de l’intégration.

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
`@FocusState`. Les raccourcis de sidebar `⌘1` à `⌘5` et `⌘,` restent
disponibles.

## Intégration restant hors de ce périmètre

Les fichiers suivants appartiennent à l’intégration des autres agents et n’ont
pas été modifiés ici :

- `App/LessonView.swift` doit utiliser `SylluneFlowLayout` pour les phrases,
  passer la `vocabulary` et la `segmentation` au composant, puis conserver les
  actions propres aux réponses (sélection, déplacement et audio contextuel).
  Ses tailles système et ses groupes de boutons doivent encore être vérifiés
  à XXXL.
- `App/ReviewViews.swift` doit remplacer ses tailles fixes, empiler les
  évaluations quand la largeur est étroite, appliquer `skyButton`/`jadeButton`
  aux contrôles proéminents et séparer les langues du recto/verso.
- `App/PracticeViews.swift` doit conserver le chemin oral « Passer sans
  évaluer » et raccorder les actions clavier/VoiceOver d’écriture sans
  dépendre du seul geste de dessin.
- `Apple/Audio/SpeechPracticeView.swift` doit empiler ses groupes à XXXL,
  appliquer les langues au caractère et au pinyin, exposer l’état non configuré
  sans faux score et enregistrer les actions d’arrêt/Échap du composant de
  capture. La persistance et l’annulation Speech restent à valider par
  l’intégration Apple.

## Validation Apple à effectuer

1. Parcourir l’onboarding, une leçon, une fiche mot, une carte, une histoire
   et les réglages avec VoiceOver ; vérifier `zh-CN`, `fr-FR`, les états et les
   actions d’ouverture/audio.
2. Tester Dynamic Type jusqu’aux tailles d’accessibilité en portrait sur un
   iPhone étroit, sur iPad et dans une fenêtre Mac réduite.
3. Tester clair/sombre, contraste augmenté, Réduire les animations, focus
   clavier et `⌘1…⌘5`, `⌘K`, ainsi que la saisie avec `Espace` et `Échap`.
4. Tester contenu audio absent, voix mandarin absente, mode hors ligne,
   microphone/transcription refusés et retour depuis chaque sous-route.
