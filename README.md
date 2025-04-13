# Minikube in Docker with ShinyProxy Integration

A reproducible local Kubernetes cluster using Minikube inside a Docker container with ShinyProxy integration, supporting both ARM64 and AMD64 architectures.

## Features

- 🐳 Docker-based Minikube deployment
- 🔄 Automatic cluster initialization
- 📊 Kubernetes Dashboard integration
- 🚀 ShinyProxy with Kustomize support
- 📁 Host directory mounting
- 🔌 Multi-architecture support (ARM64/AMD64)
- 🔗 Inter-pod communication testing

## Prerequisites

- Docker Desktop (macOS/Windows) or Docker Engine (Linux)
- Colima (macOS, optional instead of Docker Desktop)
- Docker Compose
- Minimum 4GB RAM, 2 CPU cores

## Setup

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd <repository-name>
   ```

2. Create `.env` file:
   ```bash
   ARCH=arm64  # Use amd64 for Intel/AMD processors
   MOUNT_DIR=/Users/YOUR_USER/shared
   ```

3. Start the environment (choose one method):

   **Method 1: Using Docker Compose**
   ```bash
   docker-compose up -d --build
   ```

   **Method 2: Using Setup Script**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

## Directory Structure

```
.
├── .env                    # Environment configuration
├── docker-compose.yml      # Docker Compose configuration
├── Dockerfile             # Container build instructions
├── setup.sh              # Main setup script
└── shinyproxy/          # ShinyProxy Kustomize configurations
    ├── configmap.yaml
    ├── deployment.yaml
    ├── kustomization.yaml
    ├── rbac.yaml
    └── service.yaml
```

## Automated Installations

The setup automatically handles:

### Kustomize Installation
- Downloads and installs latest Kustomize version
- Configures for use with ShinyProxy deployment
- Sets up proper permissions and path

### ShinyProxy Deployment
- Deploys using Kustomize configurations
- Creates dedicated namespace
- Applies RBAC configurations
- Sets up service and deployment configurations

### Pod Communication Test
The setup includes automatic testing of:
- Pod-to-pod network connectivity
- DNS resolution
- Service discovery
- Network policies

## Available Services

| Service | URL | Port |
|---------|-----|------|
| ShinyProxy | http://localhost:30080 | 30080 |
| Kubernetes Dashboard | Via token authentication | Auto-assigned |
| Kubernetes API | https://localhost:8443 | 8443 |

## Accessing Services

### Kubernetes Dashboard

1. Get the container ID:
   ```bash
   docker ps | grep minikube-setup
   ```
   If you start environment as method 2 pass this step.

2. Generate dashboard token:
   ```bash
   docker exec <container-id> kubectl -n kubernetes-dashboard create token kubernetes-dashboard
   ```
   If you start environment as method 2 run below command:
   ```bash
   sudo kubectl -n kubernetes-dashboard create token kubernetes-dashboard
   ```   

3. Get the Dashboard URL:
   ```bash
   docker exec <container-id> minikube dashboard -p minikube-cluster --url
   ```
   If you start environment as method 2 run below command: 
   ```bash
   sudo minikube dashboard -p minikube-cluster --url
   ```

4. Access Dashboard:
   - Copy the URL from step 3
   - Paste the URL in your browser
   - When prompted, use the token generated in step 2


### Alternative Access Method

1. Enable port-forwarding:
   ```bash
   kubectl proxy
   ```

2. Access through:
   http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/

3. Use the token generated in step 2 to log in


### ShinyProxy
Access at url after script logs "ShinyProxy port 30080 is mapped to host port 51356  Waiting for ShinyProxy to be accessible at http://localhost:51356" after ~2-3 minutes initialization

### Verify Pod Communication
```bash
# Check test pods status
docker exec <container-id> kubectl get pods -n test-communication

# View communication test results
docker exec <container-id> kubectl logs -n test-communication test-pod-2
```

## Troubleshooting

1. **Container Startup Issues**
   - Check Docker resources
   - Verify port availability
   - Ensure Docker daemon is running

2. **Mount Directory Issues**
   - Ensure MOUNT_DIR exists and has correct permissions
   - Verify the path is absolute

3. **ShinyProxy Deployment Issues**
   - Check Kustomize configuration
   - Verify namespace creation
   - Check pod logs for errors

## Cleanup

```bash
# Stop and remove containers
docker-compose down

# Complete cleanup including volumes
docker-compose down -v
rm -rf .kube
```

## Security Note

This setup is configured for development environments. Modify security settings for production use.
