# Contribuer à Mac Remote Control

Merci de votre intérêt ! Ce guide explique comment compiler l'app, comment elle est organisée et
comment proposer une modification.

## Signaler un bug ou proposer une idée

[Ouvrez une issue](../../issues) en précisant :

- la version de macOS et le modèle de Mac (Apple Silicon ou Intel) ;
- le téléphone et le navigateur (iPhone + Safari, Android + Chrome…) ;
- l'app concernée sur le Mac (navigateur, lecteur vidéo…) ;
- ce que vous avez fait, ce que vous attendiez et ce qui s'est passé.

Bonnes premières contributions : ajouter les raccourcis d'un lecteur vidéo dans
`mac/Sources/MacRemote/Model/AppProfile.swift`, ou traduire l'interface en anglais.

## Prérequis

- macOS 14 Sonoma ou plus récent
- Xcode 16 ou plus récent (Swift 6)
- Node.js 20 ou plus récent, avec npm
- Optionnel : un certificat « Apple Development ». Sans lui, l'app est signée ad hoc et macOS redemande
  l'autorisation Accessibilité à chaque build.

## Compiler et lancer

```bash
git clone https://github.com/0rezh/MacRemoteControl.git
cd MacRemoteControl
make run
```

`make` construit l'interface web (`web/out`), compile l'app Swift, assemble `build/Mac Remote Control.app`
et la signe ; `make run` la lance ensuite.

