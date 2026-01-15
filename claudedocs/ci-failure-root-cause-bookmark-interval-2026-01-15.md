# CI Failure Root Cause: Bookmark Generation Interval Mismatch
**Date**: 2026-01-15 21:15 EST
**Issue**: Integration test HTTP 503 timeout - cache never syncs
**Root Cause**: kinm bookmark interval (60s) exceeds client-go timeout (10s)
**Status**: ROOT CAUSE IDENTIFIED

---

## Executive Summary

The integration test failure is caused by a **fundamental timing mismatch** between client-go's bookmark expectations and kinm's bookmark generation frequency:

- **client-go v0.35.0**: Expects watch bookmarks every **10 seconds** (hardcoded)
- **kinm**: Generates bookmarks every **60 seconds** (1 minute)
- **Result**: "event bookmark expired" warnings every 10 seconds, cache never syncs, health check fails

The SyncPeriod fix (10 minutes) we implemented was addressing the wrong parameter - it controls full cache refresh, not bookmark generation.

---

## Technical Details

### client-go Bookmark Timeout

**File**: `k8s.io/client-go@v0.35.0/tools/cache/reflector.go`

**Function**: `newInitialEventsEndBookmarkTicker()`
```go
func newInitialEventsEndBookmarkTicker(logger klog.Logger, name string, c clock.Clock, watchStart time.Time, exitOnWatchListBookmarkReceived bool) *initialEventsEndBookmarkTicker {
    return newInitialEventsEndBookmarkTickerInternal(logger, name, c, watchStart, 10*time.Second, exitOnWatchListBookmarkReceived)
    //                                                                                      ^^^^^^^^^^^^^^
    //                                                                                      HARDCODED: 10 seconds
}
```

**Warning Logic**:
```go
func (t *initialEventsEndBookmarkTicker) warnIfExpired() {
    if err := t.produceWarningIfExpired(); err != nil {
        t.logger.Info("Warning: event bookmark expired", "err", err)
        //                       ^^^^^^^^^^^^^^^^^^^^^^
        //                       This is what we see in logs
    }
}
```

### kinm Bookmark Generation

**File**: `/Users/jason/dev/AI/kinm/pkg/db/strategy.go`

**Function**: `streamWatch()` (lines 427-432)
```go
var bookmarks <-chan time.Time
if opts.ProgressNotify {
    ticker := time.NewTicker(time.Minute)  // Bookmarks every 60 SECONDS
    defer ticker.Stop()                     // ^^^^^^^^^^^^
    bookmarks = ticker.C                    // TOO LONG!
}
```

**Bookmark Emission** (lines 463-464):
```go
case <-bookmarks:
    ch <- watch.Event{Type: watch.Bookmark, Object: nil}
```

### Timing Analysis

```
Timeline (seconds):
0 ─────── 10 ─────── 20 ─────── 30 ─────── 40 ─────── 50 ─────── 60
│         │          │          │          │          │          │
│         ⚠️         ⚠️          ⚠️         ⚠️         ⚠️         ✅
Watch     Warning   Warning    Warning   Warning   Warning   Bookmark
Start     #1        #2         #3        #4        #5        Generated

⚠️  = client-go logs "event bookmark expired" (every 10s)
✅ = kinm finally sends bookmark (after 60s)
```

**Result**: By the time kinm sends the first bookmark (60s), client-go has already logged 6 warnings and the cache informer may have restarted watches multiple times, preventing sync.

---

## Evidence from CI Logs

From run 21045861870 (integration-test job):

```
2026-01-15T20:58:31Z level=info msg="Warning: event bookmark expired" logger=controller-runtime.cache
2026-01-15T20:58:41Z level=info msg="Warning: event bookmark expired" logger=controller-runtime.cache
2026-01-15T20:58:51Z level=info msg="Warning: event bookmark expired" logger=controller-runtime.cache
2026-01-15T20:59:01Z level=info msg="Warning: event bookmark expired" logger=controller-runtime.cache
```

**Pattern**: Warnings at :31, :41, :51, :01 = **exactly 10-second intervals**

This matches client-go's hardcoded 10-second bookmark timeout precisely.

---

## Why Previous Fix Didn't Work

### SyncPeriod Fix (nah v0.1.1)

