#!/usr/bin/env bash
# Fonctions et variables partagées par tous les scripts. À "sourcer", pas à exécuter.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC2034  # variables utilisées par les scripts qui sourcent ce fichier
NAMESPACE="poll"
# shellcheck disable=SC2034
SERVICES=(poll worker result)

info()  { printf '\033[1;34m▶ %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m⚠ %s\033[0m\n' "$*" >&2; }
die()   { printf '\033[1;31m✖ %s\033[0m\n' "$*" >&2; exit 1; }

# Charge .env (secrets + paramètres Azure). Le fichier n'est jamais versionné.
load_env() {
  local env_file="${ROOT_DIR}/.env"
  [[ -f "$env_file" ]] || die "Fichier .env introuvable : cp .env.example .env puis remplis-le."
  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
}

# Vérifie que des variables sont définies et non vides.
require_vars() {
  local missing=""
  for v in "$@"; do
    [[ -n "${!v:-}" ]] || missing="$missing $v"
  done
  [[ -z "$missing" ]] || die "Variables manquantes dans .env :$missing"
}

# Vérifie que des commandes sont installées.
require_cmds() {
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "Commande introuvable : $c (voir README, section Prérequis)"
  done
}

# Tag des images = commit Git courant (+ horodatage si des fichiers sont modifiés).
# Chaque changement de code produit donc un tag unique : jamais de "latest".
image_tag() {
  local tag
  if ! tag="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null)"; then
    # Pas de dépôt Git (ou aucun commit) : un horodatage garantit quand même un tag unique.
    warn "Pas de commit Git : tag basé sur la date. Pense à : git init && git commit"
    date +%Y%m%d%H%M%S
    return
  fi
  if [[ -n "$(git -C "$ROOT_DIR" status --porcelain -- poll worker result 2>/dev/null)" ]]; then
    tag="${tag}-dirty-$(date +%Y%m%d%H%M%S)"
  fi
  echo "$tag"
}
