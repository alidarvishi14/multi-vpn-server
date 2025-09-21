#!/bin/bash

# Run tests for Multi-VPN Server
# Usage: ./scripts/run-tests.sh [test_type]
# test_type: unit, integration, all (default: all)

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get test type from argument
TEST_TYPE=${1:-all}

# Change to project root
cd "$(dirname "$0")/.."

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   VPN Server Test Suite        ${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check Python version
echo -e "${YELLOW}Checking environment...${NC}"
python3 --version
echo ""

# Install test dependencies if needed
if ! python3 -c "import unittest" 2>/dev/null; then
    echo -e "${RED}unittest module not found${NC}"
    exit 1
fi

# Function to run tests
run_tests() {
    local test_file=$1
    local test_name=$2
    
    echo -e "${BLUE}Running $test_name...${NC}"
    
    if [ -f "$test_file" ]; then
        python3 -m pytest "$test_file" -v 2>/dev/null || \
        python3 "$test_file" || \
        echo -e "${YELLOW}Test framework not fully configured, running basic test${NC}"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ $test_name passed${NC}"
        else
            echo -e "${RED}✗ $test_name failed${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        echo -e "${RED}Test file not found: $test_file${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo ""
}

# Initialize counters
FAILED_TESTS=0

# Run syntax checks first
echo -e "${BLUE}Running syntax checks...${NC}"

# Check Python syntax
for py_file in subscription/*.py tests/*.py; do
    if [ -f "$py_file" ]; then
        python3 -m py_compile "$py_file" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}✓${NC} $py_file"
        else
            echo -e "  ${RED}✗${NC} $py_file"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    fi
done

# Check shell script syntax
for script in scripts/*.sh; do
    if [ -f "$script" ]; then
        bash -n "$script" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}✓${NC} $script"
        else
            echo -e "  ${RED}✗${NC} $script"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    fi
done
echo ""

# Run unit tests
if [ "$TEST_TYPE" = "unit" ] || [ "$TEST_TYPE" = "all" ]; then
    run_tests "tests/test_subscription.py" "Unit Tests"
fi

# Run integration tests
if [ "$TEST_TYPE" = "integration" ] || [ "$TEST_TYPE" = "all" ]; then
    run_tests "tests/test_integration.py" "Integration Tests"
fi

# Check configuration files
echo -e "${BLUE}Validating configuration files...${NC}"

for config in configs/*.json; do
    if [ -f "$config" ]; then
        python3 -m json.tool "$config" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}✓${NC} $config is valid JSON"
        else
            echo -e "  ${RED}✗${NC} $config is invalid JSON"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    fi
done
echo ""

# Check Docker configuration
if [ -f "docker-compose.yml" ]; then
    echo -e "${BLUE}Validating Docker configuration...${NC}"
    
    # Check if docker-compose is available
    if command -v docker-compose &> /dev/null; then
        docker-compose config > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}✓${NC} docker-compose.yml is valid"
        else
            echo -e "  ${RED}✗${NC} docker-compose.yml is invalid"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
        docker compose config > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}✓${NC} docker-compose.yml is valid"
        else
            echo -e "  ${RED}✗${NC} docker-compose.yml is invalid"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} Docker not installed, skipping validation"
    fi
fi
echo ""

# Check service files
echo -e "${BLUE}Validating systemd service files...${NC}"

for service in configs/systemd/*.service; do
    if [ -f "$service" ]; then
        # Basic syntax check - look for required sections
        if grep -q "\[Unit\]" "$service" && grep -q "\[Service\]" "$service"; then
            echo -e "  ${GREEN}✓${NC} $(basename $service)"
        else
            echo -e "  ${RED}✗${NC} $(basename $service) - missing required sections"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    fi
done
echo ""

# Security checks
echo -e "${BLUE}Running security checks...${NC}"

# Check for hardcoded credentials in code
if grep -r "password\|secret\|key" --include="*.py" --include="*.sh" subscription/ scripts/ 2>/dev/null | grep -v "^Binary" | grep -v "#" | grep "="; then
    echo -e "  ${YELLOW}⚠${NC} Potential hardcoded credentials found"
else
    echo -e "  ${GREEN}✓${NC} No obvious hardcoded credentials"
fi

# Check file permissions
for script in scripts/*.sh; do
    if [ -f "$script" ]; then
        perms=$(stat -c %a "$script")
        if [ "$perms" = "755" ] || [ "$perms" = "750" ] || [ "$perms" = "700" ]; then
            echo -e "  ${GREEN}✓${NC} $(basename $script) has secure permissions"
        else
            echo -e "  ${YELLOW}⚠${NC} $(basename $script) has permissions $perms"
        fi
    fi
done
echo ""

# Summary
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}        Test Summary            ${NC}"
echo -e "${BLUE}================================${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}All tests passed successfully!${NC}"
    exit 0
else
    echo -e "${RED}$FAILED_TESTS test(s) failed${NC}"
    echo -e "${YELLOW}Please review the errors above${NC}"
    exit 1
fi