#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print messages
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Source the .env file if it exists
if [ -f .env ]; then
    print_message "Loading environment variables from .env file"
    set -a  # automatically export all variables
    source .env
    set +a
else
    print_error ".env file not found"
    exit 1
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Verify MOUNT_DIR is set and is absolute
if [ -z "${MOUNT_DIR}" ]; then
    print_error "MOUNT_DIR environment variable is not set"
    exit 1
fi

if [[ "${MOUNT_DIR}" != /* ]]; then
    print_error "MOUNT_DIR must be an absolute path"
    exit 1
fi

# Create mount directory if it doesn't exist
mkdir -p "${MOUNT_DIR}"

check_and_delete_minikube() {
    if minikube status -p minikube-cluster >/dev/null 2>&1; then
        print_message "Found existing minikube cluster 'minikube-cluster'. Deleting it..."
        minikube delete -p minikube-cluster
        # Wait a moment to ensure cleanup is complete
        sleep 10
    fi
}

# Set architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    *)
        print_error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

print_message "Using architecture: ${ARCH}"

# Check and install kubectl
if command_exists kubectl; then
    print_message "kubectl is already installed. Version: $(kubectl version --client --short)"
else
    print_message "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    print_message "kubectl installed successfully"
fi

# Check and install minikube
if command_exists minikube; then
    print_message "minikube is already installed. Version: $(minikube version --short)"
else
    print_message "Installing minikube..."
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${ARCH}
    chmod +x minikube-linux-${ARCH}
    sudo mv minikube-linux-${ARCH} /usr/local/bin/minikube
    print_message "minikube installed successfully"
fi

# Check and install kustomize
if command_exists kustomize; then
    print_message "kustomize is already installed. Version: $(kustomize version --short)"
else
    print_message "Installing kustomize..."
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
    chmod +x kustomize
    sudo mv kustomize /usr/local/bin/
    print_message "kustomize installed successfully"
fi

check_and_delete_minikube

# Start minikube
print_message "Starting minikube cluster..."
minikube start -p minikube-cluster \
    --driver=docker \
    --force \
    --memory=2048mb \
    --cpus=2 \
    --bootstrapper=kubeadm \
    --kubernetes-version=v1.25.3 \
    --apiserver-ips=127.0.0.1 \
    --apiserver-port=8443 \
    --container-runtime=containerd \
    --base-image="gcr.io/k8s-minikube/kicbase:v0.0.37" \
    --addons=dashboard,metrics-server,ingress \
    --ports=30080,8443,80,443,30000 \
    --mount-string="${MOUNT_DIR}:${MOUNT_DIR}" \
    --mount

# Update kubeconfig
mkdir -p "$HOME/.kube"
minikube update-context -p minikube-cluster

# Deploy ShinyProxy using existing kustomize files
deploy_shinyproxy() {
    print_message "Deploying ShinyProxy using kustomize..."
    
    # Wait for kubernetes API to be ready
    print_message "Waiting for Kubernetes API to be ready..."
    until kubectl get nodes &>/dev/null; do
        sleep 5
    done
    
    # Create namespace
    kubectl create namespace shinyproxy
    
    # Apply kustomize configuration
    kubectl apply -k ./shinyproxy -n shinyproxy
    
    # Wait for deployment
    print_message "Waiting for ShinyProxy deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/shinyproxy -n shinyproxy
    
    if [ $? -eq 0 ]; then
        print_message "ShinyProxy deployed successfully!"
        print_message "You can access ShinyProxy at http://$(minikube ip -p minikube-cluster):30080"
        
        # Show deployment status
        kubectl get all -n shinyproxy
    else
        print_error "Failed to deploy ShinyProxy"
        exit 1
    fi
}

# Deploy ShinyProxy
deploy_shinyproxy

# verify_dashboard_access() {
#     print_message "Verifying Kubernetes Dashboard access..."
    
#     # Get dashboard URL and token
#     DASHBOARD_URL=$(minikube dashboard -p minikube-cluster --url)
    
#     if [ $? -eq 0 ]; then
#         print_message "Kubernetes Dashboard is accessible at: ${DASHBOARD_URL}"
        
#         # Get dashboard token
#         print_message "Getting dashboard token..."
#         TOKEN=$(kubectl -n kubernetes-dashboard create token kubernetes-dashboard)
#         print_message "Dashboard Token: ${TOKEN}"
#     else
#         print_error "Failed to get dashboard URL"
#         return 1
#     fi
# }

test_container_communication() {
    print_message "Testing container communication..."

    # Create test namespace
    kubectl create namespace test-communication

    # Deploy test pods
    cat <<EOF | kubectl apply -f - -n test-communication
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-1
  labels:
    app: test-pod-1
spec:
  containers:
  - name: nginx
    image: nginx:alpine
---
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-2
  labels:
    app: test-pod-2
spec:
  containers:
  - name: busybox
    image: busybox
    command: ['sh', '-c', 'while true; do sleep 3600; done']
EOF

    # Wait for pods to be ready
    print_message "Waiting for test pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=test-pod-1 -n test-communication --timeout=120s
    kubectl wait --for=condition=ready pod -l app=test-pod-2 -n test-communication --timeout=120s

    # Create service for test-pod-1
    cat <<EOF | kubectl apply -f - -n test-communication
apiVersion: v1
kind: Service
metadata:
  name: test-service-1
spec:
  selector:
    app: test-pod-1
  ports:
  - port: 80
    targetPort: 80
EOF

    # Test communication between pods
    print_message "Testing pod-to-pod communication..."
    if kubectl exec -n test-communication test-pod-2 -- wget -q -O- --timeout=5 test-service-1; then
        print_message "Pod-to-pod communication successful!"
    else
        print_error "Pod-to-pod communication failed"
    fi

    # Test DNS resolution
    print_message "Testing DNS resolution..."
    if kubectl exec -n test-communication test-pod-2 -- nslookup kubernetes.default; then
        print_message "DNS resolution successful!"
    else
        print_error "DNS resolution failed"
    fi

    # Clean up test namespace
    print_message "Cleaning up test resources..."
    kubectl delete namespace test-communication
}

# Add these calls after deploy_shinyproxy
# verify_dashboard_access
test_container_communication

verify_shinyproxy_access() {
    print_message "Verifying ShinyProxy access..."
    
    # Get the NodePort URL
    NODE_IP=$(minikube ip -p minikube-cluster)
    
    # Get the mapped port for 30080
    MAPPED_PORT=$(docker port minikube-cluster | grep 30080 | cut -d ':' -f 2)
    
    if [ -z "$MAPPED_PORT" ]; then
        print_error "Could not find mapped port for 30080"
        return 1
    fi
    
    print_message "ShinyProxy port 30080 is mapped to host port ${MAPPED_PORT}"
    
    # Wait for the service to be accessible
    print_message "Waiting for ShinyProxy to be accessible at http://localhost:${MAPPED_PORT}"
    timeout=300
    while ! curl -s "http://localhost:${MAPPED_PORT}" >/dev/null; do
        sleep 5
        timeout=$((timeout-5))
        if [ $timeout -le 0 ]; then
            print_error "Timeout waiting for ShinyProxy to be accessible"
            return 1
        fi
    done
    
    print_message "ShinyProxy is now accessible at http://localhost:${MAPPED_PORT}"
    print_message "You can also access it at http://${NODE_IP}:${MAPPED_PORT}"
}


verify_shinyproxy_access

# Show cluster information
print_message "Cluster Information:"
kubectl cluster-info
kubectl get nodes
kubectl get pods -A

# Keep container running
tail -f /dev/null
