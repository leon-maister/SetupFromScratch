#!/bin/sh

# Set UTF-8 locale for the current session to prevent terminal corruption
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# ANSI Color Codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color (Reset)

# --- Configuration Section ---
ADMIN_EMAIL="fojoh30986@netoiu.com"
ADMIN_PASSWORD="adminADMIN1!"

# Admin Object names
AUTH_METHOD_NAME="/Admin/admin-api-key"
ROLE_NAME="/Admin/admin-role"

# Gateway Object names
GW_AUTH_METHOD_NAME="/Gateway/gateway-api-key"
GW_ROLE_NAME="/Gateway/gateway-admin-role"

CLI_EXE=$(command -v akeyless)

# --- Phase 1: Authentication ---
echo "--- Authenticating for cleanup ---"
AUTH_OUT=$($CLI_EXE auth --access-type password --admin-email "$ADMIN_EMAIL" --admin-password "$ADMIN_PASSWORD")
SESSION_TOKEN=$(echo "$AUTH_OUT" | grep "Token:" | awk '{print $NF}' | tr -cd '[:print:]')

if [ -z "$SESSION_TOKEN" ]; then
    printf "${RED}Error: Authentication failed.${NC}\n"
    exit 1
fi
printf "${GREEN}Authentication successful.${NC}\n"

# --- Phase 2: Conditional Delete ---
echo "--- Starting cleanup ---"

# 1. Delete Admin Role
echo "Checking admin role..."
CHECK_ROLE=$(echo "$ROLE_NAME" | sed 's/^\///')
if $CLI_EXE list-roles --filter "$CHECK_ROLE" --token "$SESSION_TOKEN" | grep -q "$CHECK_ROLE"; then
    $CLI_EXE delete-role --name "$ROLE_NAME" --token "$SESSION_TOKEN" > /dev/null
    printf "${GREEN}SUCCESS: Role $ROLE_NAME deleted.${NC}\n"
else
    printf "${YELLOW}Role $ROLE_NAME not found (skipping).${NC}\n"
fi

# 2. Delete Admin Auth Method
echo "Checking admin auth method..."
CHECK_AUTH=$(echo "$AUTH_METHOD_NAME" | sed 's/^\///')
if $CLI_EXE list-auth-methods --filter "$CHECK_AUTH" --token "$SESSION_TOKEN" | grep -q "$CHECK_AUTH"; then
    $CLI_EXE auth-method delete --name "$AUTH_METHOD_NAME" --token "$SESSION_TOKEN" > /dev/null
    printf "${GREEN}SUCCESS: Auth method $AUTH_METHOD_NAME deleted.${NC}\n"
else
    printf "${YELLOW}Auth method $AUTH_METHOD_NAME not found (skipping).${NC}\n"
fi

# 3. Delete Gateway Role
echo "Checking gateway role..."
CHECK_GW_ROLE=$(echo "$GW_ROLE_NAME" | sed 's/^\///')
if $CLI_EXE list-roles --filter "$CHECK_GW_ROLE" --token "$SESSION_TOKEN" | grep -q "$CHECK_GW_ROLE"; then
    $CLI_EXE delete-role --name "$GW_ROLE_NAME" --token "$SESSION_TOKEN" > /dev/null
    printf "${GREEN}SUCCESS: Role $GW_ROLE_NAME deleted.${NC}\n"
else
    printf "${YELLOW}Role $GW_ROLE_NAME not found (skipping).${NC}\n"
fi

# 4. Delete Gateway Auth Method
echo "Checking gateway auth method..."
CHECK_GW_AUTH=$(echo "$GW_AUTH_METHOD_NAME" | sed 's/^\///')
if $CLI_EXE list-auth-methods --filter "$CHECK_GW_AUTH" --token "$SESSION_TOKEN" | grep -q "$CHECK_GW_AUTH"; then
    $CLI_EXE auth-method delete --name "$GW_AUTH_METHOD_NAME" --token "$SESSION_TOKEN" > /dev/null
    printf "${GREEN}SUCCESS: Auth method $GW_AUTH_METHOD_NAME deleted.${NC}\n"
else
    printf "${YELLOW}Auth method $GW_AUTH_METHOD_NAME not found (skipping).${NC}\n"
fi

echo "--- Cleanup Finished ---"