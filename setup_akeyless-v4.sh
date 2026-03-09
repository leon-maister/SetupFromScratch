#!/bin/sh

# Set UTF-8 locale to prevent terminal corruption
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# ANSI Color Codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color (Reset)

# --- Configuration Section ---
ADMIN_EMAIL="fojoh30986@netoiu.com"
ADMIN_PASSWORD=''

# Admin Object names
AUTH_METHOD_NAME="/Admin/admin-api-key"
ROLE_NAME="/Admin/admin-role"

# Gateway Object names
GW_AUTH_METHOD_NAME="/Gateway/gateway-api-key"
GW_ROLE_NAME="/Gateway/gateway-admin-role"

# --- Phase 1: Environment Preparation ---
echo "--- Checking Akeyless CLI ---"

# Target directory for the binary
BIN_DIR="$HOME/.akeyless/bin"
TARGET_PATH="$BIN_DIR/akeyless"

# 1. Check if akeyless is already in system PATH
if command -v akeyless > /dev/null 2>&1; then
    echo "Akeyless CLI is already available in PATH."
    CLI_EXE="akeyless"
else
    # 2. If not in PATH, check if it's already installed in the standard hidden folder
    if [ -x "$TARGET_PATH" ]; then
        echo "Akeyless CLI found in $TARGET_PATH."
        CLI_EXE="$TARGET_PATH"
    else
        echo "Akeyless CLI not found. Installing per documentation..."
        
        # Create the bin directory if it doesn't exist
        mkdir -p "$BIN_DIR"
        
        # Download strictly using your documentation command
        curl -o "$TARGET_PATH" https://akeyless-cli.s3.us-east-2.amazonaws.com/cli/latest/production/cli-linux-amd64
        
        chmod +x "$TARGET_PATH"
        
        # Force bash to forget remembered paths and re-scan
        hash -r 
        
        echo "Waiting for CLI to stabilize..."
        sleep 3
        
        # Always use the absolute path for the first run to be 100% safe
        CLI_EXE="$TARGET_PATH"
    fi

    # 3. Add to PATH if it's not already there
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo "Adding $BIN_DIR to PATH in .bashrc..."
        echo "export PATH=\"\$PATH:$BIN_DIR\"" >> "$HOME/.bashrc"
        # Export for current session as well
        export PATH="$PATH:$BIN_DIR"
        printf "${YELLOW}NOTE: PATH updated. For future sessions, run 'source ~/.bashrc' or restart terminal.${NC}\n"
    fi
fi

# Final check to ensure CLI_EXE is an absolute path if possible
if [ "$CLI_EXE" = "akeyless" ]; then
    CLI_EXE=$(command -v akeyless)
fi

# If for some reason it's still just "akeyless", fall back to the known target path
if [ -z "$CLI_EXE" ] || [ "$CLI_EXE" = "akeyless" ]; then
    CLI_EXE="$TARGET_PATH"
fi 

# --- Fix for "Cold Start" issue ---
# Create the config directory and an empty profile to suppress interactive prompts
mkdir -p "$HOME/.akeyless"
if [ ! -f "$HOME/.akeyless/.akeyless-config.json" ]; then
    echo "{}" > "$HOME/.akeyless/.akeyless-config.json"
    echo "Pre-created empty Akeyless config to bypass first-run prompts."
fi
printf "n\nn\n" | $CLI_EXE --version > /dev/null 2>&1
printf "${GREEN}SUCCESS: Using CLI at: $(command -v akeyless || echo $CLI_EXE)${NC}\n"

# --- Phase 2: Authentication ---
echo "--- Capturing Session Token ---"


# Check if ADMIN_EMAIL is set, if not - prompt the user
if [ -z "$ADMIN_EMAIL" ]; then
    printf "${YELLOW}Admin Email is not set. Please enter it: ${NC}"
    read -r ADMIN_EMAIL
fi

# Check if ADMIN_PASSWORD is set, if not - prompt the user
if [ -z "$ADMIN_PASSWORD" ]; then
    printf "${YELLOW}Admin Password is not set. Please enter it: ${NC}"
    read -s ADMIN_PASSWORD
    echo "" 
fi

# Perform authentication
# Added 'echo' to see the exact command being executed (hiding password for security)
echo "[DEBUG] Executing: $CLI_EXE auth --access-type password --admin-email $ADMIN_EMAIL --admin-password *******"

AUTH_OUT=$(echo n | $CLI_EXE auth --access-type password --admin-email "$ADMIN_EMAIL" --admin-password "$ADMIN_PASSWORD")
SESSION_TOKEN=$(echo "$AUTH_OUT" | grep "Token:" | awk '{print $NF}' | tr -cd '[:print:]')

if [ -z "$SESSION_TOKEN" ]; then
    printf "${RED}Error: Authentication failed.${NC}\n"
    # Show the output of the failed command to see the real error from Akeyless
    echo "[DEBUG] Full Auth Output: $AUTH_OUT"
    exit 1
fi

