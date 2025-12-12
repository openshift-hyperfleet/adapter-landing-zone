# HyperFleet Landing Zone Adapter

Event-driven adapter for HyperFleet cluster provisioning. Handles environment preparation and prerequisite setup for GCP-based cluster provisioning operations. Consumes CloudEvents from message brokers (GCP Pub/Sub, RabbitMQ), processes AdapterConfig, manages Kubernetes resources, and reports status via API.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Local Development](#local-development)
- [Helm Chart Installation](#helm-chart-installation)
- [Configuration](#configuration)
- [Examples](#examples)
- [GCP Workload Identity Setup](#gcp-workload-identity-setup)
- [Notes](#notes)

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- GCP Workload Identity (for Pub/Sub access)
- `gcloud` CLI configured with appropriate permissions

## Local Development

Run the adapter locally for development and testing.

### Prerequisites

- `hyperfleet-adapter` binary installed and in PATH
- GCP authentication configured (via `gcloud auth application-default login` or service account key)
- `podman` or `docker` for RabbitMQ (if `BROKER_TYPE=rabbitmq`)

### Setup

1. Copy environment template:

```bash
cp env.example .env
```

2. Edit `.env` with your configuration:

```bash
# Required for Google Pub/Sub (default)
GCP_PROJECT_ID="your-gcp-project-id"
BROKER_TOPIC="hyperfleet-adapter-topic"
BROKER_SUBSCRIPTION_ID="hyperfleet-adapter-landing-zone-subscription"

# Required for all broker types
HYPERFLEET_API_BASE_URL="https://localhost:8000"

# Optional (defaults provided)
SUBSCRIBER_PARALLELISM="1"
HYPERFLEET_API_VERSION="v1"

# Required for RabbitMQ (if BROKER_TYPE=rabbitmq)
# RABBITMQ_URL="amqp://guest:guest@localhost:5672/"
```

3. Authenticate with GCP:

```bash
gcloud auth application-default login
```

### Run

```bash
# For Google Pub/Sub (default)
make run-local

# For RabbitMQ
BROKER_TYPE=rabbitmq make run-local

# For RabbitMQ with Docker (override default podman)
BROKER_TYPE=rabbitmq CONTAINER_RUNTIME=docker make run-local
```

The script will:
- Auto-source `.env` if it exists
- Verify `hyperfleet-adapter` is installed
- Validate required environment variables
- **Auto-create Pub/Sub topic and subscription if missing** (for `googlepubsub` type)
- **Manage RabbitMQ container** (start/create for `rabbitmq` type)
- Generate broker config from `configs/broker-local-pubsub.yaml` or `configs/broker-local-rabbitmq.yaml`
- Start the adapter with verbose logging

### Local Environment Variables

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `GCP_PROJECT_ID` | Yes* | GCP project ID | - |
| `BROKER_TOPIC` | Yes* | Pub/Sub topic name | - |
| `BROKER_SUBSCRIPTION_ID` | Yes* | Pub/Sub subscription ID | - |
| `HYPERFLEET_API_BASE_URL` | Yes | HyperFleet API base URL | - |
| `SUBSCRIBER_PARALLELISM` | No | Number of parallel workers | `1` |
| `HYPERFLEET_API_VERSION` | No | API version | `v1` |
| `GOOGLE_APPLICATION_CREDENTIALS` | No | Path to service account key (if not using gcloud auth) | - |
| `RABBITMQ_URL` | No** | RabbitMQ connection URL (when using RabbitMQ broker) | `amqp://guest:guest@localhost:5672/` |
| `BROKER_TYPE` | No | Broker type: `googlepubsub` or `rabbitmq` | `googlepubsub` |
| `CONTAINER_RUNTIME` | No | Container runtime for RabbitMQ | `podman` |

\* Required when using GCP Pub/Sub broker (default)
\*\* Required when using RabbitMQ broker

## Helm Chart Installation

### Installing the Chart

```bash
helm install landing-zone ./charts/
```

### Install to a Specific Namespace

```bash
helm install landing-zone ./charts/ \
  --namespace hyperfleet-system \
  --create-namespace
```

### Uninstalling the Chart

```bash
helm delete landing-zone

# Or with namespace
helm delete landing-zone --namespace hyperfleet-system
```

## Configuration

All configurable parameters are in `values.yaml`. For advanced customization, modify the templates directly.

### Image & Replica

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.registry` | Image registry | `quay.io/openshift-hyperfleet` |
| `image.repository` | Image repository | `hyperfleet-adapter` |
| `image.tag` | Image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `imagePullSecrets` | Image pull secrets | `[]` |

### Naming

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nameOverride` | Override chart name | `""` |
| `fullnameOverride` | Override full release name | `""` |

### ServiceAccount & RBAC

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceAccount.create` | Create ServiceAccount | `true` |
| `serviceAccount.name` | ServiceAccount name (auto-generated if empty) | `""` |
| `serviceAccount.annotations` | ServiceAccount annotations (for Workload Identity) | `{}` |
| `rbac.create` | Create ClusterRole and ClusterRoleBinding | `false` |
| `rbac.namespaceAdmin` | Grant namespace admin permissions | `false` |

When `rbac.namespaceAdmin=true`, the adapter gets full access to:
- Namespaces (create, update, delete)
- Core resources (configmaps, secrets, serviceaccounts, services, pods, PVCs)
- Apps (deployments, statefulsets, daemonsets, replicasets)
- Batch (jobs, cronjobs)
- Networking (ingresses, networkpolicies)
- RBAC (roles, rolebindings)

### Logging

| Parameter | Description | Default |
|-----------|-------------|---------|
| `logging.verbosity` | Log verbosity level (0-10, higher = more verbose) | `2` |
| `logging.logtostderr` | Log to stderr instead of files | `true` |

### Scheduling

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nodeSelector` | Node selector | `{}` |
| `tolerations` | Tolerations | `[]` |
| `affinity` | Affinity rules | `{}` |

### Adapter Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.enabled` | Enable adapter ConfigMap | `true` |
| `config.adapterYaml` | Adapter YAML config content (uses bundled default if empty) | `""` |

When `config.enabled=true`:
- Creates ConfigMap with `adapter.yaml` key
- Mounts at `/etc/adapter/adapter.yaml`
- Sets `ADAPTER_CONFIG_PATH=/etc/adapter/adapter.yaml`

Override with custom config:
```bash
--set-file config.adapterYaml=./my-config.yaml
```

### Broker Configuration

The broker configuration generates a `broker.yaml` file that is mounted as a ConfigMap.

#### General Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `broker.create` | Create broker ConfigMap | `false` |
| `broker.type` | Broker type: `googlepubsub` or `rabbitmq` | `""` |
| `broker.subscriber.parallelism` | Number of parallel workers | `1` |
| `broker.yaml` | Raw YAML override (advanced use) | `""` |

#### Google Pub/Sub (when `broker.type=googlepubsub`)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `broker.googlepubsub.projectId` | GCP project ID (**required**) | `""` |
| `broker.googlepubsub.topic` | Pub/Sub topic name (**required**) | `""` |
| `broker.googlepubsub.subscription` | Pub/Sub subscription ID (**required**) | `""` |
| `broker.googlepubsub.deadLetterTopic` | Dead letter topic name (optional) | `""` |

Other Pub/Sub settings (ack deadline, retention, goroutines, etc.) are configured with sensible defaults in the broker config template.

#### RabbitMQ (when `broker.type=rabbitmq`)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `broker.rabbitmq.url` | RabbitMQ connection URL (**required**) | `""` |

> **Note:** The `broker.rabbitmq.url` must be provided via `--set` or values file. Do not commit credentials to version control.
> Format: `amqp://username:password@hostname:port/vhost`

Other RabbitMQ settings (exchange type, prefetch count, etc.) are configured with sensible defaults in the broker config template.

When `broker.create=true`:
- Generates `broker.yaml` from structured values
- Creates ConfigMap with `broker.yaml` key
- Mounts at `/etc/broker/broker.yaml`
- Sets `BROKER_CONFIG_FILE=/etc/broker/broker.yaml`

### HyperFleet API

| Parameter | Description | Default |
|-----------|-------------|---------|
| `hyperfleetApi.baseUrl` | HyperFleet API base URL | `""` |
| `hyperfleetApi.version` | API version | `v1` |

### Environment Variables

| Parameter | Description | Default |
|-----------|-------------|---------|
| `env` | Additional environment variables | `[]` |

Example:
```yaml
env:
  - name: MY_VAR
    value: "my-value"
  - name: MY_SECRET
    valueFrom:
      secretKeyRef:
        name: my-secret
        key: key
```

## Examples

### Basic Installation with Google Pub/Sub

```bash
helm install landing-zone ./charts/ \
  --set broker.create=true \
  --set broker.type=googlepubsub \
  --set broker.googlepubsub.projectId=my-gcp-project \
  --set broker.googlepubsub.topic=my-topic \
  --set broker.googlepubsub.subscription=my-subscription
```

### With HyperFleet API Configuration

```bash
helm install landing-zone ./charts/ \
  --set hyperfleetApi.baseUrl=https://api.hyperfleet.example.com \
  --set broker.create=true \
  --set broker.type=googlepubsub \
  --set broker.googlepubsub.projectId=my-gcp-project \
  --set broker.googlepubsub.topic=my-topic \
  --set broker.googlepubsub.subscription=my-subscription
```

### With RabbitMQ

```bash
helm install landing-zone ./charts/ \
  --set broker.create=true \
  --set broker.type=rabbitmq \
  --set broker.rabbitmq.url="amqp://user:password@rabbitmq.svc:5672/"
```

> **Security:** For production, store credentials in a Kubernetes Secret and reference via `env`.

### With GCP Workload Identity and RBAC

```bash
helm install landing-zone ./charts/ \
  --namespace hyperfleet-system \
  --create-namespace \
  --set image.registry=us-central1-docker.pkg.dev/my-project/my-repo \
  --set image.repository=hyperfleet-adapter \
  --set image.tag=v0.1.0 \
  --set broker.create=true \
  --set broker.type=googlepubsub \
  --set broker.googlepubsub.projectId=my-gcp-project \
  --set broker.googlepubsub.topic=my-topic \
  --set broker.googlepubsub.subscription=my-subscription \
  --set hyperfleetApi.baseUrl=https://api.hyperfleet.example.com \
  --set 'serviceAccount.annotations.iam\.gke\.io/gcp-service-account=adapter@my-gcp-project.iam.gserviceaccount.com' \
  --set rbac.create=true \
  --set rbac.namespaceAdmin=true
```

After deployment, bind KSA to GSA:

```bash
gcloud iam service-accounts add-iam-policy-binding \
  adapter@my-gcp-project.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:my-gcp-project.svc.id.goog[hyperfleet-system/landing-zone]"
```

### With Custom Logging

```bash
helm install landing-zone ./charts/ \
  --set logging.verbosity=5 \
  --set logging.logtostderr=true \
  --set broker.create=true \
  --set broker.type=googlepubsub \
  --set broker.googlepubsub.projectId=my-gcp-project \
  --set broker.googlepubsub.topic=my-topic \
  --set broker.googlepubsub.subscription=my-subscription
```

### Using Existing ServiceAccount

```bash
helm install landing-zone ./charts/ \
  --set serviceAccount.create=false \
  --set serviceAccount.name=my-existing-sa
```

### With Values File

<details>
<summary>Example <code>my-values.yaml</code></summary>

```yaml
replicaCount: 2

image:
  registry: us-central1-docker.pkg.dev/my-project/my-repo
  repository: hyperfleet-adapter
  tag: v0.1.0

serviceAccount:
  create: true
  annotations:
    iam.gke.io/gcp-service-account: adapter@my-project.iam.gserviceaccount.com

rbac:
  create: true
  namespaceAdmin: true

logging:
  verbosity: 3
  logtostderr: true

hyperfleetApi:
  baseUrl: https://api.hyperfleet.example.com
  version: v1

broker:
  create: true
  type: googlepubsub
  googlepubsub:
    projectId: my-gcp-project
    topic: hyperfleet-events
    subscription: hyperfleet-adapter-subscription
  subscriber:
    parallelism: 10
```

</details>

Install with values file:

```bash
helm install landing-zone ./charts/ -f my-values.yaml
```

## Deployment Environment Variables

The deployment sets these environment variables automatically:

| Variable | Value | Condition |
|----------|-------|-----------|
| `HYPERFLEET_API_BASE_URL` | From `hyperfleetApi.baseUrl` | When set |
| `HYPERFLEET_API_VERSION` | From `hyperfleetApi.version` | Always (default: v1) |
| `ADAPTER_CONFIG_PATH` | `/etc/adapter/adapter.yaml` | When `config.enabled=true` |
| `BROKER_CONFIG_FILE` | `/etc/broker/broker.yaml` | When `broker.create=true` |
| `BROKER_SUBSCRIPTION_ID` | From `broker.googlepubsub.subscription` | When `broker.type=googlepubsub` |
| `BROKER_TOPIC` | From `broker.googlepubsub.topic` | When `broker.type=googlepubsub` |
| `GCP_PROJECT_ID` | From `broker.googlepubsub.projectId` | When `broker.type=googlepubsub` |

## GCP Workload Identity Setup

To use GCP Pub/Sub with Workload Identity:

### Step 1: Create Google Service Account (GSA)

```bash
gcloud iam service-accounts create landing-zone-adapter \
  --project=MY_PROJECT \
  --display-name="Landing Zone Adapter"
```

### Step 2: Grant Pub/Sub Permissions to GSA

```bash
gcloud projects add-iam-policy-binding MY_PROJECT \
  --member="serviceAccount:landing-zone-adapter@MY_PROJECT.iam.gserviceaccount.com" \
  --role="roles/pubsub.subscriber"
```

### Step 3: Bind KSA to GSA (Workload Identity Federation)

Run this **before** deploying so the pod works immediately:

```bash
gcloud iam service-accounts add-iam-policy-binding \
  landing-zone-adapter@MY_PROJECT.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:MY_PROJECT.svc.id.goog[MY_NAMESPACE/landing-zone]"
```

> **Note:** This binding works even before the KSA exists. It registers that "when a KSA named `landing-zone` exists in `MY_NAMESPACE`, allow it to impersonate this GSA."

### Step 4: Deploy with Workload Identity Annotation

```bash
helm install landing-zone ./charts/ \
  --namespace MY_NAMESPACE \
  --create-namespace \
  --set broker.create=true \
  --set broker.type=googlepubsub \
  --set broker.googlepubsub.projectId=MY_PROJECT \
  --set broker.googlepubsub.topic=MY_TOPIC \
  --set broker.googlepubsub.subscription=MY_SUBSCRIPTION \
  --set 'serviceAccount.annotations.iam\.gke\.io/gcp-service-account=landing-zone-adapter@MY_PROJECT.iam.gserviceaccount.com' \
  --set rbac.create=true \
  --set rbac.namespaceAdmin=true
```

> **Note:** Replace the following placeholders:
> - `MY_PROJECT` - Your GCP project ID
> - `MY_NAMESPACE` - Kubernetes namespace (e.g., `hyperfleet-system`)
> - `MY_TOPIC` - Pub/Sub topic name
> - `MY_SUBSCRIPTION` - Pub/Sub subscription name
> - `landing-zone` - The Helm release name (KSA name)

### Verify Workload Identity

```bash
# Check ServiceAccount annotation
kubectl get serviceaccount landing-zone -n MY_NAMESPACE -o yaml

# Test authentication from pod
kubectl run -it --rm debug \
  --image=google/cloud-sdk:slim \
  --serviceaccount=landing-zone \
  --namespace=MY_NAMESPACE \
  -- gcloud auth list
```

## Notes

- The adapter runs as non-root user (UID 65532) with read-only filesystem
- Health probes are disabled by default (adapter is a message consumer, not HTTP server)
- Uses `distroless` base image for minimal attack surface
- Config checksum annotation triggers pod restart on ConfigMap changes
- Default resource limits: 500m CPU, 512Mi memory
- Default resource requests: 100m CPU, 128Mi memory

## License

See [LICENSE](LICENSE) for details.
