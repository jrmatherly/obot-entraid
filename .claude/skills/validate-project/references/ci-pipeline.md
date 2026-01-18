# CI Pipeline Reference

Documentation for obot-entraid CI/CD pipeline and local reproduction.

## GitHub Actions Workflows

### Main CI Workflow

Location: `.github/workflows/ci.yml`

**Triggers:**

- Push to `main` branch
- Pull requests to `main`

**Jobs:**

1. **build** - Build Docker image
2. **test** - Run Go tests
3. **lint** - Run golangci-lint
4. **frontend** - Run frontend validation

### Release Workflow

Location: `.github/workflows/release.yml`

**Triggers:**

- Tag push matching `v*`

**Jobs:**

1. Build multi-arch Docker image
2. Push to container registry
3. Create GitHub release

## Local Reproduction

### Full CI Equivalent

```bash
# 1. Go validation (same as CI)
go mod tidy
go fmt ./...
golangci-lint run
go vet ./...
go test -short ./...

# 2. Auth provider builds
for dir in tools/*-auth-provider; do
    (cd "$dir" && go build -o /dev/null .)
done

# 3. Frontend validation
cd ui/user && pnpm run ci

# 4. Clean check
git diff --exit-code
```

### Docker Build Test

```bash
# Build image locally (same as CI)
docker build -t obot-entraid:local .

# Verify image runs
docker run --rm obot-entraid:local --help
```

## Common CI Failures

### Lint Failures

**Error:** `golangci-lint: error`

**Fix:**

```bash
# See specific errors
golangci-lint run

# Auto-fix some issues
golangci-lint run --fix
```

### Tidy Failures

**Error:** `go.mod is not tidy`

**Fix:**

```bash
go mod tidy
git add go.mod go.sum
```

### Frontend Type Errors

**Error:** `pnpm run check failed`

**Fix:**

```bash
cd ui/user
pnpm run check  # See specific TypeScript errors
```

### Auth Provider Build Failures

**Error:** `cannot find module`

**Fix:**

```bash
cd tools/entra-auth-provider
go mod tidy
go build -o /dev/null .
```

## Integration Tests

### Running Locally

```bash
# Start dev environment
make dev

# Run integration tests (separate terminal)
make test-integration
```

### Common Integration Test Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| 503 on health check | Database not ready | Wait for DB, check DSN |
| Controller never ready | Bookmark interval (K8s v0.35.0+) | Check kinm bookmark config |
| Auth failures | Missing env vars | Set OBOT_* variables |

## Environment Variables for CI

### Required for Tests

```bash
export OBOT_SERVER_DSN="postgres://..."
export OBOT_AUTH_PROVIDER_COOKIE_SECRET="$(openssl rand -base64 32)"
```

### Required for Auth Provider Tests

```bash
export OBOT_ENTRA_AUTH_PROVIDER_CLIENT_ID="test-client"
export OBOT_ENTRA_AUTH_PROVIDER_CLIENT_SECRET="test-secret"
```

## Caching

### Go Module Cache

CI caches `~/go/pkg/mod` between runs. If you suspect cache issues:

```bash
go clean -modcache
go mod download
```

### pnpm Cache

CI caches `node_modules`. For fresh install:

```bash
rm -rf ui/user/node_modules
cd ui/user && pnpm install
```

## Parallel Execution

For faster local validation, run independent checks in parallel:

```bash
# Run in parallel (using & and wait)
golangci-lint run &
go test -short ./... &
(cd ui/user && pnpm run ci) &
wait
```

## Pre-Push Hook

Consider adding a pre-push hook:

```bash
#!/bin/bash
# .git/hooks/pre-push

echo "Running pre-push validation..."
make validate-go-code
(cd ui/user && pnpm run ci)
```

Make executable:

```bash
chmod +x .git/hooks/pre-push
```
