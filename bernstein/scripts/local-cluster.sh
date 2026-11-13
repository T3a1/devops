#!/usr/bin/env bash
# Cluster Kubernetes local (kind) pour tester avant Azure.
#
#   scripts/local-cluster.sh create   crée un cluster de 3 nœuds + metrics-server (pour le HPA)
#   scripts/local-cluster.sh delete   supprime le cluster
source "$(dirname "$0")/common.sh"
require_cmds kind kubectl docker

CLUSTER="bernstein"

case "${1:-}" in
  create)
    if kind get clusters | grep -qx "$CLUSTER"; then
      info "Le cluster kind \"$CLUSTER\" existe déjà"
    else
      info "Création du cluster kind \"$CLUSTER\" (1 control-plane + 2 workers)"
      kind create cluster --config "$ROOT_DIR/kind-config.yaml"
    fi
    kubectl config use-context "kind-$CLUSTER" >/dev/null

    info "Installation de metrics-server (mesures CPU/RAM pour kubectl top et le HPA)"
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    # kind utilise des certificats auto-signés pour les kubelets : on désactive leur vérification
    if ! kubectl -n kube-system get deployment metrics-server \
        -o jsonpath='{.spec.template.spec.containers[0].args}' | grep -q kubelet-insecure-tls; then
      kubectl -n kube-system patch deployment metrics-server --type=json \
        -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
    fi
    kubectl get nodes -o wide
    ok "Cluster local prêt. Étape suivante : scripts/deploy.sh local" ;;
  delete)
    kind delete cluster --name "$CLUSTER"
    ok "Cluster local supprimé" ;;
  *)
    sed -n '2,6p' "$0"; exit 1 ;;
esac
