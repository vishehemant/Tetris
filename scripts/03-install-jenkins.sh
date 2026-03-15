#!/bin/bash
set -euo pipefail

#######################################################################
# Script 03: Install Jenkins on Kubernetes
# Installs Jenkins using Helm chart with pre-configured plugins
#######################################################################

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
header() { echo -e "\n${CYAN}========================================${NC}"; echo -e "${CYAN} $1${NC}"; echo -e "${CYAN}========================================${NC}\n"; }

INSTALL_METHOD="${1:-helm}"

if [ "$INSTALL_METHOD" == "helm" ]; then

    header "Installing Jenkins via Helm"

    log "Adding Jenkins Helm repository..."
    helm repo add jenkins https://charts.jenkins.io
    helm repo update

    log "Creating Jenkins namespace..."
    kubectl create namespace jenkins 2>/dev/null || log "Namespace 'jenkins' already exists"

    log "Installing Jenkins..."
    helm install jenkins jenkins/jenkins \
        --namespace jenkins \
        --set controller.serviceType=NodePort \
        --set controller.nodePort=30080 \
        --set controller.admin.username=admin \
        --set controller.admin.password=admin123 \
        --set controller.installPlugins[0]=kubernetes:latest \
        --set controller.installPlugins[1]=workflow-aggregator:latest \
        --set controller.installPlugins[2]=git:latest \
        --set controller.installPlugins[3]=docker-workflow:latest \
        --set controller.installPlugins[4]=sonar:latest \
        --set controller.installPlugins[5]=pipeline-stage-view:latest \
        --set controller.installPlugins[6]=blueocean:latest \
        --set controller.installPlugins[7]=credentials-binding:latest \
        --set controller.installPlugins[8]=pipeline-utility-steps:latest \
        --set controller.installPlugins[9]=htmlpublisher:latest \
        --set controller.installPlugins[10]=slack:latest \
        --set persistence.size=20Gi \
        --wait --timeout=10m

    log "Waiting for Jenkins to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=jenkins -n jenkins --timeout=300s

elif [ "$INSTALL_METHOD" == "standalone" ]; then

    header "Installing Jenkins Standalone (VM)"

    log "Adding Jenkins repository..."
    sudo wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y jenkins

    sudo systemctl enable jenkins
    sudo systemctl start jenkins

    log "Waiting for Jenkins to start..."
    sleep 30

    log "Jenkins initial admin password:"
    sudo cat /var/lib/jenkins/secrets/initialAdminPassword
fi

header "Jenkins Installation Complete!"
echo ""
if [ "$INSTALL_METHOD" == "helm" ]; then
    JENKINS_URL=$(minikube service jenkins -n jenkins --url 2>/dev/null || echo "http://<NODE_IP>:30080")
    log "Jenkins URL: ${JENKINS_URL}"
    log "Username: admin"
    log "Password: admin123"
    echo ""
    warn "To get Jenkins URL on minikube: minikube service jenkins -n jenkins --url"
    warn "To get Jenkins URL on cloud: http://<NODE_EXTERNAL_IP>:30080"
else
    log "Jenkins URL: http://localhost:8080"
    log "Initial password: $(sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo 'Check /var/lib/jenkins/secrets/initialAdminPassword')"
fi

echo ""
log "Next Steps:"
echo "  1. Access Jenkins UI"
echo "  2. Install suggested plugins"
echo "  3. Configure the following:"
echo "     a. Docker Hub credentials (ID: dockerhub-credentials)"
echo "     b. GitHub credentials (ID: github-credentials)"
echo "     c. SonarQube server configuration"
echo "     d. SonarQube scanner tool"
echo "  4. Create a pipeline job pointing to your Git repository"
