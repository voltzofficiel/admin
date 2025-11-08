# RageUI Admin Menu

Ce dépôt contient un exemple complet de menu administrateur basé sur [RageUI-Libs](https://github.com/s95268/RageUI-Libs) pour FiveM. Il fournit une structure prête à l'emploi avec la plupart des outils courants (gestion de joueurs, modération, utilitaires, fun et options techniques) et de nombreux hooks côté serveur pour intégrer vos propres systèmes (inventaires, sanctions, logs, etc.).

## Installation

1. Téléchargez et installez la librairie [RageUI-Libs](https://github.com/s95268/RageUI-Libs) dans votre dossier `resources`.
2. Placez ce dossier `admin` dans votre dossier `resources`.
3. Ajoutez la ressource à votre `server.cfg` :

   ```cfg
   ensure admin
   ```

4. Redémarrez votre serveur. Par défaut, la touche `F10` (ou la commande `/adminmenu`) ouvre l'interface.

## Fonctionnalités principales

### ⚙️ Gestion des joueurs

- Liste des joueurs connectés avec informations basiques (ID, ping, position).
- Recherche rapide par nom/ID, rafraîchissement périodique.
- Spectate, téléportation vers/depuis un joueur, TP vers waypoint.
- Message privé, freeze/unfreeze, kill/revive, heal/armure.
- Ouverture de menu skin/clothing (support ESX et QB-Core si disponibles).
- Gestion économique (dons/retraits d'argent, changement de job, give item) avec intégration automatique ESX ou QB-Core.
- Accès inventaire / inspection (hooks à compléter selon votre ressource).

### 🛡️ Modération

- Kick, ban (placeholder), warn et historique (à compléter).
- Mute vocal/chat (hook), message global, création de safe zone, mode staff.

### ✨ Utilitaires admin

- NoClip, spawn/suppression/fix véhicule, mode undercover, sauvegarde/chargement position.
- Gestion météo/heure, demande de screenshot (via `screenshot-basic` si présent), gestion de ressources.

### 😎 Fun & gestion RP

- Animations globales, téléportations d'évènement, spawn véhicules pour tous.
- Explosions contrôlées, invisibilité/god mode, distribution d'items, drop visuel d'objets.

### 🧰 Options techniques

- Liste des ressources actives, affichage coordonnées, rafraîchissement DB (hook), test de triggers.
- Rappels des raccourcis et accès aux logs internes du menu.

## Intégrations optionnelles

Le script détecte automatiquement la présence de certains frameworks :

- **ESX** (`es_extended`) pour la gestion de l'argent, des jobs et inventaires.
- **QB-Core** (`qb-core`) pour les mêmes actions.
- **esx_skin / qb-clothing** pour l'ouverture du menu skin.
- **screenshot-basic** pour capturer des screenshots distants.

Pour les actions marquées comme « à implémenter », complétez simplement les événements côté serveur ou remplacez les placeholders par vos propres appels.

## Personnalisation

Les options de configuration de base se trouvent dans `config.lua` :

- `OpenKey` : touche clavier (FiveM keybind).
- `CommandName` : commande textuelle.
- `RequireAcePermission` / `AcePermission` : sécurisez l'accès via ACE.
- `DefaultPermissions` : activer/désactiver les catégories par défaut.
- `LogLimit` : nombre maximum de logs affichés dans le menu.

## Remarques

- Certaines fonctionnalités (inventaires, logs de sanctions, freecam) nécessitent des ressources additionnelles et/ou une intégration propre à votre serveur.
- Utilisez ce projet comme base : adaptez les events et ajoutez vos vérifications de permissions.

Bon développement !
