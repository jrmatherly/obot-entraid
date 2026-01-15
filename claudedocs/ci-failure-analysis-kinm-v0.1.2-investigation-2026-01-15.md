# CI Failure Analysis: kinm v0.1.2 Still Shows Bookmark Warnings
**Date**: 2026-01-15 22:00 EST
**CI Run**: 21047102721
**Commit**: 45d895e6
**Status**: INVESTIGATING - v0.1.2 fix didn't resolve issue

---

## Executive Summary

Despite implementing the 5-second bookmark interval fix in kinm v0.1.2, the integration test **STILL FAILED** with the same "event bookmark expired" warnings appearing every 10 seconds. The CI run 21047102721 confirms:

- ✅ **Correct version deployed**: go.mod shows `kinm v0.1.2`
- ✅ **Fix is in the code**: v0.1.2 has `time.NewTicker(5 * time.Second)`
- ❌ **Warnings still occur**: Logs show bookmark expired at 10-second intervals
- ❌ **Test still times out**: 300-second timeout, HTTP 503

---

## Evidence from CI Run 21047102721

### Commit Used
```bash
$ gh run view 21047102721 --json headSha
45d895e682bc046ed2abda7ef9f931ee7fecb05c
```

### go.mod in That Commit
```bash
$ git show 45d895e6:go.mod | grep kinm
github.com/obot-platform/kinm => github.com/jrmatherly/kinm v0.1.2
```

### Failure Logs
```
2026-01-15T21:47:13Z level=info msg="Warning: event bookmark expired" logger=controller-runtime.cache
2026-01-15T21:47:23Z level=info msg="Warning: event bookmark expired" logger=controller-runtime.cache
2026-01-15T21:47:23Z level=info msg="Warning: event bookmark expired" logger=controller-runtime.cache
...
(100+ warnings)
```

**Pattern**: Warnings at :13, :23, :33, :43... → **exactly 10-second intervals**

---

## Why the Fix Didn't Work: Hypothesis Analysis

### Hypothesis 1: ProgressNotify Not Enabled ⚠️ LIKELY

The bookmark generation code is **conditional**:

```go
if opts.ProgressNotify {
    ticker := time.NewTicker(5 * time.Second)
    defer ticker.Stop()
    bookmarks = ticker.C
}
```

**Critical question**: Is `ProgressNotify` actually being set to `true` when watches are created?

**Where to check**:
1. controller-runtime cache watch creation
2. client-go watch options
3. nah watcher configuration

If `ProgressNotify = false`, then **NO bookmarks are generated at all**, which would cause continuous "bookmark expired" warnings as client-go expects them.

### Hypothesis 2: AllowWatchBookmarks Not Set

From kinm's watch adapter (pkg/strategy/watch.go:67):
```go
if options != nil {
    resourceVersion = options.ResourceVersion
    predicate.AllowWatchBookmarks = options.AllowWatchBookmarks  // ← Must be true
}
```

From kinm's opts conversion (pkg/strategy/opts.go:22):
```go
AllowWatchBookmarks:  opts.ProgressNotify || opts.Predicate.AllowWatchBookmarks,
```

**Logic**: `AllowWatchBookmarks` is true IF `ProgressNotify` OR `Predicate.AllowWatchBookmarks`

If both are false, bookmarks aren't generated.

### Hypothesis 3: WatchList Feature vs Regular Watch

client-go v0.35.0 introduced **WatchList** feature with `SendInitialEvents`. The bookmark timeout ticker is specifically for this feature:

```go
func newInitialEventsEndBookmarkTicker(..., exitOnWatchListBookmarkReceived bool) {
    if !exitOnWatchListBookmarkReceived {
        return &noopTicker{}  // ← Returns noop if not using WatchList
    }
    return newInitialEventsEndBookmarkTickerInternal(..., 10*time.Second, ...)
}
```

**Critical insight**: The 10-second bookmark timeout **only applies to WatchList watches**, not regular watches.

**Question**: Is controller-runtime using WatchList feature in v0.22.4?

### Hypothesis 4: Multiple Watch Types

There may be MULTIPLE types of watches:
1. **Initial LIST + WATCH**: Traditional pattern, no bookmark requirement
2. **WatchList with SendInitialEvents**: New pattern, requires bookmarks

If controller-runtime is using WatchList, it expects:
- Initial events sent as watch events (not LIST response)
- Bookmark event marking end of initial events
- Timeout of 10 seconds for that bookmark

---

## Source Code Investigation Needed

### 1. Check controller-runtime Cache Watch Creation

**File**: `sigs.k8s.io/controller-runtime@v0.22.4/pkg/cache/internal/informers_map.go`

Need to find:
- How watches are created
- What options are passed
- Is `SendInitialEvents` used?
- Is `AllowWatchBookmarks` set?

### 2. Check client-go Reflector

**File**: `k8s.io/client-go@v0.35.0/tools/cache/reflector.go`

Need to find:
- When is `newInitialEventsEndBookmarkTicker` called?
- What triggers `exitOnWatchListBookmarkReceived = true`?
- Is there a feature gate or configuration?

### 3. Check nah Watcher

**File**: `/Users/jason/dev/AI/nah/pkg/watcher/watcher.go:216`

Current code:
```go
Raw: &metav1.ListOptions{
    ResourceVersion:     revision,
    AllowWatchBookmarks: true,  // ← This is set
},
```

