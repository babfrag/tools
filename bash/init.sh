# shellcheck shell=bash
# Point d'entrée : à sourcer depuis ~/.bashrc (voir install.sh).
# Charge tous les modules bash/*.sh du dépôt.

[[ $- == *i* ]] || return 0

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export TOOLS_DIR

for _tools_module in "$TOOLS_DIR"/bash/*.sh; do
  [[ $_tools_module == */init.sh ]] && continue
  # shellcheck source=/dev/null
  . "$_tools_module"
done
unset _tools_module

HISTCONTROL=ignoreboth
HISTSIZE=10000

# tools-help : liste des commandes disponibles
tools-help() {
  cat <<EOF
VM / SSH   (fichier : $TOOLS_CRED_FILE)
  vm [mots-clés]          Lister VM et users      ex: vm abc dev
  cx [mots-clés]          Se connecter (menu si plusieurs résultats)
  cred-add                Ajouter / mettre à jour un user sur une VM
  cred-rm <host> <user>   Supprimer un user d'une VM
  cred-edit               Éditer le fichier de credentials
Divers
  reload                  Recharger la configuration
  alias                   Voir tous les alias
EOF
}
