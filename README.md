# Kubernetes Homelab

This repository contains the application configuration for my local Kubernetes cluster.

## Prerequisites

- A k8s cluster
- `helm` installed.
- `yq` installed.

## Usage

1. Configure your repositories and charts in `repos.yml`.
2. Run the installation script:
   ```bash
   ./install_charts.sh
   ```

## Configuration

### repos.yml

The `repos.yml` file is used to configure Helm repositories and charts to be installed by the `install_charts.sh` script.

Structure:
```yaml
repos:
  - name: "repo-name"          # Name of the Helm repository
    url: "repo-url"            # URL of the Helm repository
    chart: "repo/chart-name"   # (Optional) Chart to install
    release_name: "release"    # (Optional) Release name for the chart
    namespace: "namespace"     # (Optional) Namespace to install into
    values: "./path/to/values" # (Optional) Path to values file
```

Example:
```yaml
repos:
  - name: "cilium"
    url: "https://helm.cilium.io/"
    chart: "cilium/cilium"
    release_name: "cilium"
    namespace: "kube-system"
    values: "./values/cilium.yaml"
```

### L2 Announcement Pool

To configure L2 announcements for Cilium, apply the IP Pool manifest:

```bash
kubectl apply --filename manifests/pool.yml
```

### L2 Announcement Policy

To configure the announcement policy for services (who announces what IPs), apply the Policy manifest:

```bash
kubectl apply --filename manifests/policy.yml
```