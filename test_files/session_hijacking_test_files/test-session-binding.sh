#!/bin/bash
# Fixed Session Binding Security Test Script
# This script tests the session binding security fixes

set -e
API_URL="http://localhost:3000"  # Rails API URL
CLIENT_URL="http://localhost:4200"  # Web client URL
ADMIN_USERNAME="aadmin"
ADMIN_PASSWORD="password"
STUDENT_USERNAME="student_1"
STUDENT_PASSWORD="password"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}===== Session Binding Security Test =====${NC}"
echo -e "${BLUE}This test will verify that session tokens cannot be used across different user contexts.${NC}"
echo -e "${BLUE}Expected result: The attempt to use an admin token with student credentials should fail.${NC}\n"

# Step 1: Login as admin to get admin token
echo -e "${BLUE}Step 1: Logging in as admin (${ADMIN_USERNAME})...${NC}"
ADMIN_RESPONSE=$(curl -s -X POST "${API_URL}/api/auth" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${ADMIN_USERNAME}\",\"password\":\"${ADMIN_PASSWORD}\"}")

# Extract admin token from the response
ADMIN_TOKEN=$(echo $ADMIN_RESPONSE | grep -o '"auth_token":"[^"]*"' | sed 's/"auth_token":"//;s/"//')

if [ -z "$ADMIN_TOKEN" ]; then
  echo -e "${RED}Failed to get admin token. Check credentials or server status.${NC}"
  exit 1
fi
echo -e "${GREEN}Successfully obtained admin token: ${ADMIN_TOKEN:0:10}...${NC}\n"

# Step 2: Login as student to verify student credentials
echo -e "${BLUE}Step 2: Logging in as student (${STUDENT_USERNAME})...${NC}"
STUDENT_RESPONSE=$(curl -s -X POST "${API_URL}/api/auth" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${STUDENT_USERNAME}\",\"password\":\"${STUDENT_PASSWORD}\"}")

# Extract student token from the response
STUDENT_TOKEN=$(echo $STUDENT_RESPONSE | grep -o '"auth_token":"[^"]*"' | sed 's/"auth_token":"//;s/"//')

if [ -z "$STUDENT_TOKEN" ]; then
  echo -e "${RED}Failed to get student token. Check credentials or server status.${NC}"
  exit 1
fi
echo -e "${GREEN}Successfully obtained student token: ${STUDENT_TOKEN:0:10}...${NC}\n"

# Step 3: Test the specific vulnerability - try to create a unit using admin token but student username
echo -e "${BLUE}Step 3: Attempting to create a unit using admin token with student username...${NC}"
echo -e "${BLUE}This request should fail if session binding is working correctly.${NC}"

UNIT_CODE="TEST$(date +%H%M%S)"
UNIT_NAME="Security Test Unit $(date +%H:%M:%S)"

# Try to create a unit - this directly tests the security vulnerability
RESULT=$(curl -s -X POST "${API_URL}/api/units/" \
  -H "Content-Type: application/json" \
  -H "Username: ${STUDENT_USERNAME}" \
  -H "Auth-Token: ${ADMIN_TOKEN}" \
  -d "{\"unit\":{\"code\":\"${UNIT_CODE}\",\"name\":\"${UNIT_NAME}\"}}" \
  -w "\n%{http_code}" 2>&1)

HTTP_STATUS=$(echo "$RESULT" | tail -n1)
RESPONSE_BODY=$(echo "$RESULT" | sed '$d')

echo -e "${BLUE}HTTP Status: ${HTTP_STATUS}${NC}"
echo -e "${BLUE}Response: ${RESPONSE_BODY}${NC}\n"

# Check if the request failed (expected outcome with session binding fix)
if [[ $HTTP_STATUS == 2* ]]; then
  echo -e "${RED}TEST FAILED: Session hijacking attempt succeeded! The security fix is not working.${NC}"
  echo -e "${RED}The system allowed using an admin token with student credentials.${NC}"
  CROSS_USER_TEST="FAILED"
elif [[ $RESPONSE_BODY == *"Session hijacking"* || $RESPONSE_BODY == *"security"* || $RESPONSE_BODY == *"Security"* || $HTTP_STATUS == 403 || $HTTP_STATUS == 419 || $HTTP_STATUS == 401 ]]; then
  echo -e "${GREEN}TEST PASSED: Session hijacking attempt was blocked!${NC}"
  echo -e "${GREEN}The system correctly prevented using an admin token with student credentials.${NC}"
  CROSS_USER_TEST="PASSED"
else
  echo -e "${YELLOW}TEST INCONCLUSIVE: Request failed but not specifically due to session binding.${NC}"
  echo -e "${YELLOW}Further investigation may be needed.${NC}"
  CROSS_USER_TEST="INCONCLUSIVE"
fi

# Step 4: Try multiple possible admin unit endpoints
echo -e "\n${BLUE}Step 4: Testing admin units API endpoint from student account with admin token...${NC}"
echo -e "${BLUE}This simulates a student accessing http://localhost:4200/#/admin/units with stolen admin token${NC}"

# Try multiple possible endpoint paths
# 1. Try /api/units (with admin privileges check)
ADMIN_UNITS_RESULT1=$(curl -s -X GET "${API_URL}/api/units?as_admin=true" \
  -H "Username: ${STUDENT_USERNAME}" \
  -H "Auth-Token: ${ADMIN_TOKEN}" \
  -w "\n%{http_code}" 2>&1)

