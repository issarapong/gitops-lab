#!/bin/bash

# GitOps Demo - Test All Environments
# This script demonstrates deploying the same application to different environments

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🚀 GitOps Multi-Environment Deployment Demo${NC}"
echo "================================================"
echo

# Ensure namespaces exist
echo -e "${BLUE}📋 Creating namespaces...${NC}"
kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -
echo

# Deploy to dev (default namespace)
echo -e "${YELLOW}📦 Deploying to DEV environment (default namespace)...${NC}"
kubectl apply -k clusters/dev/sample-app/
echo -e "${GREEN}✅ Dev deployment complete${NC}"
echo

# Deploy to staging
echo -e "${YELLOW}📦 Deploying to STAGING environment...${NC}"
kubectl apply -k clusters/staging/sample-app/
echo -e "${GREEN}✅ Staging deployment complete${NC}"
echo

# Deploy to production
echo -e "${YELLOW}📦 Deploying to PRODUCTION environment...${NC}"
kubectl apply -k clusters/prod/sample-app/
echo -e "${GREEN}✅ Production deployment complete${NC}"
echo

# Wait for all deployments to be ready
echo -e "${BLUE}⏳ Waiting for all deployments to be ready...${NC}"
kubectl wait --for=condition=Available deployment/sample-app --timeout=120s
kubectl wait --for=condition=Available deployment/sample-app -n staging --timeout=120s
kubectl wait --for=condition=Available deployment/sample-app -n production --timeout=120s
echo

# Show deployment status
echo -e "${CYAN}🔍 Deployment Status:${NC}"
kubectl get deployments -l app=sample-app --all-namespaces
echo

echo -e "${CYAN}🔍 Pod Status:${NC}"
kubectl get pods -l app=sample-app --all-namespaces
echo

echo -e "${CYAN}🎯 Environment Configuration Summary:${NC}"
echo "┌─────────────┬─────────┬─────────────┬─────────────────┐"
echo "│ Environment │ Replicas│ Namespace   │ Config          │"
echo "├─────────────┼─────────┼─────────────┼─────────────────┤"
echo "│ Development │    1    │ default     │ ENVIRONMENT=dev │"
echo "│ Staging     │    2    │ staging     │ ENVIRONMENT=stag│"
echo "│ Production  │    3    │ production  │ ENVIRONMENT=prod│"
echo "└─────────────┴─────────┴─────────────┴─────────────────┘"
echo

echo -e "${CYAN}🧪 Testing Applications:${NC}"
echo

# Test dev environment
echo -e "${YELLOW}Testing DEV environment...${NC}"
kubectl port-forward deployment/sample-app 8080:80 &
DEV_PID=$!
sleep 2

if curl -s http://localhost:8080 > /dev/null; then
    echo -e "${GREEN}✅ Dev application responding on http://localhost:8080${NC}"
else
    echo -e "${RED}❌ Dev application not responding${NC}"
fi
kill $DEV_PID 2>/dev/null || true

# Test staging environment
echo -e "${YELLOW}Testing STAGING environment...${NC}"
kubectl port-forward deployment/sample-app -n staging 8081:80 &
STAGING_PID=$!
sleep 2

if curl -s http://localhost:8081 > /dev/null; then
    echo -e "${GREEN}✅ Staging application responding on http://localhost:8081${NC}"
else
    echo -e "${RED}❌ Staging application not responding${NC}"
fi
kill $STAGING_PID 2>/dev/null || true

# Test production environment
echo -e "${YELLOW}Testing PRODUCTION environment...${NC}"
kubectl port-forward deployment/sample-app -n production 8082:80 &
PROD_PID=$!
sleep 2

if curl -s http://localhost:8082 > /dev/null; then
    echo -e "${GREEN}✅ Production application responding on http://localhost:8082${NC}"
else
    echo -e "${RED}❌ Production application not responding${NC}"
fi
kill $PROD_PID 2>/dev/null || true

echo
echo -e "${GREEN}🎉 GitOps Multi-Environment Demo Complete!${NC}"
echo
echo -e "${CYAN}What This Demonstrates:${NC}"
echo "• Same application deployed to 3 environments"
echo "• Different configurations per environment (replicas, env vars)"
echo "• Namespace isolation"
echo "• Kustomize overlay pattern"
echo "• GitOps declarative approach"
echo
echo -e "${CYAN}Manual Testing:${NC}"
echo "# Test each environment individually:"
echo "kubectl port-forward deployment/sample-app 8080:80                    # Dev"
echo "kubectl port-forward deployment/sample-app -n staging 8081:80         # Staging"
echo "kubectl port-forward deployment/sample-app -n production 8082:80      # Production"
echo
echo -e "${CYAN}Cleanup:${NC}"
echo "kubectl delete -k clusters/dev/sample-app/"
echo "kubectl delete -k clusters/staging/sample-app/"
echo "kubectl delete -k clusters/prod/sample-app/"
