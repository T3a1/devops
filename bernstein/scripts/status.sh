#!/usr/bin/env bash
# shellcheck disable=SC2016  # les $VARIABLES sont volontairement évaluées DANS le conteneur
# Tableau de bord rapide de l'application dans le cluster courant (ou --context X).
#   scripts/status.sh                 -> contexte kubectl courant
#   scripts/status.sh kind-bernstein  -> un contexte précis
set -uo pipefail
CTX="${1:-$(kubectl config current-context)}"
k() { kubectl --context "$CTX" "$@"; }
h() { printf '\n\033[1;34m== %s ==\033[0m\n' "$*"; }

h "Contexte";            echo "$CTX"
h "Nœuds";               k get nodes -o wide
h "Consommation nœuds";  k top nodes 2>/dev/null || echo "(metrics-server indisponible)"
h "Pods";                k -n poll get pods -o wide
h "Consommation pods";   k -n poll top pods 2>/dev/null || echo "(metrics-server indisponible)"
h "Services";            k -n poll get svc
h "Autoscaling / PDB";   k -n poll get hpa,pdb
h "Volumes";             k -n poll get pvc
h "Événements récents";  k -n poll get events --sort-by=.lastTimestamp | tail -n 15
h "File Redis (votes en attente)"
k -n poll exec statefulset/redis -- sh -c 'redis-cli -a "$REDIS_PASSWORD" --no-auth-warning LLEN votes' 2>/dev/null || echo "(Redis indisponible)"
h "Votes en base"
k -n poll exec statefulset/db -- sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT vote, COUNT(*) FROM votes GROUP BY vote ORDER BY vote"' 2>/dev/null || echo "(PostgreSQL indisponible)"
