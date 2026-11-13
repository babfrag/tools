# shellcheck shell=bash
# -----------------------------------------------------------------------------
# Connexion SSH (mot de passe) aux VM listées dans un fichier de credentials.
#
# Format du fichier (une ligne par couple VM + user, '#' = commentaire) :
#   CODE_CIA/hostname/ENV/user/password
# Le mot de passe peut contenir des '/' (tout ce qui suit le 4e '/').
#
# Commandes : vm, cx, cred-add, cred-rm, cred-edit
# -----------------------------------------------------------------------------

TOOLS_CRED_FILE="${TOOLS_CRED_FILE:-$HOME/.bpce_credentials}"
TOOLS_CLIP_TIMEOUT="${TOOLS_CLIP_TIMEOUT:-30}"   # secondes avant effacement (0 = jamais)
TOOLS_SSH_OPTS="${TOOLS_SSH_OPTS:--o PubkeyAuthentication=no -o StrictHostKeyChecking=accept-new}"

# ---------------------------------------------------------------- utilitaires
_tools_err() { printf '\e[31m%s\e[0m\n' "$*" >&2; }
_tools_info() { printf '\e[36m%s\e[0m\n' "$*"; }

# Copie $1 dans le presse-papier Windows, puis l'efface après TOOLS_CLIP_TIMEOUT s.
_tools_clip() {
  local secret=$1
  if [[ -w /dev/clipboard ]]; then
    printf '%s' "$secret" > /dev/clipboard
  else
    printf '%s' "$secret" | clip.exe
  fi
  (( TOOLS_CLIP_TIMEOUT > 0 )) || return 0
  # Double sous-shell : évite l'affichage "[1] PID" du job en arrière-plan.
  ( ( sleep "$TOOLS_CLIP_TIMEOUT"
      [[ -w /dev/clipboard && "$(cat /dev/clipboard)" == "$secret" ]] && printf '' > /dev/clipboard
    ) >/dev/null 2>&1 & )
}

