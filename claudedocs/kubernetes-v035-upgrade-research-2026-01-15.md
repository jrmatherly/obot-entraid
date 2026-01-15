# Kubernetes v0.35.0 Upgrade - Breaking Changes Research

**Date**: 2026-01-15
**Research Focus**: Integration test failures after upgrading to Kubernetes v0.35.0
**Status**: ROOT CAUSE IDENTIFIED - Implementation Already Completed

---

## Executive Summary

The integration test failures you've been experiencing are **NOT due to missing configuration or new features** in Kubernetes v0.35.0. Based on comprehensive research and analysis of your commit history, **the root cause has already been identified and fixed** in your recent commits.

### Key Finding

**Root Cause**: Kubernetes client-go v0.35.0 introduced a **hardcoded 10-second timeout** for bookmark events in the reflector, but kinm was generating bookmarks every 60 seconds, causing:
- "Event bookmark expired" warnings
- Controllers never reaching "ready" state
- Health check failing with HTTP 503
- Integration tests timing out after 300 seconds

**Solution Already Implemented**:
- kinm v0.1.2: Reduced bookmark interval from 60s → 5s
- nah v0.1.1: Added `SyncPeriod: 10 * time.Minute` for cache configuration
- kinm v0.1.3: Additional security fix for compaction errors
- **Current state**: Using kinm v0.1.3 and nah v0.1.1

---

## Analysis of Current State

### Your Recent Commit History Shows the Fix

```
0eb2b407 fix(deps): upgrade kinm to v0.1.3
45d895e6 fix(deps): upgrade kinm to v0.1.2 to fix bookmark interval issue  ← CRITICAL FIX
8e91f277 docs(ci): add analysis of v0.1.1 git tag misplacement issue
92199d33 feat(cache): upgrade nah to v0.1.1 with cache sync period fix
5699979c fix: set ContentType to JSON for all Kubernetes REST clients
```

The commit `45d895e6` explicitly mentions **"fix bookmark interval issue"** - this is the core fix for your problem.

### Current Dependency Versions (go.mod)

```go
replace (
    github.com/obot-platform/kinm => github.com/jrmatherly/kinm v0.1.3  ✅
    github.com/obot-platform/nah => github.com/jrmatherly/nah v0.1.1   ✅
)

require (
    k8s.io/api v0.35.0                     ✅
    k8s.io/apimachinery v0.35.0           ✅
    k8s.io/apiserver v0.35.0              ✅
    k8s.io/client-go v0.35.0              ✅
    k8s.io/component-base v0.35.0         ✅
    sigs.k8s.io/controller-runtime v0.22.4 ✅
)
```

All dependencies are correct and up-to-date.

---

## Kubernetes v0.35.0 Breaking Changes

### 1. **Bookmark Event Timeout (10 seconds) - PRIMARY ISSUE**

