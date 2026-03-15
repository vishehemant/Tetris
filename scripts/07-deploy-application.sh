#!/bin/bash
set -euo pipefail

#######################################################################
# Script 07: Build and Deploy the Tetris Application (Kind cluster)
# Builds Docker image, loads into Kind, deploys to Kubernetes
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

DOCKER_USERNAME="${DOCKER_USERNAME:-YOUR_DOCKERHUB_USERNAME}"
IMAGE_NAME="tetris-app"
IMAGE_TAG="${1:-latest}"
FULL_IMAGE="${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"
CLUSTER_NAME="${KIND_CLUSTER_NAME:-tetris-devsecops}"

header "Step 1: Build Docker Image"

log "Building image: ${FULL_IMAGE}"
docker build -t "${FULL_IMAGE}" .
docker tag "${FULL_IMAGE}" "${DOCKER_USERNAME}/${IMAGE_NAME}:latest"

header "Step 2: Security Scan with Trivy"

log "Scanning Docker image..."
trivy image --severity HIGH,CRITICAL "${FULL_IMAGE}" || warn "Vulnerabilities found (review report)"

log "Scanning Dockerfile..."
trivy config Dockerfile || warn "Config issues found (review report)"

header "Step 3: Load Image into Kind Cluster"

log "Loading image into Kind cluster '${CLUSTER_NAME}'..."
kind load docker-image "${FULL_IMAGE}" --name "${CLUSTER_NAME}"
kind load docker-image "${DOCKER_USERNAME}/${IMAGE_NAME}:latest" --name "${CLUSTER_NAME}"
log "Image loaded into Kind cluster successfully."

header "Step 4: (Optional) Push to Docker Hub"

read -p "Also push image to Docker Hub? (yes/no): " push_to_hub
if [ "$push_to_hub" == "yes" ]; then
    log "Logging into Docker Hub..."
    docker login -u "${DOCKER_USERNAME}"
    log "Pushing image..."
    docker push "${FULL_IMAGE}"
    docker push "${DOCKER_USERNAME}/${IMAGE_NAME}:latest"
    log "Image pushed to Docker Hub."
fi

header "Step 5: Update Kubernetes Manifests"

log "Updating deployment with new image tag..."
sed -i "s|image: .*|image: ${FULL_IMAGE}|" k8s/deployment.yaml

header "Step 6: Deploy to Kubernetes"

log "Applying Kubernetes manifests..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/service-nodeport.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/network-policy.yaml

log "Waiting for deployment to be ready..."
kubectl rollout status deployment/tetris -n tetris --timeout=120s

header "Deployment Complete!"
echo ""
log "Application Status:"
kubectl get all -n tetris
echo ""
log "Access the application:"
echo "  - NodePort:     http://localhost:30080"
echo "  - Ingress:      http://tetris.local (add '127.0.0.1 tetris.local' to /etc/hosts)"
echo "  - Port-forward: kubectl port-forward svc/tetris-service -n tetris 8080:80"
echo "                  Then access at http://localhost:8080"