Need to check:
- Is `SendInitialEvents` being set?
- Is `ProgressNotify` being set somewhere?

---

## Diagnostic Steps

### Step 1: Verify ProgressNotify in kinm Logs

Add debug logging to kinm v0.1.4:

```go
if opts.ProgressNotify {
    klog.Infof("🔖 BOOKMARK TICKER ENABLED: 5 second interval for %s watch", namespace)
    ticker := time.NewTicker(5 * time.Second)
    ...
} else {
    klog.Infof("⚠️  BOOKMARK TICKER DISABLED: ProgressNotify=false for %s watch", namespace)
}
```

### Step 2: Verify Bookmark Sending

Add logging when bookmarks are sent:

```go
case <-bookmarks:
    klog.Infof("📤 SENDING BOOKMARK EVENT for %s watch at rv=%s", namespace, newResourceVersion)
    ch <- watch.Event{Type: watch.Bookmark, Object: nil}
```

### Step 3: Check Watch Options at Runtime

Add logging in kinm watch adapter:

```go
func (w *WatchAdapter) Watch(ctx context.Context, options *metainternalversion.ListOptions) (watch.Interface, error) {
    klog.Infof("🔍 WATCH OPTIONS: ResourceVersion=%s AllowWatchBookmarks=%v SendInitialEvents=%v",
        options.ResourceVersion,
        options != nil && options.AllowWatchBookmarks,
        options != nil && options.SendInitialEvents != nil && *options.SendInitialEvents)
    ...
}
```

### Step 4: Check controller-runtime Configuration

Look for these in nah cache configuration:
- `cache.Options.UnsafeDisableDeepCopy`
- Watch-specific options
- Feature gates

---

## Possible Solutions

### Solution 1: Force ProgressNotify (Server-Side)

Modify kinm to **always** generate bookmarks regardless of `ProgressNotify`:

```go
// ALWAYS generate bookmarks for client-go v0.35.0 compatibility
ticker := time.NewTicker(5 * time.Second)
defer ticker.Stop()
bookmarks = ticker.C
```

**Pro**: Guarantees bookmark generation
**Con**: May send unnecessary bookmarks for clients that don't need them

### Solution 2: Set SendInitialEvents in nah

Modify nah watcher to explicitly request WatchList feature:

```go
sendInitialEvents := true
Raw: &metav1.ListOptions{
    ResourceVersion:     revision,
    AllowWatchBookmarks: true,
    SendInitialEvents:   &sendInitialEvents,  // ← Add this
},
```

**Pro**: Explicitly opts into WatchList behavior
**Con**: May change watch semantics, needs testing

### Solution 3: Disable Bookmark Requirement

If possible, configure controller-runtime to not require bookmarks:

```go
cache.Options{
    // ... existing options
    // Some hypothetical option to disable bookmark requirement
}
```

**Pro**: Bypasses the issue entirely
**Con**: May not be possible with controller-runtime v0.22.4

---

## Next Actions

1. **Add debug logging** to kinm v0.1.4 to verify:
   - Is `ProgressNotify` true or false?
   - Are bookmarks being generated?
   - Are they being sent on the channel?

2. **Examine controller-runtime v0.22.4** cache source:
   - How are watches created?
   - What options are passed?
   - Is WatchList feature used?

3. **Test bookmark generation** locally:
   - Run obot with kinm in dev mode
   - Check logs for bookmark activity
   - Verify controller cache sync

4. **Consider Solution 1** as immediate workaround:
   - Force bookmark generation regardless of options
   - Test in CI

---

## Updated To kinm v0.1.3

Per user request, updated obot-entraid to use kinm v0.1.3:

**Changes**:
- `go.mod`: `github.com/jrmatherly/kinm v0.1.2` → `v0.1.3`
- `go.sum`: Updated checksums
- kinm v0.1.3 includes security fix for integer overflow in compaction errors

**Bookmark fix status**: v0.1.3 still has the 5-second bookmark interval from v0.1.2

**Next**: Push changes and monitor CI to see if v0.1.3 behavior differs

---

## Critical Question

**Why didn't kinm v0.1.2 work when the code clearly has 5-second bookmarks?**

The most likely answer: **`ProgressNotify` is never set to `true`**, so the bookmark ticker is never created, and NO bookmarks are generated at all.

This would explain:
- Continuous "bookmark expired" warnings (no bookmarks received)
- 10-second interval warnings (client-go timeout)
- Test timeout (cache never syncs)

**Verification needed**: Add logging to confirm this hypothesis.

---

## Files to Investigate

**controller-runtime**:
- `pkg/cache/cache.go` - Cache interface and implementation
- `pkg/cache/internal/informers_map.go` - Watch creation
- `pkg/cache/internal/cache_reader.go` - List/Watch operations

**client-go**:
- `tools/cache/reflector.go` - Bookmark timeout logic
- `tools/cache/list_watch.go` - ListWatch interface

**nah**:
- `pkg/runtime/clients.go` - Cache configuration
- `pkg/watcher/watcher.go` - Watch creation with options

**kinm**:
- `pkg/strategy/watch.go` - Watch adapter
- `pkg/strategy/opts.go` - Options conversion
- `pkg/db/strategy.go` - Bookmark generation

---

**Analysis completed**: 2026-01-15 22:00 EST
**Status**: Updated to kinm v0.1.3, awaiting CI results
**Confidence**: HIGH that ProgressNotify is not being set
**Recommended action**: Add debug logging to verify hypothesis