# Lit le fichier de credentials et remplit les tableaux _VM_* avec les lignes
# dont "cia/host/env/user" contient tous les mots-clés passés (insensible à la casse).
_tools_load() {
  _VM_CIA=() _VM_HOST=() _VM_ENV=() _VM_USER=() _VM_PASS=()
  [[ -f $TOOLS_CRED_FILE ]] || { _tools_err "Fichier absent : $TOOLS_CRED_FILE (utilisez cred-add)"; return 1; }

  local line n=0 cia host env user pass key kw
  while IFS= read -r line || [[ -n $line ]]; do
    n=$((n + 1))
    line=${line%$'\r'}                                   # fichiers édités sous Windows
    [[ -z ${line//[[:space:]]/} || $line == \#* ]] && continue
    IFS=/ read -r cia host env user pass <<< "$line"
    if [[ -z $cia || -z $host || -z $env || -z $user || -z $pass ]]; then
      _tools_err "Ligne $n ignorée (format attendu CODE_CIA/hostname/ENV/user/password)"
      continue
    fi
    key="${cia,,}/${host,,}/${env,,}/${user,,}"
    for kw in "$@"; do
      [[ $key == *"${kw,,}"* ]] || continue 2
    done
    _VM_CIA+=("$cia") _VM_HOST+=("$host") _VM_ENV+=("$env") _VM_USER+=("$user") _VM_PASS+=("$pass")
  done < "$TOOLS_CRED_FILE"
}

_tools_print_list() {
  local i
  printf '\e[1m%3s  %-8s %-30s %-5s %s\e[0m\n' '#' CIA HOST ENV USER
  for i in "${!_VM_HOST[@]}"; do
    printf '%3d  %-8s %-30s %-5s %s\n' $((i + 1)) "${_VM_CIA[i]}" "${_VM_HOST[i]}" "${_VM_ENV[i]}" "${_VM_USER[i]}"
  done
}

# ------------------------------------------------------------------ commandes

# vm [mots-clés...] : liste les VM / users (sans mot de passe)
vm() {
  _tools_load "$@" || return 1
  (( ${#_VM_HOST[@]} )) || { _tools_err "Aucune VM ne correspond"; return 1; }
  _tools_print_list
}

# Menu interactif : _tools_menu <titre> <valeurs...>
# Affiche le menu sur stderr et écrit la valeur choisie sur stdout.
# Saisie : un numéro, la valeur exacte, ou un texte qui réduit la liste.
# Une seule valeur => choisie sans question. Saisie vide => annulation.
_tools_menu() {
  local title=$1; shift
  local items=("$@") filtered=() item input i
  (( ${#items[@]} == 1 )) && { printf '%s\n' "${items[0]}"; return 0; }

  while :; do
    printf '\e[1m%s\e[0m\n' "$title" >&2
    for i in "${!items[@]}"; do
      printf '%3d) %s\n' $((i + 1)) "${items[i]}"
    done | column -c "${COLUMNS:-100}" >&2
    read -rp "Numéro ou texte (vide = annuler) : " input || return 1
    [[ -n $input ]] || return 1

    if [[ $input =~ ^[0-9]+$ ]]; then
      if (( input >= 1 && input <= ${#items[@]} )); then
        printf '%s\n' "${items[input - 1]}"; return 0
      fi
      _tools_err "Choix invalide : $input"; continue
    fi

    filtered=()
    for item in "${items[@]}"; do
      [[ ${item,,} == "${input,,}" ]] && { printf '%s\n' "$item"; return 0; }
      [[ ${item,,} == *"${input,,}"* ]] && filtered+=("$item")
    done
    case ${#filtered[@]} in
      0) _tools_err "Aucune correspondance : $input" ;;
      1) printf '%s\n' "${filtered[0]}"; return 0 ;;
      *) items=("${filtered[@]}") ;;
    esac
  done
}

# Étape de sélection : _tools_step <titre> <tableau _VM_*>
# Propose les valeurs distinctes de la colonne parmi les lignes _SEL,
# puis ne garde dans _SEL que les lignes correspondant au choix.
_tools_step() {
  local -n _col=$2
  local i choice values=() keep=()
  mapfile -t values < <(for i in "${_SEL[@]}"; do printf '%s\n' "${_col[i]}"; done | sort -u)
  choice=$(_tools_menu "$1" "${values[@]}") || { _tools_err "Annulé"; return 1; }
  for i in "${_SEL[@]}"; do
    [[ ${_col[i]} == "$choice" ]] && keep+=("$i")
  done
  _SEL=("${keep[@]}")
}

# cx [mots-clés...] : sélection CIA > ENV > machine > user, copie le mot de passe et lance ssh
cx() {
  _tools_load "$@" || return 1
  (( ${#_VM_HOST[@]} )) || { _tools_err "Aucune VM ne correspond : $*"; return 1; }

  _SEL=("${!_VM_HOST[@]}")
  _tools_step "Code CIA"      _VM_CIA  || return 1
  _tools_step "Environnement" _VM_ENV  || return 1
  _tools_step "Machine"       _VM_HOST || return 1
  _tools_step "User"          _VM_USER || return 1
  local i=${_SEL[0]}

  _tools_clip "${_VM_PASS[i]}"
  _tools_info "[${_VM_ENV[i]}] ${_VM_CIA[i]} ${_VM_USER[i]}@${_VM_HOST[i]}"
  _tools_info "Mot de passe copié : Shift+Inser ou clic droit pour coller"
  printf '\e]0;%s\a' "[${_VM_ENV[i]}] ${_VM_USER[i]}@${_VM_HOST[i]}"   # titre de l'onglet
  # shellcheck disable=SC2086  # TOOLS_SSH_OPTS doit être découpé en mots
  ssh $TOOLS_SSH_OPTS "${_VM_USER[i]}@${_VM_HOST[i]}"
}

# Supprime la ligne d'un couple host + user (comparaison exacte, insensible à la casse)
_tools_delete() {
  local host=$1 user=$2 tmp
  tmp=$(mktemp) || return 1
  awk -F/ -v h="${host,,}" -v u="${user,,}" 'tolower($2) != h || tolower($4) != u' \
    "$TOOLS_CRED_FILE" > "$tmp" && cat "$tmp" > "$TOOLS_CRED_FILE"
  rm -f "$tmp"
}

# cred-add : ajoute (ou met à jour) un user sur une VM
cred-add() {
  local cia host env user pass pass2
  read -rp "CODE CIA : " cia
  read -rp "Hostname : " host
  read -rp "ENV      : " env
  read -rp "User     : " user
  read -rsp "Mot de passe : " pass; echo
  read -rsp "Confirmation : " pass2; echo

  local f
  for f in "$cia" "$host" "$env" "$user"; do
    [[ -n $f && $f != */* && $f != *[[:space:]]* ]] \
      || { _tools_err "Champs obligatoires, sans '/' ni espace"; return 1; }
  done
  [[ -n $pass && $pass == "$pass2" ]] || { _tools_err "Mots de passe vides ou différents"; return 1; }

  touch "$TOOLS_CRED_FILE" && chmod 600 "$TOOLS_CRED_FILE"
  _tools_delete "$host" "$user"
  printf '%s/%s/%s/%s/%s\n' "${cia^^}" "$host" "${env^^}" "$user" "$pass" >> "$TOOLS_CRED_FILE"
  _tools_info "Enregistré : ${cia^^}/$host/${env^^}/$user"
}

# cred-rm <hostname> <user> : supprime un user d'une VM
cred-rm() {
  (( $# == 2 )) || { echo "Usage : cred-rm <hostname> <user>"; return 1; }
  awk -F/ -v h="${1,,}" -v u="${2,,}" 'tolower($2) == h && tolower($4) == u {found=1} END {exit !found}' \
    "$TOOLS_CRED_FILE" 2>/dev/null || { _tools_err "Introuvable : $2@$1"; return 1; }
  _tools_delete "$1" "$2" && _tools_info "Supprimé : $2@$1"
}

# cred-edit : ouvre le fichier de credentials dans l'éditeur
cred-edit() { "${EDITOR:-notepad}" "$TOOLS_CRED_FILE"; }
