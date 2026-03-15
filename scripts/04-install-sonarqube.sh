#!/bin/bash
set -euo pipefail

#######################################################################
# Script 04: Install SonarQube on Kubernetes
# Installs SonarQube Community Edition for code quality analysis
#######################################################################

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
header() { echo -e "\n${CYAN}========================================${NC}"; echo -e "${CYAN} $1${NC}"; echo -e "${CYAN}========================================${NC}\n"; }

header "Installing SonarQube on Kubernetes"

log "Creating namespace..."
kubectl create namespace sonarqube 2>/dev/null || log "Namespace 'sonarqube' already exists"

log "Setting kernel parameter for Elasticsearch..."
# SonarQube needs this on the host
sudo sysctl -w vm.max_map_count=524288 2>/dev/null || warn "Could not set vm.max_map_count (may need host access)"
sudo sysctl -w fs.file-max=131072 2>/dev/null || warn "Could not set fs.file-max"

log "Adding SonarQube Helm repository..."
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update

log "Installing SonarQube..."
helm install sonarqube sonarqube/sonarqube \
    --namespace sonarqube \
    --set service.type=NodePort \
    --set service.nodePort=30900 \
    --set account.adminPassword=admin123 \
    --set persistence.enabled=true \
    --set persistence.size=10Gi \
    --wait --timeout=10m

log "Waiting for SonarQube to be ready..."
kubectl wait --for=condition=ready pod -l app=sonarqube -n sonarqube --timeout=600s || warn "SonarQube may take a few minutes to start"

header "SonarQube Installation Complete!"
echo ""
log "SonarQube URL: http://<NODE_IP>:30900"
log "Default credentials: admin / admin123"
echo ""
log "Next Steps:"
echo "  1. Access SonarQube UI"
echo "  2. Change the default admin password"
echo "  3. Generate a project token:"
echo "     - Go to: My Account -> Security -> Generate Tokens"
echo "     - Name: jenkins-sonar-token"
echo "     - Copy the token"
echo "  4. Create a project:"
echo "     - Go to: Projects -> Create Project"
echo "     - Project Key: tetris-app"
echo "     - Display Name: Tetris App"
echo "  5. Configure Jenkins:"
echo "     - Jenkins -> Manage Jenkins -> Configure System"
echo "     - Add SonarQube Server:"
echo "       Name: sonarqube-server"
echo "       URL: http://sonarqube-sonarqube.sonarqube.svc.cluster.local:9000"
echo "       Token: (add the token from step 3 as a credential)"
echo "     - Jenkins -> Manage Jenkins -> Global Tool Configuration"
echo "     - Add SonarQube Scanner:"
echo "       Name: sonar-scanner"
echo "       Install automatically: checked"
