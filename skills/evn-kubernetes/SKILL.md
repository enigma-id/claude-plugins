---
name: evn-kubernetes
description: Kubernetes cluster operations and debugging for EVN ID infrastructure. Use this skill for any Kubernetes operations including namespace inventory, deployment management, pod debugging, service inspection, log retrieval, and resource monitoring. Apply when working with the kubernetes-admin@kubernetes cluster, troubleshooting deployments, checking pod status, or managing resources across namespaces (envio, onward, sukabread, tokocare, wordpress, playground, dev-warehouse).
---

# Kubernetes Cluster Operations

## Overview

Reference skill for our on-premise Kubernetes cluster. Contains full topology, networking, workload inventory, and operational patterns. Use this to avoid re-discovering cluster state every session.

## Operational Notes

See `k8s_cluster_facts.md` in this skill directory for durable cluster facts and current topology.

## Cluster Facts

- **Context:** `kubernetes-admin@kubernetes`
- **API server:** `https://10.0.11.11:6443`
- **Version:** v1.28.15
- **Nodes:** 3 control-plane, 4 worker
- **MetalLB L2 pool:** `10.0.11.200-10.0.11.220`
- **Primary gateway:** Kong; NGINX is secondary
- **cert-manager issuer:** `letsencrypt-prod`
- **Namespaces:** `envio`, `onward`, `sukabread`, `tokocare`, `wordpress`, `playground`, `dev-warehouse`
- **No metrics-server / No HPA**
- **No dynamic storage provisioner; PVs are manually managed**
- Kong previously had a crashlooping pod (admin listen mismatch), rolled back to revision 1

## Namespace Inventory

### Production Workloads

#### `envio` — Logistics/TMS Platform (Envio)
**Registry:** AWS ECR `479275045424.dkr.ecr.ap-southeast-3.amazonaws.com`
**Image pull secret:** `nvo-ecr` (auto-renewed every 6h via `ecr-renew` CronJob)
**ECR Renew SA:** `ecr-renew`

**Platform services (microservices):**
- `platform-auth`, `platform-user`, `platform-usergroup`
- `platform-location` (2 replicas), `platform-geocoding` (2 replicas), `platform-region` (2 replicas)
- `platform-product`, `platform-partner`, `platform-project`
- `platform-finance`, `platform-accounting`
- `platform-mailer`, `platform-uploader` (2 replicas)
- `platform-public` (2 replicas), `platform-tracking` (2 replicas)
- `marketing-quotation`

**TMS services:**
- `tms-job` (3 replicas), `tms-delivery` (3 replicas), `tms-manifest` (3 replicas)
- `tms-routing` (2 replicas), `tms-contract`, `tms-driver`
- `tms-invoice`, `tms-pricing`, `tms-service`, `tms-vehicle`

**WMS services:**
- `wms-fulfillment`, `wms-item`, `wms-receiving`
- `wms-stock`, `wms-stockmovement`, `wms-stockopname`, `wms-warehouse`

**VM (Vendor Management):**
- `vm-po`, `vm-rfq` (added ~10 days ago)

**Message Broker:** Kafka (1 broker) + ZooKeeper (2 replicas) — StatefulSets
**Service ports:** 80/TCP (HTTP) + 40/TCP (gRPC) per microservice

#### `onward` — Onward Platform
**Registry:** Docker Hub `enivent/*`
**Image tags:** Git commit SHA-based (e.g., `99490255101701424b9e43952c8c6891379f7b5b`)

**Services (all single replica):**
- `svc-auth`, `svc-user`, `svc-permission`, `svc-company`
- `svc-order`, `svc-invoice`, `svc-payment`, `svc-rates`
- `svc-customer`, `svc-vendor`, `svc-service`
- `svc-location`, `svc-tracking`, `svc-tms`, `svc-warehouse`
- `svc-chat`, `svc-ws` (WebSocket), `svc-notify`, `svc-mailer`
- `svc-uploader`, `svc-subscribe`, `svc-connect`, `svc-monitoring`

**Message Broker:** RabbitMQ (StatefulSet, 1 replica, 5 GiB PV)
**Service ports:** 80/TCP (HTTP) + 40/TCP (gRPC)

#### `sukabread` — Sukabread Franchise Platform
**Registry:** AWS ECR `479275045424.dkr.ecr.ap-southeast-3.amazonaws.com/sb.*`
**Image pull secret:** `sb-ecr`

**Services:** `api-franchisee`, `api-franchisor`, `api-franchisorder`, `api-pg`, `api-pos`, `api-tarif`, `api-warehouse`, `api-worker`
**Service ports:** 80/TCP

#### `tokocare` — TokoCare API
**Registry:** Docker Hub `enivent/tokocare:v3`
**Replicas:** 2
**Port:** 8081/TCP

### Infrastructure Namespaces

| Namespace | Purpose | Key Components |
|-----------|---------|----------------|
| `kube-system` | Core K8s | etcd (3), CoreDNS (2), kube-proxy, Calico |
| `metallb-system` | Load balancing | controller + speaker (DaemonSet) |
| `ingress-nginx` | NGINX ingress | 1 controller pod |
| `kong` | Kong API gateway | 2 pods (1 crashlooping — monitor) |
| `cert-manager` | TLS automation | controller + cainjector + webhook |

