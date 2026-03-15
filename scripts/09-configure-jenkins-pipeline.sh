#!/bin/bash
set -euo pipefail

#######################################################################
# Script 09: Configure Jenkins Pipeline
# Provides step-by-step instructions for Jenkins pipeline configuration
#######################################################################

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
header() { echo -e "\n${CYAN}========================================${NC}"; echo -e "${CYAN} $1${NC}"; echo -e "${CYAN}========================================${NC}\n"; }

header "Jenkins Pipeline Configuration Guide"

echo "
╔══════════════════════════════════════════════════════════════╗
║                JENKINS CONFIGURATION STEPS                   ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  STEP 1: Add Credentials                                     ║
║  ────────────────────────                                     ║
║  Go to: Manage Jenkins → Credentials → System → Global       ║
║                                                              ║
║  a) Docker Hub Credentials:                                   ║
║     - Kind: Username with password                            ║
║     - ID:   dockerhub-credentials                             ║
║     - Username: your-dockerhub-username                       ║
║     - Password: your-dockerhub-password                       ║
║                                                              ║
║  b) GitHub Credentials:                                       ║
║     - Kind: Username with password                            ║
║     - ID:   github-credentials                                ║
║     - Username: your-github-username                          ║
║     - Password: your-github-pat-token                         ║
║                                                              ║
║  STEP 2: Configure SonarQube                                  ║
║  ──────────────────────────                                   ║
║  a) System Configuration:                                     ║
║     Go to: Manage Jenkins → System                            ║
║     - SonarQube servers → Add SonarQube                       ║
║     - Name: sonarqube-server                                  ║
║     - URL: http://sonarqube-sonarqube.sonarqube:9000          ║
║     - Token: (create credential with SonarQube token)         ║
║                                                              ║
║  b) Tool Configuration:                                       ║
║     Go to: Manage Jenkins → Tools                             ║
║     - SonarQube Scanner installations → Add                   ║
║     - Name: sonar-scanner                                     ║
║     - Install automatically: ✓                                ║
║                                                              ║
║  STEP 3: Install Trivy on Jenkins                             ║
║  ─────────────────────────────────                            ║
║  If Jenkins is on K8s, Trivy needs to be in the agent image.  ║
║  For standalone Jenkins:                                      ║
║     sudo apt-get install trivy                                ║
║                                                              ║
║  STEP 4: Create Pipeline Job                                  ║
║  ───────────────────────────                                  ║
║  a) New Item → Pipeline                                       ║
║  b) Name: tetris-devsecops-pipeline                           ║
║  c) Pipeline section:                                         ║
║     - Definition: Pipeline script from SCM                    ║
║     - SCM: Git                                                ║
║     - Repository URL: your-github-repo-url                    ║
║     - Credentials: github-credentials                         ║
║     - Branch: */main                                          ║
║     - Script Path: Jenkinsfile                                ║
║                                                              ║
║  STEP 5: Configure Webhook (auto-trigger)                     ║
║  ─────────────────────────────────────────                    ║
║  In GitHub repo → Settings → Webhooks → Add:                  ║
║  - URL: http://<JENKINS_URL>/github-webhook/                  ║
║  - Content type: application/json                             ║
║  - Events: Push events                                        ║
║                                                              ║
║  In Jenkins job → Configure:                                  ║
║  - Build Triggers → GitHub hook trigger for GITScm polling    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
"

log "After completing these steps, your CI/CD pipeline will:"
echo "  1. Trigger on every git push"
echo "  2. Run SonarQube code analysis"
echo "  3. Build Docker image"
echo "  4. Scan with Trivy (image + filesystem + Dockerfile)"
echo "  5. Push image to Docker Hub"
echo "  6. Update K8s manifests with new image tag"
echo "  7. Argo CD detects the change and deploys automatically"
