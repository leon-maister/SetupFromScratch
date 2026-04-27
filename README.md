# Setup From Scratch (Akeyless Gateway Automation Suite)

This project is divided into two professional automation phases.

## 1️⃣ Phase 1: setup_akeyless-v4.sh (Akeyless API Orchestrator)

This script is the **brain** of the operation. It interacts directly with the Akeyless API to provision all necessary access objects before any infrastructure is touched.

### 🔍 Detailed Workflow of Phase 1:
- **CLI Automation**: Installs and configures the Akeyless binary to ensure environment readiness.
- **Security Provisioning**: Creates two distinct API-Key Authentication Methods (Admin and Gateway).
- **RBAC Enforcement**: Configures Roles and Associations with granular permissions (full access for Admin, restricted operational access for Gateway).
- **Dynamic Configuration (The Glue)**: Generates the `gw-setup.properties` file, capturing newly created Access IDs and Keys for use in Phase 2.

## 2️⃣ Phase 2: gw-install-prep.sh (Kubernetes & Helm Pre-flight)

Once the Akeyless side is ready, Phase 2 takes over to bridge the gap to Kubernetes:
- **K8s Infrastructure**: Automates Namespace creation and Secret provisioning using IDs from Phase 1.
- **Intelligent Patching**: Generates and modifies the Helm `values.yaml` with precise YAML-compliant indentation and dynamic data injection.

## 🚀 How to Run
Everything starts with a single command:
```bash
chmod +x *.sh
./setup_akeyless-v4.sh
```

---
**Maintained by**: [leon-maister](https://github.com/leon-maister)
<sub style="color: gray;">Context: $(pwd) | $(kubectl config current-context 2>/dev/null)</sub>
