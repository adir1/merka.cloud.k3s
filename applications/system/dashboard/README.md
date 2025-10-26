# Cluster Dashboard Helm Chart

A custom Kubernetes dashboard for K3s cluster management with configurable service links and granular ingress path control.

## Features

- **No Sidecar Containers**: Lightweight static dashboard with no runtime overhead
- **Configurable Services**: Add/remove/modify services through Helm values
- **Granular Ingress Control**: Specify exact URI paths for each service
- **Health Monitoring**: Optional health checks for all services
- **Responsive UI**: Modern Bootstrap-based interface with dark/light themes
- **Service Categories**: Organize services by category (Monitoring, GitOps, etc.)
- **Quick Actions**: Configurable shortcuts to common tasks

## Quick Start

### 1. Basic Installation

```bash
# Install with default values
helm install cluster-dashboard . -n kubernetes-dashboard --create-namespace

# Access dashboard
kubectl port-forward -n kubernetes-dashboard svc/cluster-dashboard-nodeport 8080:8080
# Open http://localhost:8080
```

### 2. Custom Configuration

Edit `values.yaml` to configure your services:

```yaml
services:
  grafana:
    name: "Grafana"
    description: "Monitoring dashboards"
    path: "/grafana"           # Accessible at https://cluster.local/grafana
    icon: "chart-line"
    category: "Monitoring"
    enabled: true
    target:
      service: "grafana"       # Kubernetes service name
      namespace: "monitoring"  # Service namespace
      port: 80                # Service port
    healthCheck: "/grafana/api/health"
```

### 3. Production Deployment

```bash
# Use production values
helm install cluster-dashboard . \
  -n kubernetes-dashboard \
  --create-namespace \
  -f values-production.yaml
```

## Configuration

### Adding New Services

To add a new service to the dashboard:

1. Edit `values.yaml` and add your service:

```yaml
services:
  myapp:
    name: "My Application"
    description: "Custom application"
    path: "/myapp"
    icon: "rocket"
    category: "Applications"
    color: "#28a745"
    enabled: true
    external: false
    target:
      service: "myapp-service"
      namespace: "default"
      port: 8080
    healthCheck: "/myapp/health"
```

2. The service will automatically:
   - Appear in the dashboard UI
   - Get an ingress route at `/myapp`
   - Have health monitoring (if configured)
   - Be categorized under "Applications"

### External Services

For external services (like GitHub, documentation):

```yaml
services:
  github:
    name: "GitHub Repository"
    description: "Source code"
    path: "/github"
    icon: "github"
    category: "Development"
    enabled: true
    external: true
    externalUrl: "https://github.com/your-org/repo"
```

### Ingress Configuration

Control ingress paths and routing:

```yaml
ingress:
  enabled: true
  className: "traefik"  # or "nginx"
  host: "cluster.local"
  
  tls:
    enabled: true
    secretName: "cluster-dashboard-tls"
    issuer: "letsencrypt-prod"
```

All services defined in `values.yaml` will automatically get ingress routes based on their `path` configuration.

### Service Categories

Services are automatically grouped by category:

- **Management**: Cluster administration tools
- **GitOps**: ArgoCD and deployment tools  
- **Monitoring**: Grafana, Prometheus, Alertmanager
- **Observability**: Tracing and logging tools
- **Security**: Vault, security scanners
- **Applications**: User workloads
- **Development**: Code repositories, CI/CD

### Health Monitoring

Enable health checks for services:

```yaml
healthChecks:
  enabled: true
  interval: 30  # Check every 30 seconds
  timeout: 5    # 5 second timeout
  retries: 3    # Retry 3 times

services:
  grafana:
    # ... other config
    healthCheck: "/grafana/api/health"  # Health endpoint
```

### Customization

Customize appearance and behavior:

```yaml
customization:
  title: "Production K3s Cluster"
  subtitle: "Handle with Care"
  theme: "dark"  # or "light"
  
  colors:
    primary: "#326ce5"
    success: "#28a745"
    warning: "#ffc107"
    danger: "#dc3545"
    
  layout:
    showClusterInfo: true
    showQuickActions: true
    servicesPerRow: 3
    
  features:
    healthChecks: true
    serviceCategories: true
    searchFilter: true
    darkModeToggle: true
```

## URL Structure

With the default configuration, services are accessible at:

- Dashboard: `https://cluster.local/`
- ArgoCD: `https://cluster.local/argocd`
- Grafana: `https://cluster.local/grafana`
- Prometheus: `https://cluster.local/prometheus`
- Alertmanager: `https://cluster.local/alertmanager`

## Environment-Specific Deployments

### Development
```bash
helm install cluster-dashboard . -f values.yaml
```

### Production
```bash
helm install cluster-dashboard . -f values-production.yaml
```

### Custom Environment
```bash
# Create your own values file
cp values.yaml values-staging.yaml
# Edit values-staging.yaml
helm install cluster-dashboard . -f values-staging.yaml
```

## ArgoCD Integration

The dashboard is deployed via ArgoCD using the `dashboard-app.yaml` application definition. To modify the configuration:

1. Edit `values.yaml` or create environment-specific values files
2. Commit changes to Git
3. ArgoCD will automatically sync the changes

For environment-specific deployments, update the ArgoCD application to use different values files:

```yaml
source:
  helm:
    valueFiles:
      - values.yaml
      - values-production.yaml  # Add environment-specific overrides
```

## Troubleshooting

### Dashboard Not Loading
```bash
# Check pod status
kubectl get pods -n kubernetes-dashboard

# Check logs
kubectl logs -n kubernetes-dashboard deployment/cluster-dashboard

# Check service
kubectl get svc -n kubernetes-dashboard
```

### Ingress Issues
```bash
# Check ingress
kubectl get ingress -n kubernetes-dashboard

# Check ingress controller logs
kubectl logs -n kube-system deployment/traefik
```

### Service Health Checks Failing
- Verify the health check endpoint is correct
- Check if the target service is running
- Verify network policies allow communication

## Security

The dashboard runs with minimal privileges:
- Read-only access to cluster resources
- No service account token mounted
- Security context with non-root user
- Read-only root filesystem

For production deployments, consider:
- Enabling authentication via ingress annotations
- Using network policies to restrict access
- Regular security updates of the base image

## Development

To modify the dashboard:

1. Edit templates in `templates/`
2. Update `values.yaml` for new configuration options
3. Test with `helm template . | kubectl apply -f -`
4. Package with `helm package .`

The dashboard is a static HTML/CSS/JS application served by nginx, making it lightweight and easy to customize.