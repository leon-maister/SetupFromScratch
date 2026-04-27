# Setup From Scratch (Akeyless Gateway Suite)

This project is strategically divided into two distinct phases to ensure a robust and error-free deployment.

## 1️⃣ Phase 1: setup_akeyless-v4.sh (Master Orchestrator)

The `setup_akeyless-v4.sh` script serves as the **primary entrypoint** and environment validator. It is responsible for the high-level orchestration of the installation process.

### 🔍 Detailed Responsibilities of Phase 1:
- **Environment Sanitation**: Verifies that the local machine has all required binary dependencies installed and accessible in the PATH.
- **Helm Repository Governance**: Automates the `helm repo add` and `helm repo update` commands to ensure the Gateway is deployed from the most recent official Akeyless charts.
- **Pre-flight Configuration Check**: Confirms that both `gw-setup.properties` and `gw-prep-conf.properties` exist, preventing execution with missing parameters.
- **Execution Flow Control**: Once the environment is validated, it triggers **Phase 2** (`gw-install-prep.sh`) to handle specific resource provisioning.

## 2️⃣ Phase 2: gw-install-prep.sh (Infrastructure & Patching Engine)

This phase handles the "surgical" part of the setup:
- **Namespace & Secrets**: Creation of the K8s namespace and the `access-key` authentication secret.
- **Dynamic Values Patching**: Automates the modification of the Helm `values.yaml` with precise indentation and real-time data injection.

## 🚀 Execution
To begin the process, you only need to run the Phase 1 script:
```bash
chmod +x *.sh
./setup_akeyless-v4.sh
```

---
**Maintained by**: [leon-maister](https://github.com/leon-maister)
<sub style="color: gray;">Context: $(pwd) | $(kubectl config current-context 2>/dev/null)</sub>
