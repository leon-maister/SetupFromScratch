# Setup From Scratch (Dotfiles & System Automation)

This repository contains an automated setup suite designed to provision a development environment from scratch using Ansible.

### 🎯 Project Goal
**The primary goal of this project is to provide a clean, idempotent, and automated way to bootstrap local development environments (Linux/macOS) with custom dotfiles and essential applications.**

## 📂 Core Components
| File | Function |
| :--- | :--- |
| setup.sh | **Entrypoint**: The main shell script that installs Ansible dependencies and triggers the playbook. |
| playbook.yml | **Automation**: The core Ansible playbook that manages system configuration, package installation, and dotfiles symlinking. |
| group_vars/ | **Variables**: Configuration files for managing system-specific settings and application lists. |

## 🏗️ Setup Scope (playbook.yml)
The automation workflow follows these phases:

### 1. Environment Preparation
- Installs or verifies the presence of **Ansible** on the local host.
- Detects the operating system to apply relevant package manager tasks (APT/Homebrew).

### 2. System Configuration
- **Dotfiles**: Automatically symlinks configuration files (like `.zshrc`, `.vimrc`, etc.) from the repository to the user's home directory.
- **Packages**: Executes a series of tasks to install essential development tools and utilities defined in `group_vars`.

### 3. Customization
- Applies user-defined preferences for shell environments, editor configurations, and terminal settings.

## 🧹 Maintenance & Updates
The project is built for re-runability:
- **Idempotency**: Running the playbook multiple times ensures the system state matches the configuration without redundant changes.
- **Customization**: Easily add new applications or modify existing configurations by updating the files within `group_vars/`.

## ⚙️ Configuration Variables
The setup is highly configurable via Ansible variables:

### System Settings
- **ansible_python_interpreter**: Path to the Python executable used for tasks.
- **dotfiles_repo**: Path to the local repository containing configuration files.

### Application Management
- **packages_list**: A defined list of software packages to be installed per distribution.
- **symlink_map**: Dictionary mapping source files in the repo to target locations in the `/home/keyless` directory.

## 🚀 Usage
1. Clone the repository and navigate to the directory:
```bash
git clone https://github.com/leon-maister/SetupFromScratch.git
cd SetupFromScratch
```
2. Run the main setup script:
```bash
./setup.sh
```

---
**Maintained by**: [leon-maister](https://github.com/leon-maister)

<sub style="color: gray;">/home/projects/SetupFromScratch | bootstrap_automation_v1</sub>
