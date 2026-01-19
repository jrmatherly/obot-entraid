---
globs:
  - "**/go.mod"
  - "**/go.sum"
---

# Kubernetes Dependency Upgrade Patterns

## K8s v0.35.0+ Breaking Changes

### 1. Initial-Events-End Bookmark (CRITICAL)

client-go v0.35.0 introduced the **watch-list pattern** where `WaitForCacheSync` blocks until an `initial-events-end` bookmark is received. Without this bookmark, controllers NEVER reach ready state.

**Problem**: `WaitForCacheSync` blocks forever because:

1. The reflector calls `watchList()` which expects a special bookmark
2. The bookmark must have annotation `metav1.InitialEventsAnnotationKey: "true"`
3. Without it, `DeltaFIFO.HasSynced()` never returns true

**Symptoms**:

- Health check returns HTTP 503 "controllers not ready"
- No "bookmark expired" warnings (different from timeout issue)
- Server starts but never becomes healthy

**Fix in kinm** (`pkg/db/strategy.go`):

```go
// After streaming initial events, send the initial-events-end bookmark
if needsInitialEventsEndBookmark {
    bookmarkObj := s.New()
    bookmarkObj.SetResourceVersion(opts.ResourceVersion)
    bookmarkObj.SetAnnotations(map[string]string{
        metav1.InitialEventsAnnotationKey: "true",  // CRITICAL
    })
    ch <- watch.Event{Type: watch.Bookmark, Object: bookmarkObj}
}
```

**Detection logic** - send bookmark when:

1. `SendInitialEvents=true` (explicit API call), OR
2. `AllowWatchBookmarks=true` AND original `ResourceVersion=""` or `"0"` (inferred initial sync)

The inferred case is critical because controller-runtime/nah doesn't propagate `SendInitialEvents`.

**Reference**: <https://github.com/kubernetes/kubernetes/issues/120348>

### 2. Bookmark Interval

client-go v0.35.0 has a **hardcoded 10-second timeout** for watch bookmarks:

```go
// k8s.io/client-go/tools/cache/reflector.go
func newInitialEventsEndBookmarkTicker(...) *initialEventsEndBookmarkTicker {
    return newInitialEventsEndBookmarkTickerInternal(logger, name, c, watchStart,
        10*time.Second,  // HARDCODED - NOT CONFIGURABLE
        exitOnWatchListBookmarkReceived)
}
```

**Problem**: If your API server generates bookmarks slower than 10s, you'll see:

```
Warning: event bookmark expired
```

Controllers never reach ready state.

**Fix**: Generate bookmarks every 5 seconds:

```go
ticker := time.NewTicker(5 * time.Second)  // Was 60s
```

### 3. REST Client ContentType (CRITICAL)

client-go v0.35.0 changed default content negotiation. Servers must accept JSON:

```go
// Set ContentType to JSON for all REST clients
config.ContentType = "application/json"
```

Without this fix:

```
the body of the request was in an unknown format - accepted media types include: application/json
```

### 4. client.WithWatch Interface

K8s v0.35.0+ requires `Apply()` method:

```go
type WithWatch interface {
    Watch(ctx context.Context, list ObjectList, opts ...ListOption) (watch.Interface, error)
    Apply(ctx context.Context, obj runtime.ApplyConfiguration, opts ...ApplyOption) error  // NEW
}
```

**Minimal implementation** (if SSA not used):

```go
func (c *client) Apply(ctx context.Context, obj runtime.ApplyConfiguration, opts ...client.ApplyOption) error {
    return fmt.Errorf("Apply not implemented")
}
```

### 5. Cache SyncPeriod

Controller-runtime v0.22+ changed cache sync behavior. Increase sync period to reduce churn:

```go
cache.Options{
    SyncPeriod: ptr.To(10 * time.Minute),  // Was default
}
```

## Dependency Alignment

When upgrading K8s packages, ALL related packages must align:

```go
// All packages must be same version
k8s.io/api               v0.35.0
k8s.io/apimachinery      v0.35.0
k8s.io/apiserver         v0.35.0
k8s.io/client-go         v0.35.0
k8s.io/component-base    v0.35.0

// Controller-runtime compatibility
sigs.k8s.io/controller-runtime  v0.22.4  // For K8s v0.35.0
```

## Fork Dependencies

If upstream dependencies (nah, kinm) don't support new K8s version:

1. Fork and upgrade dependencies
2. Use `replace` directives:

   ```go
   replace github.com/obot-platform/nah => github.com/jrmatherly/nah v0.1.1
   replace github.com/obot-platform/kinm => github.com/jrmatherly/kinm v0.1.3
   ```

## Debugging Integration Tests

HTTP 503 on health check usually means:

1. **Missing initial-events-end bookmark** - kinm not sending the special bookmark (see section 1)
2. **Database check failing** - Verify DSN propagation to background process
3. **Controllers not ready** - Check bookmark warnings in logs
4. **Cache never syncs** - Bookmark interval too slow

**Diagnostic steps**:

```bash
# Check for bookmark warnings (indicates timeout, not missing bookmark)
grep "bookmark expired" obot.log

# Check if initial-events-end bookmark is being sent (add debug logging to kinm)
# Look for: SendInitialEvents=nil, AllowWatchBookmarks=true, RV=""

# Verify DSN reaches process
echo "$OBOT_SERVER_DSN" | head -c 20

# Check controller ready state
curl -v http://localhost:8080/api/healthz

# Test with WatchListClient disabled (workaround to confirm issue)
KUBE_FEATURE_WatchListClient=false go run . server
```

**Key insight**: If server starts but health never returns 200, and there are NO "bookmark expired" warnings, the issue is likely the missing `initial-events-end` bookmark, not the bookmark interval.

## Validation Checklist

- [ ] All k8s.io packages at same version
- [ ] controller-runtime compatible with K8s version
- [ ] **kinm sends initial-events-end bookmark** (with `InitialEventsAnnotationKey` annotation)
- [ ] Bookmark interval ≤ 10 seconds
- [ ] ContentType set to application/json
- [ ] Cache SyncPeriod configured
- [ ] Integration tests pass (health check returns 200)
