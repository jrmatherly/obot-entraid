# Cache Deletion Test Analysis

**Date**: 2026-01-15
**Test Run**: https://github.com/jrmatherly/obot-entraid/actions/runs/21048342770?pr=64
**Test Type**: Cache invalidation with debug logging enabled
**Hypothesis**: CI failures caused by stale Go module cache

---

## Test Setup

### Action Taken
```bash
gh cache delete --all
# Re-ran workflow with "Enable debug logging" option
```

### Expected Outcomes

#### If Cache Was The Problem (Success Scenario)
1. ✅ Go module download shows correct versions:
   - `github.com/jrmatherly/kinm v0.1.3`
   - `github.com/jrmatherly/nah v0.1.1`
2. ✅ No "event bookmark expired" warnings in obot.log
3. ✅ Health check passes within 30 seconds
4. ✅ Integration tests execute and pass

#### If Cache Was NOT The Problem (Failure Scenario)
1. ❌ Same timeout after 300 seconds
2. ❌ "Event bookmark expired" warnings still present
3. ❌ Health check continues to return 503
4. ❌ Suggests third issue beyond cache and known fixes

---

## Debug Log Inspection Checklist

### Phase 1: Dependency Verification (First 2 minutes)

**Look for in "Set up job" or "Build" step**:

```
✓ Expected Output (Good):
go: downloading github.com/jrmatherly/kinm v0.1.3
go: downloading github.com/jrmatherly/nah v0.1.1
```

```
✗ Problem Indicators (Bad):
go: downloading github.com/obot-platform/kinm v0.0.0-...
go: downloading github.com/obot-platform/nah v0.0.0-...
# OR
using cached module github.com/jrmatherly/kinm v0.1.1  # Wrong version!
```

**Debug Command to Verify**:
```bash
# Should be in CI logs somewhere
go list -m github.com/jrmatherly/kinm
go list -m github.com/jrmatherly/nah
```

**What to Look For**:
- Exact version numbers matching go.mod
- Download messages (not "using cached")
- No "replace" directive errors

---

### Phase 2: Build Verification (Minutes 2-5)

**Look for in "Build" step**:

```
✓ Expected Output (Good):
go build -o bin/obot .
# No errors, binary created successfully
```

```
✗ Problem Indicators (Bad):
# undefined: SomeNewKinmFunction
# cannot use X (type Y) as type Z
# incompatible types or missing methods
```

**What to Look For**:
- Clean build with no compilation errors
- Binary size (compare to previous builds)
- Go version in use (should be 1.25.5)

---

### Phase 3: Integration Test Startup (Minutes 5-10)

**Look for in "Run integration tests" step**:

```
✓ Expected Output (Good):
Starting obot server...
Waiting for http://localhost:8080/api/healthz to return OK...
Attempt 1/60: Service not ready (HTTP 000). Retrying in 5 seconds...
# ... early attempts while server initializes
Attempt 3/60: Service not ready (HTTP 503). Retrying in 5 seconds...
Attempt 4/60: Service not ready (HTTP 503). Retrying in 5 seconds...
Attempt 5/60: Service not ready (HTTP 503). Retrying in 5 seconds...
✅ Health check passed! Response: ok
go test ./tests/integration/... -v
```

```
✗ Problem Indicators (Bad):
Attempt 1/60: Service not ready (HTTP 000). Retrying in 5 seconds...
# ... continues for all 60 attempts
Attempt 60/60: Service not ready (HTTP 503). Retrying in 5 seconds...
❌ Timeout reached! Service at http://localhost:8080/api/healthz did not return OK
```

**What to Look For**:
- How quickly HTTP 503 starts returning (if server starts at all)
- Total time until health check passes
- Any panic or fatal errors in server startup

---

### Phase 4: Server Log Analysis (Minutes 5-10)

**Look for in "Last 200 lines of obot.log"**:

```
✓ Expected Output (Good):
# NO bookmark warnings
time="..." level=info msg="Starting controllers..."
time="..." level=info msg="Controller cache synced"
time="..." level=info msg="All controllers ready"
# Health endpoint starts returning 200
```

```
✗ Problem Indicators (Bad):
time="..." level=info msg="Warning: event bookmark expired" err="{}" logger=controller-runtime.cache
time="..." level=info msg="Warning: event bookmark expired" err="{}" logger=controller-runtime.cache
# Repeating every 10 seconds, never stops
```

**Additional Warnings to Watch For**:
```
# Protobuf serialization errors (should NOT appear with ContentType fix)
error serializing object: proto: ...

# Rate limiting errors (if QPS too low after adding rate limiter)
rate: Wait(n=1) would exceed context deadline

# Leader election failures
failed to acquire lease: ...

# Database errors
failed to connect to database: ...
```

---

## Analysis Framework

### Scenario A: Test Passes After Cache Deletion

**Conclusion**: Cache was the root cause

**Evidence**:
- ✅ Correct module versions downloaded
- ✅ No bookmark warnings
- ✅ Health check passes quickly
- ✅ Tests execute

**Root Cause**: GitHub Actions cached old kinm v0.1.1 or nah v0.1.0

**Solution**: Add cache invalidation to CI workflow:
```yaml
- name: Clean Go Cache
  run: |
    go clean -modcache
    go clean -cache
```

**Next Steps**:
1. Update `.github/workflows/ci.yml` to clear cache on each run
2. Consider using `hashFiles('**/go.sum')` in cache key
3. Monitor subsequent runs for consistency

---

### Scenario B: Test Still Fails With Same Symptoms

**Conclusion**: Cache was NOT the root cause

**Evidence**:
- ❌ Still times out after 300 seconds
- ❌ "Event bookmark expired" warnings persist
- ❌ Health check never passes
- ❌ Correct versions downloaded but still fails

