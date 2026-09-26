# Feuille

Éditeur macOS volontairement calme, ciblé sur l'écriture longue.

- Le paragraphe sous le curseur reste net.
- Les autres paragraphes s'effacent progressivement.
- Le titre reste fixé au-dessus du texte, qui défile derrière lui.
- Texte riche natif : gras, italique, souligné et taille de police.
- Police `Courier` (repli automatique sur la police monospace système).
- Ouvre et enregistre des fichiers `.rtf`, plus `.txt` en lecture.

## Ouvrir sur macOS 10.13

1. Copier ce dossier sur le Mac.
2. Ouvrir `Feuille.xcodeproj` avec **Xcode 9.4.1** (ou plus récent).
3. Sélectionner le schéma **Feuille**, puis `Product > Run`.

Le projet cible macOS 10.13 et Swift 4.0. Aucun package externe.

### Raccourcis

- `⌘N` : nouveau
- `⌘O` : ouvrir
- `⌘S` : enregistrer
- `⌘B`, `⌘I`, `⌘U` : gras, italique, souligné
- `⌘−`, `⌘+` : diminuer / augmenter la taille

Le bouton **Concentration** permet de basculer entre le texte estompé et l'affichage uniforme.
