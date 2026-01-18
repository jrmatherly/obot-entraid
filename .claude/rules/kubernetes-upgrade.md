---
globs:
  - "**/go.mod"
  - "**/go.sum"
---

# Kubernetes Dependency Upgrade Patterns

## K8s v0.35.0+ Breaking Changes

### 1. Bookmark Interval (CRITICAL)

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

### 2. REST Client ContentType (CRITICAL)

client-go v0.35.0 changed default content negotiation. Servers must accept JSON:

```go
// Set ContentType to JSON for all REST clients
config.ContentType = "application/json"
```

Without this fix:

```
the body of the request was in an unknown format - accepted media types include: application/json
```

### 3. client.WithWatch Interface

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

### 4. Cache SyncPeriod

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

1. **Database check failing** - Verify DSN propagation to background process
2. **Controllers not ready** - Check bookmark warnings in logs
3. **Cache never syncs** - Bookmark interval too slow

**Diagnostic steps**:

```bash
# Check for bookmark warnings
grep "bookmark expired" obot.log

# Verify DSN reaches process
echo "$OBOT_SERVER_DSN" | head -c 20

# Check controller ready state
curl -v http://localhost:8080/api/healthz
```

## Validation Checklist

- [ ] All k8s.io packages at same version
- [ ] controller-runtime compatible with K8s version
- [ ] Bookmark interval ≤ 10 seconds
- [ ] ContentType set to application/json
- [ ] Cache SyncPeriod configured
- [ ] Integration tests pass
