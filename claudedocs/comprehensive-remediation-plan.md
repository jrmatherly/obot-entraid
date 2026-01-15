# Comprehensive Remediation Plan: K8s v0.35.0 Upgrade and Dependency Alignment

**Date:** 2026-01-15
**Status:** ANALYSIS COMPLETE - ROOT CAUSE IDENTIFIED
**Author:** Claude Code Analysis

## Executive Summary

The integration test failures on PR #64 (K8s v0.35.0 upgrade) are caused by a **critical dependency version mismatch** between `obot-entraid`, `nah` fork, and `kinm`. The leader election mechanism fails because `kinm` (the embedded API server) uses k8s.io v0.31.1 while the application uses k8s.io v0.35.0, causing wire protocol incompatibilities.

## Root Cause Analysis

### Error Observed
```
Error initially creating lease lock" error="the body of the request was in an unknown format - accepted media types include: application/json, application/yaml
```

### Technical Root Cause

| Component | k8s.io/client-go | k8s.io/apiserver | sigs.k8s.io/controller-runtime |
| ----------- | ------------------ | ------------------ | -------------------------------- |
| **kinm** (embedded server) | v0.31.1 | v0.31.1 | v0.19.0 |
| **nah** (controller framework) | v0.35.0 | N/A | v0.22.4 |
| **obot-entraid** (main app) | v0.35.0 | v0.35.0 | v0.22.4 |

**The Problem:**
When the `nah` leader election code (using k8s.io/client-go v0.35.0) sends a lease creation request to the `kinm` embedded API server (using k8s.io/apiserver v0.31.1), the server cannot parse the request because the serialization format has changed between versions.

### Why Previous Analysis Missed This

The previous implementation plan (`nah-fork-k8s-upgrade-implementation-plan.md`) focused on the `Apply()` method requirement for `client.WithWatch` interface but did not consider:

1. The `kinm` dependency being stuck at k8s.io v0.31.1
2. Wire protocol incompatibilities between k8s.io major versions
3. The embedded API server being a separate concern from the controller framework

## Dependencies Requiring Updates

### Critical Path (Must Update)

1. **github.com/obot-platform/kinm** - Currently at v0.0.0-20250905213846-3c65d6845f83
   - Needs upgrade to k8s.io v0.35.0
   - Requires updating:
     - k8s.io/api v0.31.1 → v0.35.0
     - k8s.io/apimachinery v0.31.1 → v0.35.0
     - k8s.io/apiserver v0.31.1 → v0.35.0
     - k8s.io/client-go v0.31.1 → v0.35.0
     - sigs.k8s.io/controller-runtime v0.19.0 → v0.22.4

### Already Updated (nah fork)

The `jrmatherly/nah` fork has already been updated to k8s.io v0.35.0 at tag v0.1.0:
- k8s.io/api v0.35.0
- k8s.io/apimachinery v0.35.0
- k8s.io/client-go v0.35.0
- sigs.k8s.io/controller-runtime v0.22.4

### obot-entraid Status

The obot-entraid repository has been updated except for:
- **Missing:** kinm fork with k8s.io v0.35.0 support
- **Fixed:** OpenAPI regeneration (committed)
- **Fixed:** ESLint errors in ProviderConfigure.svelte (committed)

## Remediation Options

### Option A: Fork and Update kinm (RECOMMENDED)

**Effort:** Medium
**Risk:** Low
**Timeline:** 1-2 days

1. Fork `github.com/obot-platform/kinm` to `github.com/jrmatherly/kinm`
2. Update all k8s.io dependencies to v0.35.0
3. Update sigs.k8s.io/controller-runtime to v0.22.4
4. Test with obot-entraid
5. Add replace directive in obot-entraid's go.mod:
   ```go
   replace github.com/obot-platform/kinm => github.com/jrmatherly/kinm v0.1.0
   ```

**Advantages:**
- Complete version alignment across all components
- Maintains upstream compatibility
- Can be contributed back to upstream

### Option B: Use File-Based Leader Election (WORKAROUND)

**Effort:** Low
**Risk:** Medium
**Timeline:** 1-2 hours

1. Set `ElectionFile` configuration parameter in integration tests
2. This bypasses the kinm API server for leader election
3. Does NOT solve the underlying dependency mismatch

**Configuration Change:**
```bash
./bin/obot server --dev-mode --election-file=/tmp/obot-leader-election
```

**Disadvantages:**
- Only works for single-node deployments
- Does not fix production scenarios
- Hides the underlying issue

