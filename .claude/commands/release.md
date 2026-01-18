---
description: Create a new release with proper tagging and workflow triggers
argument-hint: [version]
allowed-tools: Bash, Read
---

# Release Process

Create a new release for obot-entraid. This command handles versioning, tagging, and workflow verification.

## Arguments

- `version`: Optional version number (e.g., `0.2.24` or `v0.2.24`)
- No arguments: Auto-detect next version from existing tags

User provided arguments: $ARGUMENTS

## Pre-Release Checklist

Before releasing, verify:

1. **Working directory is clean**

   ```bash
   git status
   ```

2. **On main branch**

   ```bash
   git branch --show-current
   ```

3. **All changes pushed**

   ```bash
   git log origin/main..main --oneline
   ```

## Step 1: Determine Version

If no version provided, find the next version:

```bash
# List recent tags
git tag -l 'v0.2.*' | sort -V | tail -5

# Get latest
LATEST=$(git tag -l 'v0.2.*' | sort -V | tail -1)
echo "Latest version: $LATEST"
```

Suggest incrementing the patch version (e.g., `v0.2.23` -> `v0.2.24`).

## Step 2: Validate Build

Before tagging, ensure the build works:

```bash
make build
make lint
```

## Step 3: Create and Push Tag

**CRITICAL**: Push tag SEPARATELY from branch commits to ensure workflows trigger.

```bash
# Ensure branch commits are pushed first
git push origin main

# Create tag
git tag v0.2.XX

# Push tag SEPARATELY
git push origin v0.2.XX
```

**Why separate?** Using `git push origin main --tags` may cause GitHub to skip tag-triggered workflows.

## Step 4: Monitor Workflows

```bash
gh run list --repo jrmatherly/obot-entraid --limit 5
```

Wait for these workflows to complete:

- `Build and Push Docker Image` - Builds container, pushes to GHCR
- `Helm Chart` - Packages and pushes Helm chart to GHCR OCI
- `release` - Creates GitHub release

## Step 5: Verify Artifacts

**Helm Chart:**

```bash
helm show chart oci://ghcr.io/jrmatherly/charts/obot --version 0.2.XX
```

Expected:

```yaml
apiVersion: v2
appVersion: v0.2.XX
name: obot
version: 0.2.XX
```

**Docker Image:**

```bash
docker pull ghcr.io/jrmatherly/obot-entraid:v0.2.XX
```

## Version Format Reference

| Artifact | Format | Example |
| ---------- | -------- | --------- |
| Git tag | `v{major}.{minor}.{patch}` | `v0.2.24` |
| Docker image | Same as tag | `ghcr.io/jrmatherly/obot-entraid:v0.2.24` |
| Helm chart version | No `v` prefix | `0.2.24` |
| Helm appVersion | With `v` prefix | `v0.2.24` |

## Downstream Update (talos-k8s-cluster)

After release, optionally update the cluster:

1. Update `cluster.yaml` with new version (no `v` prefix):

   ```yaml
   obot_version: "0.2.XX"
   ```

2. Render templates:

   ```bash
   cd /Users/jason/dev/IaC/talos-k8s-cluster
   task configure -y
   ```

3. Verify and commit:

   ```bash
   git add -A
   git commit -m "chore(obot): upgrade to v0.2.XX"
   git push
   ```

## Troubleshooting

### Workflows didn't trigger

- Verify tag was pushed separately from commits
- Check workflow files exist and are valid YAML
- Check GitHub Actions is enabled for the repository

### Chart version mismatch

- The Helm workflow auto-updates Chart.yaml from the tag
- Check `.github/workflows/helm.yml` has version extraction logic

### Image pull fails

- Verify image tag includes `v` prefix: `v0.2.XX`
- Check GHCR authentication and package visibility

Read `release_procedure` Serena memory for detailed procedures.
