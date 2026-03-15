#!/bin/bash
set -euo pipefail

#######################################################################
# Script 02: Set Up Kubernetes Cluster using Kind
# Creates a Kind (Kubernetes IN Docker) cluster with port mappings
# for all services (Jenkins, SonarQube, Argo CD, Monitoring, App)
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

CLUSTER_NAME="${1:-tetris-devsecops}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
KIND_CONFIG="${PROJECT_ROOT}/kind-config.yaml"

header "Setting up Kind Cluster: ${CLUSTER_NAME}"

if ! command -v kind &>/dev/null; then
    err "Kind is not installed. Run ./scripts/01-install-prerequisites.sh first."
    exit 1
fi

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    warn "Cluster '${CLUSTER_NAME}' already exists."
    read -p "Delete and recreate? (yes/no): " recreate
    if [ "$recreate" == "yes" ]; then
        log "Deleting existing cluster..."
        kind delete cluster --name "${CLUSTER_NAME}"
    else
        log "Using existing cluster."
        kubectl cluster-info --context "kind-${CLUSTER_NAME}"
        exit 0
    fi
fi

log "Creating Kind cluster with port mappings..."
kind create cluster --name "${CLUSTER_NAME}" --config "${KIND_CONFIG}" --wait 120s

log "Setting kubectl context..."
kubectl cluster-info --context "kind-${CLUSTER_NAME}"

header "Installing NGINX Ingress Controller (Kind-compatible)"

log "Applying NGINX Ingress Controller for Kind..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

log "Waiting for Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s || warn "Ingress controller may take a moment to start"

header "Installing Metrics Server"

log "Applying Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

log "Patching Metrics Server for Kind (disable TLS verification)..."
kubectl patch deployment metrics-server -n kube-system \
    --type='json' \
    -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]' \
    2>/dev/null || warn "Metrics Server patch may already be applied"

header "Kind Cluster Setup Complete!"
echo ""
log "Cluster Info:"
kubectl cluster-info
echo ""
log "Nodes:"
kubectl get nodes -o wide
echo ""
log "All system pods:"
kubectl get pods -A
echo ""
log "Port Mappings (accessible on localhost):"
echo "  - Port 80/443:  Ingress Controller"
echo "  - Port 30080:   Tetris App / Jenkins"
echo "  - Port 30443:   Argo CD"
echo "  - Port 30090:   Prometheus"
echo "  - Port 30030:   Grafana"
echo "  - Port 30093:   AlertManager"
echo "  - Port 30900:   SonarQube"
echo ""
warn "All NodePort services are accessible via http://localhost:<port>"
