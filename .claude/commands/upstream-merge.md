---
description: Guide upstream merge process with optional release workflow
argument-hint: [--release] [--dry-run]
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# Upstream Merge Process

You are guiding the upstream merge process for obot-entraid. This fork adds custom authentication providers (Entra ID, Keycloak) to the upstream obot-platform/obot project.

## Arguments

- `--release`: After successful merge, proceed with release workflow
- `--dry-run`: Perform merge without committing, show what would change
- No arguments: Interactive merge with confirmation prompts

User provided arguments: $ARGUMENTS

## Pre-Merge Checklist

Before starting, verify:

1. **Working directory is clean**

   ```bash
   git status
   ```

2. **Upstream remote is configured**

   ```bash
   git remote -v | grep upstream
   # If missing: git remote add upstream https://github.com/obot-platform/obot.git
   ```

3. **On main branch**

   ```bash
   git branch --show-current
   ```

## Step 1: Analyze Divergence

Fetch upstream and analyze the differences:

```bash
git fetch upstream

# Store merge base
MERGE_BASE=$(git merge-base main upstream/main)

# Count commits
echo "Commits ahead of upstream: $(git rev-list --count upstream/main..main)"
echo "Commits behind upstream: $(git rev-list --count main..upstream/main)"
```

Show recent upstream commits:

```bash
git log --oneline main..upstream/main | head -20
```

## Step 2: Identify Conflict Risk

Find files modified in both repositories:

```bash
MERGE_BASE=$(git merge-base main upstream/main)
comm -12 \
  <(git diff --name-only ${MERGE_BASE}..main | sort) \
  <(git diff --name-only ${MERGE_BASE}..upstream/main | sort)
```

## Step 3: Perform Dry-Run Merge

Test the merge without committing:

```bash
git merge --no-commit --no-ff upstream/main
git status
```

**If conflicts exist**, report them and ask for guidance on resolution strategy.

## Step 4: Verify Custom Changes Preserved

After merge (or dry-run), verify customizations:

```bash
# Auth providers
ls -la tools/entra-auth-provider/
ls -la tools/keycloak-auth-provider/

# Tool registry
cat tools/index.yaml

# Dockerfile merge logic
grep -A5 "Merge index.yaml" Dockerfile

# Workflows
ls -la .github/workflows/docker-build-and-push.yml
```

## Step 5: Resolve Conflicts (if any)

For conflicts, use these strategies:

| File Pattern | Strategy |
| -------------- | ---------- |
| `.github/workflows/*` | Keep OURS |
| `Dockerfile` | Keep OURS |
| `tools/*` | Keep OURS |
| `chart/values.yaml` | Merge carefully, preserve our config |
| `go.mod`, `go.sum` | Accept theirs, then `go mod tidy` |
| `pkg/*` | Accept theirs (unless auth-related) |
| `ui/*` | Manual merge, preserve our additions |

Commands for conflict resolution:

```bash
# Keep ours
git checkout --ours <file>
git add <file>

# Keep theirs
git checkout --theirs <file>
git add <file>

# Mark resolved after manual edit
git add <file>
```

## Step 6: Build Validation

```bash
go mod tidy
make lint
make build

# Optional: Docker build test
docker build -t obot-entraid:merge-test .
```

## Step 7: Commit or Abort

**If --dry-run**: Abort and report findings

```bash
git merge --abort
```

**If ready to commit**:

```bash
git commit -m "Merge upstream obot-platform/obot main (vX.Y.Z)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

## Step 8: Release (if --release flag)

If `--release` was specified, proceed with release:

1. Push merge commit: `git push origin main`
2. Determine next version from existing tags
3. Ask user to confirm new version number
4. Create and push tag SEPARATELY
5. Monitor workflows

Otherwise, inform user they can:

- Push with `git push origin main`
- Create a release by running `/upstream-merge --release` or following `release_procedure` memory

## Custom Changes Reference

These MUST be preserved:

**Auth Providers:**

- `tools/entra-auth-provider/`
- `tools/keycloak-auth-provider/`
- `tools/auth-providers-common/`
- `tools/index.yaml`

**Build Infrastructure:**

- `Dockerfile` (contains merge logic for unified tool registry)
- `.github/workflows/docker-build-and-push.yml`
- `.github/workflows/helm.yml`
- `.github/workflows/release.yml`

**Helm Chart:**

- `chart/Chart.yaml` (our versioning)
- `chart/values.yaml` (our defaults)

**UI Customizations:**

- `ui/user/src/lib/components/navbar/Profile.svelte`
- `ui/user/src/lib/components/profile/ProfileIcon.svelte`

Read the `upstream_merge_procedure` Serena memory for detailed guidance.
