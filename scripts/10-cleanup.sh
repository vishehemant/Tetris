#!/bin/bash
set -euo pipefail

#######################################################################
# Script 10: Cleanup - Remove all resources
# Use this to tear down the entire setup
#######################################################################

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }
header() { echo -e "\n${CYAN}========================================${NC}"; echo -e "${CYAN} $1${NC}"; echo -e "${CYAN}========================================${NC}\n"; }

header "Cleanup - Removing All Resources"

echo -e "${RED}WARNING: This will delete all resources!${NC}"
read -p "Are you sure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

log "Deleting Argo CD application..."
argocd app delete tetris-app --yes 2>/dev/null || kubectl delete -f argocd/application.yaml 2>/dev/null || warn "Argo CD app not found"

log "Deleting Tetris application..."
kubectl delete -f k8s/ 2>/dev/null || warn "Tetris resources not found"
kubectl delete namespace tetris 2>/dev/null || warn "Tetris namespace not found"

log "Deleting monitoring stack..."
helm uninstall monitoring -n monitoring 2>/dev/null || true
kubectl delete -f monitoring/grafana/ 2>/dev/null || true
kubectl delete -f monitoring/alertmanager/ 2>/dev/null || true
kubectl delete -f monitoring/prometheus/ 2>/dev/null || true
kubectl delete namespace monitoring 2>/dev/null || warn "Monitoring namespace not found"

log "Deleting SonarQube..."
helm uninstall sonarqube -n sonarqube 2>/dev/null || true
kubectl delete namespace sonarqube 2>/dev/null || warn "SonarQube namespace not found"

log "Deleting Jenkins..."
helm uninstall jenkins -n jenkins 2>/dev/null || true
kubectl delete namespace jenkins 2>/dev/null || warn "Jenkins namespace not found"

log "Deleting Argo CD..."
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml 2>/dev/null || true
kubectl delete namespace argocd 2>/dev/null || warn "Argo CD namespace not found"

read -p "Delete Minikube cluster? (yes/no): " delete_minikube
if [ "$delete_minikube" == "yes" ]; then
    log "Deleting Minikube cluster..."
    minikube delete 2>/dev/null || warn "Minikube not found"
fi

read -p "Remove Docker images? (yes/no): " delete_images
if [ "$delete_images" == "yes" ]; then
    log "Removing Docker images..."
    docker rmi $(docker images -q "*tetris*") 2>/dev/null || warn "No tetris images found"
fi

header "Cleanup Complete!"
log "All resources have been removed."
