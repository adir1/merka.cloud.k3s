# K3s Cluster Management Repository

This repository provides a comprehensive K3s cluster management solution that evolves through three phases:

1. **Bootstrap Phase**: Initial cluster setup and configuration
2. **GitOps Integration Phase**: ArgoCD installation and GitOps workflow setup
3. **Administration Phase**: Full cluster management through GitOps practices

## Repository Structure

```
/
├── bootstrap/          # Cluster initialization scripts and configs
│   ├── scripts/        # Installation and setup scripts
│   ├── configs/        # Cluster configuration templates
│   └── docs/           # Bootstrap documentation
├── argocd/             # ArgoCD installation and configuration
│   ├── installation/   # ArgoCD deployment files
│   ├── bootstrap-apps/ # Initial ArgoCD applications
│   └── configs/        # ArgoCD configuration files
├── infrastructure/     # Infrastructure as code
│   ├── base/           # Base configurations
│   ├── overlays/       # Environment-specific customizations
│   └── operators/      # Cluster operator definitions
├── applications/       # Application management
│   ├── system/         # System-level applications
│   └── workloads/      # User workload applications
├── docs/               # Comprehensive documentation
└── .github/            # CI/CD pipeline configurations
```

## Getting Started

### Phase 1: Bootstrap
1. Review and customize cluster configuration in `bootstrap/configs/`
2. Run the initialization scripts in `bootstrap/scripts/`
3. Validate cluster setup

### Phase 2: GitOps Setup
1. Deploy ArgoCD using configurations in `argocd/installation/`
2. Configure initial applications in `argocd/bootstrap-apps/`
3. Set up repository connections

### Phase 3: Cluster Management
1. Manage infrastructure through `infrastructure/` directory
2. Deploy applications via `applications/` directory
3. Use GitOps workflow for all changes

## Documentation

Detailed documentation is available in the `docs/` directory and within each component directory.

## Contributing

Please refer to the documentation for contribution guidelines and best practices.