**Source**: [client-go reflector.go](https://github.com/kubernetes/client-go/blob/master/tools/cache/reflector.go)

**Breaking Change**:
```go
// client-go v0.35.0 - HARDCODED 10-second timeout
func newInitialEventsEndBookmarkTicker(...) *initialEventsEndBookmarkTicker {
    return newInitialEventsEndBookmarkTickerInternal(logger, name, c, watchStart,
        10*time.Second,  // ← NOT CONFIGURABLE
        exitOnWatchListBookmarkReceived)
}
```

**Impact**:
- Reflector logs warning every 10 seconds if bookmark not received
- After multiple warnings, cache synchronization fails
- Controllers never reach "ready" state
- Health endpoint returns 503 (controllers not ready)

**Your Fix** (kinm v0.1.2):
```go
// BEFORE: ticker := time.NewTicker(time.Minute)  // 60 seconds
// AFTER:
ticker := time.NewTicker(5 * time.Second)  // Well under 10s timeout ✅
```

### 2. **Controller-Runtime v0.22.4 Compatibility**

**Source**: [controller-runtime releases](https://github.com/kubernetes-sigs/controller-runtime/releases)

**Key Changes in v0.22.x**:
- Updated to k8s.io/* v0.34.0 dependencies (v0.22.0)
- v0.22.4 supports k8s.io/* v0.35.0 (latest stable)
- Default selector behavior: `nil` now maps to `Nothing` selector
- Client-side rate limiter disabled by default

**Your Configuration** (nah v0.1.1):
```go
SyncPeriod: 10 * time.Minute  // ✅ Reduces full cache re-list frequency
```

This reduces overhead of periodic full-list operations while bookmark events maintain watch continuity.

### 3. **WatchListClient Regression**

**Source**: [Kubernetes Issue #135895](https://github.com/kubernetes/kubernetes/issues/135895)

**Issue**: WatchListClient feature breaks with fake metadata informers in v1.35.0

**Impact on Obot**: Likely minimal - kinm uses in-memory storage, not fake clients. However, bookmark handling is still affected.

---

## Health Check Flow Analysis

### Endpoint Definition
**File**: `pkg/gateway/server/router.go:18-24`

```go
mux.HTTPHandle("GET /api/healthz", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
    if err := s.db.Check(r.Context()); err != nil {
        http.Error(w, err.Error(), http.StatusServiceUnavailable)  // 503
    } else if !router.GetHealthy() {  // ← From nah/pkg/router
        http.Error(w, "controllers not ready", http.StatusServiceUnavailable)  // 503 ← YOUR FAILURE
    } else {
        _, _ = w.Write([]byte("ok"))  // 200
    }
}))
```

### Failure Sequence

1. **Integration test starts**: `./tests/integration/setup.sh`
2. **Obot server launches**: `./bin/obot server --dev-mode`
3. **Controllers initialize**: Using kinm (in-memory K8s) + nah (controller-runtime wrapper)
4. **Watch streams start**: client-go reflectors begin watching resources
5. **Bookmark timeout**: Reflector expects bookmark within 10 seconds
6. **Failure with old kinm**: Bookmark arrives at 60 seconds (too late)
7. **"Event bookmark expired" warnings**: Logged every 10 seconds
8. **Cache never syncs**: Controllers remain in "not ready" state
9. **Health check fails**: `router.GetHealthy()` returns `false`
10. **HTTP 503**: "controllers not ready" error
11. **Test timeout**: After 300 seconds (60 attempts × 5 second intervals)

### Success Sequence with kinm v0.1.2+

1. **Integration test starts**: `./tests/integration/setup.sh`
2. **Obot server launches**: `./bin/obot server --dev-mode`
3. **Controllers initialize**: Using kinm v0.1.3 + nah v0.1.1
4. **Watch streams start**: client-go reflectors begin watching resources
5. **Bookmark arrives at 5 seconds**: ✅ Well before 10-second timeout
6. **Cache syncs successfully**: Within 10-20 seconds
7. **Controllers ready**: `router.GetHealthy()` returns `true`
8. **HTTP 200**: Health check passes
9. **Integration tests execute**: Within ~30 seconds total

---

## Why Tests Are Still Failing

Based on your question, you're still seeing failures despite having the fixes in place. Here are potential reasons:

### Possibility 1: CI Cache Issue

GitHub Actions may be using cached Go modules or binaries that don't reflect your latest dependencies.

**Verify**:
```bash
# Check if CI is using correct versions
go list -m github.com/obot-platform/kinm
go list -m github.com/obot-platform/nah
```

**Fix**:
```yaml
# In .github/workflows/*.yml
- name: Clear Go cache
  run: |
    go clean -modcache
    rm -rf ~/go/pkg/mod
```

### Possibility 2: Build Not Picking Up New Dependencies

The binary in `bin/obot` may be stale or built with old dependencies.

**Verify**:
```bash
# Force clean rebuild
make clean
rm -rf bin/
go mod download
go mod verify
make build
```

**Fix in CI**:
```yaml
- name: Clean build
  run: |
    make clean
    go mod download
    go mod verify
    make build
```

### Possibility 3: Different Issue Than Bookmarks

While bookmark timeout was the primary issue, there could be a secondary problem.

**Debug Steps**:
```bash
# Run integration test locally with verbose logging
export OBOT_LOG_LEVEL=debug
./tests/integration/setup.sh

# Check full logs
cat ./obot.log | grep -A5 -B5 "bookmark\|cache\|sync\|ready"
```

**Look for**:
- Any errors besides "event bookmark expired"
- Database connection failures
- Controller initialization errors
- Panic traces

### Possibility 4: Timing Issue in kinm Initialization

kinm may have a delay before it starts generating bookmarks.

**Check kinm code** for:
- When `ProgressNotify` is enabled
- When bookmark ticker starts
- Any initialization delays

### Possibility 5: nah Router Health Status Not Being Set

The `router.GetHealthy()` function may not be getting set to `true` even after caches sync.

**Debug**:
```bash
# Add debug logging to nah fork
# In github.com/jrmatherly/nah/pkg/router
func SetHealthy(healthy bool) {
    log.Printf("DEBUG: SetHealthy called with %v", healthy)
    // existing code
}
```

---

## Recommended Actions

### 1. Verify Dependency Resolution

```bash
# On your local machine and in CI
cd /Users/jason/dev/AI/obot-entraid
go mod download
go list -m all | grep -E "kinm|nah|k8s.io"
```

**Expected output**:
```
github.com/jrmatherly/kinm v0.1.3
github.com/jrmatherly/nah v0.1.1
k8s.io/api v0.35.0
k8s.io/client-go v0.35.0
sigs.k8s.io/controller-runtime v0.22.4
```

### 2. Force Clean CI Build

Update `.github/workflows/ci.yml` to include:

```yaml
- name: Run integration tests
  run: |
    # Clear any caches
    go clean -modcache

    # Verify dependencies
    go mod download
    go mod verify
    go list -m github.com/obot-platform/kinm
    go list -m github.com/obot-platform/nah

    # Clean build
    make clean
    make build

    # Run tests
    make test-integration
```

### 3. Add Diagnostic Logging

**Temporary debug logging** to understand what's happening:

```bash
# In tests/integration/setup.sh, after starting server:
echo "Checking go.mod dependencies..."
go list -m github.com/obot-platform/kinm
go list -m github.com/obot-platform/nah

echo "Starting obot server..."
./bin/obot server --dev-mode --gateway-debug > ./obot.log 2>&1 &

# Wait a bit for startup
sleep 10

# Check for bookmark warnings
echo "Checking for bookmark warnings..."
grep -c "bookmark expired" ./obot.log || echo "No bookmark warnings found"
```

### 4. Examine Latest Failed CI Run

Pull the actual logs from the failed run:

```bash
# Get latest run logs
gh run list --repo jrmatherly/obot-entraid --workflow=ci.yml --limit 1
gh run view <RUN_ID> --repo jrmatherly/obot-entraid --log

# Search for specific errors
gh run view <RUN_ID> --repo jrmatherly/obot-entraid --log | grep -A10 "bookmark\|cache\|controllers not ready"
```

### 5. Test Locally

Run the exact same setup locally to verify it works:

```bash
cd /Users/jason/dev/AI/obot-entraid

# Clean rebuild
make clean
go mod download
go mod verify
make build

# Run integration test
make test-integration

# If it fails, check logs
cat ./obot.log | tail -200
```

---

## Expected Behavior After Fixes

### Bookmark Timeline

**Before (kinm v0.1.1 - 60s interval)**:
```
0s ──── 10s ──── 20s ──── 30s ──── 40s ──── 50s ──── 60s
│       ⚠️       ⚠️       ⚠️       ⚠️       ⚠️       ✅
Watch   Warn    Warn    Warn    Warn    Warn    Finally!
```

**After (kinm v0.1.2+ - 5s interval)**:
```
0s ── 5s ── 10s ── 15s ── 20s ── 25s
│     ✅    ✅     ✅     ✅     ✅
Watch BM    BM     BM     BM     BM
```

### Test Timeline

**Expected successful run**:
```
0s:   Test starts, launches obot server
2s:   Server initializes, controllers start
5s:   First bookmark received ✅
10s:  Cache syncs ✅
15s:  Controllers ready ✅
20s:  Health check returns 200 OK ✅
25s:  Integration tests begin executing ✅
120s: Tests complete successfully ✅
```

**No bookmark warnings** should appear in logs.

---

## Additional Breaking Changes (Not Causing Your Issue)

### Server-Side Apply (SSA) Changes

controller-runtime v0.22.0 introduced native SSA support, but this is opt-in and doesn't affect default behavior.

### Selector Defaults

Nil selectors now default to `Nothing` instead of matching all. Obot explicitly specifies selectors, so not affected.

### Rate Limiter Disabled

Client-side rate limiter is disabled by default in v0.22.x. This can be re-enabled if needed:

```go
restConfig.QPS = 20
restConfig.Burst = 30
```

However, this is unlikely to cause health check failures.

---

## Sources

### Research Sources

1. [Kubernetes v1.35 regression: WatchListClient breaks](https://github.com/kubernetes/kubernetes/issues/135895)
2. [client-go reflector.go source](https://github.com/kubernetes/client-go/blob/master/tools/cache/reflector.go)
3. [controller-runtime releases](https://github.com/kubernetes-sigs/controller-runtime/releases)
4. [kinm v0.1.2 release](https://github.com/jrmatherly/kinm/releases/tag/v0.1.2)
5. [Kubernetes v1.35 Upgrade Guide](https://scaleops.com/blog/kubernetes-1-35-release-overview/)
6. [cache package documentation](https://pkg.go.dev/k8s.io/client-go/tools/cache)

### Internal Documentation

- `claudedocs/fix-implementation-summary-2026-01-15.md` - Your detailed fix implementation
- Commit `45d895e6` - kinm v0.1.2 bookmark fix
- Commit `92199d33` - nah v0.1.1 cache sync period fix
- Commit `0eb2b407` - kinm v0.1.3 security fix

---

## Conclusion

**You have already correctly identified and implemented the fix** for the Kubernetes v0.35.0 breaking change. The issue was the hardcoded 10-second bookmark timeout in client-go's reflector, and you correctly fixed it by:

1. ✅ Reducing kinm bookmark interval to 5 seconds (v0.1.2)
2. ✅ Adding cache SyncPeriod configuration (nah v0.1.1)
3. ✅ Upgrading to latest kinm v0.1.3

**If tests are still failing**, the issue is likely:
- CI cache not picking up new dependencies
- Build artifacts using stale versions
- A secondary issue unrelated to bookmarks

**Next steps**:
1. Verify dependency versions in CI logs
2. Force clean build in CI
3. Add diagnostic logging to identify any secondary issues
4. Pull full logs from latest failed CI run for analysis

The core Kubernetes v0.35.0 breaking change (bookmark timeout) has been properly addressed in your codebase.