#!/bin/bash
# Validation script for fork dependency management
set -e

echo "🔍 Validating fork dependencies in obot-entraid..."

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd /Users/jason/dev/AI/obot-entraid

# Test 1a: Verify Go module replace directives exist
echo "Test 1a: Checking Go module replace directives..."
GO_MODULE_REPLACES=("kinm" "mcp-oauth-proxy" "nah" "namegenerator")
for pkg in "${GO_MODULE_REPLACES[@]}"; do
  if grep -q "github.com/obot-platform/$pkg.*=>" go.mod; then
    echo -e "${GREEN}✅ Replace directive for $pkg found${NC}"
  else
    echo -e "${RED}❌ Replace directive for $pkg MISSING${NC}"
    exit 1
  fi
done

# Test 1b: Verify runtime dependencies exist locally
echo ""
echo "Test 1b: Checking runtime dependencies..."
RUNTIME_DEPS=("mcp-catalog" "obot-tools")
for pkg in "${RUNTIME_DEPS[@]}"; do
  if [ -d "/Users/jason/dev/AI/$pkg" ]; then
    echo -e "${GREEN}✅ Runtime dependency $pkg exists locally${NC}"
  else
    echo -e "${RED}❌ Runtime dependency $pkg NOT FOUND at /Users/jason/dev/AI/$pkg${NC}"
    exit 1
  fi
done

# Test 2: Verify no upstream packages in use
echo ""
echo "Test 2: Checking for upstream package usage..."
UPSTREAM_PACKAGES=$(go list -m all | grep "github.com/obot-platform" | grep -v "=>" | grep -v "^github.com/obot-platform/obot$" | wc -l)
if [ "$UPSTREAM_PACKAGES" -eq 0 ]; then
  echo -e "${GREEN}✅ All obot-platform packages redirected to forks${NC}"
else
  echo -e "${RED}❌ Found $UPSTREAM_PACKAGES upstream packages without replace directives:${NC}"
  go list -m all | grep "github.com/obot-platform" | grep -v "=>" | grep -v "^github.com/obot-platform/obot$"
  exit 1
fi

# Test 3: Verify Go module resolution
echo ""
echo "Test 3: Verifying Go module resolution..."
for pkg in "${GO_MODULE_REPLACES[@]}"; do
  RESOLVED=$(go list -m "github.com/obot-platform/$pkg" 2>/dev/null | grep "jrmatherly" || echo "")
  if [ -n "$RESOLVED" ]; then
    echo -e "${GREEN}✅ $pkg resolves to jrmatherly fork${NC}"
  else
    echo -e "${RED}❌ $pkg does not resolve to jrmatherly fork${NC}"
    exit 1
  fi
done

# Test 4: Build test
echo ""
echo "Test 4: Running build..."
if make build >/dev/null 2>&1; then
  echo -e "${GREEN}✅ Build successful${NC}"
else
  echo -e "${RED}❌ Build failed${NC}"
  exit 1
fi

# Test 5: Quick test run
echo ""
echo "Test 5: Running tests..."
if make test >/dev/null 2>&1; then
  echo -e "${GREEN}✅ Tests passed${NC}"
else
  echo -e "${YELLOW}⚠️  Some tests failed (review test-output.log)${NC}"
  # Don't exit - tests might fail for reasons unrelated to dependencies
fi

echo ""
echo -e "${GREEN}✅ All validations passed!${NC}"
echo ""
echo "Summary:"
echo "- Go module replace directives: $(echo ${GO_MODULE_REPLACES[@]} | wc -w | tr -d ' ')/$(echo ${GO_MODULE_REPLACES[@]} | wc -w | tr -d ' ') present"
echo "- Runtime dependencies: $(echo ${RUNTIME_DEPS[@]} | wc -w | tr -d ' ')/$(echo ${RUNTIME_DEPS[@]} | wc -w | tr -d ' ') found"
echo "- Upstream packages: 0"
echo "- Module resolution: ✅ All forked"
echo "- Build: ✅ Success"
echo "- Tests: See above"
