#!/bin/bash
# Test script to verify Docker deployment works

set -e

echo "=========================================="
echo "Testing Docker Deployment"
echo "=========================================="

# Colors
GREEN='\033[0.32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Build the image
echo -e "\n${GREEN}Step 1: Building Docker image...${NC}"
docker build -t ldap-auth-app:test -f deploy/Dockerfile .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build successful${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

# Step 2: Run the container
echo -e "\n${GREEN}Step 2: Starting container...${NC}"
docker run -d \
    --name ldap-auth-test \
    -p 5001:5000 \
    -e LDAP_SERVER=ldap://dc.domain.com \
    -e LDAP_BASE_DN=DC=domain,DC=com \
    -e LDAP_POOL_SIZE=10 \
    -e FLASK_DEBUG=False \
    ldap-auth-app:test

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Container started${NC}"
else
    echo -e "${RED}❌ Container failed to start${NC}"
    exit 1
fi

# Step 3: Wait for app to start
echo -e "\n${GREEN}Step 3: Waiting for app to start...${NC}"
sleep 5

# Step 4: Test health endpoint
echo -e "\n${GREEN}Step 4: Testing health endpoint...${NC}"
HEALTH_RESPONSE=$(curl -s http://localhost:5001/health || echo "failed")

if echo "$HEALTH_RESPONSE" | grep -q "status"; then
    echo -e "${GREEN}✅ Health check passed${NC}"
    echo "Response: $HEALTH_RESPONSE"
else
    echo -e "${RED}❌ Health check failed${NC}"
    echo "Response: $HEALTH_RESPONSE"
    docker logs ldap-auth-test
fi

# Step 5: Test root endpoint
echo -e "\n${GREEN}Step 5: Testing root endpoint...${NC}"
ROOT_RESPONSE=$(curl -s http://localhost:5001/ || echo "failed")

if echo "$ROOT_RESPONSE" | grep -q "username"; then
    echo -e "${GREEN}✅ Root endpoint works${NC}"
    echo "Response: $ROOT_RESPONSE"
else
    echo -e "${RED}❌ Root endpoint failed${NC}"
    echo "Response: $ROOT_RESPONSE"
fi

# Step 6: Check logs
echo -e "\n${GREEN}Step 6: Container logs:${NC}"
docker logs ldap-auth-test | tail -20

# Cleanup
echo -e "\n${GREEN}Cleaning up...${NC}"
docker stop ldap-auth-test
docker rm ldap-auth-test

echo -e "\n=========================================="
echo -e "${GREEN}✅ Docker deployment test complete!${NC}"
echo "=========================================="
echo ""
echo "To deploy for real:"
echo "  cd deploy"
echo "  docker-compose up -d"
