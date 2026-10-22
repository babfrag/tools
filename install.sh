#!/usr/bin/env bash
# Installe les outils : ajoute le chargement de bash/init.sh dans ~/.bashrc
# et crée le fichier de credentials à partir de l'exemple s'il n'existe pas.
set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRED_FILE="${TOOLS_CRED_FILE:-$HOME/.bpce_credentials}"
LINE="[ -f \"$TOOLS_DIR/bash/init.sh\" ] && . \"$TOOLS_DIR/bash/init.sh\""

touch "$HOME/.bashrc"
if grep -qF "$TOOLS_DIR/bash/init.sh" "$HOME/.bashrc"; then
  echo "Déjà présent dans ~/.bashrc"
else
  printf '\n# tools (%s)\n%s\n' "$TOOLS_DIR" "$LINE" >> "$HOME/.bashrc"
  echo "Ajouté dans ~/.bashrc"
fi

# Git Bash lit ~/.bash_profile au démarrage : on s'assure qu'il charge ~/.bashrc
if [[ ! -f $HOME/.bash_profile ]]; then
  echo '[ -f ~/.bashrc ] && . ~/.bashrc' > "$HOME/.bash_profile"
  echo "Créé ~/.bash_profile"
fi

if [[ ! -f $CRED_FILE ]]; then
  cp "$TOOLS_DIR/examples/bpce_credentials.example" "$CRED_FILE"
  chmod 600 "$CRED_FILE"
  echo "Créé $CRED_FILE (à compléter avec cred-add ou cred-edit)"
fi

echo "OK. Ouvrez un nouveau terminal Git Bash puis tapez : tools-help"
