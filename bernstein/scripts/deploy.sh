#!/usr/bin/env bash
# Déploiement complet de l'application Poll, du code source jusqu'au cluster.
#
#   scripts/deploy.sh azure   build linux/amd64 -> push dans ACR -> déploiement sur AKS
#   scripts/deploy.sh local   build -> chargement dans kind -> déploiement sur kind
#
# Étapes : 1. build des images   2. publication   3. Secret + schéma SQL
#          4. manifestes (kubectl apply -k)   5. attente des rollouts   6. URLs
# Le script est idempotent : le relancer après une modification du code
# produit une mise à jour progressive (rolling update) sans coupure.
source "$(dirname "$0")/common.sh"

TARGET="${1:-}"
[[ "$TARGET" == "azure" || "$TARGET" == "local" ]] || { sed -n '2,10p' "$0"; exit 1; }

load_env
require_cmds docker kubectl git
require_vars POSTGRES_PASSWORD REDIS_PASSWORD

TAG="${IMAGE_TAG:-$(image_tag)}"

# ---------------------------------------------------------------- 0. cible
if [[ "$TARGET" == "azure" ]]; then
  require_cmds az
  require_vars AZURE_SUBSCRIPTION_ID AZURE_RESOURCE_GROUP AZURE_ACR_NAME AZURE_AKS_NAME
  az account set --subscription "$AZURE_SUBSCRIPTION_ID"
  REGISTRY="$(az acr show --name "$AZURE_ACR_NAME" --query loginServer -o tsv)"
  CONTEXT="$AZURE_AKS_NAME"
  kubectl config get-contexts "$CONTEXT" >/dev/null 2>&1 \
    || az aks get-credentials --name "$AZURE_AKS_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --overwrite-existing -o none
  IMAGE_PREFIX="${REGISTRY}/"
else
  require_cmds kind
  CONTEXT="kind-bernstein"
  kubectl config get-contexts "$CONTEXT" >/dev/null 2>&1 || die "Cluster local absent : scripts/local-cluster.sh create"
  IMAGE_PREFIX=""
fi
# Toutes les commandes kubectl visent explicitement le bon cluster.
k() { kubectl --context "$CONTEXT" "$@"; }
info "Cible : $TARGET (contexte kubectl : $CONTEXT) — version des images : $TAG"

# ---------------------------------------------------------------- 1-2. images
if [[ "$TARGET" == "azure" ]]; then
  info "Connexion au registry $REGISTRY"
  az acr login --name "$AZURE_ACR_NAME"
  for s in "${SERVICES[@]}"; do
    info "Build + push de ${REGISTRY}/${s}:${TAG} (linux/amd64, l'architecture des nœuds AKS)"
    docker buildx build --platform linux/amd64 -t "${REGISTRY}/${s}:${TAG}" --push "$ROOT_DIR/$s"
  done
else
  for s in "${SERVICES[@]}"; do
    info "Build de ${s}:${TAG}"
    docker build -t "${s}:${TAG}" "$ROOT_DIR/$s"
  done
  info "Chargement des images dans les nœuds kind"
  images=(); for s in "${SERVICES[@]}"; do images+=("${s}:${TAG}"); done
  if ! kind load docker-image "${images[@]}" --name bernstein; then
    warn "kind load a échoué, nouvel essai via une archive"
    archive="$(mktemp "${TMPDIR:-/tmp}/poll-images.XXXXXX")"
    docker save "${images[@]}" -o "$archive"
    kind load image-archive "$archive" --name bernstein
    rm -f "$archive"
  fi
fi

# ---------------------------------------------------------------- 3. secrets et schéma
info "Namespace, Secret et schéma SQL"
k apply -f "$ROOT_DIR/k8s/base/00-namespace.yaml"
# "create --dry-run | apply" = créer OU mettre à jour, sans jamais écrire le secret dans un fichier
k create secret generic poll-secrets -n "$NAMESPACE" \
  --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  --from-literal=REDIS_PASSWORD="$REDIS_PASSWORD" \
  --dry-run=client -o yaml | k apply -f -
k create configmap postgres-schema -n "$NAMESPACE" \
  --from-file=schema.sql="$ROOT_DIR/schema.sql" \
  --dry-run=client -o yaml | k apply -f -

# ---------------------------------------------------------------- 4. manifestes
info "Application des manifestes (images ${IMAGE_PREFIX}<service>:${TAG})"
GEN_DIR="$ROOT_DIR/k8s/.generated"
mkdir -p "$GEN_DIR"
{
  echo "# Fichier généré par scripts/deploy.sh — ne pas modifier, ne pas versionner."
  echo "apiVersion: kustomize.config.k8s.io/v1beta1"
  echo "kind: Kustomization"
  echo "resources:"
  echo "  - ../base"
  echo "images:"
  for s in "${SERVICES[@]}"; do
    echo "  - name: ${s}"
    echo "    newName: ${IMAGE_PREFIX}${s}"
    echo "    newTag: \"${TAG}\""
  done
} > "$GEN_DIR/kustomization.yaml"
k apply -k "$GEN_DIR"

if [[ "$TARGET" == "azure" || "${WITH_NETWORK_POLICIES:-0}" == "1" ]]; then
  info "NetworkPolicies (pare-feu entre les pods)"
  k apply -f "$ROOT_DIR/k8s/policies/"
fi

# ---------------------------------------------------------------- 5. attente
info "Attente que tout soit prêt"
k -n "$NAMESPACE" rollout status statefulset/redis  --timeout=180s
k -n "$NAMESPACE" rollout status statefulset/db     --timeout=300s
for d in worker poll result; do
  k -n "$NAMESPACE" rollout status "deployment/$d" --timeout=300s
done
k -n "$NAMESPACE" get pods -o wide

# ---------------------------------------------------------------- 6. accès
if [[ "$TARGET" == "azure" ]]; then
  info "Attente des IP publiques (1 à 3 minutes au premier déploiement)"
  for svc in poll result; do
    ip=""
    for _ in $(seq 1 60); do
      ip="$(k -n "$NAMESPACE" get svc "$svc" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
      [[ -n "$ip" ]] && break
      sleep 5
    done
    if [[ -n "$ip" ]]; then
      ok "$svc : http://$ip"
    else
      warn "$svc : pas encore d'IP, vérifier avec : kubectl -n poll get svc $svc -w"
    fi
  done
else
  ok "Déployé sur kind. Pour ouvrir les pages (un terminal chacune) :"
  echo "    kubectl --context $CONTEXT -n $NAMESPACE port-forward svc/poll   8080:80   → http://localhost:8080"
  echo "    kubectl --context $CONTEXT -n $NAMESPACE port-forward svc/result 8081:80   → http://localhost:8081"
fi
