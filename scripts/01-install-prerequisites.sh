#!/bin/bash
set -euo pipefail

#######################################################################
# Script 01: Install Prerequisites
# Installs: Docker, kubectl, Helm, Kind, Trivy, Java
# Platform: Ubuntu/Debian
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

header "Step 1: System Update"
sudo apt-get update -y
sudo apt-get upgrade -y

header "Step 2: Install Docker"
if command -v docker &>/dev/null; then
    log "Docker is already installed: $(docker --version)"
else
    log "Installing Docker..."
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker "$USER"
    log "Docker installed: $(docker --version)"
fi

header "Step 3: Install kubectl"
if command -v kubectl &>/dev/null; then
    log "kubectl is already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
    log "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
    log "kubectl installed: $(kubectl version --client 2>/dev/null)"
fi

header "Step 4: Install Kind"
if command -v kind &>/dev/null; then
    log "Kind is already installed: $(kind version)"
else
    log "Installing Kind..."
    [ "$(uname -m)" = "x86_64" ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.25.0/kind-linux-amd64
    [ "$(uname -m)" = "aarch64" ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.25.0/kind-linux-arm64
    sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
    rm -f kind
    log "Kind installed: $(kind version)"
fi

header "Step 5: Install Helm"
if command -v helm &>/dev/null; then
    log "Helm is already installed: $(helm version --short)"
else
    log "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    log "Helm installed: $(helm version --short)"
fi

header "Step 6: Install Trivy"
if command -v trivy &>/dev/null; then
    log "Trivy is already installed: $(trivy --version)"
else
    log "Installing Trivy..."
    sudo apt-get install -y wget apt-transport-https gnupg lsb-release
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list
    sudo apt-get update -y
    sudo apt-get install -y trivy
    log "Trivy installed: $(trivy --version)"
fi

header "Step 7: Install Java (for Jenkins)"
if command -v java &>/dev/null; then
    log "Java is already installed: $(java -version 2>&1 | head -1)"
else
    log "Installing OpenJDK 17..."
    sudo apt-get install -y fontconfig openjdk-17-jre
    log "Java installed: $(java -version 2>&1 | head -1)"
fi

header "Prerequisites Installation Complete!"
log "Installed tools:"
echo "  - Docker:  $(docker --version 2>/dev/null || echo 'not found')"
echo "  - kubectl: $(kubectl version --client --short 2>/dev/null || echo 'not found')"
echo "  - Kind:    $(kind version 2>/dev/null || echo 'not found')"
echo "  - Helm:    $(helm version --short 2>/dev/null || echo 'not found')"
echo "  - Trivy:   $(trivy --version 2>/dev/null || echo 'not found')"
echo "  - Java:    $(java -version 2>&1 | head -1 || echo 'not found')"
echo ""
warn "NOTE: You may need to log out and log back in for Docker group changes to take effect."
warn "Run: newgrp docker"
