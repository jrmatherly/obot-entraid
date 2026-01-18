---
name: debugging
description: Structured debugging for obot-entraid issues
keep-coding-instructions: true
---

# Debugging Output Style

Follow systematic debugging process:

## 1. Reproduce

- Confirm exact steps to reproduce
- Note environment (dev mode, container, Kubernetes)

## 2. Isolate

- Narrow down to specific component (controller, API handler, auth provider, UI)
- Identify last known good state

## 3. Analyze

- Form hypothesis
- Gather evidence (logs, state, traces)

## 4. Fix

- Make minimal change
- Verify fix doesn't introduce regressions

## 5. Prevent

- Add test case
- Document if non-obvious

## Response Structure

Always structure debugging responses with these headers:

~~~~~markdown
## Problem

**Symptom:** [What the user observed]
**Error:** [Exact error message if any]
**Context:** [Where/when it occurs]

## Investigation

### Hypothesis 1: [Most likely cause]

**Evidence:**
- [Finding 1]
- [Finding 2]

**Verdict:** [Confirmed/Ruled out]

### Hypothesis 2: [Alternative cause]
...

## Root Cause

[Clear explanation of what's actually wrong]

## Fix

```text
// Before
[problematic code]

// After
[fixed code]
```

**Why this fixes it:** [Brief explanation]

## Verification

```bash
# Command to verify the fix
[test command]
```

**Expected output:** [What success looks like]

## Prevention

- [ ] Add test: [test description]
- [ ] Update docs: [if applicable]
- [ ] Consider: [related improvements]
~~~~~

## Debug Commands Reference

### Go Backend

```bash
# Run with race detector
go test -race ./...

# Verbose test output
go test -v ./pkg/...

# Run specific test
go test -run TestReconcileMCPServer ./pkg/controller/handlers/mcpserver/...

# Check for goroutine leaks
go test -count=1 -timeout=60s ./...

# Build auth provider to check compilation
cd tools/entra-auth-provider && go build -o /dev/null .
```

### Controllers (nah)

```bash
# Dev mode with kubeconfig
make dev
export KUBECONFIG=tools/devmode-kubeconfig

# Watch controller logs
kubectl logs -f -l app=obot -n default

# Check resource status
kubectl get mcpserver -o yaml
```

### Auth Providers

```bash
# Test auth provider locally
cd tools/entra-auth-provider
export OBOT_AUTH_PROVIDER_COOKIE_SECRET=$(openssl rand -base64 32)
go run .

# Test endpoints
curl http://localhost:9999/
curl -H "Authorization: Bearer <token>" http://localhost:9999/obot-get-user-info
```

### Frontend

```bash
# TypeScript type check
cd ui/user && pnpm run check

# Lint with auto-fix
pnpm run lint --fix

# Dev server with HMR
pnpm run dev
```

## Common obot-entraid Issues

### Auth Provider 401 on Profile Pictures

- Root cause: Returning Graph API URL instead of data URL
- Fix: Fetch image server-side, return base64

### Controller Never Ready

- Root cause: Bookmark interval > 10s (K8s v0.35.0+)
- Fix: Generate bookmarks every 5 seconds

### User Name Not Showing

- Root cause: Field name mismatch (displayName vs name)
- Fix: Map provider's field to expected `name`

## Do

- Start with the most likely cause
- Show your reasoning process
- Provide verification steps
- Suggest preventive measures

## Do Not

- Jump to conclusions without evidence
- Propose complex fixes before understanding the problem
- Skip the verification step
- Leave debugging sessions without a clear resolution
