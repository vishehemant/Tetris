#!/bin/bash
set -euo pipefail

#######################################################################
# Script 02: Set Up Kubernetes Cluster
# Options: minikube (local dev) or kubeadm (production-like)
# Default: minikube for learning/practice
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

CLUSTER_TYPE="${1:-minikube}"

if [ "$CLUSTER_TYPE" == "minikube" ]; then

    header "Setting up Minikube Cluster"

    if command -v minikube &>/dev/null; then
        log "Minikube is already installed"
    else
        log "Installing Minikube..."
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
        rm -f minikube-linux-amd64
    fi

    log "Starting Minikube cluster..."
    minikube start \
        --driver=docker \
        --cpus=4 \
        --memory=8192 \
        --disk-size=40g \
        --kubernetes-version=stable \
        --addons=ingress,metrics-server,dashboard

    log "Enabling Minikube addons..."
    minikube addons enable ingress
    minikube addons enable metrics-server
    minikube addons enable dashboard

    log "Minikube cluster is ready!"
    kubectl cluster-info
    kubectl get nodes

elif [ "$CLUSTER_TYPE" == "kubeadm" ]; then

    header "Setting up Kubernetes with kubeadm"
    warn "This will set up a single-node cluster. For multi-node, repeat worker steps on other nodes."

    log "Disabling swap..."
    sudo swapoff -a
    sudo sed -i '/ swap / s/^/#/' /etc/fstab

    log "Loading required kernel modules..."
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
    sudo modprobe overlay
    sudo modprobe br_netfilter

    log "Setting sysctl params..."
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    sudo sysctl --system

    log "Installing kubeadm, kubelet, kubectl..."
    sudo apt-get update -y
    sudo apt-get install -y apt-transport-https ca-certificates curl gpg

    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

    sudo apt-get update -y
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl

    log "Initializing cluster..."
    sudo kubeadm init --pod-network-cidr=10.244.0.0/16

    log "Configuring kubectl..."
    mkdir -p "$HOME/.kube"
    sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
    sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

    log "Installing Calico CNI..."
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

    log "Allowing scheduling on control-plane (single-node)..."
    kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

    log "Installing NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/baremetal/deploy.yaml

    log "Installing Metrics Server..."
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

    log "Kubeadm cluster is ready!"
    kubectl cluster-info
    kubectl get nodes
fi

header "Kubernetes Cluster Setup Complete!"
echo ""
log "Cluster Info:"
kubectl cluster-info
echo ""
log "Nodes:"
kubectl get nodes -o wide
echo ""
log "All system pods:"
kubectl get pods -A
