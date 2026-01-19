# K8s v0.35.0 WatchList Bookmark Fix

## Issue Summary

After upgrading to client-go v0.35.0, `WaitForCacheSync` blocks forever and controllers never reach ready state, causing health checks to return HTTP 503.

## Root Cause

client-go v0.35.0 introduced the **watch-list pattern** (enabled by default via `WatchListClient` feature gate). This pattern requires the API server to send a special `initial-events-end` bookmark after streaming all initial events.

The bookmark must have the annotation:

```go
metav1.InitialEventsAnnotationKey: "true"
```

Without this bookmark:

1. `DeltaFIFO.initialPopulationCount` never reaches 0
2. `HasSynced()` never returns true
3. `WaitForCacheSync` blocks forever

## The Fix (kinm)

Location: `kinm/pkg/db/strategy.go`

### Key Components

1. **Capture original ResourceVersion** before it gets modified:

```go
func (s *Strategy) Watch(...) {
    originalRV := opts.ResourceVersion  // BEFORE any modifications
    // ...
}
```

1. **Detection function** to determine when bookmark is needed:

```go
func isInitialEventsEndBookmarkRequired(opts storage.ListOptions, originalRV string) bool {
    // Case 1: Explicit SendInitialEvents=true
    if opts.SendInitialEvents != nil && *opts.SendInitialEvents && opts.Predicate.AllowWatchBookmarks {
        return true
    }
    // Case 2: Inferred from AllowWatchBookmarks + empty original RV
    if opts.SendInitialEvents == nil && opts.Predicate.AllowWatchBookmarks {
        if originalRV == "" || originalRV == "0" {
            return true
        }
    }
    return false
}
```

1. **Send the bookmark** after initial events:

```go
if needsInitialEventsEndBookmark {
    bookmarkObj := s.New()
    bookmarkObj.SetResourceVersion(opts.ResourceVersion)
    bookmarkObj.SetAnnotations(map[string]string{
        metav1.InitialEventsAnnotationKey: "true",
    })
    ch <- watch.Event{Type: watch.Bookmark, Object: bookmarkObj}
    needsInitialEventsEndBookmark = false
}
```

## Why Case 2 (Inferred) is Critical

controller-runtime/nah does NOT propagate `SendInitialEvents` through all layers. By the time the Watch call reaches kinm's storage layer, `SendInitialEvents` is always `nil`.

However, we can infer this is an initial sync request when:

- `AllowWatchBookmarks=true` (controller-runtime sets this)
- Original `ResourceVersion` is empty or "0" (indicates start from beginning)

## Debugging Tips

1. **Add debug logging** to see if bookmark is being sent
2. **Check `SendInitialEvents` value** - expect it to be `nil` from controller-runtime
3. **Test with feature gate disabled**: `KUBE_FEATURE_WatchListClient=false`
4. **No "bookmark expired" warnings** indicates missing bookmark, not timeout

## Reference

- K8s Issue: https://github.com/kubernetes/kubernetes/issues/120348
- client-go reflector.go: `watchList()` function expects the bookmark
- client-go delta_fifo.go: `HasSynced()` implementation
