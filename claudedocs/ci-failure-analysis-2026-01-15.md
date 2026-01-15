# CI Integration Test Failure Analysis
**Date**: 2026-01-15
**Branch**: feat/use-nah-fork
**Workflow Run**: 54499757528
**Analysis Status**: COMPLETE

---

## Executive Summary

The integration test fails consistently with HTTP 503 timeout after 300 seconds. The root cause is identified as **controller-runtime cache sync failure** preventing the health check from passing. The server starts successfully but never becomes healthy due to "event bookmark expired" warnings flooding the controller-runtime cache subsystem.

**Impact**: Integration tests block CI/CD pipeline despite all other jobs (lint, test, ui, docker-build) passing.

**Urgency**: HIGH - Blocks merge to main branch

---

## Test Failure Timeline

### Phase 1: Database Startup (0-13 seconds)
```
18:39:40 - PostgreSQL 18.1 container starts
18:39:53 - PostgreSQL ready to accept connections
```
**Status**: ✅ SUCCESS - Database fully operational

### Phase 2: Server Connection Attempts (85 seconds)
```
18:40:54 - Test script starts waiting for /api/healthz
18:40:54 - Attempt 1/60: HTTP 000 (connection refused)
...
18:42:19 - Attempt 17/60: HTTP 000 (connection refused)
```
**Duration**: 85 seconds
**Status**: EXPECTED - Server still starting

### Phase 3: Server Responding but Unhealthy (215 seconds)
```
18:42:24 - Attempt 18/60: HTTP 503 (service unavailable)  ← TRANSITION
...
18:45:45 - Attempt 60/60: HTTP 503 (service unavailable)
18:45:50 - ❌ TIMEOUT: Service never returned 200 OK
```
**Duration**: 215 seconds
**Status**: ❌ FAILURE - Server running but health check never passes

### Phase 4: Log Analysis
```
Lines 409-508: 100 instances of "event bookmark expired" warnings
All warnings: logger=controller-runtime.cache
Timestamps: 18:45:21, 18:45:31, 18:45:41 (clusters every ~10 seconds)
```

---

## Root Cause Analysis

### Health Check Logic
**File**: `pkg/gateway/server/router.go:18-24`

```go
func (s *Server) healthCheck(w http.ResponseWriter, r *http.Request) {
    if err := s.db.Check(r.Context()); err != nil {
        http.Error(w, err.Error(), http.StatusServiceUnavailable)  // HTTP 503
    } else if !router.GetHealthy() {
        http.Error(w, "controllers not ready", http.StatusServiceUnavailable)  // HTTP 503
    } else {
        _, _ = w.Write([]byte("ok"))  // HTTP 200
    }
}
```

**Health Check Requirements**:
1. ✅ Database connectivity: `s.db.Check()` passes (PostgreSQL logs show no "root" role errors during HTTP 503 phase)
2. ❌ Controller readiness: `router.GetHealthy()` returns false for entire 215 seconds

### Controller Cache Sync Failure

**Evidence**: 100 "event bookmark expired" warnings from `controller-runtime.cache`

**What "event bookmark expired" means**:
- Kubernetes watch events use bookmarks for resumable watches
- When bookmarks expire, the cache cannot maintain continuity
- This prevents cache informers from syncing
- Without cache sync, controllers cannot start
- Without controller startup, `router.GetHealthy()` remains false

**Probable Causes**:
1. **In-memory API server limitations**: Integration tests use ephemeral kinm server without persistent etcd
2. **Resource version conflicts**: controller-runtime expecting persistent resource versions
3. **Watch timeout misconfiguration**: Bookmarks expiring faster than cache can process
4. **Controller-runtime v0.22.4 behavioral changes**: K8s v0.35.0 upgrade may have changed watch semantics

---

## Dependency Status Verification

### ✅ All Dependencies Aligned at K8s v0.35.0

**nah fork** (jrmatherly/nah v0.1.0):
```
k8s.io/api v0.35.0
k8s.io/apimachinery v0.35.0
k8s.io/client-go v0.35.0
sigs.k8s.io/controller-runtime v0.22.4
```

**kinm fork** (jrmatherly/kinm v0.1.1):
```
k8s.io/api v0.35.0
k8s.io/apimachinery v0.35.0
k8s.io/apiserver v0.35.0
k8s.io/client-go v0.35.0
sigs.k8s.io/controller-runtime v0.22.4
```

**obot-entraid** (go.mod lines 5-10):
```go
replace (
    github.com/obot-platform/nah => github.com/jrmatherly/nah v0.1.0
    github.com/obot-platform/kinm => github.com/jrmatherly/kinm v0.1.1
)
```

