# Setup From Scratch (Akeyless Gateway Automation Suite)

This repository contains a suite of scripts designed to automate the deployment preparation and configuration of an Akeyless Gateway in Kubernetes.

### 🎯 Project Goal
**The primary goal of this project is to automate the environment setup, secret provisioning, and dynamic values patching for a seamless Gateway installation.**

This project is strategically divided into two distinct phases:

## 1️⃣ Phase 1: setup_akeyless-v4.sh (Akeyless API Orchestrator)

This script is the **brain** of the operation. It interacts directly with the Akeyless API to provision all necessary access objects before any infrastructure is touched.

### 🔍 Detailed Workflow of Phase 1:
- **CLI Automation**: Installs and configures the Akeyless binary to ensure environment readiness.
- **Security Provisioning**: Creates two distinct API-Key Authentication Methods (Admin and Gateway).
- **RBAC Enforcement**: Configures Roles and Associations with granular permissions.
- **Artifact Generation**: Generates the `gw-setup.properties` file, capturing newly created Access IDs and Keys for Phase 2.

### 🚀 Execution of Phase 1:
To start the entire automated process, run the master orchestrator:
```bash
chmod +x *.sh
./setup_akeyless-v4.sh
```

## 2️⃣ Phase 2: gw-install-prep.sh (Infrastructure & Patching Engine)

The `gw-install-prep.sh` script handles the **heavy lifting** before the Helm deployment.

### ⚙️ Environment Configuration (gw-prep-conf.properties)
- **NAMESPACE**: The target Kubernetes Namespace for the Gateway installation.
- **CUSTOMER_FRAGMENT_SECRET_NAME**: Name of the K8s secret that will store the Customer Fragment.
- **FRAGMENT_FILE**: The filename of your customer fragment JSON file.
- **ACCESS_KEY_SECRET_NAME**: Name of the K8s secret that will store the Gateway Access Key.
- **RELEASE_NAME**: The Helm release name for the Gateway deployment.
- **PATCH_VALUES_YAML**: Set to `true` to enable automatic modification of the values file.
- **CLUSTER_NAME**: The unique ID for this cluster within Akeyless.
- **CLUSTER_DISPLAY_NAME**: The human-readable name for the cluster in the Akeyless UI.

### 📂 Gateway Settings (gw-setup.properties)
- **GATEWAY_ACCESS_ID**: The ID for the Gateway identity.
- **ADMIN_ACCESS_ID**: The ID granted administrative permissions.
- **CLUSTER_NAME**: Unique identifier for this cluster in Akeyless.

### 🛠️ Preparation Scope:
- **Environment & Context Validation**: Checks for configuration files and creates the target **Kubernetes Namespace** if it doesn't exist.
- **Kubernetes Secret Provisioning**: Automatically creates K8s secrets for both Gateway credentials and the generated Customer Fragment. Skips if already exists (**Idempotency**).
- **Dynamic Helm Values Patching**: 
    - Downloads the latest `values.yaml` from the Akeyless Helm chart and renames it using the target Namespace (e.g., `${NAMESPACE}_values.yaml`).
    - Injects Gateway IDs, Admin Permissions, Cluster Name, and Cluster Display Name.

---
**Maintained by**: [leon-maister](https://github.com/leon-maister)

<sub style="color: gray;">Context: $(pwd) | $(kubectl config current-context 2>/dev/null || echo "no-k8s-context")</sub>
