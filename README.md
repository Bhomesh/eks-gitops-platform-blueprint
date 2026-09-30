# Enterprise EKS GitOps Platform Fleet Blueprint

[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.31%20%7C%20v1.32-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD%20App--of--Apps-EF7B4D?logo=argo&logoColor=white)](https://argoproj.github.io/cd/)
[![Istio](https://img.shields.io/badge/Service%20Mesh-Istio%20Strict%20mTLS-466BB0?logo=istio&logoColor=white)](https://istio.io/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform%20AWS-623CE4?logo=terraform&logoColor=white)](https://terraform.io/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![CI](https://github.com/Bhomesh/eks-gitops-platform-blueprint/actions/workflows/ci.yml/badge.svg)](https://github.com/Bhomesh/eks-gitops-platform-blueprint/actions)

A production-grade, compliance-ready AWS EKS Fleet infrastructure blueprint implementing **declarative GitOps (ArgoCD App-of-Apps)**, **Zero-Trust Service Mesh (Istio Strict mTLS)**, **IAM Roles for Service Accounts (IRSA)**, and an **automated zero-downtime cluster version upgrade orchestrator**.

---

## 🏛 Platform Architecture

```mermaid
graph TD
    subgraph "AWS Cloud Infrastructure (Terraform IaC)"
        VPC["Multi-AZ EKS VPC (10.50.0.0/16)"]
        KMS["KMS Customer-Managed Key<br/>Envelope Encryption for Secrets"]
        EKS["EKS Control Plane v1.31<br/>API, Audit & Authenticator Logs"]
        OIDC["IAM OIDC Identity Provider<br/>Fine-Grained IRSA Roles"]
        
        subgraph "Managed Node Groups (IMDSv2 + GP3 Encrypted)"
            SYS_NODES["System Node Pool (On-Demand)<br/>ArgoCD, Istio, CoreDNS, Prometheus"]
            WORK_NODES["Workload Node Pool (Spot)<br/>Payment & Banking Workloads"]
        end
    end

    subgraph "GitOps Engine (ArgoCD)"
        ROOT_APP["Root Application (App-of-Apps)<br/>gitops/bootstrap/root-app.yaml"]
        APP_CORE["Core Infra Application<br/>gitops/apps/core/"]
        APP_WORK["Workload Application<br/>gitops/apps/workloads/"]
    end

    subgraph "Zero-Trust Service Mesh (Istio)"
        ISTIO_CP["Istiod Control Plane"]
        INGRESS["Istio Ingress Gateway (AWS NLB)"]
        MTLS["PeerAuthentication (mode: STRICT)"]
        AUTH_POL["AuthorizationPolicy (Default Deny)"]
    end

    subgraph "Observability Fleet"
        PROM["Prometheus + Grafana Stack"]
        DD["Datadog Agent Fleet (APM & Tracing)"]
    end

    VPC --> EKS
    KMS -.->|Envelope Encryption| EKS
    EKS --> SYS_NODES
    EKS --> WORK_NODES
    EKS --> OIDC

    SYS_NODES --> ROOT_APP
    ROOT_APP --> APP_CORE
    ROOT_APP --> APP_WORK
    APP_CORE --> ISTIO_CP
    APP_CORE --> PROM
    APP_CORE --> DD
    APP_WORK --> MTLS
    APP_WORK --> AUTH_POL
```

---

## 🔒 Zero-Trust Service Mesh (Istio Strict mTLS)

All east-west pod-to-pod communication is encrypted and mutually authenticated via SPIFFE/SPIRE cryptographic identities issued by Istio CA:

```mermaid
sequenceDiagram
    autonumber
    participant Ingress as Istio Ingress Gateway
    participant Payment as payment-core (Pod A)
    participant Ledger as ledger-db (Pod B)
    participant Rogue as Unauthorized Pod (Attacker)

    Note over Payment,Ledger: PeerAuthentication mode: STRICT (mTLS enforced)
    Ingress->>Payment: mTLS handshake with SPIFFE SAN
    Payment->>Payment: AuthorizationPolicy evaluation (Allow Ingress GET /api/v1/*)
    Payment-->>Ingress: 200 OK

    Payment->>Ledger: Mutual TLS handshake (SPIFFE identity verified)
    Ledger->>Ledger: AuthorizationPolicy evaluation (Allow payment-core ServiceAccount)
    Ledger-->>Payment: Transaction Record

    Rogue-xLedger: Plaintext or unapproved TLS connection
    Ledger--xRogue: Connection Terminated (STRICT mTLS rejection)
```

---

## 🔄 Zero-Downtime Cluster Version Upgrade Sequence

The blueprint provides an automated Python orchestration script (`tools/upgrade_orchestrator.py`) and detailed runbook (`docs/UPGRADE_RUNBOOK.md`) adhering to AWS best practices:

```mermaid
sequenceDiagram
    autonumber
    participant CLI as Upgrade Orchestrator CLI
    participant K8s as Kubernetes API
    participant AWS as AWS EKS Service
    participant ASG as Auto Scaling Groups

    CLI->>K8s: Pre-flight check: Verify PDBs, deprecated APIs, node health
    K8s-->>CLI: Pre-flight checks PASSED
    CLI->>AWS: Update EKS Control Plane to v1.32
    AWS-->>CLI: Control Plane update completed (ACTIVE)
    CLI->>AWS: Update Managed Add-ons (vpc-cni, kube-proxy, coredns, ebs-csi)
    AWS-->>CLI: Add-ons healthy & active
    CLI->>ASG: Rolling update Managed Node Groups
    Note over ASG: Launches v1.32 nodes, cordons v1.31 nodes, drains pods safely
    ASG-->>CLI: Node groups rotated with 100% capacity maintained
    CLI->>K8s: Post-upgrade smoke test: DNS resolution, mTLS connectivity
    K8s-->>CLI: All checks verified. Zero downtime achieved!
```

---

## 📁 Repository Layout

```
.
├── terraform/
│   ├── vpc.tf                      # Multi-AZ VPC with EKS subnets and NAT Gateways
│   ├── kms.tf                      # KMS customer key for secrets envelope encryption
│   ├── eks.tf                      # EKS v1.31 cluster with comprehensive control plane logging
│   ├── node_groups.tf              # Managed Node Groups (System On-Demand + Workload Spot)
│   ├── irsa.tf                     # IAM Roles for Service Accounts (ALB, ExternalDNS, Cert-Manager)
│   ├── variables.tf                # Configurable variables
│   ├── outputs.tf                  # Infrastructure outputs
│   └── versions.tf                 # Pinned AWS and TLS provider constraints
├── gitops/
│   ├── bootstrap/
│   │   └── root-app.yaml           # Root ArgoCD App-of-Apps manifest
│   ├── apps/
│   │   ├── core/                   # Platform infrastructure applications
│   │   └── workloads/              # Business microservice applications
│   ├── environments/
│   │   ├── base/                   # Kustomize base deployment & service
│   │   ├── dev/                    # Dev overlay (1 replica)
│   │   ├── staging/                # Staging overlay (2 replicas)
│   │   └── prod/                   # Production overlay (3-20 replicas with HPA)
│   ├── istio/
│   │   ├── base/istio-operator.yaml# IstioOperator spec with AWS NLB annotations
│   │   ├── security/               # STRICT mTLS & AuthorizationPolicy rules
│   │   └── routing/                # Canary VirtualService with 90/10 traffic shift
│   └── observability/
│       ├── prometheus-grafana/     # Production Helm values for Prometheus stack
│       ├── datadog/                # Datadog Agent Helm values (APM, logs, metrics)
│       └── dashboards/             # Pre-built Grafana JSON dashboards
├── tools/
│   └── upgrade_orchestrator.py     # Automated zero-downtime cluster upgrade CLI
├── docs/
│   └── UPGRADE_RUNBOOK.md          # Step-by-step production upgrade operational guide
├── tests/
│   └── test_upgrade_orchestrator.py# Unit test suite for upgrade safety rules
├── .github/workflows/
│   └── ci.yml                      # CI validation workflow (Terraform + Kustomize + PyTest)
├── Makefile                        # Common developer commands
└── LICENSE                         # Apache 2.0
```

---

## 🚀 Quickstart & Deployment

### 1. Provision Infrastructure via Terraform
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 2. Configure Local Kubectl
```bash
aws eks update-kubeconfig --region us-east-1 --name bank-prod-eks
kubectl get nodes
```

### 3. Bootstrap GitOps App-of-Apps with ArgoCD
```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Apply the Root App-of-Apps
kubectl apply -f gitops/bootstrap/root-app.yaml
```

### 4. Test Zero-Downtime Cluster Upgrade in Dry-Run Mode
```bash
python3 tools/upgrade_orchestrator.py --cluster-name bank-prod-eks --target-version 1.32 --dry-run
```

---

## 📄 License
This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.
