#!/usr/bin/env bash
# Interroge une ou plusieurs URL en continu et compte les erreurs.
# À lancer PENDANT une mise à jour (scripts/deploy.sh azure) pour prouver l'absence de coupure.
#
#   scripts/test-no-downtime.sh http://<ip-poll> http://<ip-result>
#   Ctrl+C pour arrêter et afficher le bilan.
# Compatible avec le bash 3.2 fourni par macOS.
set -uo pipefail
(($# > 0)) || { sed -n '2,7p' "$0"; exit 1; }

URLS=("$@")
OKS=(); ERRS=()
for i in "${!URLS[@]}"; do OKS[i]=0; ERRS[i]=0; done

summary() {
  echo; echo "===== Bilan ====="
  for i in "${!URLS[@]}"; do
    printf '%-40s  OK: %-6s  ERREURS: %s\n' "${URLS[i]}" "${OKS[i]}" "${ERRS[i]}"
  done
  exit 0
}
trap summary INT

while true; do
  for i in "${!URLS[@]}"; do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "${URLS[i]}")"
    if [[ "$code" == "200" ]]; then
      OKS[i]=$(( OKS[i] + 1 ))
    else
      ERRS[i]=$(( ERRS[i] + 1 ))
      printf '\n%s  %s  -> %s\n' "$(date +%T)" "${URLS[i]}" "$code"
    fi
  done
  total=0; for n in "${OKS[@]}"; do total=$(( total + n )); done
  printf '\r%s  requêtes OK : %s' "$(date +%T)" "$total"
  sleep 0.2
done
