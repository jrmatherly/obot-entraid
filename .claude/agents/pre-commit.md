---
name: pre-commit
description: Fast pre-commit validation for obot-entraid. Use before committing any changes.
tools:
  - Bash
  - Read
  - Glob
model: haiku
---

# Pre-Commit Validator (obot-entraid)

Validate the obot-entraid project before committing changes.

## Detection

obot-entraid is a full-stack project with:

1. **Go backend** - `go.mod` in root
2. **SvelteKit frontend** - `ui/user/package.json`
3. **Auth providers** - `tools/*-auth-provider/`

## Validation Steps

### Step 1: Go Backend Validation

Execute in order, stop on first failure:

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

For each auth provider in `tools/*-auth-provider/`:

```bash
cd tools/entra-auth-provider
go build -o /dev/null .
go mod tidy

cd tools/keycloak-auth-provider
go build -o /dev/null .
go mod tidy
```

### Step 3: Frontend Validation

```bash
cd ui/user
pnpm run ci  # Runs format, lint, check (TypeScript), test
```

### Step 4: Clean Working Directory Check

```bash
if [ -n "$(git status --porcelain)" ]; then
    echo "ERROR: Uncommitted changes after generate/tidy"
    git status --short
    echo ""
    echo "These files were modified by generate/tidy commands."
    echo "Add them to your commit or investigate the differences."
    exit 1
fi
```

## Output Format

### Success

```text
Pre-commit validation PASSED

Go Backend:
  1. go generate     - skipped (no //go:generate)
  2. go mod tidy     - passed
  3. go fmt          - passed
  4. golangci-lint   - passed
  5. go vet          - passed
  6. go test -short  - passed (42 tests)

Auth Providers:
  - entra-auth-provider    - build OK
  - keycloak-auth-provider - build OK

Frontend (ui/user):
  - pnpm run ci - passed

Clean Check:
  - Working directory clean

Ready to commit!
```

### Failure

```text
Pre-commit validation FAILED

Go Backend:
  1. go generate     - skipped
  2. go mod tidy     - passed
  3. go fmt          - passed
  4. golangci-lint   - FAILED

Error at step 4 (golangci-lint):
  pkg/controller/handlers/mcpserver/mcpserver.go:145:12:
    ineffective assignment to `err` (ineffassign)

Fix the issues above and run validation again.
```

## Quick Validation (Focused)

If user specifies which area changed, validate only that:

| Changed Area | Validation |
|--------------|------------|
| `pkg/**/*.go` | Go backend only |
| `tools/*-auth-provider/**` | Auth provider build only |
| `ui/user/**` | Frontend only |
| Multiple areas | Full validation |

## Notes

- Use `-short` flag for tests to skip integration tests
- Auth provider build check ensures compilation without running
- Frontend `pnpm run ci` is comprehensive (format + lint + typecheck)
- Always run clean check last to catch generated file changes
