# Tetris - DevSecOps CI/CD Pipeline on Kubernetes

A complete, production-ready DevSecOps CI/CD pipeline that deploys a Tetris game on Kubernetes using industry-standard tools and best practices. Uses **Kind (Kubernetes IN Docker)** for local cluster setup.

## Architecture Overview

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   GitHub     │────▶│   Jenkins    │────▶│  Docker Hub  │     │  Argo CD     │
│  (Source)    │     │   (CI)       │     │  (Registry)  │     │  (CD/GitOps) │
└─────────────┘     └──────┬───────┘     └──────────────┘     └──────┬───────┘
                           │                                         │
                    ┌──────┴───────┐                          ┌──────┴───────┐
                    │  SonarQube   │                          │  Kubernetes  │
                    │  + Trivy     │                          │  (Kind)      │
                    │  (Security)  │                          └──────┬───────┘
                    └──────────────┘                                 │
                                                             ┌──────┴───────┐
                                                             │ Prometheus   │
                                                             │ Grafana      │
                                                             │ AlertManager │
                                                             │ (Monitoring) │
                                                             └──────────────┘
```

### Pipeline Flow

1. **Developer pushes code** to GitHub
2. **Jenkins (CI)** triggers automatically via webhook:
   - Pulls source code
   - Runs SonarQube code quality analysis
   - Checks quality gate pass/fail
   - Builds Docker image
   - Scans with Trivy (image vulnerabilities, filesystem, Dockerfile misconfigs)
   - Pushes image to Docker Hub
   - Updates Kubernetes manifests with new image tag
   - Commits manifest changes back to Git
3. **Argo CD (CD)** detects Git changes:
   - Syncs Kubernetes manifests automatically
   - Deploys the new version with rolling update
   - Self-heals if drift is detected
4. **Monitoring stack** observes the application:
   - Prometheus scrapes metrics
   - Grafana visualizes dashboards
   - AlertManager sends notifications on anomalies

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Repository Structure](#repository-structure)
- [Step 1: Install Prerequisites](#step-1-install-prerequisites)
- [Step 2: Set Up Kubernetes Cluster (Kind)](#step-2-set-up-kubernetes-cluster-kind)
- [Step 3: Install Jenkins (CI Server)](#step-3-install-jenkins-ci-server)
- [Step 4: Install SonarQube (Code Quality)](#step-4-install-sonarqube-code-quality)
- [Step 5: Install Argo CD (GitOps CD)](#step-5-install-argo-cd-gitops-cd)
- [Step 6: Install Monitoring Stack](#step-6-install-monitoring-stack)
- [Step 7: Build and Deploy the Application](#step-7-build-and-deploy-the-application)
- [Step 8: Configure the CI/CD Pipeline](#step-8-configure-the-cicd-pipeline)
- [Step 9: Test the Full Pipeline](#step-9-test-the-full-pipeline)
- [Step 10: Production Considerations](#step-10-production-considerations)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

---

## Prerequisites

| Tool | Purpose | Minimum Version |
|------|---------|-----------------|
| Ubuntu/Debian | Host OS | 20.04+ |
| Docker | Containerization | 24.0+ |
| Kind | Local Kubernetes cluster | 0.20+ |
| kubectl | Kubernetes CLI | 1.28+ |
| Helm | Kubernetes package manager | 3.12+ |
| Git | Version control | 2.30+ |
| Trivy | Vulnerability scanning | 0.48+ |
| Java (JDK 17) | Jenkins runtime | 17+ |

**Hardware Requirements (for local practice):**
- CPU: 4+ cores
- RAM: 16 GB minimum (8 GB for Kind cluster + tools)
- Disk: 50 GB free space

---

## Repository Structure

```
tetris-devsecops/
├── app/                              # Application source code
│   ├── index.html                    # Tetris game HTML
│   ├── css/
│   │   └── style.css                 # Game styles
│   ├── js/
│   │   └── tetris.js                 # Game logic
│   └── nginx.conf                    # Nginx server configuration
│
├── k8s/                              # Kubernetes manifests
│   ├── namespace.yaml                # Tetris namespace
│   ├── deployment.yaml               # Application deployment
│   ├── service.yaml                  # ClusterIP service
│   ├── service-nodeport.yaml         # NodePort service (for external access)
│   ├── ingress.yaml                  # Ingress rules
│   ├── hpa.yaml                      # Horizontal Pod Autoscaler
│   └── network-policy.yaml           # Network security policies
│
├── argocd/                           # Argo CD configurations
│   ├── application.yaml              # Argo CD application definition
│   ├── project.yaml                  # Argo CD project
│   └── repository.yaml              # Git repository secret
│
├── monitoring/                       # Monitoring stack
│   ├── prometheus/
│   │   ├── prometheus-config.yaml    # Prometheus config + alert rules
│   │   └── prometheus-deployment.yaml# Prometheus deployment + RBAC
│   ├── grafana/
│   │   ├── grafana-deployment.yaml   # Grafana deployment
│   │   ├── grafana-datasources.yaml  # Prometheus datasource
│   │   ├── grafana-dashboards-provider.yaml
│   │   └── grafana-dashboards.yaml   # Pre-built dashboards (Tetris + K8s)
│   └── alertmanager/
│       ├── alertmanager-config.yaml  # Alert routing rules
│       └── alertmanager-deployment.yaml
│
├── scripts/                          # Installation & setup scripts
│   ├── 01-install-prerequisites.sh   # Docker, kubectl, Kind, Helm, Trivy
│   ├── 02-setup-kubernetes.sh        # Kind cluster setup
│   ├── 03-install-jenkins.sh         # Jenkins (Helm or standalone)
│   ├── 04-install-sonarqube.sh       # SonarQube on Kubernetes
│   ├── 05-install-argocd.sh          # Argo CD installation
│   ├── 06-install-monitoring.sh      # Prometheus + Grafana + AlertManager
│   ├── 07-deploy-application.sh      # Build, scan, deploy Tetris
│   ├── 08-setup-argocd-app.sh        # Configure Argo CD application
│   ├── 09-configure-jenkins-pipeline.sh  # Jenkins configuration guide
│   └── 10-cleanup.sh                 # Remove all resources
│
├── kind-config.yaml                  # Kind cluster configuration with port mappings
├── Dockerfile                        # Docker build for Tetris app
├── .dockerignore                     # Docker build exclusions
├── docker-compose.yml                # Local dev environment
├── Jenkinsfile                       # CI pipeline definition
├── sonar-project.properties          # SonarQube project config
├── .gitignore
└── README.md                         # This file
```

---

## Step 1: Install Prerequisites

> **What this does:** Installs Docker, kubectl, Kind, Helm, Trivy, and Java on your machine. These are the foundational tools needed for everything else.

```bash
chmod +x scripts/*.sh
./scripts/01-install-prerequisites.sh
```

### What Gets Installed

| Tool | Why It's Needed |
|------|----------------|
| **Docker** | Builds and runs container images. Kind uses Docker to run the Kubernetes cluster nodes as containers. |
| **Kind** | Creates local Kubernetes clusters using Docker containers as nodes. Lightweight and fast. |
| **kubectl** | Command-line tool to interact with Kubernetes clusters. |
| **Helm** | Package manager for Kubernetes - simplifies installing complex apps (Jenkins, Prometheus, etc.). |
| **Trivy** | Security scanner that checks Docker images, filesystems, and config files for vulnerabilities. |
| **Java 17** | Required runtime for Jenkins. |

### Manual Verification

```bash
docker --version        # Should show 24.x+
kind version             # Should show v0.20+
kubectl version --client # Should show v1.28+
helm version --short     # Should show v3.12+
trivy --version          # Should show 0.48+
java -version            # Should show 17+
```

---

## Step 2: Set Up Kubernetes Cluster (Kind)

> **What this does:** Creates a Kind (Kubernetes IN Docker) cluster with pre-configured port mappings so all services are accessible on localhost. Kind runs the entire Kubernetes cluster inside Docker containers, making it fast to create and destroy.

```bash
./scripts/02-setup-kubernetes.sh
```

### What Happens

1. Creates a Kind cluster named `tetris-devsecops` using `kind-config.yaml`
2. Maps NodePort ranges to localhost (so you can access services via `localhost:<port>`)
3. Installs the NGINX Ingress Controller (Kind-specific variant)
4. Installs the Metrics Server (patched for Kind's self-signed certs)

### Kind Cluster Configuration

The `kind-config.yaml` defines port mappings:

| Host Port | Kubernetes Port | Purpose |
|-----------|----------------|---------|
| 80, 443 | 80, 443 | Ingress Controller |
| 30080 | 30080 | Tetris App / Jenkins |
| 30443 | 30443 | Argo CD |
| 30090 | 30090 | Prometheus |
| 30030 | 30030 | Grafana |
| 30093 | 30093 | AlertManager |
| 30900 | 30900 | SonarQube |

### Verify Cluster

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
```

> **Key Concept:** Kind runs Kubernetes cluster nodes as Docker containers on your machine. Unlike a full VM-based cluster, Kind is extremely fast to spin up (under 60 seconds) and uses minimal resources. The `extraPortMappings` in `kind-config.yaml` forward ports from your host into the cluster, so NodePort services are accessible on `localhost`.

> **Kind vs Minikube:** Kind is lighter and faster. It uses Docker containers instead of VMs. It's preferred for CI/CD testing and local development. Multiple clusters can run simultaneously.

---

## Step 3: Install Jenkins (CI Server)

> **What this does:** Installs Jenkins, which will be the CI (Continuous Integration) server. Jenkins automates building, testing, scanning, and pushing your Docker images.

### Install via Helm (Recommended)

```bash
./scripts/03-install-jenkins.sh helm
```

### Install Standalone (on VM directly)

```bash
./scripts/03-install-jenkins.sh standalone
```

### Access Jenkins

```bash
# Kind - directly via localhost
open http://localhost:30080

# Fallback via port-forward
kubectl port-forward svc/jenkins -n jenkins 8080:8080
open http://localhost:8080
```

- **Username:** `admin`
- **Password:** `admin123` (Helm) or check `/var/lib/jenkins/secrets/initialAdminPassword` (standalone)

### Configure Jenkins (Manual Steps)

After installation, you need to configure Jenkins through the UI:

#### 1. Install Required Plugins

Go to **Manage Jenkins -> Plugins -> Available Plugins** and install:
- Docker Pipeline
- SonarQube Scanner
- Pipeline: Stage View
- Blue Ocean
- HTML Publisher
- Slack Notification (optional)

#### 2. Add Credentials

Go to **Manage Jenkins -> Credentials -> System -> Global credentials**:

| Credential | ID | Type | Purpose |
|---|---|---|---|
| Docker Hub | `dockerhub-credentials` | Username/Password | Push images to Docker Hub |
| GitHub | `github-credentials` | Username/Password (use PAT as password) | Pull code and push manifest updates |
| SonarQube Token | `sonarqube-token` | Secret text | Authenticate with SonarQube |

#### 3. Configure SonarQube Server

Go to **Manage Jenkins -> System**:
- Scroll to **SonarQube servers**
- Click **Add SonarQube**
- Name: `sonarqube-server`
- Server URL: `http://sonarqube-sonarqube.sonarqube.svc.cluster.local:9000`
- Server authentication token: select your SonarQube token credential

#### 4. Configure SonarQube Scanner Tool

Go to **Manage Jenkins -> Tools**:
- Scroll to **SonarQube Scanner installations**
- Click **Add SonarQube Scanner**
- Name: `sonar-scanner`
- Check **Install automatically**

> **Key Concept:** Jenkins is the CI engine. It listens for Git pushes (via webhooks) and runs the pipeline defined in `Jenkinsfile`. Think of it as an automated assembly line for your code.

---

## Step 4: Install SonarQube (Code Quality)

> **What this does:** Installs SonarQube, a code quality and security analysis tool. It scans your source code for bugs, code smells, vulnerabilities, and duplications.

```bash
./scripts/04-install-sonarqube.sh
```

### Access SonarQube

```bash
# Kind - directly via localhost
open http://localhost:30900

# Fallback via port-forward
kubectl port-forward svc/sonarqube-sonarqube -n sonarqube 9000:9000
open http://localhost:9000
```

- **Username:** `admin`
- **Password:** `admin123`

### Configure SonarQube (Manual Steps)

1. **Change default password** on first login

2. **Generate a token:**
   - Go to **My Account -> Security -> Generate Tokens**
   - Name: `jenkins-sonar-token`
   - Type: Global Analysis Token
   - Copy the token (you'll need it for Jenkins)

3. **Create a project:**
   - Go to **Projects -> Create Project -> Manually**
   - Project Key: `tetris-app`
   - Display Name: `Tetris App`

> **Key Concept:** SonarQube performs static code analysis. It doesn't run your code - it reads it and finds potential problems. The "Quality Gate" is a pass/fail threshold. If your code quality drops below the gate, the Jenkins pipeline will fail, preventing bad code from reaching production.

---

## Step 5: Install Argo CD (GitOps CD)

> **What this does:** Installs Argo CD, a GitOps-based continuous deployment tool. It watches your Git repository and automatically syncs Kubernetes manifests to the cluster.

```bash
./scripts/05-install-argocd.sh
```

### Access Argo CD

```bash
# Get the admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# Kind - directly via localhost
open https://localhost:30443

# Fallback via port-forward
kubectl port-forward svc/argocd-server -n argocd 8443:443
open https://localhost:8443
```

### Set Up the Argo CD Application

```bash
# Update the Git repo URL in argocd/application.yaml first!
# Then run:
./scripts/08-setup-argocd-app.sh
```

Or manually via CLI:

```bash
# Login (via Kind NodePort)
argocd login localhost:30443 --username admin --password <PASSWORD> --insecure

# Create application
argocd app create tetris-app \
  --repo https://github.com/YOUR_USERNAME/tetris-devsecops.git \
  --path k8s \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace tetris \
  --sync-policy automated \
  --auto-prune \
  --self-heal
```

> **Key Concept:** Argo CD implements GitOps - the idea that Git is the single source of truth for your infrastructure. Instead of running `kubectl apply` manually, Argo CD watches the `k8s/` directory in Git and automatically applies any changes. If someone manually changes something in the cluster, Argo CD will detect the "drift" and revert it (self-healing).

### How Jenkins + Argo CD Work Together

```
Jenkins (CI)                          Argo CD (CD)
─────────────                         ───────────────
1. Build image                        5. Detect Git change
2. Scan with Trivy                    6. Compare desired vs actual state
3. Push to Docker Hub                 7. Apply new manifests
4. Update k8s/deployment.yaml         8. Rolling update in K8s
   (commit & push to Git)             9. Self-heal if drift detected
```

This separation means:
- Jenkins never directly touches the cluster
- All cluster changes go through Git (audit trail)
- You can see exactly what changed and when
- Easy rollbacks: just revert the Git commit

---

## Step 6: Install Monitoring Stack

> **What this does:** Installs Prometheus (metrics collection), Grafana (visualization), and AlertManager (notifications). This gives you full observability of your application and cluster.

### Option A: Using Manifests (from this repo)

```bash
./scripts/06-install-monitoring.sh manifests
```

### Option B: Using Helm (Recommended for Production)

```bash
./scripts/06-install-monitoring.sh helm
```

### Access Monitoring Tools

| Tool | URL | Credentials |
|------|-----|-------------|
| Prometheus | `http://localhost:30090` | No auth |
| Grafana | `http://localhost:30030` | admin / admin123 |
| AlertManager | `http://localhost:30093` | No auth |

**Fallback via port-forward:**

```bash
kubectl port-forward svc/prometheus -n monitoring 9090:9090
kubectl port-forward svc/grafana -n monitoring 3000:3000
kubectl port-forward svc/alertmanager -n monitoring 9093:9093
```

### Pre-configured Dashboards

The setup includes two pre-built Grafana dashboards:

1. **Tetris App Dashboard** - Application-specific metrics:
   - Application status (up/down)
   - Active pod count
   - Pod restart count
   - CPU and memory usage per pod
   - Request rate and error rate
   - Network I/O

2. **Kubernetes Cluster Dashboard** - Cluster-wide metrics:
   - Node count and status
   - Total running pods
   - Namespace count
   - Node CPU and memory usage

### Import Additional Dashboards

In Grafana, go to **Dashboards -> Import** and use these IDs:

| Dashboard ID | Name | What It Shows |
|---|---|---|
| 3119 | Kubernetes Cluster Monitoring | Cluster-level CPU, memory, network |
| 6417 | Kubernetes Pods Monitoring | Per-pod resource usage |
| 315 | Kubernetes Deployment | Deployment status and replicas |
| 12740 | Kubernetes Pod Resources | Detailed pod resource metrics |

### Configure Alerts

The monitoring stack includes pre-configured alert rules:

| Alert | Condition | Severity |
|-------|-----------|----------|
| TetrisAppDown | App unreachable for 1 min | Critical |
| TetrisHighCPU | CPU > 80% for 5 min | Warning |
| TetrisHighMemory | Memory > 85% for 5 min | Warning |
| TetrisPodRestarting | > 3 restarts/hour | Warning |
| TetrisHighErrorRate | > 5% error rate for 5 min | Critical |
| KubeNodeNotReady | Node not ready for 5 min | Critical |
| KubePodCrashLooping | > 3 restarts in 15 min | Warning |

To receive notifications, configure AlertManager with your preferred channel. Edit `monitoring/alertmanager/alertmanager-config.yaml`:

**Slack:**
```yaml
slack_configs:
  - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
    channel: '#alerts'
```

**Email:**
```yaml
email_configs:
  - to: 'team@example.com'
    from: 'alertmanager@example.com'
    smarthost: 'smtp.gmail.com:587'
    auth_username: 'your-email@gmail.com'
    auth_password: 'your-app-password'
```

> **Key Concept:** Prometheus pulls (scrapes) metrics from your application every 15 seconds. It stores them as time-series data. Grafana connects to Prometheus and visualizes the data. AlertManager evaluates rules against the data and sends notifications when thresholds are breached.

---

## Step 7: Build and Deploy the Application

> **What this does:** Builds the Tetris Docker image, scans it for vulnerabilities, loads it into the Kind cluster, and deploys it to Kubernetes. With Kind, you use `kind load docker-image` instead of pushing to a remote registry for local development.

### Quick Local Test (Docker Compose)

```bash
docker-compose up -d tetris
# Access at http://localhost:8080
```

### Full Deployment (Kind)

```bash
# Set your Docker Hub username
export DOCKER_USERNAME=your-dockerhub-username

# Build, scan, load into Kind, and deploy
./scripts/07-deploy-application.sh v1.0.0
```

### Manual Deployment Steps

```bash
# 1. Build the Docker image
docker build -t your-username/tetris-app:v1.0.0 .

# 2. Scan with Trivy
trivy image --severity HIGH,CRITICAL your-username/tetris-app:v1.0.0

# 3. Load image into Kind cluster (no push needed for local dev!)
kind load docker-image your-username/tetris-app:v1.0.0 --name tetris-devsecops

# 4. Update the image in deployment.yaml
# Replace YOUR_DOCKERHUB_USERNAME/tetris-app:latest with your image

# 5. Deploy to Kubernetes
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/service-nodeport.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml

# 6. Verify
kubectl get all -n tetris
```

### Access the Application

```bash
# NodePort (Kind port mapping)
http://localhost:30080

# Ingress (add '127.0.0.1 tetris.local' to /etc/hosts)
http://tetris.local

# Port-forward (always works)
kubectl port-forward svc/tetris-service -n tetris 8080:80
http://localhost:8080
```

> **Kind-specific Note:** With Kind, you don't need to push images to Docker Hub for local testing. The `kind load docker-image` command copies the image directly from your local Docker daemon into the Kind cluster nodes. This is much faster than push/pull through a registry. For the full CI/CD pipeline (via Jenkins), images are pushed to Docker Hub so Argo CD can pull them.

---

## Step 8: Configure the CI/CD Pipeline

> **What this does:** Connects everything together so that a single `git push` triggers the entire pipeline automatically.

### Before You Start

Update these placeholders across the project:

| Placeholder | Replace With | Files |
|---|---|---|
| `YOUR_DOCKERHUB_USERNAME` | Your Docker Hub username | `Jenkinsfile`, `k8s/deployment.yaml` |
| `YOUR_GITHUB_USERNAME` | Your GitHub username | `Jenkinsfile`, `argocd/application.yaml`, `argocd/project.yaml`, `argocd/repository.yaml` |
| `tetris-devsecops` | Your GitHub repo name | Same as above |

### Set Up GitHub Webhook

1. Go to your GitHub repo -> **Settings -> Webhooks -> Add webhook**
2. Payload URL: `http://<JENKINS_URL>/github-webhook/`
3. Content type: `application/json`
4. Events: **Just the push event**

> **Note for Kind:** Since Kind runs locally, GitHub webhooks can't reach `localhost`. For local testing, trigger Jenkins builds manually. For production, Jenkins should be on a public server or use a tool like [ngrok](https://ngrok.com) to expose your local Jenkins.

### Create Jenkins Pipeline Job

1. In Jenkins -> **New Item -> Pipeline**
2. Name: `tetris-devsecops-pipeline`
3. Check **GitHub hook trigger for GITScm polling** under Build Triggers
4. Pipeline section:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: your GitHub repo URL
   - Credentials: `github-credentials`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`
5. Click **Save**

### Run the Configuration Guide

```bash
./scripts/09-configure-jenkins-pipeline.sh
```

> **Key Concept:** The webhook tells Jenkins "something changed in Git." Jenkins then pulls the Jenkinsfile and runs it. The Jenkinsfile defines the pipeline stages. After Jenkins updates the Kubernetes manifests in Git, Argo CD picks up the change and deploys it.

---

## Step 9: Test the Full Pipeline

> **What this does:** Validates the entire end-to-end pipeline by making a code change and watching it flow through all stages.

### Test Procedure

1. **Make a code change:**
   ```bash
   # Change the game title or any visual element
   # Edit app/index.html
   git add .
   git commit -m "feat: update game title"
   git push origin main
   ```

2. **Watch Jenkins:**
   - Open Jenkins UI at `http://localhost:30080`
   - Trigger the pipeline manually (or wait for webhook if publicly accessible)
   - Watch stages: Checkout -> SonarQube -> Quality Gate -> Docker Build -> Trivy Scan -> Docker Push -> Update Manifests

3. **Watch Argo CD:**
   - Open Argo CD UI at `https://localhost:30443`
   - The application should show "OutOfSync" briefly
   - Then automatically sync and show "Healthy"

4. **Verify Deployment:**
   ```bash
   kubectl get pods -n tetris -w
   # Watch pods rolling update (old -> new)

   kubectl rollout status deployment/tetris -n tetris
   ```

5. **Check Monitoring:**
   - Open Grafana at `http://localhost:30030`
   - View the "Tetris App" dashboard
   - Verify metrics are flowing

### Expected Pipeline Duration

| Stage | Expected Time |
|-------|--------------|
| Checkout | ~5s |
| SonarQube Analysis | ~30s |
| Quality Gate | ~10s |
| Docker Build | ~30s |
| Trivy Image Scan | ~60s |
| Trivy Filesystem Scan | ~15s |
| Docker Push | ~30s |
| Update Manifests | ~10s |
| **Total CI** | **~3-4 min** |
| Argo CD Sync | ~30s |
| Rolling Update | ~60s |
| **Total E2E** | **~5-6 min** |

---

## Step 10: Production Considerations

### Security Hardening

1. **Image Security:**
   - Use distroless or Alpine base images (already using Alpine)
   - Run as non-root user (already configured)
   - Set `readOnlyRootFilesystem: true` where possible
   - Drop all capabilities (already configured)

2. **Kubernetes Security:**
   - Enable Network Policies (already included)
   - Use RBAC with least-privilege
   - Enable Pod Security Standards
   - Encrypt secrets with Sealed Secrets or Vault
   - Scan manifests with `trivy config`

3. **CI/CD Security:**
   - Use credentials-binding in Jenkins
   - Rotate tokens and passwords regularly
   - Enable audit logging in Jenkins
   - Use private container registry
   - Sign images with Cosign/Notation

4. **Monitoring Security:**
   - Enable authentication on Prometheus
   - Use strong passwords for Grafana
   - Restrict AlertManager access
   - Monitor for security events

### Moving from Kind to Production

When moving to production, replace Kind with a managed Kubernetes service:

| Kind (Local) | Production Equivalent |
|---|---|
| `kind create cluster` | EKS / GKE / AKS managed cluster |
| `kind load docker-image` | Push to ECR / GCR / ACR / Docker Hub |
| `extraPortMappings` | LoadBalancer services / Ingress with real DNS |
| Self-signed certs | cert-manager with Let's Encrypt |
| NodePort services | LoadBalancer or Ingress with TLS |
| Single node | Multi-node with autoscaling |

### Recommended Additions for Production

| Component | Purpose | Tool |
|---|---|---|
| Secrets Management | Encrypt K8s secrets | HashiCorp Vault / Sealed Secrets |
| Service Mesh | mTLS, traffic management | Istio / Linkerd |
| Log Aggregation | Centralized logging | ELK Stack / Loki |
| Image Signing | Supply chain security | Cosign / Notation |
| Policy Engine | Enforce policies | OPA Gatekeeper / Kyverno |
| Backup | Disaster recovery | Velero |
| Certificate Management | TLS certificates | cert-manager |

---

## Troubleshooting

### Kind-Specific Issues

#### Port Already in Use

```bash
# If Kind creation fails due to port conflicts:
# Check what's using the port
sudo lsof -i :30080

# Kill the process or change the port in kind-config.yaml
```

#### Image Not Found in Kind Cluster

```bash
# After building locally, you must load the image into Kind:
kind load docker-image your-username/tetris-app:v1.0.0 --name tetris-devsecops

# Verify the image is loaded:
docker exec -it tetris-devsecops-control-plane crictl images | grep tetris
```

#### Kind Cluster Won't Start

```bash
# Check Docker is running
docker ps

# Delete and recreate the cluster
kind delete cluster --name tetris-devsecops
./scripts/02-setup-kubernetes.sh
```

### Common Issues

#### Jenkins Pipeline Fails at SonarQube

```bash
# Check SonarQube is running
kubectl get pods -n sonarqube

# Check SonarQube logs
kubectl logs -n sonarqube -l app=sonarqube

# Verify SonarQube URL from Jenkins pod
kubectl exec -n jenkins <jenkins-pod> -- curl -s http://sonarqube-sonarqube.sonarqube:9000/api/system/status
```

#### Trivy Scan Shows Vulnerabilities

```bash
# This is expected! Trivy reports known vulnerabilities.
# Review the report and decide:
# - HIGH: Should fix before production
# - CRITICAL: Must fix before production
# To ignore specific CVEs, create .trivyignore:
echo "CVE-2023-XXXXX" >> .trivyignore
```

#### Argo CD Shows OutOfSync

```bash
# Check what's different
argocd app diff tetris-app

# Force sync
argocd app sync tetris-app --force

# Check events
kubectl get events -n tetris --sort-by='.lastTimestamp'
```

#### Pods in CrashLoopBackOff

```bash
# Check pod logs
kubectl logs -n tetris <pod-name> --previous

# Check pod events
kubectl describe pod -n tetris <pod-name>

# Common causes:
# - Wrong image tag
# - Image not loaded into Kind (use: kind load docker-image)
# - Failed health checks
# - Insufficient resources
```

#### Prometheus Not Scraping Metrics

```bash
# Check Prometheus targets
# Open Prometheus UI -> Status -> Targets

# Verify service annotations
kubectl get svc -n tetris -o yaml | grep prometheus

# Check Prometheus config
kubectl get configmap prometheus-config -n monitoring -o yaml
```

### Useful Debug Commands

```bash
# Check all resources in tetris namespace
kubectl get all -n tetris

# Watch pod status changes
kubectl get pods -n tetris -w

# Get pod resource usage
kubectl top pods -n tetris

# Check ingress status
kubectl describe ingress -n tetris

# View Argo CD application status
argocd app get tetris-app

# Check Jenkins logs
kubectl logs -n jenkins -l app.kubernetes.io/name=jenkins -f

# Port forward for debugging (always works with Kind)
kubectl port-forward svc/tetris-service -n tetris 8080:80
kubectl port-forward svc/prometheus -n monitoring 9090:9090
kubectl port-forward svc/grafana -n monitoring 3000:3000
kubectl port-forward svc/argocd-server -n argocd 8443:443

# Check Kind cluster docker container
docker ps --filter name=tetris-devsecops
docker logs tetris-devsecops-control-plane
```

---

## Cleanup

To remove everything and start fresh:

```bash
./scripts/10-cleanup.sh
```

Or manually:

```bash
# Delete application
kubectl delete -f k8s/

# Delete Argo CD app
kubectl delete -f argocd/application.yaml

# Delete monitoring
kubectl delete -f monitoring/prometheus/
kubectl delete -f monitoring/grafana/
kubectl delete -f monitoring/alertmanager/

# Delete namespaces
kubectl delete namespace tetris monitoring argocd jenkins sonarqube

# Delete Kind cluster entirely
kind delete cluster --name tetris-devsecops
```

---

## Quick Reference

### All Service URLs (Kind - localhost)

| Service | Port | URL |
|---------|------|-----|
| Tetris App | 30080 | `http://localhost:30080` |
| Jenkins | 30080 | `http://localhost:30080` (jenkins namespace) |
| SonarQube | 30900 | `http://localhost:30900` |
| Argo CD | 30443 | `https://localhost:30443` |
| Prometheus | 30090 | `http://localhost:30090` |
| Grafana | 30030 | `http://localhost:30030` |
| AlertManager | 30093 | `http://localhost:30093` |

### Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| Jenkins | admin | admin123 |
| SonarQube | admin | admin123 |
| Argo CD | admin | (auto-generated, see script output) |
| Grafana | admin | admin123 |

### Key Files to Customize

| File | What to Change |
|------|---------------|
| `Jenkinsfile` | Docker Hub username, GitHub repo URL |
| `k8s/deployment.yaml` | Docker image name |
| `argocd/application.yaml` | GitHub repo URL |
| `argocd/project.yaml` | GitHub repo URL |
| `kind-config.yaml` | Port mappings if defaults conflict |
| `monitoring/alertmanager/alertmanager-config.yaml` | Notification channels (Slack, email) |

### Essential Kind Commands

```bash
kind create cluster --name tetris-devsecops --config kind-config.yaml   # Create cluster
kind get clusters                                                        # List clusters
kind load docker-image <image> --name tetris-devsecops                  # Load image
kind delete cluster --name tetris-devsecops                              # Delete cluster
docker exec -it tetris-devsecops-control-plane crictl images             # List images in cluster
```

---

## Learning Path

If you're new to DevSecOps, follow this recommended learning order:

1. **Docker Basics** - Understand how to build and run containers
2. **Kubernetes Fundamentals** - Learn pods, deployments, services
3. **Kind** - Learn how to run local K8s clusters in Docker
4. **CI with Jenkins** - Understand pipeline stages and automation
5. **Security Scanning** - Learn what Trivy and SonarQube find
6. **GitOps with Argo CD** - Understand declarative deployment
7. **Monitoring** - Learn observability with Prometheus and Grafana
8. **Alerting** - Set up notifications for incidents
9. **Production Hardening** - Apply security best practices

Each tool builds on the previous one. Master each layer before moving to the next.

---

## License

This project is open source and available under the [MIT License](LICENSE).