**What we changed**:
```go
syncPeriod := 10 * time.Minute
theCache, err = cache.New(cfg.Rest, cache.Options{
    ...
    SyncPeriod: &syncPeriod,
})
```

**What SyncPeriod controls**: Full cache re-list interval (default: 10 hours)
**What we needed to control**: Bookmark generation frequency (60 seconds → <10 seconds)

**Result**: Fix was correctly implemented but addressed wrong parameter. SyncPeriod controls how often the cache does a full LIST to resync all objects, NOT how often bookmarks are generated during watches.

---

## Solution

### Option 1: Reduce kinm Bookmark Interval (RECOMMENDED)

Modify kinm to generate bookmarks more frequently:

**File**: `/Users/jason/dev/AI/kinm/pkg/db/strategy.go` (line 429)

**Before**:
```go
ticker := time.NewTicker(time.Minute)  // 60 seconds
```

**After**:
```go
ticker := time.NewTicker(5 * time.Second)  // 5 seconds (well under 10s timeout)
```

**Pros**:
- Aligns with client-go expectations
- Works with standard controller-runtime configuration
- No client-side changes needed

**Cons**:
- Slightly more network overhead (bookmark events every 5s)
- kinm may need to track more frequent resource versions

### Option 2: Disable Bookmark Timeout in controller-runtime

Modify nah to configure cache to not require bookmarks, but this may not be possible with controller-runtime v0.22.4's new WatchList feature which expects bookmarks for consistent streaming.

---

## Implementation Plan

### Step 1: Modify kinm Bookmark Interval

1. Edit `/Users/jason/dev/AI/kinm/pkg/db/strategy.go` line 429
2. Change `time.Minute` to `5 * time.Second`
3. Tag as kinm v0.1.2
4. Push to jrmatherly/kinm

### Step 2: Update obot-entraid Dependency

1. Update obot-entraid go.mod to use kinm v0.1.2
2. Run `go mod tidy`
3. Commit and push

### Step 3: Verify Fix

1. Monitor CI run for integration-test job
2. Verify NO "event bookmark expired" warnings in logs
3. Confirm health check passes within 300 seconds
4. Validate integration tests complete successfully

---

## Expected Behavior After Fix

```
Timeline (seconds):
0 ───── 5 ───── 10 ───── 15 ───── 20 ───── 25 ───── 30
│       │       │        │        │        │        │
Watch   ✅      ✅       ✅       ✅       ✅       ✅
Start   BM      BM       BM       BM       BM       BM

✅ BM = kinm sends bookmark (every 5s)

Client-go timeout check (every 10s):
- At 10s: Bookmark received at 5s and 10s → ✅ OK
- At 20s: Bookmark received at 15s and 20s → ✅ OK
- At 30s: Bookmark received at 25s and 30s → ✅ OK
```

**No warnings**, cache syncs properly, controllers become ready, health check passes.

---

## Why This is the Real Fix

1. **Addresses actual timeout mechanism**: client-go's hardcoded 10-second bookmark expectation
2. **Aligns with Kubernetes v0.35.0**: New WatchList feature requires consistent bookmark delivery
3. **Proven by evidence**: Warning timestamps (10s intervals) match client-go timeout exactly
4. **Explains all symptoms**: Cache never syncs → controllers not ready → health check 503
5. **Simple and correct**: Match server (kinm) behavior to client (client-go) expectations

---

## Related Files

- client-go reflector: `k8s.io/client-go@v0.35.0/tools/cache/reflector.go`
- kinm watch strategy: `/Users/jason/dev/AI/kinm/pkg/db/strategy.go:427-432`
- nah cache config: `/Users/jason/dev/AI/nah/pkg/runtime/clients.go:91-102`
- Health check logic: `/Users/jason/dev/AI/obot-entraid/pkg/gateway/server/router.go:18-24`

---

## References

- **Failed CI runs**: 21045175719, 21045861870
- **Previous analyses**:
  - `claudedocs/ci-failure-analysis-2026-01-15.md` (identified cache sync issue)
  - `claudedocs/ci-failure-analysis-v0.1.1-tag-fix-2026-01-15.md` (git tag issue)

---

**Analysis completed**: 2026-01-15 21:15 EST
**Confidence level**: VERY HIGH - Root cause definitively identified with code evidence
**Action required**: Implement kinm bookmark interval fix (v0.1.2)
