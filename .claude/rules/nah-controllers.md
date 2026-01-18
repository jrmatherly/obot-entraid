---
globs: pkg/controller/**/*.go
description: nah controller development patterns for obot-entraid
---

# nah Controller Patterns

## Handler Signature

```go
import "github.com/obot-platform/nah/pkg/router"

func(req router.Request, resp router.Response) error
```

- `req.Object`: Resource being reconciled (e.g., `*v1.MCPServer`)
- `req.Ctx`: Context for the request
- `resp.Backend()`: Kubernetes client for CRUD
- `resp.Objects()`: Apply instance for declarative management

## Key Principles

1. **Idempotent**: Handler can be called multiple times safely
2. **Level-triggered**: Work from current state, not events
3. **Status separate from Spec**: Update status independently
4. **Error handling**: Return error for retry, nil for success

## Route Registration

Location: `pkg/controller/routes.go:setupRoutes()`

```go
root := c.router
root.Type(&v1.MyResource{}).HandlerFunc(myHandler)

// Multiple handlers (execute in order)
root.Type(&v1.Thread{}).HandlerFunc(retention.Migrate)
root.Type(&v1.Thread{}).HandlerFunc(cleanup.Cleanup)

// Finalizer
root.Type(&v1.MCPServer{}).FinalizeFunc(v1.MCPServerFinalizer, cleanup.Remove)
```

## Apply Pattern

Use Apply for declarative resource management:

```go
import "github.com/obot-platform/nah/pkg/apply"

func (h *Handler) Handle(req router.Request, resp router.Response) error {
    owner := req.Object
    a := apply.New(resp.Backend(), h.routerName)

    desiredResources := []runtime.Object{
        &corev1.ConfigMap{...},
        &appsv1.Deployment{...},
    }

    return a.Apply(owner, desiredResources)
}
```

## Backend Operations

```go
backend := resp.Backend()

// Get
var obj v1.MyResource
backend.Get(req.Ctx, client.ObjectKey{Namespace: "ns", Name: "name"}, &obj)

// List with selectors
backend.List(req.Ctx, &list,
    client.InNamespace("namespace"),
    client.MatchingLabels{"key": "value"})

// Update status (separate subresource)
obj.Status.Phase = "Ready"
backend.Status().Update(req.Ctx, &obj)
```

## Error Handling

- Return `err` for retryable failures (auto-retry with backoff)
- Return `nil` for success (no requeue)
- Use `router.EnqueueAfter(5*time.Second, err)` for delayed retry

## File Organization

```
pkg/controller/handlers/
├── mcpserver/
│   └── mcpserver.go
├── threads/
│   └── threads.go
└── myresource/
    └── myresource.go
```

## Common Anti-Patterns

- Mutate req.Object directly (use Update())
- Panic in handlers (return errors)
- Hold state across invocations
- Create infinite reconciliation loops
- Ignore errors

## Testing Controllers

1. Unit test with mocked Backend
2. Test idempotency (call handler twice)
3. Test error handling
4. Test finalizer cleanup
5. Integration test with dev mode kubeconfig

```bash
make dev
kubectl --kubeconfig tools/devmode-kubeconfig apply -f test.yaml
kubectl --kubeconfig tools/devmode-kubeconfig get myresource -o yaml
```
