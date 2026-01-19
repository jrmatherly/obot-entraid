# Forked Project Workflow Patterns

## Overview
When forking obot-platform/* repositories, GitHub Actions workflows may need modifications to account for the fork context.

## Fork-Compatible Patterns
These GitHub Actions patterns automatically adapt to forks:
- `${{ github.repository }}` - Resolves to fork's repo name
- `${{ github.repository_owner }}` - Resolves to fork owner
- `${{ secrets.GITHUB_TOKEN }}` - Default token, works in forks

## Common Fork Issues

### 1. Empty Matrix Strategy
Workflows using matrix strategy based on changed files fail when PRs don't match file patterns.

**Fix**: Add condition to skip job when matrix is empty:
```yaml
jobs:
  scan:
    needs: generate-matrix
    if: ${{ needs.generate-matrix.outputs.matrix != '[]' && needs.generate-matrix.outputs.matrix != '' }}
```

### 2. Missing Custom Secrets
Workflows requiring custom secrets (PATs, API keys) fail in forks.

**Examples**:
- `DISPATCH_TOKEN` - For repository_dispatch release workflows
- `UPSTREAM_SYNC_WORKFLOW_PAT` - For syncing with upstream
- Provider API keys (OPENAI_API_KEY, etc.)

**Fix**: Either configure secrets in fork settings, or disable workflow by renaming to `.disabled`

### 3. GitHub Pages Not Enabled
Documentation deployment workflows fail if Pages not configured.

**Fix**: Enable Pages in repo Settings → Pages, or disable workflow

## Disabling Workflows
Rename workflow file to add `.disabled` suffix:
```bash
mv .github/workflows/workflow.yml .github/workflows/workflow.yml.disabled
```

GitHub Actions ignores files without `.yml`/`.yaml` extension.

## Projects Status (as of 2026-01-19)
| Project | Status | Notes |
|---------|--------|-------|
| obot-entraid | ✅ Healthy | Has open Renovate PRs |
| nah | ✅ Healthy | v0.1.2 released |
| kinm | ✅ Healthy | v0.1.7 released |
| mcp-catalog | ✅ Fixed | Empty matrix + sync disabled |
| mcp-oauth-proxy | ⚠️ Needs Pages | docs.yml failing |
| obot-tools | ✅ Fixed | dispatch disabled |
| namegenerator | ✅ Healthy | Simple CI only |
