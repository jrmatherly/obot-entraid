---
name: validate-project
description: Run full CI validation for obot-entraid (Go backend + auth providers + frontend)
version: 1.0.0
author: obot-entraid team
tags: [ci, validation, pre-commit, testing]
---

# Validate Project

Run complete pre-commit validation for obot-entraid.

## When to Use

- Before committing changes
- After major refactoring
- When CI is failing and you need to reproduce locally
- Before creating a pull request
- After merging upstream changes

## Components to Validate

obot-entraid has three main components:

1. **Go Backend** - Main server code in `pkg/`
2. **Auth Providers** - Custom OAuth providers in `tools/*-auth-provider/`
3. **SvelteKit Frontend** - User interface in `ui/user/`

## Instructions

### Step 1: Go Backend Validation

```bash
# 1. Generate code (if applicable)
if grep -rq "go:generate" *.go pkg/ 2>/dev/null; then
    go generate ./...
fi

# 2. Tidy dependencies
go mod tidy

# 3. Format code
go fmt ./...

# 4. Lint (uses .golangci.yml)
golangci-lint run

# 5. Vet
go vet ./...

# 6. Test (short mode, skip integration)
go test -short ./...
```

### Step 2: Auth Provider Validation

For each provider in `tools/*-auth-provider/`:

```bash
# Entra Auth Provider
cd tools/entra-auth-provider
go build -o /dev/null .
go mod tidy

# Keycloak Auth Provider
cd tools/keycloak-auth-provider
go build -o /dev/null .
go mod tidy
```

### Step 3: Frontend Validation

```bash
cd ui/user
pnpm run ci  # Runs format, lint, check (TypeScript), test
```

### Step 4: Clean Check

```bash
if [ -n "$(git status --porcelain)" ]; then
    echo "ERROR: Uncommitted changes after generate/tidy"
    git status --short
    exit 1
fi
```

## Resources

Load these Level 3 resources as needed:

- `references/ci-pipeline.md` - CI pipeline documentation and troubleshooting
- Serena memory `task_completion_checklist` - Pre-commit validation checklist

## Examples

### Example 1: Full Validation

**User asks:** "Validate my changes before committing"

**Response:**

1. Run Go backend validation (generate, tidy, fmt, lint, vet, test)
2. Build auth providers to verify compilation
3. Run frontend validation (pnpm run ci)
4. Check for uncommitted changes
5. Report status with checkmarks for each step

### Example 2: Focused Validation

**User asks:** "I only changed the entra auth provider"

**Response:**

1. Navigate to `tools/entra-auth-provider/`
2. Run `go build -o /dev/null .`
3. Run `go mod tidy`
4. Verify no uncommitted changes
5. Suggest running full validation before final commit

### Example 3: After Upstream Merge

**User asks:** "Just merged upstream, need to validate"

**Response:**

1. Run full validation (all three components)
2. Pay special attention to dependency conflicts
3. Check for breaking changes in APIs
4. Verify auth provider compatibility
5. Run integration tests if time permits

## Quick Reference

| Component | Validation Command | Location |
|-----------|-------------------|----------|
| Go Backend | `make validate-go-code` | Root |
| Auth Providers | `go build -o /dev/null .` | `tools/*-auth-provider/` |
| Frontend | `pnpm run ci` | `ui/user/` |

## Notes

- Stop on first failure for faster feedback
- Always run clean check last to catch generated file changes
- Use `--short` flag for tests to skip long-running integration tests
- Auth provider build check ensures compilation without credentials
- Consider running `make test-integration` for major changes