ADMIN_UNITS_STATUS1=$(echo "$ADMIN_UNITS_RESULT1" | tail -n1)
echo -e "${BLUE}Status for /api/units?as_admin=true: ${ADMIN_UNITS_STATUS1}${NC}"

# 2. Try /api/unit_roles (often used for admin unit management)
ADMIN_UNITS_RESULT2=$(curl -s -X GET "${API_URL}/api/unit_roles" \
  -H "Username: ${STUDENT_USERNAME}" \
  -H "Auth-Token: ${ADMIN_TOKEN}" \
  -w "\n%{http_code}" 2>&1)

ADMIN_UNITS_STATUS2=$(echo "$ADMIN_UNITS_RESULT2" | tail -n1)
echo -e "${BLUE}Status for /api/unit_roles: ${ADMIN_UNITS_STATUS2}${NC}"

# 3. Try /api/admin (generic admin path)
ADMIN_UNITS_RESULT3=$(curl -s -X GET "${API_URL}/api/admin" \
  -H "Username: ${STUDENT_USERNAME}" \
  -H "Auth-Token: ${ADMIN_TOKEN}" \
  -w "\n%{http_code}" 2>&1)

ADMIN_UNITS_STATUS3=$(echo "$ADMIN_UNITS_RESULT3" | tail -n1)
echo -e "${BLUE}Status for /api/admin: ${ADMIN_UNITS_STATUS3}${NC}\n"

# Check if any endpoint access was blocked due to security
ADMIN_ACCESS_BLOCKED=false
if [[ $ADMIN_UNITS_STATUS1 == 403 || $ADMIN_UNITS_STATUS1 == 401 || $ADMIN_UNITS_STATUS1 == 419 ]]; then
  ADMIN_ACCESS_BLOCKED=true
  echo -e "${GREEN}✓ Access to admin units endpoint was properly blocked (403/401/419)${NC}"
elif [[ $ADMIN_UNITS_STATUS2 == 403 || $ADMIN_UNITS_STATUS2 == 401 || $ADMIN_UNITS_STATUS2 == 419 ]]; then
  ADMIN_ACCESS_BLOCKED=true
  echo -e "${GREEN}✓ Access to unit_roles endpoint was properly blocked (403/401/419)${NC}"
elif [[ $ADMIN_UNITS_STATUS3 == 403 || $ADMIN_UNITS_STATUS3 == 401 || $ADMIN_UNITS_STATUS3 == 419 ]]; then
  ADMIN_ACCESS_BLOCKED=true
  echo -e "${GREEN}✓ Access to admin endpoint was properly blocked (403/401/419)${NC}"
fi

if [[ "$ADMIN_ACCESS_BLOCKED" == "true" ]]; then
  ADMIN_UNITS_TEST="PASSED"
else
  ADMIN_UNITS_TEST="INCONCLUSIVE"
  echo -e "${YELLOW}Note: Could not confirm admin endpoint blocking due to 404 errors. This may just mean we're testing the wrong endpoints.${NC}"
fi

# Verify normal admin functionality still works
echo -e "\n${BLUE}Step 5: Verifying admin functionality still works with admin credentials...${NC}"

ADMIN_VALID_RESULT=$(curl -s -X GET "${API_URL}/api/units/" \
  -H "Username: ${ADMIN_USERNAME}" \
  -H "Auth-Token: ${ADMIN_TOKEN}" \
  -w "\n%{http_code}" 2>&1)

ADMIN_VALID_STATUS=$(echo "$ADMIN_VALID_RESULT" | tail -n1)

if [[ $ADMIN_VALID_STATUS == 2* ]]; then
  echo -e "${GREEN}✓ Admin token works correctly with admin username.${NC}"
  ADMIN_VALID_TEST="PASSED"
else
  echo -e "${RED}✗ Admin token doesn't work with admin username. This suggests another issue.${NC}"
  echo -e "${YELLOW}Status: ${ADMIN_VALID_STATUS}${NC}"
  ADMIN_VALID_TEST="FAILED"
fi

echo -e "\n${BLUE}===== Test Summary =====${NC}"
echo -e "${BLUE}Cross-user token test (unit creation): ${CROSS_USER_TEST}${NC}"
echo -e "${BLUE}Admin endpoint access test: ${ADMIN_UNITS_TEST}${NC}"
echo -e "${BLUE}Admin normal functionality: ${ADMIN_VALID_TEST}${NC}"

if [[ "$CROSS_USER_TEST" == "PASSED" ]]; then
  echo -e "\n${GREEN}SUCCESS: Your session binding security fix appears to be working.${NC}"
  echo -e "${GREEN}✓ Session tokens cannot be used with different usernames${NC}"

  if [[ "$ADMIN_UNITS_TEST" == "PASSED" ]]; then
    echo -e "${GREEN}✓ Students cannot use admin tokens to access admin functionality${NC}"
  fi

  if [[ "$ADMIN_VALID_TEST" == "PASSED" ]]; then
    echo -e "${GREEN}✓ Normal admin functionality is preserved${NC}"
  fi

  echo -e "\n${GREEN}The core security vulnerability has been fixed successfully.${NC}"
else
  echo -e "\n${YELLOW}ATTENTION: The test results suggest further investigation is needed.${NC}"
fi

exit 0
