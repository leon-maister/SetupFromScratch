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

# --- Helm Values Preparation ---
# Flag to track if we should perform patching
SHOULD_PATCH=false

if [ -f "$VALUES_FILE" ]; then
    printf "${YELLOW}File %s already exists. Skipping helm show values and patching.${NC}\n" "$VALUES_FILE"
else
    # Only proceed with generation and patching if the switch is ON
    if [ "$PATCH_VALUES_YAML" = "true" ]; then
        printf "${CYAN}Generating fresh %s...${NC}\n" "$VALUES_FILE"
        helm show values akeyless/akeyless-gateway > "$VALUES_FILE"
        printf "${GREEN}SUCCESS:${NC} %s created.\n" "$VALUES_FILE"
        SHOULD_PATCH=true
    else
        printf "${YELLOW}SKIP: Patching is disabled in config (PATCH_VALUES_YAML=false).${NC}\n"
    fi
fi

# --- Kubernetes Secret Provisioning ---

# 1. Check if the setup properties file exists
SETUP_FILE="gw-setup.properties"
if [ ! -f "$SETUP_FILE" ]; then
    printf "${YELLOW}WARNING: $SETUP_FILE not found!${NC}\n"
    printf "${CYAN}Please create the 'access-key' secret manually later using:${NC}\n"
    printf "kubectl create secret generic access-key --from-literal=gateway-access-key=YOUR_KEY -n $NAMESPACE\n"
    exit 1
fi

# 2. Extract the Gateway Access Key accurately
GW_ACCESS_KEY=$(grep 'GATEWAY_ACCESS_KEY=' "$SETUP_FILE" | sed 's/^GATEWAY_ACCESS_KEY=//')

# 3. Check if the key was actually found and is not empty
if [ -z "$GW_ACCESS_KEY" ]; then
    printf "${YELLOW}WARNING: GATEWAY_ACCESS_KEY is missing or empty in $SETUP_FILE!${NC}\n"
    printf "${CYAN}You will need to provision the 'access-key' secret manually to make the Gateway work.${NC}\n"
    exit 1
fi

echo "Creating Kubernetes secret 'access-key' in namespace $NAMESPACE..."

# 4. Create the secret only if we have the key
kubectl create secret generic access-key \
  --from-literal=gateway-access-key="$(echo -n "$GW_ACCESS_KEY")" \
  -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

printf "${GREEN}SUCCESS: Secret 'access-key' provisioned correctly.${NC}\n"

# --- Dynamic Values File Patching ---
if [ "$SHOULD_PATCH" = "true" ]; then
    printf "${CYAN}Patching %s with dynamic configuration...${NC}\n" "$VALUES_FILE"

    # 1. Extract IDs from properties
    GW_ACCESS_ID=$(grep 'GATEWAY_ACCESS_ID=' gw-setup.properties | cut -d'=' -f2)
    ADMIN_ACCESS_ID=$(grep 'ADMIN_ACCESS_ID=' gw-setup.properties | cut -d'=' -f2)
    CLUSTER_NAME=$(grep 'CLUSTER_NAME=' gw-setup.properties | cut -d'=' -f2)
    CLUSTER_DISPLAY_NAME=$(grep 'CLUSTER_DISPLAY_NAME=' gw-setup.properties | cut -d'=' -f2)

    # 2. Create a temporary file with 2-space indent for the header
    # and 4-space indent for the items inside.
    cat <<EOF > permissions.tmp
  allowedAccessPermissions:
    - name: admin-access-key
      access_id: $ADMIN_ACCESS_ID
      permissions:
        - admin
EOF

    # 3. Apply patches with EXACT 4-space indentation
    # Count carefully: 4 spaces after the second '/'
    sed -i "s/gatewayAccessId:.*/gatewayAccessId: $GW_ACCESS_ID/" "$VALUES_FILE"
    sed -i "s/gatewayAccessType:.*/gatewayAccessType: access_key/" "$VALUES_FILE"
    sed -i "s/gatewayCredentialsExistingSecret:.*/gatewayCredentialsExistingSecret: $CUSTOMER_FRAGMENT_SECRET_NAME/" "$VALUES_FILE"
    
    # 4. Replace the placeholder line with our 2-space indented block
    sed -i -e '/allowedAccessPermissions: \[\]/ {' -e 'r permissions.tmp' -e 'd' -e '}' "$VALUES_FILE"
    
    # 4. Replace the empty brackets with the multiline block from temp file
    # This specifically targets the line with '[]' to avoid double patching
    sed -i -e '/allowedAccessPermissions: \[\]/ {' -e 'r permissions.tmp' -e 'd' -e '}' "$VALUES_FILE"

    sed -i "s/clusterName:.*/clusterName: $CLUSTER_NAME/" "$VALUES_FILE"
    sed -i "s/initialClusterDisplayName:.*/initialClusterDisplayName: $CLUSTER_DISPLAY_NAME/" "$VALUES_FILE"

    # Clean up
    rm permissions.tmp
    printf "${GREEN}SUCCESS: %s fully patched and ready.${NC}\n" "$VALUES_FILE"
fi
printf "\n${GREEN} Environment preparation completed successfully.${NC}\n"