printf "${GREEN}SUCCESS: Session Token captured: $SESSION_TOKEN${NC}\n"

# --- Phase 3: Admin Resource Creation ---
echo "--- Creating Admin Auth Method ---"
CHECK_AUTH=$(echo "$AUTH_METHOD_NAME" | sed 's/^\///')
if $CLI_EXE list-auth-methods --filter "$CHECK_AUTH" --token "$SESSION_TOKEN" | grep -q "$CHECK_AUTH"; then
    printf "${YELLOW}Auth Method $AUTH_METHOD_NAME already exists. Skipping.${NC}\n"
    FINAL_ACCESS_ID=$($CLI_EXE auth-method get --name "$AUTH_METHOD_NAME" --token "$SESSION_TOKEN" | grep "access_id" | awk '{print $NF}' | tr -d '", ')
    FINAL_ACCESS_KEY="${YELLOW}Already exists (Hidden)${NC}"
else
    # Capturing output for initial secrets
    CREATE_OUT=$($CLI_EXE auth-method create api-key --name "$AUTH_METHOD_NAME" --token "$SESSION_TOKEN")
    FINAL_ACCESS_ID=$(echo "$CREATE_OUT" | grep "Access ID:" | awk '{print $NF}' | tr -cd '[:print:]')
    FINAL_ACCESS_KEY=$(echo "$CREATE_OUT" | grep "Access Key:" | awk '{print $NF}' | tr -cd '[:print:]')
    printf "${GREEN}SUCCESS: Admin Auth Method $AUTH_METHOD_NAME created.${NC}\n"
fi

# Printing Access ID and Access Key as requested
echo "Admin Access ID: $FINAL_ACCESS_ID"
echo "Admin Access Key: $FINAL_ACCESS_KEY"

echo "--- Creating Admin Role ---"
CHECK_ROLE=$(echo "$ROLE_NAME" | sed 's/^\///')
if $CLI_EXE list-roles --filter "$CHECK_ROLE" --token "$SESSION_TOKEN" | grep -q "$CHECK_ROLE"; then
    printf "${YELLOW}Role $ROLE_NAME already exists. Skipping.${NC}\n"
else
    $CLI_EXE create-role --name "$ROLE_NAME" --token "$SESSION_TOKEN" > /dev/null
    printf "${GREEN}SUCCESS: Role $ROLE_NAME created.${NC}\n"
fi

echo "--- Linking Admin Role and Auth Method ---"
$CLI_EXE assoc-role-am --role-name "$ROLE_NAME" --am-name "$AUTH_METHOD_NAME" --token "$SESSION_TOKEN" > /dev/null
printf "${GREEN}SUCCESS: Admin Association updated.${NC}\n"

# --- Phase 4: Admin Permissions ---
echo "--- Setting Admin Resource Rules ---"
# Informing about the specific capabilities being applied
CAP_FLAGS="--capability read --capability list --capability create --capability update --capability delete"
REGULAR_RULES="item-rule auth-method-rule role-rule target-rule"

for RULE in $REGULAR_RULES; do
    printf "${CYAN}Applying [read, list, create, update, delete] for $RULE...${NC}\n"
    $CLI_EXE set-role-rule --role-name "$ROLE_NAME" --path "/*" --rule-type "$RULE" $CAP_FLAGS --token "$SESSION_TOKEN" > /dev/null
    printf "${GREEN}SUCCESS: Permissions set for $RULE.${NC}\n"
done

echo "--- Updating Admin Role with Administrative Access ---"
# Providing clear info on administrative flags
printf "${CYAN}Applying full administrative access (audit, analytics, event-center)...${NC}\n"
$CLI_EXE update-role --name "$ROLE_NAME" \
    --audit-access all --analytics-access all --gw-analytics-access all \
    --sra-reports-access all --usage-reports-access all \
    --event-center-access all --event-forwarders-access all --token "$SESSION_TOKEN" > /dev/null
printf "${GREEN}SUCCESS: Admin Administrative permissions updated.${NC}\n"

# --- Phase 6: Gateway Resource Creation ---
echo "--- Creating Gateway Auth Method ---"
CHECK_GW_AUTH=$(echo "$GW_AUTH_METHOD_NAME" | sed 's/^\///')
if $CLI_EXE list-auth-methods --filter "$CHECK_GW_AUTH" --token "$SESSION_TOKEN" | grep -q "$CHECK_GW_AUTH"; then
    printf "${YELLOW}Gateway Auth Method already exists.${NC}\n"
    GW_ACCESS_ID=$($CLI_EXE auth-method get --name "$GW_AUTH_METHOD_NAME" --token "$SESSION_TOKEN" | grep "access_id" | awk '{print $NF}' | tr -d '", ')
    GW_ACCESS_KEY="${YELLOW}Already exists (Hidden)${NC}"
