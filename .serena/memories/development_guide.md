# Development Guide for obot-entraid

This guide consolidates local development and debugging workflows.

## Quick Start

```bash
# Clone and run
git clone https://github.com/jrmatherly/obot-entraid
cd obot-entraid
make dev          # Full dev environment (API + UI with hot reload)
make dev-open     # Same + opens browser
```

**Access URLs**:

- User UI: http://localhost:8080/
- Admin UI: http://localhost:8080/admin/
- API: http://localhost:8080/api

## Dev Mode Features

`--dev-mode` enables:

- Debug logging (all levels)
- Kubectl access via `tools/devmode-kubeconfig`
- Simplified auth for local testing
- UI hot reload

### Kubectl Access

```bash
export KUBECONFIG=tools/devmode-kubeconfig

kubectl get agents
kubectl get mcpservers
kubectl get threads
kubectl get mcpservercatalogentries
kubectl describe agent <name>
kubectl get events --sort-by='.lastTimestamp'
```

## Database Access

**Dev mode uses SQLite**:

```bash
sqlite3 obot.db           # Main database
sqlite3 obot-credentials.db  # Encrypted credentials

# In SQLite
.tables
SELECT * FROM agents;
.quit
```

## Auth Provider Development

### Local Tool Registry

```bash
export OBOT_SERVER_TOOL_REGISTRIES=github.com/obot-platform/tools,./tools
```

### Environment Variables

**Entra ID**:

```bash
export OBOT_ENTRA_AUTH_PROVIDER_CLIENT_ID="..."
export OBOT_ENTRA_AUTH_PROVIDER_CLIENT_SECRET="..."
export OBOT_ENTRA_AUTH_PROVIDER_TENANT_ID="common"
export OBOT_AUTH_PROVIDER_COOKIE_SECRET="$(openssl rand -base64 32)"
```

### Testing Auth Provider

```bash
cd tools/entra-auth-provider
go build -o /dev/null .
go run .
curl http://localhost:9999/
curl -H "Authorization: Bearer <token>" http://localhost:9999/obot-get-user-info
```

## Resetting Environment

```bash
# Mac
rm -rf ~/Library/Application\ Support/obot && \
rm -rf ~/Library/Application\ Support/gptscript && \
rm obot.db obot-credentials.db

# Linux
rm -rf ~/.local/share/obot ~/.local/share/gptscript && \
rm obot.db obot-credentials.db
```

## Docker Development

```bash
docker build -t obot-entraid:dev .
docker run -p 8080:8080 obot-entraid:dev

# Verify tool registry
docker run --rm obot-entraid:dev cat /obot-tools/tools/index.yaml
```

## Debugging

### Enable Debug Logging

```bash
make dev                         # Auto-enables
./bin/obot server --dev-mode    # Manual
```

### Filter Logs

```bash
make dev | grep controller   # Controller logs
make dev | grep auth         # Auth logs
make dev | grep gateway      # Gateway logs
make dev | grep mcp          # MCP loader logs
```

### Controller Debugging

```bash
# Check controller running
make dev | grep "router.*started"

# Check leader election
make dev | grep "leader"

# Verify CRDs
kubectl get crd | grep obot.obot.ai

# Resource status
kubectl get agent <name> -o yaml
kubectl describe agent <name>
```

### Common Controller Issues

**Handler not triggered**:

- Check router started in logs
- Verify CRD registered
- Check handler registered in `pkg/controller/routes.go`

**Resource update conflicts**:

- Use fresh object in Update()
- Don't cache across invocations

**Finalizer stuck**:

```bash
# Check finalizers
kubectl get agent <name> -o yaml | grep finalizers -A 5

# Force remove (testing only!)
kubectl patch agent <name> -p '{"metadata":{"finalizers":null}}' --type=merge
```

### Auth Provider Issues

**Profile picture 401**:

- icon_url must be base64 data URL, not Graph API URL
- See `auth_fix_jan2026` memory

**Field name mismatch**:

- Map `displayName` → `name`
- See `.claude/rules/auth-provider-go.md`

**Cookie not persisting**:

- Check OBOT_AUTH_PROVIDER_COOKIE_SECRET set
- Check Secure flag matches protocol
- Cookie name must be `obot_access_token`

### API Issues

```bash
# Test endpoint
curl -v http://localhost:8080/api/agents

# With auth
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/agents
```

### Database Issues

```bash
# Read-only access while server running
sqlite3 -readonly obot.db

# Corrupted database - delete and restart
rm obot.db obot-credentials.db
make dev
```

## IDE Debugging

### VS Code (launch.json)

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Obot Server (Dev)",
      "type": "go",
      "request": "launch",
      "mode": "debug",
      "program": "${workspaceFolder}",
      "args": ["server", "--dev-mode"]
    }
  ]
}
```

### GoLand

- Run → Edit Configurations → Go Build
- Package: `github.com/obot-platform/obot`
- Args: `server --dev-mode`

## Essential Commands

```bash
# Development
make dev                    # Full dev environment
make build                  # Build binary
make test                   # Run tests
make lint                   # Run linters

# Database
sqlite3 obot.db
sqlite3 obot-credentials.db

# Docker
docker build -t obot-entraid:dev .

# Documentation
make serve-docs
```

## Troubleshooting Checklist

- [ ] Check logs with `make dev`
- [ ] Verify environment variables
- [ ] Check K8s resources with kubectl
- [ ] Inspect resource status and events
- [ ] Check database state
- [ ] Verify dependencies: `go mod tidy`
- [ ] Clear caches if needed
- [ ] Check recent git changes
