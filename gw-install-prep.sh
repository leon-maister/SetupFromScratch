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

# --- Load Configuration ---
CONF_FILE="gw-prep-conf.properties"

if [ -f "$CONF_FILE" ]; then
    echo "Loading configuration from $CONF_FILE..."
    source "$CONF_FILE"
else
    echo "Error: $CONF_FILE not found!"
    exit 1
fi 

# --- Variables ---

# The following values are now loaded from gw-prep-conf.properties:
# NAMESPACE, CUSTOMER_FRAGMENT_SECRET_NAME, FRAGMENT_FILE

# Dynamically determine the current Kubernetes context
CURRENT_CONTEXT=$(kubectl config current-context)

# Automatically set the values file name based on the NAMESPACE
VALUES_FILE="${NAMESPACE}_values.yaml"

# --- Safety Check: Confirm Kubernetes Context and Namespace ---
printf "${YELLOW}ATTENTION: Context: ${NC}${CYAN}${CURRENT_CONTEXT}${NC}\n"
printf "${YELLOW}           Namespace: ${NC}${CYAN}${NAMESPACE}${NC}\n"
printf "${YELLOW}Is this correct? (Type 'Yes' to continue): ${NC}"
read user_confirmation

if [ "$user_confirmation" != "Yes" ]; then
    printf "${RED}Operation cancelled by user. Exiting.${NC}\n"
    exit 1
fi

printf "${GREEN}Confirmation received. Proceeding in namespace $NAMESPACE...${NC}\n"

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

if kubectl get secret "$CUSTOMER_FRAGMENT_SECRET_NAME" >/dev/null 2>&1; then
    printf "${YELLOW}Secret %s already exists. Deleting...${NC}\n" "$CUSTOMER_FRAGMENT_SECRET_NAME"
    kubectl delete secret "$CUSTOMER_FRAGMENT_SECRET_NAME"
fi

printf "${CYAN}Creating customer fragment secret %s...${NC}\n" "$CUSTOMER_FRAGMENT_SECRET_NAME"

kubectl create secret generic "$CUSTOMER_FRAGMENT_SECRET_NAME" \
  --from-file=customer-fragments="$(pwd)/$FRAGMENT_FILE"

if kubectl get secret "$CUSTOMER_FRAGMENT_SECRET_NAME" >/dev/null 2>&1; then
    printf "${GREEN}SUCCESS:${NC} Secret %s created successfully in namespace %s.\n" "$CUSTOMER_FRAGMENT_SECRET_NAME" "$NAMESPACE"
else
    printf "${RED}ERROR:${NC} Secret %s was not created.\n" "$CUSTOMER_FRAGMENT_SECRET_NAME"
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

# --- Kubernetes Secret Provisioning ---

# 1. Extract the Gateway Access Key accurately (preserving any '=' signs within the key)
# Using sed to remove the prefix and keep the rest of the string intact
GW_ACCESS_KEY=$(grep 'GATEWAY_ACCESS_KEY=' gw-setup.properties | sed 's/^GATEWAY_ACCESS_KEY=//')

echo "Creating Kubernetes secret 'access-key' in namespace $NAMESPACE..."

# 2. Create the secret using the full plaintext Access Key
# Using 'echo -n' to prevent adding any trailing newline characters
kubectl create secret generic access-key \
  --from-literal=gateway-access-key="$(echo -n "$GW_ACCESS_KEY")" \
  -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

printf "${GREEN}SUCCESS: Secret 'access-key' provisioned correctly.${NC}\n"

printf "\n${GREEN} Environment preparation completed successfully.${NC}\n"