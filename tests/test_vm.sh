#!/usr/bin/env bash
# Tests de bash/vm.sh — lancer : bash tests/test_vm.sh
# ssh et le presse-papier sont simulés ; aucun accès réseau.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export TOOLS_CRED_FILE="$TMP/creds" TOOLS_CLIP_TIMEOUT=0
# shellcheck source=../bash/vm.sh
. "$ROOT/bash/vm.sh"

# Simulations
_tools_clip() { printf '%s' "$1" > "$TMP/clip"; }
ssh() { echo "${@: -1}" > "$TMP/ssh"; }

PASS=0 FAIL=0
check() {  # check <description> <attendu> <obtenu>
  if [[ $2 == "$3" ]]; then PASS=$((PASS + 1)); echo "ok   - $1"
  else FAIL=$((FAIL + 1)); echo "FAIL - $1 : attendu [$2], obtenu [$3]"; fi
}
add() { cred-add < <(printf '%s\n' "$@") > /dev/null; }

# --- cred-add
add abc vm-abc-dev01 dev root 'p/a@ss w' 'p/a@ss w'
add abc vm-abc-dev01 dev appli secret secret
add xyz vm-xyz-val01 val root val1 val1
check "ajout de 3 lignes" 3 "$(wc -l < "$TOOLS_CRED_FILE")"
check "CIA/ENV en majuscules" "ABC/vm-abc-dev01/DEV/root/p/a@ss w" "$(head -1 "$TOOLS_CRED_FILE")"

add abc vm-abc-dev01 dev root 'new/pw' 'new/pw'
check "mise à jour sans doublon" 3 "$(wc -l < "$TOOLS_CRED_FILE")"
check "mise à jour du mot de passe" 1 "$(grep -c 'vm-abc-dev01/DEV/root/new/pw$' "$TOOLS_CRED_FILE")"

add abc vm-x dev root a b 2>/dev/null
check "confirmation différente refusée" 0 "$(grep -c '/vm-x/' "$TOOLS_CRED_FILE")"

# --- vm
check "filtre multi mots-clés" 2 "$(vm abc dev | tail -n +2 | wc -l)"
check "filtre sur le user" 2 "$(vm root | tail -n +2 | wc -l)"
check "mot de passe jamais affiché" 0 "$(vm | grep -c 'new/pw')"

# --- lignes commentées / invalides / CRLF
printf '# commentaire\n\nINVALIDE/ligne\r\nDEF/vm-def/VER/user/pw\r\n' >> "$TOOLS_CRED_FILE"
check "commentaires et lignes invalides ignorés" 4 "$(vm 2>/dev/null | tail -n +2 | wc -l)"

# --- cx
cx vm-def > /dev/null 2>&1
check "cx : résultat unique, connexion directe" "user@vm-def" "$(cat "$TMP/ssh")"
check "cx : CRLF retiré du mot de passe" "pw" "$(cat "$TMP/clip")"

cx abc dev < <(echo 2) > /dev/null 2>&1
check "cx : choix du user dans le menu" "root@vm-abc-dev01" "$(cat "$TMP/ssh")"
check "cx : mot de passe avec '/' copié" "new/pw" "$(cat "$TMP/clip")"

cx abc dev < <(echo 9) > /dev/null 2>&1
check "cx : choix hors limites refusé" 1 $?
cx inexistant > /dev/null 2>&1
check "cx : aucune VM" 1 $?

# --- cred-rm
cred-rm vm-abc-dev01 appli > /dev/null
check "cred-rm supprime le bon user" 0 "$(grep -c '/appli/' "$TOOLS_CRED_FILE")"
check "cred-rm conserve les autres" 1 "$(grep -c 'vm-abc-dev01/DEV/root' "$TOOLS_CRED_FILE")"
cred-rm vm-abc-dev01 appli > /dev/null 2>&1
check "cred-rm : user introuvable" 1 $?

echo "--- $PASS ok, $FAIL échec(s)"
(( FAIL == 0 ))
