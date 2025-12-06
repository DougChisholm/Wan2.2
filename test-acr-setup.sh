#!/bin/bash

# Test script to validate ACR task configuration and Dockerfile changes
# This script verifies that the Python installation setup is correct for ACR tasks

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Testing ACR Task Configuration and Dockerfile...${NC}"
echo "================================================================"

# Test 1: Validate ACR task YAML syntax
echo -e "\n${BLUE}Test 1: Validating acr-task.yaml syntax...${NC}"
if python3 -c "import yaml; yaml.safe_load(open('acr-task.yaml'))" 2>/dev/null; then
    echo -e "${GREEN}✓ acr-task.yaml is valid YAML${NC}"
else
    echo -e "${RED}✗ acr-task.yaml has syntax errors${NC}"
    exit 1
fi

# Test 2: Validate deployment scripts syntax
echo -e "\n${BLUE}Test 2: Validating shell script syntax...${NC}"
if bash -n deploy.sh && bash -n deploy-acr-task.sh; then
    echo -e "${GREEN}✓ Shell scripts have valid syntax${NC}"
else
    echo -e "${RED}✗ Shell scripts have syntax errors${NC}"
    exit 1
fi

# Test 3: Check Dockerfile for Python installation
echo -e "\n${BLUE}Test 3: Checking Dockerfile for Python installation...${NC}"
if grep -q "python3" Dockerfile && grep -q "python3-pip" Dockerfile && grep -q "python3-dev" Dockerfile; then
    echo -e "${GREEN}✓ Dockerfile includes Python3 installation${NC}"
else
    echo -e "${RED}✗ Dockerfile missing Python installation${NC}"
    exit 1
fi

# Test 4: Check Dockerfile for build-essential (required for ACR builds)
echo -e "\n${BLUE}Test 4: Checking Dockerfile for build tools...${NC}"
if grep -q "build-essential" Dockerfile; then
    echo -e "${GREEN}✓ Dockerfile includes build-essential${NC}"
else
    echo -e "${RED}✗ Dockerfile missing build-essential${NC}"
    exit 1
fi

# Test 5: Check Dockerfile for update-alternatives setup
echo -e "\n${BLUE}Test 5: Checking Dockerfile for Python alternatives setup...${NC}"
if grep -q "update-alternatives" Dockerfile; then
    echo -e "${GREEN}✓ Dockerfile configures Python alternatives${NC}"
else
    echo -e "${RED}✗ Dockerfile missing Python alternatives configuration${NC}"
    exit 1
fi

# Test 6: Verify ACR task file includes timeout
echo -e "\n${BLUE}Test 6: Checking ACR task timeout configuration...${NC}"
if grep -q "timeout: 3600" acr-task.yaml; then
    echo -e "${GREEN}✓ ACR task has appropriate timeout (3600s)${NC}"
else
    echo -e "${RED}✗ ACR task missing or has incorrect timeout${NC}"
    exit 1
fi

# Test 7: Check that deploy-acr-task.sh is executable
echo -e "\n${BLUE}Test 7: Checking deploy-acr-task.sh permissions...${NC}"
if [ -x deploy-acr-task.sh ]; then
    echo -e "${GREEN}✓ deploy-acr-task.sh is executable${NC}"
else
    echo -e "${RED}✗ deploy-acr-task.sh is not executable${NC}"
    exit 1
fi

# Test 8: Verify documentation mentions ACR tasks
echo -e "\n${BLUE}Test 8: Checking documentation for ACR task information...${NC}"
if grep -q "ACR Task" DEPLOYMENT.md && grep -q "acr-task" DEPLOYMENT.md; then
    echo -e "${GREEN}✓ DEPLOYMENT.md includes ACR task documentation${NC}"
else
    echo -e "${RED}✗ DEPLOYMENT.md missing ACR task documentation${NC}"
    exit 1
fi

# Test 9: Verify README mentions ACR tasks
echo -e "\n${BLUE}Test 9: Checking README for ACR task mention...${NC}"
if grep -q "ACR" README.md; then
    echo -e "${GREEN}✓ README.md mentions ACR tasks${NC}"
else
    echo -e "${RED}✗ README.md missing ACR task mention${NC}"
    exit 1
fi

echo ""
echo "================================================================"
echo -e "${GREEN}All tests passed! ✓${NC}"
echo "================================================================"
echo ""
echo "Summary of changes:"
echo "  - Dockerfile updated with robust Python installation for ACR tasks"
echo "  - Added build-essential package for compilation support"
echo "  - Created acr-task.yaml for ACR task builds"
echo "  - Created deploy-acr-task.sh for easy ACR deployment"
echo "  - Updated documentation with ACR task instructions"
echo ""
echo "You can now build Docker images using ACR tasks without local Docker!"
echo ""
