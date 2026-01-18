# Kubernetes Homelab

This repository contains the application configuration for my local Kubernetes cluster.

## Prerequisites

- A k8s cluster
- `helm` installed.
- `yq` installed.

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