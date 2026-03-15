#!/bin/bash
set -euo pipefail

#######################################################################
# Script 06: Install Monitoring Stack (Kind cluster)
# Installs: Prometheus, Grafana, AlertManager
# Option A: Using manifests (from this repo)
# Option B: Using kube-prometheus-stack Helm chart (recommended for prod)
#######################################################################

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
header() { echo -e "\n${CYAN}========================================${NC}"; echo -e "${CYAN} $1${NC}"; echo -e "${CYAN}========================================${NC}\n"; }

INSTALL_METHOD="${1:-manifests}"

if [ "$INSTALL_METHOD" == "helm" ]; then

    header "Installing Monitoring Stack via Helm (kube-prometheus-stack)"

    log "Adding Helm repositories..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update

    log "Creating monitoring namespace..."
    kubectl create namespace monitoring 2>/dev/null || log "Namespace 'monitoring' already exists"

    log "Installing kube-prometheus-stack..."
    helm install monitoring prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --set grafana.adminPassword=admin123 \
        --set grafana.service.type=NodePort \
        --set grafana.service.nodePort=30030 \
        --set prometheus.service.type=NodePort \
        --set prometheus.service.nodePort=30090 \
        --set alertmanager.service.type=NodePort \
        --set alertmanager.service.nodePort=30093 \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
        --wait --timeout=10m

    log "Applying custom alert rules..."
    kubectl apply -f monitoring/prometheus/prometheus-config.yaml

elif [ "$INSTALL_METHOD" == "manifests" ]; then

    header "Installing Monitoring Stack via Manifests"

    log "Applying Prometheus configuration..."
    kubectl apply -f monitoring/prometheus/prometheus-config.yaml

    log "Deploying Prometheus..."
    kubectl apply -f monitoring/prometheus/prometheus-deployment.yaml

    log "Deploying AlertManager..."
    kubectl apply -f monitoring/alertmanager/alertmanager-config.yaml
    kubectl apply -f monitoring/alertmanager/alertmanager-deployment.yaml

    log "Deploying Grafana..."
    kubectl apply -f monitoring/grafana/grafana-datasources.yaml
    kubectl apply -f monitoring/grafana/grafana-dashboards-provider.yaml
    kubectl apply -f monitoring/grafana/grafana-dashboards.yaml
    kubectl apply -f monitoring/grafana/grafana-deployment.yaml

    log "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=120s || warn "Prometheus may take a moment"
    kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=120s || warn "Grafana may take a moment"
    kubectl wait --for=condition=ready pod -l app=alertmanager -n monitoring --timeout=120s || warn "AlertManager may take a moment"

fi

header "Monitoring Stack Installation Complete!"
echo ""
log "Access URLs (Kind - all via localhost):"
echo "  - Prometheus:   http://localhost:30090"
echo "  - Grafana:      http://localhost:30030 (admin/admin123)"
echo "  - AlertManager: http://localhost:30093"
echo ""
warn "If ports are not reachable, use port-forward as fallback:"
warn "  kubectl port-forward svc/prometheus -n monitoring 9090:9090"
warn "  kubectl port-forward svc/grafana -n monitoring 3000:3000"
warn "  kubectl port-forward svc/alertmanager -n monitoring 9093:9093"
echo ""
log "Monitoring pods:"
kubectl get pods -n monitoring
echo ""
log "Next Steps:"
echo "  1. Access Grafana at http://localhost:30030"
echo "  2. Login with admin / admin123"
echo "  3. Pre-configured dashboards are available under 'Dashboards'"
echo "  4. Import additional dashboards from https://grafana.com/grafana/dashboards/"
echo "     Recommended IDs:"
echo "       - 3119  (Kubernetes cluster monitoring)"
echo "       - 6417  (Kubernetes pods monitoring)"
echo "       - 315   (Kubernetes deployment)"
echo "       - 12740 (Kubernetes pod resources)"
echo "  5. Configure AlertManager for notifications (Slack, Email, PagerDuty)"