else
    GW_CREATE_OUT=$($CLI_EXE auth-method create api-key --name "$GW_AUTH_METHOD_NAME" --token "$SESSION_TOKEN")
    GW_ACCESS_ID=$(echo "$GW_CREATE_OUT" | grep "Access ID:" | awk '{print $NF}' | tr -cd '[:print:]')
    GW_ACCESS_KEY=$(echo "$GW_CREATE_OUT" | grep "Access Key:" | awk '{print $NF}' | tr -cd '[:print:]')
    printf "${GREEN}SUCCESS: Gateway Auth Method $GW_AUTH_METHOD_NAME created.${NC}\n"
fi
echo "Gateway Access ID: $GW_ACCESS_ID"
echo "Gateway Access Key: $GW_ACCESS_KEY"

echo "--- Creating Gateway Role ---"
CHECK_GW_ROLE=$(echo "$GW_ROLE_NAME" | sed 's/^\///')
if $CLI_EXE list-roles --filter "$CHECK_GW_ROLE" --token "$SESSION_TOKEN" | grep -q "$CHECK_GW_ROLE"; then
    printf "${YELLOW}Gateway Role already exists.${NC}\n"
else
    $CLI_EXE create-role --name "$GW_ROLE_NAME" --token "$SESSION_TOKEN" > /dev/null
    printf "${GREEN}SUCCESS: Gateway Role created.${NC}\n"
fi

echo "--- Linking Gateway Role and Auth Method ---"
$CLI_EXE assoc-role-am --role-name "$GW_ROLE_NAME" --am-name "$GW_AUTH_METHOD_NAME" --token "$SESSION_TOKEN" > /dev/null
printf "${GREEN}SUCCESS: Gateway Association updated.${NC}\n"

# --- Phase 7: Gateway Permissions ---
echo "--- Setting Gateway Specific Rules ---"
# Informing about restricted capabilities for Gateway
GW_CAPS="--capability read --capability list"
GW_RULES="item-rule target-rule"

# --- Phase 7: Gateway Permissions (Based on Minimal Requirements) ---
echo "--- Setting Gateway Specific Rules ---"

# 1. Items: create, read, update, list (for caching, rotation, and migration)
printf "${CYAN}Applying [create, read, update, list] for item-rule...${NC}\n"
$CLI_EXE set-role-rule --role-name "$GW_ROLE_NAME" --path "/*" --rule-type "item-rule" \
    --capability create --capability read --capability update --capability list \
    --token "$SESSION_TOKEN" > /dev/null

# 2. Targets: read, update, list (for dynamic/rotated secrets)
printf "${CYAN}Applying [read, update, list] for target-rule...${NC}\n"
$CLI_EXE set-role-rule --role-name "$GW_ROLE_NAME" --path "/*" --rule-type "target-rule" \
    --capability read --capability update --capability list \
    --token "$SESSION_TOKEN" > /dev/null

# 3. Roles: list (required for caching)
printf "${CYAN}Applying [list] for role-rule...${NC}\n"
$CLI_EXE set-role-rule --role-name "$GW_ROLE_NAME" --path "/*" --rule-type "role-rule" \
    --capability list \
    --token "$SESSION_TOKEN" > /dev/null

# 4. Auth Methods: list (required for caching)
printf "${CYAN}Applying [list] for auth-method-rule...${NC}\n"
$CLI_EXE set-role-rule --role-name "$GW_ROLE_NAME" --path "/*" --rule-type "auth-method-rule" \
    --capability list \
    --token "$SESSION_TOKEN" > /dev/null

printf "${GREEN}SUCCESS: Gateway Permissions fully set according to documentation.${NC}\n"


# --- Final Result ---
echo "--- Finalizing ---"
echo "--------------------------------------------------------"
printf "${GREEN} Success! Environment is provisioned.${NC}\n"
echo " [ADMIN ACCESS]"
echo " Admin Auth Method Name: $AUTH_METHOD_NAME"
echo " Access ID:  $FINAL_ACCESS_ID"
# Using printf to correctly render the color if the key is hidden
printf " Access Key: %b\n" "$FINAL_ACCESS_KEY"
echo ""
echo " [GATEWAY ACCESS]"
echo " Gateway Auth Method Name: $GW_AUTH_METHOD_NAME"
echo " Access ID:  $GW_ACCESS_ID"
# Using printf to correctly render the color if the key is hidden
printf " Access Key: %b\n" "$GW_ACCESS_KEY"
echo "--------------------------------------------------------"

GW_PROPS_FILE="gw-setup.properties"

cat > "$GW_PROPS_FILE" <<EOF
ADMIN_AUTH_METHOD_NAME=$AUTH_METHOD_NAME
ADMIN_ACCESS_ID=$FINAL_ACCESS_ID
ADMIN_ACCESS_KEY=$FINAL_ACCESS_KEY

GATEWAY_AUTH_METHOD_NAME=$GW_AUTH_METHOD_NAME
GATEWAY_ACCESS_ID=$GW_ACCESS_ID
GATEWAY_ACCESS_KEY=$GW_ACCESS_KEY
EOF

printf "${GREEN}SUCCESS:${NC} Properties saved to %s\n" "$GW_PROPS_FILE"