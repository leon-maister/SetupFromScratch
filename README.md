# Setup From Scratch (Akeyless Gateway Automation)

This repository contains a suite of scripts designed to automate the deployment preparation and configuration of an Akeyless Gateway in Kubernetes.

### 🎯 Project Goal
**The primary goal of this project is to automate the environment setup, secret provisioning, and dynamic values patching for a seamless Gateway installation.**

## 📂 Core Components
| File | Function |
| :--- | :--- |
| **setup_akeyless-v4.sh** | **Main Orchestrator**: The entrypoint script that triggers the entire automation workflow. |
| gw-install-prep.sh | **Preparation Engine**: Automates Namespace creation, K8s Secrets provisioning, and dynamic Values patching. |
| gw-setup.properties | **Configuration**: Source of truth for Gateway Access IDs, Admin IDs, and Cluster names. |
| gw-prep-conf.properties | **Logic Toggles**: Configuration file to enable/disable specific automation features like YAML patching. |

## 🚀 Main Workflow (setup_akeyless-v4.sh)
The `setup_akeyless-v4.sh` acts as the master controller for the installation process:

### 1. Initialization
- Triggers the execution of `gw-install-prep.sh` to ensure the environment is ready.
- Validates that all required configuration files and generated values are present.

### 2. Dependency Orchestration
- Ensures that the Kubernetes infrastructure (Namespace, Secrets) is provisioned before proceeding.
- Coordinates the flow between environment preparation and the actual deployment logic.

### 3. Execution Control
- Acts as a high-level wrapper to simplify the user experience, allowing the entire setup to be triggered with a single command.

## 🏗️ Preparation Scope (gw-install-prep.sh)
The `gw-install-prep.sh` script handles the heavy lifting before the Helm deployment:

### 1. Environment & Context Validation
- Checks for the existence of required configuration files (`.properties`).
- Verifies and creates the target **Kubernetes Namespace** if it doesn't exist.

### 2. Kubernetes Secret Provisioning
- **Gateway Credentials**: Automatically creates a K8s secret containing the `access-id` and `access-key` from properties.

### 3. Dynamic Helm Values Patching
- **Fresh Generation**: Downloads the latest `values.yaml` from the Akeyless Helm chart.
- **Smart Injection**: Injects Cluster Name, Gateway IDs, and Admin Permissions with perfect YAML indentation.

## ⚙️ Configuration Variables
- **GATEWAY_ACCESS_ID**: Gateway identity token.
- **ADMIN_ACCESS_ID**: ID granted administrative permissions.
- **PATCH_VALUES_YAML**: Set to `true` in `gw-prep-conf.properties` to enable auto-patching.

## 🏁 How to Run
To start the entire automated process, simply run the master script:
```bash
chmod +x *.sh
./setup_akeyless-v4.sh
```

---
**Maintained by**: [leon-maister](https://github.com/leon-maister)

<sub style="color: gray;">/home/keyless/SetupFromScratch | arn:aws:eks:us-east-2:358215316561:cluster/CS-EKS</sub>
