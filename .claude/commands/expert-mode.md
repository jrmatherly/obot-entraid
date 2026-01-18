---
description: Initialize expert mode with progressive context loading and Serena integration
---

# Expert Mode Initialization (obot-entraid)

Initialize an expert session with smart context loading based on the task at hand.

## Step 1: Activate Serena Project

Activate the obot-entraid Serena project for symbolic code intelligence:

```
mcp__plugin_serena_serena__activate_project with project: "obot-entraid"
```

## Step 2: Core Context (Always Loaded)

These are already in context via CLAUDE.md:

- Project overview and tech stack
- Common commands (make dev, make build, pnpm run ci)
- Directory structure
- Safety rules

**Don't re-read CLAUDE.md** - it's automatically injected.

## Step 3: Load Task-Specific Context

Based on keywords in the user's request, load the appropriate Serena memory:

| Task Keywords | Memory to Load | Purpose |
|---------------|----------------|---------|
| auth, oauth, provider, login, entra, keycloak | `auth_provider_implementation` | Complete auth provider spec |
| credential, secret, store, encrypt | `gptscript_credential_store` | Credential storage patterns |
| release, tag, version, deploy | `release_procedure` | Release workflow |
| upstream, merge, fork, sync | `upstream_merge_procedure` | Fork merge process |
| review, pr, code quality | `code_review_dec2025` | Code review patterns |
| commit, pre-commit, validate, ci | `task_completion_checklist` | Pre-commit validation |
| style, convention, format | `code_style_conventions` | Code style rules |
| ui, frontend, svelte, component | `app_preferences_branding` | UI patterns |

**Example:**

- User says "help me fix the auth provider" → Load `auth_provider_implementation`
- User says "prepare a release" → Load `release_procedure`
- User says "ready to commit" → Load `task_completion_checklist`

## Step 4: Check Current State

```bash
git status --short
git branch --show-current
```

Report any uncommitted changes or notable branch state.

## Step 5: Confirm Understanding

Provide a brief confirmation:

```markdown
## Expert Mode Active

**Project:** obot-entraid (fork of obot-platform/obot)
**Branch:** [current branch]
**Status:** [clean / X uncommitted changes]

**Context loaded:**
- Core project understanding (CLAUDE.md)
- [Task-specific memory if loaded]

**Available agents:**
- `auth-provider-dev` - Auth provider development
- `upstream-merge` - Fork merge specialist
- `pre-commit` - Fast validation (haiku)
- `obot-go-reviewer` - Go code review (sonnet)

**Skills:**
- `/validate-project` - Full CI validation
- `/new-auth-provider` - Scaffold new provider
- `/release` - Release workflow
- `/upstream-merge` - Merge upstream changes

Ready for your task.
```

## Progressive Disclosure Rules

### Load Memories On-Demand

Don't load all memories upfront. Wait for specific needs:

1. **Start minimal** - CLAUDE.md context only
2. **Detect keywords** - Match task to memory
3. **Load selectively** - One or two memories max
4. **Deep dive** - Read source files only when implementing

### Context Budget

| Task Type | Budget | Strategy |
|-----------|--------|----------|
| Quick question | ~3K tokens | CLAUDE.md only |
| Bug fix | ~8K tokens | + relevant memory + specific files |
| Feature work | ~15K tokens | + memory + multiple source files |
| Architecture | ~20K tokens | Full exploration with Serena |

### File Reading Strategy

Use Serena symbolic tools instead of reading entire files:

```
# Instead of reading entire file
mcp__plugin_serena_serena__read_file "pkg/controller/routes.go"

# Get overview first
mcp__plugin_serena_serena__get_symbols_overview "pkg/controller/routes.go"

# Then read specific symbols
mcp__plugin_serena_serena__find_symbol "setupRoutes" include_body=true
```

## Safety Reminders

Critical rules for obot-entraid:

1. **GitHub CLI Fork Usage**: Always use `--repo jrmatherly/obot-entraid` or `--repo origin` with `gh` commands
2. **Profile Pictures**: Must be base64 data URLs (not external API URLs)
3. **Field Mapping**: Map provider `displayName` to obot `name`
4. **Cookie Name**: Must be `obot_access_token`
5. **K8s Upgrades**: Watch for bookmark interval issues (v0.35.0+)

## Output Styles Available

Switch response style with these options:

| Style | Description |
|-------|-------------|
| `minimal` | Terse, code-focused responses |
| `debugging` | Structured problem→fix workflow |
| `teaching` | Educational with explanations |

## Quick Reference

### Common Commands

```bash
# Development
make dev                    # Full dev environment
make dev-open               # Dev + open browser

# Validation
make validate-go-code       # Go validation
cd ui/user && pnpm run ci   # Frontend validation

# Auth provider testing
cd tools/entra-auth-provider && go run .
```

### Key Directories

```
pkg/controller/handlers/    # nah controllers
pkg/api/handlers/           # REST API handlers
tools/*-auth-provider/      # Custom auth providers
ui/user/src/                # SvelteKit frontend
```

Then wait for the user's specific task.
