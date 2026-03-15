#!/bin/bash
set -euo pipefail

#######################################################################
# Script 08: Configure Argo CD Application
# Sets up the Argo CD application for GitOps continuous deployment
#######################################################################

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
header() { echo -e "\n${CYAN}========================================${NC}"; echo -e "${CYAN} $1${NC}"; echo -e "${CYAN}========================================${NC}\n"; }

GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/YOUR_GITHUB_USERNAME/tetris-devsecops.git}"

header "Setting up Argo CD Application"

log "Getting Argo CD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

log "Getting Argo CD server address..."
ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.clusterIP}')

log "Logging into Argo CD..."
argocd login "${ARGOCD_SERVER}" \
    --username admin \
    --password "${ARGOCD_PASSWORD}" \
    --insecure \
    --grpc-web

log "Adding Git repository..."
argocd repo add "${GIT_REPO_URL}" || warn "Repository may already be added"

log "Creating Argo CD project..."
kubectl apply -f argocd/project.yaml

log "Creating Argo CD application..."
kubectl apply -f argocd/application.yaml

log "Syncing application..."
argocd app sync tetris-app || warn "Auto-sync is enabled, application will sync automatically"

log "Waiting for application to be healthy..."
argocd app wait tetris-app --health --timeout 120 || warn "Application may take a moment to become healthy"

header "Argo CD Application Setup Complete!"
echo ""
log "Application Status:"
argocd app get tetris-app
echo ""
log "The application is now managed by Argo CD."
log "Any changes to the k8s/ directory in Git will be automatically synced."
echo ""
log "Useful Argo CD commands:"
echo "  argocd app get tetris-app        # Check app status"
echo "  argocd app sync tetris-app       # Manual sync"
echo "  argocd app diff tetris-app       # Show diff"
echo "  argocd app history tetris-app    # Show history"
echo "  argocd app rollback tetris-app 1 # Rollback to revision"
