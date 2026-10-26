# Éveil

**Empêche ton Mac de se mettre en veille**, en un clic depuis la barre des menus.

Pendant une présentation, un long téléchargement, un rendu vidéo, une sauvegarde, un film… Éveil garde le Mac (et l'écran) allumés le temps qu'il faut, puis rend la main à la veille normale.

- **Durées prêtes** : indéfiniment, 15 min, 30 min, 1 h, 2 h, 4 h, 8 h (raccourcis `1` à `7` dans le menu).
- **Temps restant affiché** à côté de la tasse dans la barre des menus.
- **Laisser l'écran s'éteindre** : le Mac continue de travailler, mais l'écran peut s'éteindre pour économiser de l'énergie.
- **Protection de la batterie** : sur batterie, Éveil se désactive tout seul sous 20 % pour ne pas te laisser à plat.
- Option « Ouvrir au démarrage ».
- Utilise le mécanisme officiel de macOS (les « assertions » d'alimentation, visibles avec `pmset -g assertions`) : rien ne tourne en boucle, aucun impact sur l'autonomie.

## Installer

Il faut les outils de développement d'Apple (`xcode-select --install` si ce n'est pas déjà fait).

```bash
./build.sh --install
```

Une tasse ☕ apparaît dans la barre des menus : pleine quand le Mac est gardé éveillé, vide sinon.

## Désinstaller

Quitte Éveil depuis son menu, puis supprime `/Applications/Eveil.app`.

## Licence

MIT
