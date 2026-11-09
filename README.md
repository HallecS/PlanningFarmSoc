# Planning de farm SoC

Planificateur de farm de fragments pour **Sword of Convallaria** : file de priorité et Gantt des slots,
historique, bannières, events Memories, et tier list des légendaires avec leur fiche (étoiles, trait, skills,
mots-clés).

## Accès
- Page en ligne (GitHub Pages) : https://hallecs.github.io/PlanningFarmSoc/
- Les données sont enregistrées dans le navigateur de chaque appareil : pour passer d'un appareil
  à l'autre (ou depuis l'artefact claude.ai), utiliser **Exporter** puis **Importer**.

## Fichiers de la page
- `planning-farm-soc.html` : la page (source, celle de l'artefact claude.ai).
- `index.html` : la même page avec l'en-tête HTML complet, pour GitHub Pages. Générée par `build-index.ps1`
  (à relancer après chaque modification de `planning-farm-soc.html`).
- `legendaires.js` : personnages, sprites, icônes de rôles et de tags, traits par étoile.
- `skills.js` : skills et leurs icônes (chargé à l'ouverture de l'onglet Skills).
- `keywords.js` : définitions des mots-clés (chargé à l'ouverture d'une fiche).

## Mise à jour des données
Scripts PowerShell dans `tb-export/soshage` (source : [Soshage](https://soshage.com/soc/en/unit)).
La procédure pour ajouter ou mettre à jour un personnage est dans
[`tb-export/soshage/AJOUT-PERSO.md`](tb-export/soshage/AJOUT-PERSO.md).

Les persos pas encore traduits en anglais (sortis en CN) ont une traduction non officielle dans
`tb-export/soshage/tw-translations/`.
