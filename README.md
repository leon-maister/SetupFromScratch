# Setup From Scratch (Akeyless Gateway Automation Suite)

This project is divided into two professional automation phases to ensure a seamless transition from API configuration to Kubernetes deployment.

## 1️⃣ Phase 1: setup_akeyless-v4.sh (Akeyless API Orchestrator)

This script is the **brain** of the operation. It interacts directly with the Akeyless API to provision all necessary access objects.

### 🔍 Detailed Workflow of Phase 1:
- **CLI Automation**: Installs and configures the Akeyless binary to ensure environment readiness.
- **Security Provisioning**: Creates two distinct API-Key Authentication Methods (Admin and Gateway).
- **RBAC Enforcement**: Configures Roles and Associations with granular permissions.
- **Artifact Generation**: Generates the `gw-setup.properties` file, capturing newly created Access IDs and Keys.

### 🚀 Execution of Phase 1:
To start the entire automated process, run the master orchestrator:
```bash
chmod +x *.sh
./setup_akeyless-v4.sh
```

## 2️⃣ Phase 2: gw-install-prep.sh (Kubernetes & Helm Pre-flight)

Once Phase 1 completes and `gw-setup.properties` is generated, the workflow continues (triggered automatically or manually) to bridge the gap to Kubernetes:

- **K8s Infrastructure**: Automates Namespace creation and Secret provisioning using IDs from Phase 1.
- **Intelligent Patching**: Generates and modifies the Helm `values.yaml` with precise YAML-compliant indentation.

---
**Maintained by**: [leon-maister](https://github.com/leon-maister)
<sub style="color: gray;">Context: $(pwd) | $(kubectl config current-context 2>/dev/null)</sub>
