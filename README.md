# Planning de farm SoC

Planificateur de farm de fragments pour **Sword of Convallaria** : file de priorité et Gantt des slots,
historique, bannières, events Memories, et tier list des légendaires avec leur fiche (étoiles, trait, skills,
mots-clés).

## Fichiers de la page
- `planning-farm-soc.html` : la page.
- `legendaires.js` : personnages, sprites, icônes de rôles et de tags, traits par étoile.
- `skills.js` : skills et leurs icônes (chargé à l'ouverture de l'onglet Skills).
- `keywords.js` : définitions des mots-clés (chargé à l'ouverture d'une fiche).

## Mise à jour des données
Scripts PowerShell dans `tb-export/soshage` (source : [Soshage](https://soshage.com/soc/en/unit)).
La procédure pour ajouter ou mettre à jour un personnage est dans
[`tb-export/soshage/AJOUT-PERSO.md`](tb-export/soshage/AJOUT-PERSO.md).

Les persos pas encore traduits en anglais (sortis en CN) ont une traduction non officielle dans
`tb-export/soshage/tw-translations/`.