### Option C: Wait for Upstream Updates (NOT RECOMMENDED)

**Effort:** None (waiting)
**Risk:** High
**Timeline:** Unknown

Wait for upstream `obot-platform/kinm` to be updated.

**Disadvantages:**
- Unknown timeline
- Blocks PR #64 indefinitely
- May never happen if upstream is not actively maintained

## Recommended Implementation Plan

### Phase 1: Fork kinm (Day 1)

1. Fork `github.com/obot-platform/kinm` to `github.com/jrmatherly/kinm`
2. Create branch `feat/k8s-v0.35.0-upgrade`
3. Update go.mod dependencies:
   ```go
   k8s.io/api v0.35.0
   k8s.io/apimachinery v0.35.0
   k8s.io/apiserver v0.35.0
   k8s.io/client-go v0.35.0
   k8s.io/klog/v2 v2.130.1
   k8s.io/kube-openapi v0.0.0-20251125145642-4e65d59e963e
   k8s.io/utils v0.0.0-20260108192941-914a6e750570
   sigs.k8s.io/controller-runtime v0.22.4
   ```
4. Run `go mod tidy`
5. Fix any compilation errors (may need to implement new interfaces)
6. Run tests: `go test ./...`
7. Tag release: `v0.1.0`

### Phase 2: Update obot-entraid (Day 1-2)

1. Add replace directive:
   ```go
   replace github.com/obot-platform/kinm => github.com/jrmatherly/kinm v0.1.0
   ```
2. Run `go mod tidy`
3. Run `go generate ./...` (regenerate OpenAPI if needed)
4. Build: `make build`
5. Run tests: `make test`
6. Run integration tests: `make test-integration`
7. Push to PR #64

### Phase 3: Validation (Day 2)

1. Verify all CI checks pass
2. Verify local integration tests pass
3. Document changes in CHANGELOG
4. Request PR review

## Files to Modify

### jrmatherly/kinm (new fork)
- `go.mod` - Update dependencies

### jrmatherly/obot-entraid
- `go.mod` - Add kinm replace directive

## Potential Compilation Issues in kinm

Based on the k8s.io v0.31 → v0.35 upgrade changes:

1. **Apply() method on client.WithWatch** - May need implementation
2. **Serializer changes** - Check `NoProtobufSerializer` still works
3. **APIServer configuration changes** - Review `mserver.Config` usage
4. **CBOR support** - Verify JSON/YAML serialization still primary

## Testing Strategy

### Unit Tests
```bash
cd /path/to/kinm
go test ./...
```

### Integration Tests
```bash
cd /path/to/obot-entraid
make test-integration
```

### Manual Verification
1. Start server in dev mode
2. Verify healthz returns 200 OK
3. Verify lease creation in kube-system namespace
4. Verify controller handlers start successfully

## Rollback Plan

If the kinm upgrade fails:
1. Remove replace directive from obot-entraid
2. Revert to k8s.io v0.31.x in obot-entraid
3. Update nah fork to match v0.31.x
4. This is NOT recommended but provides a fallback

## Appendix: Dependency Version Matrix

### Target State (All Components Aligned)

| Package | kinm | nah | obot-entraid |
| --------- | ------ | ----- | -------------- |
| k8s.io/api | v0.35.0 | v0.35.0 | v0.35.0 |
| k8s.io/apimachinery | v0.35.0 | v0.35.0 | v0.35.0 |
| k8s.io/apiserver | v0.35.0 | N/A | v0.35.0 |
| k8s.io/client-go | v0.35.0 | v0.35.0 | v0.35.0 |
| sigs.k8s.io/controller-runtime | v0.22.4 | v0.22.4 | v0.22.4 |

### Current State (Mismatched)

| Package | kinm | nah | obot-entraid |
| --------- | ------ | ----- | -------------- |
| k8s.io/api | v0.31.1 | v0.35.0 | v0.35.0 |
| k8s.io/apimachinery | v0.31.1 | v0.35.0 | v0.35.0 |
| k8s.io/apiserver | v0.31.1 | N/A | v0.35.0 |
| k8s.io/client-go | v0.31.1 | v0.35.0 | v0.35.0 |
| sigs.k8s.io/controller-runtime | v0.19.0 | v0.22.4 | v0.22.4 |

## References

- PR #64: K8s v0.35.0 Upgrade
- Previous plan: `nah-fork-k8s-upgrade-implementation-plan.md`
- Validation report: `validation-report.md`
- k8s.io/client-go changelog
- k8s.io/apiserver changelog
