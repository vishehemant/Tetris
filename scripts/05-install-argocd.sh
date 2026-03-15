#!/bin/bash
set -euo pipefail

#######################################################################
# Script 05: Install Argo CD on Kubernetes
# Sets up Argo CD for GitOps-based continuous deployment
#######################################################################

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
header() { echo -e "\n${CYAN}========================================${NC}"; echo -e "${CYAN} $1${NC}"; echo -e "${CYAN}========================================${NC}\n"; }

header "Installing Argo CD"

log "Creating argocd namespace..."
kubectl create namespace argocd 2>/dev/null || log "Namespace 'argocd' already exists"

log "Installing Argo CD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

log "Waiting for Argo CD pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

log "Patching Argo CD server to NodePort..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"port": 443, "targetPort": 8080, "nodePort": 30443}]}}'

header "Installing Argo CD CLI"

if command -v argocd &>/dev/null; then
    log "Argo CD CLI is already installed"
else
    log "Downloading Argo CD CLI..."
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm -f argocd-linux-amd64
    log "Argo CD CLI installed"
fi

header "Getting Argo CD Admin Password"

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

header "Argo CD Installation Complete!"
echo ""
log "Argo CD Server URL: https://<NODE_IP>:30443"
log "Username: admin"
log "Password: ${ARGOCD_PASSWORD}"
echo ""
warn "To get the URL on minikube: minikube service argocd-server -n argocd --url"
echo ""
log "Next Steps:"
echo "  1. Access Argo CD UI at https://<NODE_IP>:30443"
echo "  2. Login with admin / ${ARGOCD_PASSWORD}"
echo "  3. Change the default password"
echo "  4. Add your Git repository:"
echo "     argocd repo add https://github.com/YOUR_USERNAME/tetris-devsecops.git"
echo "  5. Deploy the Argo CD application:"
echo "     kubectl apply -f argocd/project.yaml"
echo "     kubectl apply -f argocd/application.yaml"
echo "  6. Or via CLI:"
echo "     argocd login <ARGOCD_SERVER> --username admin --password ${ARGOCD_PASSWORD} --insecure"
echo "     argocd app create tetris-app \\"
echo "       --repo https://github.com/YOUR_USERNAME/tetris-devsecops.git \\"
echo "       --path k8s \\"
echo "       --dest-server https://kubernetes.default.svc \\"
echo "       --dest-namespace tetris \\"
echo "       --sync-policy automated \\"
echo "       --auto-prune \\"
echo "       --self-heal"
