#!/bin/bash
set -e

# --- Force UTF-8 ---
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# --- ANSI COLORS (Guaranteed Working) ---
GREEN="$(printf '\033[0;32m')"
RED="$(printf '\033[0;31m')"
YELLOW="$(printf '\033[0;33m')"
CYAN="$(printf '\033[0;36m')"
NC="$(printf '\033[0m')"

# --- Variables ---
NAMESPACE="from-scratch"
CURRENT_CONTEXT=$(kubectl config current-context)
SECRET_NAME="customer-fragment"
FRAGMENT_FILE="customer_fragments.json"
VALUES_FILE="from_scratch_values.yaml"

printf "${CYAN}Creating namespace (if needed)...${NC}\n"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

printf "${CYAN}Switching context to namespace...${NC}\n"
kubectl config set-context "$CURRENT_CONTEXT" --namespace="$NAMESPACE"

printf "${GREEN}SUCCESS:${NC} Namespace %s ready.\n" "$NAMESPACE"
printf "${GREEN}SUCCESS:${NC} Context %s updated.\n" "$CURRENT_CONTEXT"

# --- Akeyless fragment generation ---

if ! command -v akeyless >/dev/null 2>&1; then
    printf "${RED}ERROR:${NC} akeyless CLI not found in PATH.\n"
    exit 1
fi

printf "${CYAN}Generating customer fragment...${NC}\n"

akeyless gen-customer-fragment \
    --name customer_fragment_number1 \
    --description customer_fragment_number1 \
    --json > "$FRAGMENT_FILE"

printf "${GREEN}SUCCESS:${NC} Fragment saved to %s\n" "$FRAGMENT_FILE"

# --- Recreate Secret Logic ---

if kubectl get secret "$SECRET_NAME" >/dev/null 2>&1; then
    printf "${YELLOW}Secret %s already exists. Deleting...${NC}\n" "$SECRET_NAME"
    kubectl delete secret "$SECRET_NAME"
fi

printf "${CYAN}Creating secret %s...${NC}\n" "$SECRET_NAME"

kubectl create secret generic "$SECRET_NAME" \
  --from-file=customer-fragments="$(pwd)/$FRAGMENT_FILE"

if kubectl get secret "$SECRET_NAME" >/dev/null 2>&1; then
    printf "${GREEN}SUCCESS:${NC} Secret %s created successfully in namespace %s.\n" "$SECRET_NAME" "$NAMESPACE"
else
    printf "${RED}ERROR:${NC} Secret %s was not created.\n" "$SECRET_NAME"
    exit 1
fi

# --- Helm repo setup ---

printf "${CYAN}Updating Helm repositories...${NC}\n"

helm repo add akeyless https://akeylesslabs.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update

# --- Values file logic ---

if [ -f "$VALUES_FILE" ]; then
    printf "${YELLOW}File %s already exists. Skipping helm show values.${NC}\n" "$VALUES_FILE"
else
    printf "${CYAN}Generating %s...${NC}\n" "$VALUES_FILE"
    helm show values akeyless/akeyless-gateway > "$VALUES_FILE"
    printf "${GREEN}SUCCESS:${NC} %s created.\n" "$VALUES_FILE"
fi

printf "\n${GREEN} Environment preparation completed successfully.${NC}\n"