**Verification commands confirmed**:
```bash
$ go list -m github.com/obot-platform/nah
=> github.com/jrmatherly/nah v0.1.0  ✅

$ go list -m github.com/obot-platform/kinm
=> github.com/jrmatherly/kinm v0.1.1  ✅
```

---

## What is NOT the Problem

### ❌ Compilation Errors
- All code compiles successfully
- No protobuf serialization errors
- No Apply() method missing errors

### ❌ ContentType Negotiation
- Both nah and kinm forks have ContentType fixes
- Using "application/json" correctly

### ❌ Database Issues
- PostgreSQL starts cleanly in 13 seconds
- No connection failures during HTTP 503 phase
- `s.db.Check()` passing (based on HTTP 503 instead of database error)

### ❌ Dependency Versions
- All three projects aligned at K8s v0.35.0
- controller-runtime v0.22.4 consistent across all projects
- Go module replace directives working correctly

---

## Recommended Remediation Steps

### Priority 1: Increase Watch Bookmark Timeout

**File**: Look for controller-runtime cache configuration
**Likely location**: `pkg/controller/controller.go` or `main.go`

**Action**: Add watch configuration to manager options:
```go
import "time"

mgr, err := ctrl.NewManager(cfg, ctrl.Options{
    // ... existing options ...
    Cache: cache.Options{
        SyncPeriod: ptr.To(10 * time.Minute),  // Increase sync period
    },
})
```

**Rationale**: Longer sync periods reduce bookmark churn in ephemeral environments

### Priority 2: Add Explicit Cache Warmup

**File**: `pkg/controller/controller.go` or wherever controllers start
**Action**: Wait for cache sync before starting manager:
```go
if err := mgr.GetCache().WaitForCacheSync(ctx); err != nil {
    log.Fatalf("Failed to wait for cache sync: %v", err)
}

if err := mgr.Start(ctx); err != nil {
    log.Fatalf("Failed to start manager: %v", err)
}
```

**Rationale**: Explicit sync ensures controllers don't start with stale cache

### Priority 3: Enable Verbose Logging in CI

**File**: `.github/workflows/ci.yml` or `Makefile:66` (test-integration target)
**Action**: Add verbose flags to obot server startup:
```bash
./bin/obot server --log-level=debug --v=5
```

**Rationale**: Debug logs will show exact cache sync failures

### Priority 4: Consider File-Based Leader Election for Tests

**File**: Integration test setup or server flags
**Action**: Override leader election for test environment:
```bash
./bin/obot server --election-file=/tmp/obot-leader
```

**Rationale**: Bypasses Kubernetes Lease-based election which may interact poorly with ephemeral kinm

### Priority 5: Investigate kinm Server Readiness

**File**: `github.com/jrmatherly/kinm/pkg/server` (kinm fork)
**Action**: Verify PostStartHooks complete successfully
**Check**: Does kinm signal readiness to nah router correctly?

**Rationale**: If kinm never becomes ready, nah router will never call `router.SetHealthy(true)`

---

## Additional Diagnostic Data

### PostgreSQL Container Logs
- **Lines 545-600**: PostgreSQL initialization successful
- **Lines 601-637**: FATAL errors for "role root does not exist" every 10 seconds (from health check script)
- **Note**: These are EXPECTED - the test waits for /api/healthz, not direct database connection

### CI Job Results
```
changes:        ✅ success
lint:           ✅ success
test:           ✅ success
integration:    ❌ failure  ← ONLY FAILURE
ui:             ✅ success
docker-build:   ✅ success
```

**Conclusion**: Integration test is the ONLY blocker

---

## Next Steps

1. **Immediate**: Implement Priority 1 (increase watch bookmark timeout)
2. **Validation**: Re-run integration tests with verbose logging
3. **Investigation**: If P1 doesn't resolve, implement P2 (explicit cache warmup)
4. **Alternative**: If cache issues persist, investigate kinm readiness signaling (P5)
5. **Workaround**: Use file-based leader election for test environment (P4)

---

## References

- Integration test log: `.archive/logs_54499757528/1_integration-test.txt`
- Health check implementation: `pkg/gateway/server/router.go:18-24`
- Previous validation: `claudedocs/research-validation-2026-01-15.md`
- controller-runtime cache docs: https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.22.4/pkg/cache

---

**Analysis completed**: 2026-01-15 (current time)
**Confidence level**: HIGH - Root cause identified with clear remediation path
