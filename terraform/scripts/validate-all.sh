#!/bin/bash
# Validate all Terraform environments
# This script validates Terraform configurations across all environments
# to ensure syntax and configuration correctness before deployment.
#
# Usage:
#   ./terraform/scripts/validate-all.sh
#
# Requirements:
#   - Terraform >= 1.13.4 installed
#   - All environments initialized (terraform init run in each)

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Terraform Multi-Environment Validation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Track overall success
ALL_VALID=true

# Function to validate a single environment
validate_environment() {
    local env_name=$1
    local env_path="${TERRAFORM_DIR}/environments/${env_name}"

    echo -e "${YELLOW}Validating ${env_name} environment...${NC}"

    # Check if directory exists
    if [ ! -d "$env_path" ]; then
        echo -e "${RED}✗ Environment directory not found: ${env_path}${NC}"
        ALL_VALID=false
        return 1
    fi

    # Change to environment directory
    cd "$env_path"

    # Check if Terraform is initialized
    if [ ! -d ".terraform" ]; then
        echo -e "${YELLOW}  ⚠ Environment not initialized. Running terraform init...${NC}"
        if ! terraform init -backend=false > /dev/null 2>&1; then
            echo -e "${RED}  ✗ Failed to initialize ${env_name}${NC}"
            ALL_VALID=false
            return 1
        fi
    fi

    # Run terraform validate (capture output to avoid running twice)
    local validate_output
    if validate_output=$(terraform validate 2>&1); then
        echo -e "${GREEN}  ✓ ${env_name} configuration is valid${NC}"
    else
        echo -e "${RED}  ✗ ${env_name} validation failed${NC}"
        echo "${validate_output}"
        ALL_VALID=false
        return 1
    fi

    echo ""
}

# Discover environments dynamically from directory
ENVIRONMENTS=()
if [ -d "${TERRAFORM_DIR}/environments" ]; then
    for env_dir in "${TERRAFORM_DIR}/environments"/*; do
        if [ -d "$env_dir" ]; then
            ENVIRONMENTS+=("$(basename "$env_dir")")
        fi
    done
fi

# Validate each environment
# Using `|| true` ensures the loop continues even if validation fails
for env in "${ENVIRONMENTS[@]}"; do
    validate_environment "$env" || true
done

# Summary
echo -e "${BLUE}========================================${NC}"
if [ "$ALL_VALID" = true ]; then
    echo -e "${GREEN}✓ All environments validated successfully!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some environments failed validation${NC}"
    exit 1
fi
