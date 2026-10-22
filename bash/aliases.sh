# shellcheck shell=bash
# Alias généraux

# Navigation / fichiers
alias ls='ls --color=auto'
alias ll='ls -lahF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'

# Git
alias gs='git status -sb'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git pull --rebase'
alias gd='git diff'
alias glog='git log --oneline --graph --decorate -20'

# Outils
alias reload='source ~/.bashrc && echo "~/.bashrc rechargé"'