### Other Namespaces

| Namespace | Purpose | Details |
|-----------|---------|---------|
| `dev-warehouse` | Dev environment | RabbitMQ StatefulSet (5 GiB PV) |
| `playground` | Experimental | `tuyul-api` (Docker Hub `enivent/tuyul`) |
| `wordpress` | WordPress site | WordPress + MySQL StatefulSet |
| `evn-9router` | Empty | Recently created, no resources |
| `userdev01-ns` | Dev sandbox | User dev namespace |

## Storage

### Storage Classes

| Name | Provisioner | Reclaim | Binding |
|------|-------------|---------|---------|
| `envio-storage` | `kubernetes.io/no-provisioner` | Retain | Immediate |
| `manual` | (implicit) | Varies | — |

**No dynamic provisioner.** All PVs are manually provisioned (hostPath or local).

### Persistent Volumes

| PV | Size | Bound To | StorageClass |
|----|------|----------|--------------|
| kafka-pv-0 | 500Mi | envio/kafka-data-kafka-broker-0 | envio-storage |
| zk-pv-{0-3} | 500Mi each | envio/zk-data-zk-{0-3} | envio-storage |
| pv-envio | 1Gi | envio/pvc-envio | envio-storage |
| pv-ds-rabbitmq | 5Gi | onward/ds-rabbitmq | — |
| pv-rabbitmq-dev | 5Gi | dev-warehouse/ds-rabbitmq | manual |
| mysql-pv | 2Gi | wordpress/mysql | manual |
| wordpress-pv-2 | 1Gi | wordpress/wp-pvc | manual |

**Released PVs (orphaned):** `pv-plane-minio` (10Gi), `pv-plane-rabbitmq` (1Gi) — from deleted `evn-task` namespace.

## Container Registries

| Registry | Namespaces | Auth |
|----------|------------|------|
| AWS ECR `479275045424.dkr.ecr.ap-southeast-3.amazonaws.com` | envio, sukabread | `nvo-ecr` / `sb-ecr` secrets, auto-renewed |
| Docker Hub `enivent/*` | onward, playground, tokocare | No pull secret (public or pre-authed) |

### ECR Token Renewal

CronJob `ecr-renew` in `envio` namespace runs every 6 hours (`0 */6 * * *`).
Uses `nabsul/k8s-ecr-login-renew:v1.7.1` to refresh `nvo-ecr` secret.
**AWS Region:** `ap-southeast-3` (Jakarta)

## Quick Reference Commands

### Health Checks

```bash
# Cluster overview
kubectl get nodes -o wide
kubectl get pods --all-namespaces --field-selector status.phase!=Running

# Check for crashlooping pods
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed

# Node resource allocation
kubectl describe nodes | grep -A5 "Allocated resources"

# Check Kong gateway health (known issue: one pod crashloops)
kubectl get pods -n kong
kubectl logs -n kong -l app.kubernetes.io/name=kong --tail=50
```

### Deployment Operations

```bash
# Roll restart a deployment (envio example)
kubectl rollout restart deployment/<service-name> -n envio

# Check rollout status
kubectl rollout status deployment/<service-name> -n envio

# Scale a deployment
kubectl scale deployment/<service-name> -n envio --replicas=<N>

# View deployment image
kubectl get deployment <service-name> -n <ns> -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### Debugging

```bash
# Pod logs
kubectl logs -n <ns> <pod-name> --tail=100
kubectl logs -n <ns> -l app=<service-name> --tail=50

# Exec into pod
kubectl exec -it -n <ns> <pod-name> -- /bin/sh

# Describe for events
kubectl describe pod -n <ns> <pod-name>

# Check ingress routing
kubectl get ingress -n <ns> -o wide
```

### ECR Operations

```bash
# Force ECR token renewal
kubectl create job --from=cronjob/ecr-renew ecr-renew-manual -n envio

# Check ECR secret expiry
kubectl get secret nvo-ecr -n envio -o jsonpath='{.metadata.creationTimestamp}'
```

## Known Issues

1. **Kong pod crashlooping:** `kong-kong-64f5f6655c-6bq7z` has 17,150+ restarts. The second pod `kong-kong-b9cd544d7-qdp5j` is healthy. Traffic still flows but investigate root cause.
2. **No metrics-server:** `kubectl top` unavailable. No HPA support.
3. **No dynamic storage provisioner:** All PVs must be manually created before PVCs.
4. **Orphaned PVs:** `pv-plane-minio` and `pv-plane-rabbitmq` are Released from deleted namespace.

## Architecture Notes

- **Microservices pattern:** Both Envio and Onward use domain-driven microservice decomposition
- **gRPC inter-service:** Port 40/TCP across Envio and Onward services suggests gRPC for internal communication
- **Event-driven:** Kafka (Envio) and RabbitMQ (Onward, dev-warehouse) for async messaging
- **No autoscaling:** No HPA configured. All scaling is manual via `kubectl scale`
- **Bare metal / VM deployment:** Not cloud-managed. MetalLB for LB, manual PVs, kubeadm-provisioned
