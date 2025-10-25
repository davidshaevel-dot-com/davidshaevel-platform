#!/bin/bash
# Estimate Terraform infrastructure costs
# This script runs terraform plan for specified environments and provides
# cost estimation information.
#
# Usage:
#   ./terraform/scripts/cost-estimate.sh [environment]
#
# Examples:
#   ./terraform/scripts/cost-estimate.sh dev    # Estimate dev environment
#   ./terraform/scripts/cost-estimate.sh prod   # Estimate prod environment
#   ./terraform/scripts/cost-estimate.sh        # Estimate all environments
#
# Requirements:
#   - Terraform >= 1.13.4 installed
#   - Environment variables set (TF_VAR_* or .envrc sourced)
#   - Environments initialized (terraform init run in each)

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
echo -e "${BLUE}Terraform Cost Estimation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to estimate costs for a single environment
estimate_environment() {
    local env_name=$1
    local env_path="${TERRAFORM_DIR}/environments/${env_name}"

    # Create secure temporary file and ensure cleanup
    local plan_file
    plan_file=$(mktemp)
    trap 'rm -f -- "$plan_file"' RETURN

    echo -e "${YELLOW}Estimating costs for ${env_name} environment...${NC}"
    echo ""

    # Check if directory exists
    if [ ! -d "$env_path" ]; then
        echo -e "${RED}✗ Environment directory not found: ${env_path}${NC}"
        return 1
    fi

    # Change to environment directory
    cd "$env_path"

    # Check if Terraform is initialized
    if [ ! -d ".terraform" ]; then
        echo -e "${YELLOW}  ⚠ Environment not initialized. Running terraform init...${NC}"
        if ! terraform init -backend=false > /dev/null 2>&1; then
            echo -e "${RED}  ✗ Failed to initialize ${env_name}${NC}"
            return 1
        fi
    fi

    # Run terraform plan
    echo -e "${BLUE}Running terraform plan for ${env_name}...${NC}"

    # Use placeholder for aws_account_id if not set
    if [ -z "${TF_VAR_aws_account_id}" ]; then
        echo -e "${YELLOW}  ⚠ TF_VAR_aws_account_id not set, using placeholder${NC}"
        export TF_VAR_aws_account_id="123456789012"
    fi

    if terraform plan -input=false -no-color > "$plan_file" 2>&1; then
        echo -e "${GREEN}  ✓ Plan generated successfully${NC}"
        echo ""

        # Display resource changes
        echo -e "${BLUE}Resource Changes:${NC}"
        grep -E "Plan:|No changes" "$plan_file" || echo "  No resources to create (configuration only)"
        echo ""

        # Cost estimation notes
        echo -e "${BLUE}Cost Estimation Notes:${NC}"
        echo -e "  ${YELLOW}Note: Terraform does not provide automatic cost estimation.${NC}"
        echo -e "  ${YELLOW}For detailed cost estimates, consider using:${NC}"
        echo -e "  - AWS Pricing Calculator: https://calculator.aws"
        echo -e "  - Infracost (open source): https://www.infracost.io"
        echo -e "  - terraform-cost-estimation tools"
        echo ""
    else
        echo -e "${RED}  ✗ Plan generation failed${NC}"
        cat "$plan_file"
        return 1
    fi

    echo -e "${BLUE}----------------------------------------${NC}"
    echo ""
}

# Determine which environments to estimate
if [ $# -eq 0 ]; then
    # No arguments - discover and estimate all environments dynamically
    ENVIRONMENTS=()
    if [ -d "${TERRAFORM_DIR}/environments" ]; then
        for env_dir in "${TERRAFORM_DIR}/environments"/*; do
            if [ -d "$env_dir" ]; then
                ENVIRONMENTS+=("$(basename "$env_dir")")
            fi
        done
    fi
else
    # Specific environment provided
    ENVIRONMENTS=("$1")
fi

# Validate that environments were found
if [ ${#ENVIRONMENTS[@]} -eq 0 ]; then
    echo -e "${RED}Error: No environments found in ${TERRAFORM_DIR}/environments/${NC}"
    exit 1
fi

# Estimate costs for each environment
ALL_SUCCESS=true
for env in "${ENVIRONMENTS[@]}"; do
    if ! estimate_environment "$env"; then
        ALL_SUCCESS=false
    fi
done

# Summary
echo -e "${BLUE}========================================${NC}"
if [ "$ALL_SUCCESS" = true ]; then
    echo -e "${GREEN}✓ Cost estimation completed successfully!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some estimations failed${NC}"
    exit 1
fi