| Commande           | Rôle                                                                    |
|--------------------|-------------------------------------------------------------------------|
| `make`             | Compiler l'app (développement)                                          |
| `make run`         | Compiler puis lancer l'app                                              |
| `make release`     | Installeur signé et notarisé (`dist/MacRemoteControl-<version>.dmg`)   |
| `make icons`       | Régénérer les icônes de l'app et de la page web                         |
| `make screenshots` | Régénérer les captures du README (l'app doit tourner)                   |
| `make clean`       | Supprimer les builds                                                    |

## Développer

```bash
# Interface du téléphone avec rechargement à chaud, sur http://localhost:3000
cd web && npm run dev

# App Mac sans repackager (elle sert l'interface de ../web/out)
cd mac && swift run
```

- En développement, l'interface se connecte à l'app Mac sur le port 8765 (`web/.env.development`).
  Ouvrez `http://localhost:3000/#t=<jeton>` : le jeton est à la fin du lien copié depuis le menu, ou
  `defaults read dev.lukas.macremote token`.
- `MAC_REMOTE_WEB_DIR=/chemin/vers/out swift run` sert un autre dossier d'interface.
- Lancée avec `swift run`, l'app hérite des autorisations du Terminal : c'est au Terminal qu'il faut
  donner l'accès Accessibilité.

> ⚠️ Envoyer des commandes au serveur appuie vraiment sur des touches du Mac et bouge vraiment la
> souris. Pensez-y avant de tester le protocole à la main.

## Architecture

```
Téléphone (page Next.js)  ── WebSocket, Wi-Fi local ──▶  App de la barre des menus (Swift)
                                                         ├─ sert la page (port 8765)
                                                         ├─ simule clavier, touches média et souris
                                                         └─ empêche la mise en veille
```

| Dossier         | Contenu                                                                          |
|-----------------|----------------------------------------------------------------------------------|
| `mac/`          | App macOS (Swift, AppKit, SwiftPM) avec le serveur [FlyingFox](https://github.com/swhitty/FlyingFox) |
| `web/`          | Interface du téléphone (Next.js en export statique, servie par l'app Mac)        |
| `.github/`      | Scripts (build, release, icônes, captures) et images du README                   |
| `Makefile`      | Commandes du projet (`make`, `make release`…)                                    |

### App Mac (MVC)

L'app suit le MVC décrit dans
[Model-View-Controller (MVC) in iOS – A Modern Approach](https://www.kodeco.com/1000705-model-view-controller-mvc-in-ios-a-modern-approach),
transposé en AppKit.

```
mac/Sources/MacRemote/
├── main.swift                     Démarrage de NSApplication
├── Model/                         Données et logique, sans interface
│   ├── RemoteAction, PointerEvent, KeyboardInput, AppProfile, Shortcut, FrontmostApp, RemoteState
│   ├── Messages.swift             Format JSON téléphone ⇄ Mac (les messages se décodent eux-mêmes)
│   ├── Pairing.swift              Jeton, lien du QR code, mode d'adresse
│   ├── Constants.swift            Constantes regroupées par domaine
│   ├── Network/                   RemoteServer (et son délégué), WebSocket, fichiers statiques, infos réseau
│   ├── Managers/                  Clavier, souris, veille, autorisation Accessibilité, app au premier plan
│   ├── Persistence/               SettingsStore (UserDefaults)
│   └── Helpers/                   QR code, disposition du clavier, emplacement de l'interface web
├── View/
│   └── MenuView.swift             Le menu (AppKit) : reçoit des valeurs à afficher, jamais d'objets du modèle
└── Controller/
    ├── AppDelegate.swift          Crée les objets et les passe aux contrôleurs
    ├── RemoteController.swift     Le moteur : qui peut se connecter, quelle touche envoyer à quelle app
    ├── MenuViewController.swift   État du RemoteController → contenu de MenuView, et inversement pour les actions
    └── StatusItemController.swift Icône de la barre des menus et popover
```

Règles :

- la **View** n'utilise rien du Model ;
- le **Model** ne connaît ni la vue ni les contrôleurs : il signale ce qui se passe à un délégué ;
- les **Controllers** font le lien et prennent les décisions ;
- les objets communiquent par **délégation** (protocoles `…Delegate`), une extension par protocole.

### Interface du téléphone

```
web/
├── app/page.tsx              Écran principal : en-tête, onglets Touches / Trackpad, jumelage
├── app/globals.css           Styles (couleurs système iOS, clair et sombre, touches de clavier)
├── components/
│   ├── KeyFace.tsx           Dessus des touches F7 à F12 (symboles et légendes)
│   ├── HoldButton.tsx        Touche déclenchée à l'appui, avec répétition
│   ├── TypingPad.tsx         Zone de saisie (clavier de l'iPhone) et modificateurs
│   └── Trackpad.tsx          Trackpad et boutons de clic
└── lib/
    ├── useRemote.ts          Connexion WebSocket, jumelage, reconnexion
    └── useHaptic.ts          Retour haptique
```

### Protocole

Messages JSON sur `ws://<mac>:8765/ws`. Toute commande est refusée avant un `hello` valide.

| Téléphone → Mac                                           | Rôle                                        |
|-----------------------------------------------------------|---------------------------------------------|
| `{"type":"hello","token":"…"}`                            | Jumelage                                    |
| `{"type":"action","action":"playPause"}`                  | Touches F7 à F12, esc, plein écran          |
| `{"type":"move","dx":4,"dy":2}`, `{"type":"scroll",…}`    | Trackpad                                    |
| `{"type":"click","button":"left"}`                        | Clic                                        |
| `{"type":"button","button":"left","down":true}`           | Bouton maintenu (glisser-déposer)           |
| `{"type":"text","text":"Bonjour"}`                        | Saisie de texte                             |
| `{"type":"key","key":"c","modifiers":["command"]}`        | Raccourcis, `delete`, `return`, `tab`       |
| `{"type":"modifiers","held":["command"]}`                 | Modificateurs verrouillés (tenus enfoncés)  |
| `{"type":"ping"}`                                         | Vérifier que la connexion répond            |

Le Mac répond par `welcome` et `state` (app au premier plan, profil de raccourcis, autorisation
Accessibilité), `pong`, ou `error` (`bad_token`, `token_revoked`).

## Conventions

- **Pas de commentaires dans le code.** Seule la documentation est permise : `///` en Swift,
  `/** … */` en TypeScript, au-dessus des types et des fonctions.
- Interface en français, au tutoiement.
- Interface du téléphone : [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
  d'Apple (police système, couleurs système iOS, clair et sombre, zones tactiles d'au moins 44 pt).
- Pas de nouvelle dépendance sans bonne raison.

## Tester

Il n'y a pas encore de tests automatisés. Avant de proposer une modification :

- [ ] `make` se termine sans erreur ni avertissement ;
- [ ] le jumelage par QR code fonctionne, et un mauvais jeton est refusé ;
- [ ] les touches fonctionnent dans un navigateur (YouTube) et dans un lecteur vidéo ;
- [ ] le trackpad, la saisie et les modificateurs (⌘ verrouillé puis tab) fonctionnent ;
- [ ] l'interface s'affiche bien en clair et en sombre, sur un petit écran (iPhone SE) comme sur un grand.

## Proposer une modification

1. Forkez le dépôt et créez une branche (`git switch -c ma-modification`).
2. Faites des commits courts et clairs.
3. Ouvrez une pull request qui explique le changement et comment vous l'avez testé. Pour un changement
   d'interface, ajoutez une capture d'écran.

Le projet est sous [licence PolyForm Strict avec des autorisations supplémentaires](LICENSE.md) : vous
pouvez modifier le code pour vous-même et proposer des contributions, mais pas redistribuer l'app ni
une version modifiée. En proposant une contribution, vous acceptez qu'elle soit intégrée au projet et
distribuée sous cette licence, et que l'auteur puisse l'utiliser, la modifier et la publier dans les
versions officielles.

## Images du README

```bash
make run           # l'app doit tourner pour les captures
make screenshots   # captures dans le mockup d'iPhone 16 Pro (.github/assets/)
make icons         # icônes de l'app et de la page
```

`make screenshots` utilise Google Chrome sans fenêtre, avec un profil temporaire. Rien n'est envoyé au Mac
pendant les captures.

## Publier une version

Pour les mainteneurs, avec un certificat « Developer ID Application » d'Apple.

### Une seule fois : le profil de notarisation

Créez un mot de passe pour app sur [appleid.apple.com](https://appleid.apple.com) (*Connexion et
sécurité › Mots de passe pour app*), puis enregistrez-le dans le trousseau :

```bash
xcrun notarytool store-credentials "mac-remote-notary" --apple-id "vous@exemple.com" --team-id "VOTRE_TEAM_ID"
```

L'identifiant d'équipe est entre parenthèses dans `security find-identity -v -p codesigning`.

### À chaque version

1. Mettez à jour le numéro dans `VERSION`.
2. Construisez l'installeur :
   ```bash
   make release
   ```
   Il produit `dist/MacRemoteControl-<version>.dmg` : app universelle (Apple Silicon et Intel), signée
   Developer ID, notarisée par Apple, ticket agrafé à l'app et à l'installeur.
3. Committez, taguez et poussez :
   ```bash
   git commit -am "Version 0.2.0" && git tag v0.2.0 && git push --follow-tags
   ```
4. Publiez la release avec l'installeur :
   ```bash
   gh release create v0.2.0 dist/MacRemoteControl-0.2.0.dmg --title "Mac Remote Control 0.2.0" --generate-notes
   ```
