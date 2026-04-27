# Setup From Scratch (Akeyless Gateway Automation)

This repository contains a suite of scripts designed to automate the deployment preparation and configuration of an Akeyless Gateway in Kubernetes.

### 🎯 Project Goal
**The primary goal of this project is to automate the environment setup, secret provisioning, and dynamic values patching for a seamless Gateway installation.**

## 📂 Core Components
| File | Function |
| :--- | :--- |
| gw-install-prep.sh | **Preparation**: Automates Namespace creation, K8s Secrets provisioning, and dynamic Values patching. |
| gw-setup.properties | **Configuration**: Source of truth for Gateway Access IDs, Admin IDs, and Cluster names. |
| gw-prep-conf.properties | **Logic Toggles**: Configuration file to enable/disable specific automation features like YAML patching. |

## 🏗️ Preparation Scope (gw-install-prep.sh)
The `gw-install-prep.sh` script handles the heavy lifting before the Helm deployment:

### 1. Environment & Context Validation
- Checks for the existence of required configuration files (`.properties`).
- Verifies and creates the target **Kubernetes Namespace** if it doesn't exist.

### 2. Kubernetes Secret Provisioning
- **Gateway Credentials**: Automatically creates a K8s secret containing the `access-id` and `access-key` from properties.
- **Idempotency**: Skips creation if the secret already exists to prevent errors.

### 3. Dynamic Helm Values Patching
- **Fresh Generation**: Downloads the latest `values.yaml` from the Akeyless Helm chart.
- **Smart Injection**: Uses `sed` and temporary buffers to inject Cluster Name, Gateway IDs, and Admin Permissions.
- **YAML Integrity**: Ensures perfect indentation (2/4/6 spaces) for the `allowedAccessPermissions` block.
- **Conditional Logic**: Only patches if the file is new or the `PATCH_VALUES_YAML` toggle is enabled.

## ⚙️ Configuration Variables
The following parameters are managed through `.properties` files:

### Gateway Settings (gw-setup.properties)
- **GATEWAY_ACCESS_ID**: The ID for the Gateway to identify itself.
- **ADMIN_ACCESS_ID**: The ID that will be granted administrative permissions.
- **CLUSTER_NAME**: The unique identifier for this cluster in Akeyless.

### Logic Settings (gw-prep-conf.properties)
- **NAMESPACE**: The target K8s namespace.
- **PATCH_VALUES_YAML**: Set to `true` to enable automatic YAML modification.

## 🚀 Usage
1. Populate your `gw-setup.properties` with valid Akeyless IDs.
2. Run the preparation script:
```bash
chmod +x gw-install-prep.sh
./gw-install-prep.sh
```
3. The script will generate a ready-to-use `${NAMESPACE}_values.yaml` file.

---
**Maintained by**: [leon-maister](https://github.com/leon-maister)

<sub style="color: gray;">/home/keyless/SetupFromScratch | arn:aws:eks:us-east-2:358215316561:cluster/CS-EKS</sub>
