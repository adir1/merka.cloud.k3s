# RBAC Configuration

This directory contains Role-Based Access Control (RBAC) configurations for the K3s cluster management system.

## Overview

The RBAC configuration implements a comprehensive access control system that follows security best practices and supports the cluster's GitOps workflow.

## Components

### Cluster Roles

- **platform-admin**: Full cluster administration privileges
- **developer**: Application development and deployment permissions
- **cluster-reader**: Read-only access for monitoring and observability
- **argocd-application-controller**: ArgoCD application controller permissions
- **argocd-server**: ArgoCD server permissions
- **operator-manager**: System operator management permissions

### Service Accounts

System service accounts for various components:
- ArgoCD components (application-controller, server, dex-server)
- Monitoring system
- Operator manager
- Backup system
- CI/CD pipeline

### Role Bindings

- **Cluster-level bindings**: For system components and global user groups
- **Namespace-level bindings**: For environment-specific access control

## User Groups

The RBAC system supports the following user groups:

- **platform-admins**: Full cluster administration access
- **developers**: Application development and deployment access
- **cluster-readers**: Read-only monitoring and observability access

## Authentication Setup

### OIDC Integration

To integrate with an external identity provider, add the following arguments to your K3s server configuration:

```bash
--oidc-issuer-url=https://your-oidc-provider.com
--oidc-client-id=kubernetes
--oidc-username-claim=email
--oidc-groups-claim=groups
--oidc-ca-file=/path/to/ca.crt
```

### ArgoCD Authentication

ArgoCD RBAC is configured through the `argocd-rbac-cm` ConfigMap, which maps user groups to ArgoCD roles.

## Security Features

### Pod Security Standards

The configuration includes guidance for implementing Pod Security Standards:
- System namespaces use `privileged` standard
- Application namespaces use `restricted` standard

### Network Policies

Network policies are included to control traffic to RBAC components.

## Deployment

Apply the RBAC configuration using Kustomize:

```bash
kubectl apply -k infrastructure/base/rbac/
```

## Namespace Requirements

The following namespaces should be created before applying the RBAC configuration:
- `argocd`
- `monitoring`
- `operators`
- `backup`
- `cicd`
- `development`
- `staging`

## Verification

After deployment, verify the RBAC configuration:

```bash
# Check cluster roles
kubectl get clusterroles | grep -E "(platform-admin|developer|cluster-reader)"

# Check service accounts
kubectl get serviceaccounts -A | grep -E "(argocd|monitoring|operator)"

# Check role bindings
kubectl get clusterrolebindings | grep -E "(platform-admins|developers|cluster-readers)"
```

## Customization

To customize the RBAC configuration for your environment:

1. Modify the user groups in `cluster-role-bindings.yaml`
2. Adjust permissions in `cluster-roles.yaml` as needed
3. Update namespace-specific bindings in `role-bindings.yaml`
4. Configure OIDC settings in `auth-config.yaml`

## Security Considerations

- Service accounts use `automountServiceAccountToken: true` only when necessary
- Principle of least privilege is applied to all roles
- Network policies restrict access to RBAC components
- Pod Security Standards are enforced at the namespace level