# Ajouter (ou mettre à jour) un personnage légendaire

Source principale : Soshage, version globale — `https://soshage.com/soc/en/unit/<n°>`.
Scripts dans ce dossier (`tb-export/soshage`), lancés avec `-Dir <ce dossier>`.

## 1. Identifier le perso
- [ ] Numéro Soshage `<n°>` (dans l'URL) et son `face` (nom de l'image `character_<face>.webp`).
- [ ] Le perso est-il déjà dans `legendaires.js` (ex. sorti d'abord en CN) ? Si oui, **garder le même `id`** :
      le classement, les étoiles, les choix de skills et la file en dépendent.

## 2. Fiche du perso (`legendaires.js`, liste `chars`)
- [ ] Entrée `{"id":"s<n°>","name","class","type","tags","icon","face","source":"soshage <n°>"}` :
      `class` = profession, `type` = rôle (Breaker, Watcher…), `tags` = factions/traits de la page.
- [ ] Retirer `"server":"CN"` quand il sort en global (sinon marque « pas encore annoncé »).
- [ ] Le nom doit correspondre à celui des bannières et de la file (« SP » et accents ignorés ;
      alias à ajouter dans la page si le nom diffère, comme Lucamar → Lukamar).
- [ ] Sprite : `img.soshage.com/soc/gl/character/character_<face>.webp` dans `sprite[<icon>]`
      (remplace la version `tw` d'un perso CN).
- [ ] Ajouter `<n°>:<face>` dans `units.txt` s'il n'y est pas.
- [ ] Rôle : un des 5 existants (Breaker, Defender, Destroyer, Seeker, Watcher) ; logos complets dans `roles/role_<rôle>.png`
      (fond `smallflag_bg_<n°>` + symbole `smallflag_<rôle>` de Soshage ; Seeker = « assaulter », Destroyer = « destoryer »).

## 3. Données de jeu
- [ ] Supprimer la page en cache `pages/<n°>.html` (sinon l'ancienne version est réutilisée).
- [ ] `traits.ps1` → trait par étoile + icône de trait (`icons/<id>.webp`).
- [ ] `skills.ps1` → skills (base, défaut, rangs avec choix ou version améliorée), icônes de skills,
      **et** mots-clés (définitions + icônes de buffs ; complétés par la liste `/api/proxy/en/skillkeyword`,
      puis par la liste des buffs `/api/proxy/en/buff` pour les termes restants).
      Après une mise à jour du jeu, supprimer `pages/skillkeyword.json` et `pages/buff-all.json` pour les re-télécharger.

## 4. Contrôles
- [ ] Langue : texte en chinois ou en portugais (Soshage n'a pas toujours la traduction) →
      texte officiel sur GameWith (`make-skills-fix.ps1`) ou corrections à la main :
      `traits-fix.json` (traits), `skills-fix.manual.json` (skills, marqués « traduction non officielle »).
- [ ] Skills sans description (`$22`, vide) : les scripts les récupèrent quand la page les a ailleurs ;
      sinon, absent aussi sur Soshage (ex. Perlevit : Ice Cone, Light of Purification).
- [ ] Renvois `{buff/desc/<n°>}` / `{buff/name/<n°>}` dans un texte : résolus par `skills.ps1` via l'API
      Soshage (`/api/proxy/en/buff/<n°>`) ; vérifier qu'il n'en reste aucun.
- [ ] Mots-clés sans définition : normal pour les noms (persos, factions) et les termes génériques.
- [ ] Trait : niveaux cohérents (le 2★ ne répète pas le trait de base, etc.).

## 4 bis. Perso pas encore traduit (sorti seulement en CN)
La page EN peut être vide ou montrer d'anciennes données (ex. Caris SP : skills de Caris, pas de trait).
- [ ] Télécharger la page zh-tw dans `pages/tw-<n°>.html`, puis `tw-dump.ps1 -Unit <n°>` → `work/tw-<n°>.json`
      (skills, trait, mots-clés en chinois ; `known` = skill déjà traduit chez un autre perso).
- [ ] Noms officiels des mots-clés : même id dans `/api/proxy/en/skillkeyword` ; classe : même id de profession sur la page EN.
- [ ] Écrire `tw-translations/<n°>.json` (`charId`, `trait`, `skills` non traduits, `keywords` propres au perso).
      `traits.ps1` et `skills.ps1` l'utilisent automatiquement (page zh-tw, images zh-tw si absentes en global) ;
      tout est marqué « traduction non officielle » dans la fiche.
- [ ] Quand le perso sort en global : supprimer `tw-translations/<n°>.json` et reprendre la procédure normale.

## 5. Reconstruire les fichiers publiés
- [ ] `build-legendaires.ps1` → traits + icônes de trait dans `legendaires.js` (contrôle avant remplacement).
- [ ] `build-skills.ps1` → `skills.js` (chargé à l'ouverture de l'onglet Skills).
- [ ] `build-keywords.ps1` → `keywords.js` (chargé à l'ouverture d'une fiche).

## 6. Tester puis publier
- [ ] Test local : fiche (sprite, nom, classe, tags), trait, skills (choix + Castalia), bulles des mots-clés.
- [ ] Publier la page avec `legendaires.js`, `skills.js`, `keywords.js`.

## 7. À faire de ton côté (données de ton planning)
- [ ] Bannière du perso dans l'onglet **Bannières** (date) : elle donne la marque ●/✕ et la date de départ du farm.
- [ ] Classer le perso dans la tier list (il arrive dans « Non classés »), régler ses étoiles, « Planifier ».
