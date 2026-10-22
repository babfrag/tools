# tools

Outils DevOps pour Git Bash (Windows) : alias et connexion SSH par mot de passe aux VM, classées par code CIA et environnement (DEV, VER, VAL…).

## Installation

```bash
git clone https://github.com/y-delaunay_Catam/tools.git ~/tools
bash ~/tools/install.sh
```

Ouvrez ensuite un nouveau terminal Git Bash, puis tapez `tools-help`.

`install.sh` ajoute une ligne dans `~/.bashrc` qui charge `bash/init.sh`. Le script peut être relancé sans risque. Pour mettre à jour : `git -C ~/tools pull`, puis `reload`.

## Fichier de credentials

`~/.bpce_credentials` contient une ligne par couple VM + user :

```
CODE_CIA/hostname/ENV/user/password
ABC/vm-abc-dev01/DEV/root/MotDePasse
ABC/vm-abc-dev01/DEV/appli/AutreMotDePasse
```

- Les lignes vides et celles commençant par `#` sont ignorées.
- Le mot de passe peut contenir des `/`.
- ⚠️ Le fichier est **en clair** et ne doit jamais être versionné (il est exclu par `.gitignore`).

## Commandes

| Commande | Description |
|---|---|
| `vm [mots-clés]` | Liste les VM et les users (sans mot de passe), ex. `vm abc dev` |
| `cx [mots-clés]` | Se connecte en SSH, avec un menu si plusieurs résultats. Le mot de passe est copié dans le presse-papier : collez-le avec **Shift+Inser** ou clic droit. |
| `cred-add` | Ajoute ou met à jour un user sur une VM (saisie masquée) |
| `cred-rm <host> <user>` | Supprime un user d'une VM |
| `cred-edit` | Ouvre le fichier de credentials |
| `tools-help` | Aide |

Les mots-clés filtrent sur `CIA/host/ENV/user`, sans tenir compte de la casse. Ils se combinent : `cx abc val root`.

## Configuration

Variables à définir dans `~/.bashrc`, **avant** la ligne qui charge `tools` :

| Variable | Défaut | Rôle |
|---|---|---|
| `TOOLS_CRED_FILE` | `~/.bpce_credentials` | Fichier de credentials |
| `TOOLS_CLIP_TIMEOUT` | `30` | Délai (s) avant l'effacement du presse-papier (`0` = jamais) |
| `TOOLS_SSH_OPTS` | `-o PubkeyAuthentication=no -o StrictHostKeyChecking=accept-new` | Options passées à `ssh` |

## Structure

```
bash/init.sh      point d'entrée : charge tous les modules bash/*.sh
bash/aliases.sh   alias généraux et git
bash/vm.sh        vm, cx, cred-*
tests/test_vm.sh  tests (ssh et presse-papier simulés)
install.sh        installation dans ~/.bashrc
```

Pour ajouter un module, créez `bash/<nom>.sh` : il est chargé automatiquement.

## Tests

```bash
bash tests/test_vm.sh
```
