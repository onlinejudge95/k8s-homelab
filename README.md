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
   ./install_charts.sh [release_name]
   ```
   
   If `release_name` is provided, only that specific chart will be processed. Otherwise, all charts in `repos.yml` will be installed/upgraded.

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

### Cert Manager Issuer

To configure the ClusterIssuer for cert-manager, first ensure that cert-manager has been installed successfully via `./install_charts.sh` (as defined in `repos.yml`), then provide your email address for Let's Encrypt registration.

1.  Export your email address:
    ```bash
    export ACME_EMAIL=your-email@example.com
    ```

2.  Create the Cloudflare API token secret in the `cert-manager` namespace:
    ```bash
    kubectl create secret generic cloudflare-api-token-secret \
      --from-literal=api-token=YOUR_CLOUDFLARE_API_TOKEN \
      --namespace cert-manager
    ```

3.  Apply the manifest using `envsubst`:
    ```bash
    envsubst < manifests/issuer.yml | kubectl apply -f -
    ```

### PostgreSQL Cluster with TLS

The PostgreSQL cluster uses **operator-managed self-signed TLS certificates** for all connections (both internal and external).

#### Architecture

```
External Client
      ↓
LoadBalancer (<LOADBALANCER_EXTERNAL_IP>) → postgres.homelab.courtroom.cloud
      ↓ (TLS: operator-managed)
PostgreSQL Cluster (postgres-rw service)
      ↓ DNS: postgres.homelab.courtroom.cloud
PostgreSQL Server
      └─ TLS: Self-signed certificates (operator-managed)
```

**Important**: The LoadBalancer does **NOT** terminate TLS. It simply forwards TCP traffic to PostgreSQL, which uses self-signed certificates.

#### Setup Steps

1.  Ensure the CNPG operator is installed via `./install_charts.sh`.

2.  Apply the PostgreSQL cluster manifest:
    ```bash
    kubectl apply -f manifests/cluster.yml
    ```

3.  Apply the LoadBalancer service for external access (PostgreSQL and Redis):
    ```bash
    kubectl apply -f manifests/load-balancer.yaml
    ```
    
    > [!IMPORTANT]
    > The LoadBalancer is configured with `loadBalancerSourceRanges` to restrict access to `192.168.1.0/24` (your home LAN). Adjust this range in `manifests/load-balancer.yaml` to match your trusted networks before applying.

4.  Configure DNS to point `postgres.homelab.courtroom.cloud` to the LoadBalancer external IP:
    ```bash
    kubectl get svc postgres-lb -n cnpg -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    ```
    In the `courtroom.cloud` zone in Cloudflare, add an A record with name `postgres.homelab` (FQDN `postgres.homelab.courtroom.cloud`) pointing to the LoadBalancer IP (for example, `192.168.1.202`, DNS only, no proxy).

#### Connecting to PostgreSQL

**Internal connections** (from within the cluster):
```bash
psql "sslmode=require host=postgres-rw.cnpg.svc.cluster.local port=5432 user=app dbname=app"
```

**External connections** (via LoadBalancer):
```bash
psql "sslmode=require host=postgres.homelab.courtroom.cloud port=5432 user=app dbname=app"
```

#### SSL Mode Options

Since PostgreSQL uses **self-signed certificates**, SSL mode options are limited:

| SSL Mode | Works? | Description |
|----------|--------|-------------|
| `sslmode=disable` | ✅ | No encryption (not recommended) |
| `sslmode=require` | ✅ | **Recommended** - Encrypts connection, doesn't verify certificate |
| `sslmode=verify-ca` | ⚠️ | Requires importing CA certificate (see below) |
| `sslmode=verify-full` | ❌ | **Won't work** - Certificate CN doesn't match `postgres.homelab.courtroom.cloud` |

**Why `verify-full` doesn't work**: The operator-managed certificate has CN=`postgres-rw` (internal service name), not the external DNS name. To use `verify-full`, you would need to configure CNPG with a custom certificate that includes the external DNS name as a SAN.

#### Using `verify-ca` Mode (Optional)

If you want to verify the CA certificate without hostname verification:

```bash
# Extract the CA certificate
kubectl get secret postgres-ca -n cnpg -o jsonpath='{.data.ca\.crt}' | base64 -d > ~/postgres-ca.crt

# Connect with CA verification
psql "sslmode=verify-ca sslrootcert=$HOME/postgres-ca.crt host=postgres.homelab.courtroom.cloud port=5432 user=app dbname=app"
```

#### TLS Certificate Management

- **Server certificates**: Automatically managed by CloudNativePG operator
- **Type**: Self-signed (not publicly trusted)
- **Rotation**: Automatic every 90 days
- **CA certificate**: Available in the `postgres-ca` secret in the `cnpg` namespace
- **No manual intervention required**

#### Enabling Full Certificate Verification (Advanced)

To enable `sslmode=verify-full` with the external DNS name, you would need to:

1. Create a custom certificate with SAN: `postgres.homelab.courtroom.cloud`
2. Configure CNPG to use it via `certificates.serverTLSSecret` and `certificates.serverCASecret`
3. Use either:
   - Self-signed certificate via cert-manager (works but still not publicly trusted)
   - TLS-terminating proxy/ingress with Let's Encrypt (adds complexity)

The current setup prioritizes **simplicity and automatic management** over full certificate verification.

### Redis with TLS

Redis is configured with **Let's Encrypt TLS certificates** for secure external access.

#### Architecture

```
External Client (redis-cli --tls)
      ↓
LoadBalancer (<LOADBALANCER_EXTERNAL_IP>) → redis.homelab.courtroom.cloud
      ↓ (TLS: Passthrough)
Redis Pod (redis-0)
      └─ TLS: Let's Encrypt Certificate (/certs/tls.crt)
```

#### Setup Steps

1.  **Generate the Certificate**:
    Apply the certificate manifest to request a Let's Encrypt certificate for `redis.homelab.courtroom.cloud`. This will create the `redis-tls` secret.
    ```bash
    kubectl apply -f manifests/certificate.yaml
    ```

2.  **Deploy Redis**:
    Ensure Redis is installed via `./install_charts.sh`. The chart is configured to use the `redis-tls` secret created in the previous step.

3.  **Apply LoadBalancer**:
    (If not already done)
    ```bash
    kubectl apply -f manifests/load-balancer.yaml
    ```

4.  **Configure DNS**:
    Get the LoadBalancer IP for Redis:
    ```bash
    kubectl get svc redis-lb -n redis -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    ```
    In Cloudflare (or your DNS provider), add an **A record** for `redis.homelab` pointing to this IP. Ensure it is **DNS Only** (Gray cloud), not proxied.

#### Connecting to Redis

**Get the Password**:
```bash
export REDIS_PASSWORD=$(kubectl get secret redis-secret -n redis -o jsonpath="{.data.password}" | base64 -d)
```

**External Connection** (Secure):
```bash
redis-cli --tls \
  -h redis.homelab.courtroom.cloud \
  -p 6379 \
  -a $REDIS_PASSWORD \
  ping
```

**Internal Connection** (From within cluster):
Note: Use `CERT_NONE` or `--insecure` because the internal hostname (`redis.redis.svc...`) does not match the public certificate.
```bash
kubectl run redis-test --rm -it --restart=Never \
  --image=redis:7.2.4 \
  --env REDIS_PASSWORD=$REDIS_PASSWORD \
  --command -- redis-cli --tls --insecure \
  -h redis.homelab.courtroom.cloud \
  -p 6379 \
  -a $REDIS_PASSWORD \
  ping
```