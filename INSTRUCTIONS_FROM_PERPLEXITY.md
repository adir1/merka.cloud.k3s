## Setup instructions from Perplexity AI

Capturing here instructions put together by Perplexity AI.
This is specifically for Debian inside WSL2, with K3s and other similar components to what was needed.

### Create WSL2 VM

*Powershell or CMD*: wsl --install Debian --location c:\wsl\debian-k3s

sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git make nano

### Brew, Kubectl and Helm

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install gcc
brew install kubectl
brew install helm

### Gemini CLI (optional)

sudo npm install -g @google/gemini-cli

### K3s cluster

curl -sfL https://get.k3s.io | sh -
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER ~/.kube/config
chmod 600 ~/.kube/config
kubectl get nodes

### find WSL2 IP (for access to K8s cluster from Windows)

ip addr show eth0  # Find your WSL2 IP

### Helm

helm version
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

### Best Practice Namespaces

kubectl create namespace argocd
kubectl create namespace monitoring
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace prod
kubectl create namespace shared-services

### ArgoCD (user: admin) (6t2HxTZH6RpFF6ev)

helm install gitops argo/argo-cd -n argocd --create-namespace
kubectl get pods -n argocd
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
kubectl port-forward service/gitops-argocd-server -n argocd 8080:443

### Graphana and Prometheus

helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
*Default credentials*: admin/prom-operator

### Ingress and Dashboard

