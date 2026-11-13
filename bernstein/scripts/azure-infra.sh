#!/usr/bin/env bash
# Gestion de l'infrastructure Azure : groupe de ressources, registry (ACR), cluster (AKS).
#
#   scripts/azure-infra.sh create       crée tout (idempotent : relançable sans risque)
#   scripts/azure-infra.sh credentials  configure kubectl pour parler au cluster AKS
#   scripts/azure-infra.sh status       état des ressources
#   scripts/azure-infra.sh stop         arrête le cluster (les nœuds ne sont plus facturés)
#   scripts/azure-infra.sh start        redémarre le cluster
#   scripts/azure-infra.sh destroy      supprime TOUT (cluster, registry, disques, IP)
source "$(dirname "$0")/common.sh"

load_env
require_cmds az
require_vars AZURE_SUBSCRIPTION_ID AZURE_LOCATION AZURE_RESOURCE_GROUP AZURE_ACR_NAME AZURE_AKS_NAME

AKS_NODE_COUNT="${AKS_NODE_COUNT:-2}"
AKS_NODE_SIZE="${AKS_NODE_SIZE:-Standard_B2s}"
RG="$AZURE_RESOURCE_GROUP"

az account set --subscription "$AZURE_SUBSCRIPTION_ID"

create() {
  info "Groupe de ressources $RG ($AZURE_LOCATION)"
  az group create --name "$RG" --location "$AZURE_LOCATION" --tags project=bernstein -o none

  info "Registry privé $AZURE_ACR_NAME (SKU Basic, le moins cher)"
  if ! az acr show --name "$AZURE_ACR_NAME" --resource-group "$RG" -o none 2>/dev/null; then
    az acr create --name "$AZURE_ACR_NAME" --resource-group "$RG" --sku Basic -o none
  fi

  info "Cluster AKS $AZURE_AKS_NAME : $AKS_NODE_COUNT nœuds $AKS_NODE_SIZE (5 à 10 minutes)"
  if ! az aks show --name "$AZURE_AKS_NAME" --resource-group "$RG" -o none 2>/dev/null; then
    # --tier free                : plan de contrôle gratuit
    # --network-dataplane cilium : réseau Azure CNI + Cilium, qui applique les NetworkPolicies
    # --attach-acr               : les nœuds peuvent tirer les images du registry sans mot de passe
    az aks create \
      --name "$AZURE_AKS_NAME" \
      --resource-group "$RG" \
      --location "$AZURE_LOCATION" \
      --tier free \
      --node-count "$AKS_NODE_COUNT" \
      --node-vm-size "$AKS_NODE_SIZE" \
      --network-plugin azure \
      --network-plugin-mode overlay \
      --network-dataplane cilium \
      --attach-acr "$AZURE_ACR_NAME" \
      --no-ssh-key \
      --tags project=bernstein \
      -o none
  else
    info "Le cluster existe déjà : on vérifie seulement le lien avec le registry"
    az aks update --name "$AZURE_AKS_NAME" --resource-group "$RG" --attach-acr "$AZURE_ACR_NAME" -o none
  fi

  credentials
  ok "Infrastructure prête. Étape suivante : scripts/deploy.sh azure"
}

credentials() {
  info "Configuration de kubectl (contexte \"$AZURE_AKS_NAME\")"
  az aks get-credentials --name "$AZURE_AKS_NAME" --resource-group "$RG" --overwrite-existing -o none
  kubectl config use-context "$AZURE_AKS_NAME" >/dev/null
  kubectl get nodes -o wide
}

status() {
  az aks show --name "$AZURE_AKS_NAME" --resource-group "$RG" \
    --query "{cluster:name, etat:powerState.code, version:kubernetesVersion, noeuds:agentPoolProfiles[0].count, taille:agentPoolProfiles[0].vmSize}" -o table
  az acr show --name "$AZURE_ACR_NAME" --resource-group "$RG" --query "{registry:loginServer, sku:sku.name}" -o table
  echo
  info "Images dans le registry"
  for s in "${SERVICES[@]}"; do
    printf '%-7s ' "$s"
    az acr repository show-tags --name "$AZURE_ACR_NAME" --repository "$s" --orderby time_desc --top 3 -o tsv 2>/dev/null | tr '\n' ' ' || true
    echo
  done
}

case "${1:-}" in
  create)      create ;;
  credentials) credentials ;;
  status)      status ;;
  stop)
    info "Arrêt du cluster : les VM ne sont plus facturées (disques et IP restent conservés)"
    az aks stop --name "$AZURE_AKS_NAME" --resource-group "$RG"
    ok "Cluster arrêté. Pour le relancer : scripts/azure-infra.sh start" ;;
  start)
    info "Démarrage du cluster (quelques minutes)"
    az aks start --name "$AZURE_AKS_NAME" --resource-group "$RG"
    credentials ;;
  destroy)
    warn "Suppression du groupe $RG : cluster, registry, images, disques (données des votes) et IP publiques."
    read -r -p "Tape le nom du groupe pour confirmer : " answer
    [[ "$answer" == "$RG" ]] || die "Confirmation incorrecte, rien n'a été supprimé."
    az group delete --name "$RG" --yes --no-wait
    kubectl config delete-context "$AZURE_AKS_NAME" >/dev/null 2>&1 || true
    ok "Suppression lancée en arrière-plan (5 à 10 minutes). Vérifier : az group exists --name $RG" ;;
  *)
    sed -n '2,10p' "$0"; exit 1 ;;
esac
