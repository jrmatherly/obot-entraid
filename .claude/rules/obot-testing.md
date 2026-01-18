---
globs: "**/*_test.go"
description: Obot-specific testing patterns (complements workspace go-tests.md)
---

# Obot Testing Patterns

This rule extends the workspace `go-tests.md` rule with obot-specific patterns.

## Mocking nah Backend

```go
type mockBackend struct {
    getFunc    func(context.Context, client.ObjectKey, client.Object) error
    updateFunc func(context.Context, client.Object) error
}

func (m *mockBackend) Get(ctx context.Context, key client.ObjectKey, obj client.Object) error {
    if m.getFunc != nil {
        return m.getFunc(ctx, key, obj)
    }
    return nil
}

// Usage
backend := &mockBackend{
    getFunc: func(ctx context.Context, key client.ObjectKey, obj client.Object) error {
        return nil
    },
}
```

## Testing Controller Idempotency

**Critical**: Controllers must be idempotent (safe to run multiple times).

```go
func TestHandlerIdempotent(t *testing.T) {
    handler := myresource.New(...)
    req := testRequest()
    resp := testResponse()

    // First call
    err1 := handler.Reconcile(req, resp)
    assert.NoError(t, err1)

    // Second call with same input
    err2 := handler.Reconcile(req, resp)
    assert.NoError(t, err2)

    // Verify no duplicate resources
}
```

## Test Fixtures

```go
func testAgent(name string) *v1.Agent {
    return &v1.Agent{
        ObjectMeta: metav1.ObjectMeta{
            Name:      name,
            Namespace: "default",
        },
        Spec: v1.AgentSpec{
            Manifest: v1.AgentManifest{Name: name},
        },
    }
}
```

## Integration Testing with Dev Mode

```bash
make dev
export KUBECONFIG=tools/devmode-kubeconfig
kubectl apply -f test-resource.yaml
kubectl get <resource> -o yaml
```

## Auth Provider Testing

```bash
cd tools/entra-auth-provider
export OBOT_ENTRA_AUTH_PROVIDER_CLIENT_ID="..."
export OBOT_AUTH_PROVIDER_COOKIE_SECRET="$(openssl rand -base64 32)"
go run .

curl http://localhost:9999/
curl -H "Authorization: Bearer <token>" http://localhost:9999/obot-get-user-info
```

## Test Checklist for Controllers

- Resource reconciles successfully
- Status updated correctly
- Dependent resources created (via Apply)
- Owner references set
- Finalizers work on deletion
- Reconciliation is idempotent
- Error conditions handled

## Coverage Goals

- Critical paths: 80%+
- Business logic: 70%+
- Overall: 60%+