**Possible Causes**:

#### 1. Missing Rate Limiter Configuration (Most Likely)
**Evidence to Look For**:
- Server starts but controllers never reach ready
- Bookmark warnings appear
- High volume of requests in logs

**Solution**: Add QPS/Burst configuration
```go
cfg.QPS = 20
cfg.Burst = 30
```

#### 2. Environmental Difference (CI vs Local)
**Evidence to Look For**:
- Works locally but fails in CI
- Different resource constraints
- Network timeouts

**Solution**:
- Increase health check timeout
- Add resource limits to CI environment
- Check for CI-specific environment variables

#### 3. Kinm Initialization Issue
**Evidence to Look For**:
- Server starts but kinm not ready
- Database connection errors
- Schema initialization failures

**Solution**:
- Add startup delay before health check
- Verify kinm initialization sequence
- Check for database migration issues

#### 4. Unknown Breaking Change
**Evidence to Look For**:
- New error messages not seen before
- Unexpected API incompatibilities
- Stack traces or panics

**Solution**:
- Analyze full stack trace
- Search for error message in Kubernetes/controller-runtime issues
- May need to downgrade temporarily to isolate

---

## Debug Commands for Live Monitoring

### Monitor Test Run Status
```bash
# Watch run status in real-time
watch -n 10 'gh run view 21048342770 --repo jrmatherly/obot-entraid --json status,conclusion | jq .'

# Get live logs (if run is in progress)
gh run watch 21048342770 --repo jrmatherly/obot-entraid
```

### After Run Completes
```bash
# Get full logs
gh run view 21048342770 --repo jrmatherly/obot-entraid --log > debug-run-full.log

# Search for key patterns
grep -i "kinm\|nah" debug-run-full.log | head -20
grep -i "bookmark" debug-run-full.log
grep -i "health check" debug-run-full.log
grep -i "controllers ready" debug-run-full.log

# Find go module versions
grep "downloading.*kinm\|downloading.*nah" debug-run-full.log
```

### Analyze Specific Job
```bash
# List all jobs in the run
gh run view 21048342770 --repo jrmatherly/obot-entraid --json jobs | jq '.jobs[] | {name, conclusion, id}'

# View specific job logs
gh api repos/jrmatherly/obot-entraid/actions/jobs/<JOB_ID>/logs > job-specific.log
```

---

## Timeline Markers to Watch For

### Ideal Timeline (Success)
```
00:00 - Job starts
00:30 - Dependencies downloaded (kinm v0.1.3, nah v0.1.1)
01:00 - Build completes
02:00 - Integration test starts
02:05 - Obot server starts
02:10 - Health check attempt 1 (503 - controllers initializing)
02:15 - Health check attempt 2 (503 - cache syncing)
02:20 - Health check attempt 3 (200 OK - controllers ready) ✅
02:25 - Integration tests execute
05:00 - Tests complete successfully ✅
```

### Failure Timeline (If Cache Wasn't The Issue)
```
00:00 - Job starts
00:30 - Dependencies downloaded
01:00 - Build completes
02:00 - Integration test starts
02:05 - Obot server starts
02:10 - Health check attempt 1 (503)
02:15 - Health check attempt 2 (503)
...
07:00 - Health check attempt 60 (503)
07:05 - Timeout, print obot.log
07:06 - "Event bookmark expired" warnings visible
07:10 - Test fails ❌
```

---

## Expected Debug Output Format

With debug logging enabled, you should see much more verbose output:

```
::debug::Download action repository 'actions/checkout@v4' (SHA:...)
::debug::Action name 'Checkout'
::debug::evaluating condition for step: 'Set up Go'
...
::debug::Evaluating: success()
::debug::Evaluating success:
::debug::=> true
```

**Key Debug Sections**:
1. **Module download**: Shows exact versions being fetched
2. **Build commands**: Shows full go build invocations
3. **Environment variables**: Shows all env vars (may reveal misconfigurations)
4. **Test execution**: Shows detailed test output
5. **Cleanup**: Shows cache operations

---

## Next Steps After Results

### If Test Passes
1. ✅ Update CI workflow to prevent cache issues
2. ✅ Add version verification to CI logs
3. ✅ Monitor next few runs for consistency
4. ✅ Close issue as resolved (cache invalidation needed)

### If Test Still Fails
1. ⚠️ Analyze full debug logs for new evidence
2. ⚠️ Implement QPS/Burst rate limiter fix
3. ⚠️ Create new test run with rate limiter
4. ⚠️ If still fails, investigate environmental differences
5. ⚠️ Consider reaching out to kinm or controller-runtime communities

---

## Test Result Template

**Fill this out after run completes**:

```
Test Run: https://github.com/jrmatherly/obot-entraid/actions/runs/21048342770
Status: [ ] PASSED  [ ] FAILED
Duration: ___ minutes

Module Versions Downloaded:
- kinm: _______________
- nah: _______________

Health Check:
- First attempt time: _______________
- Success time: _______________ (or "Never")
- Total attempts: _______________

Bookmark Warnings:
- Count: _______________
- First occurrence: _______________

Conclusion:
[ ] Cache was the problem - fixed by deletion
[ ] Cache was NOT the problem - further investigation needed

Next Action:
_______________________________________________
```

---

## References

- Test Run URL: https://github.com/jrmatherly/obot-entraid/actions/runs/21048342770?pr=64
- PR: https://github.com/jrmatherly/obot-entraid/pull/64
- Previous Research: `claudedocs/controller-runtime-v018-v022-research-2026-01-15.md`
- Reflection Doc: `claudedocs/reflection-kubernetes-v035-research-corrections.md`
