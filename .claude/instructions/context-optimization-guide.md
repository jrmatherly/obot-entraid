# Context Optimization Guide

Strategies for efficient context usage when working with obot-entraid.

## Core Principle

Load context **on-demand** based on the task, not upfront.

## Context Hierarchy

### Level 1: Always Available (Auto-loaded)

These are injected automatically:

| Source | Size | Content |
|--------|------|---------|
| `CLAUDE.md` | ~1,500 tokens | Project overview, commands, architecture |
| Active rules | ~200-500 tokens | Path-specific conventions |
| Git status | ~100 tokens | Current branch, changes |

**Don't re-read these** - they're already in context.

### Level 2: On-Demand (Serena Memories)

Load based on task keywords:

| Keyword | Memory | Size |
|---------|--------|------|
| auth, oauth, provider, login | `auth_provider_implementation` | ~2,000 tokens |
| credential, secret, store | `gptscript_credential_store` | ~800 tokens |
| release, tag, version | `release_procedure` | ~500 tokens |
| upstream, merge, fork | `upstream_merge_procedure` | ~600 tokens |
| review, pr, code quality | `code_review_dec2025` | ~1,000 tokens |
| commit, pre-commit, validate | `task_completion_checklist` | ~400 tokens |
| style, convention | `code_style_conventions` | ~600 tokens |

### Level 3: Deep Dive (Files/Docs)

Load only when specifically needed:

| Need | Source |
|------|--------|
| Controller implementation details | `pkg/controller/handlers/<name>/<name>.go` |
| API handler patterns | `pkg/api/handlers/<resource>.go` |
| Auth provider code | `tools/<provider>-auth-provider/` |
| Frontend components | `ui/user/src/lib/components/` |
| Integration test patterns | `tests/integration/` |

## Smart Loading Rules

### Task Detection

When user describes a task, detect keywords and load appropriate context:

```
"fix the auth provider" → Load auth_provider_implementation memory
"prepare a release" → Load release_procedure memory
"merge upstream changes" → Load upstream_merge_procedure memory
"review my changes" → Load code_review_dec2025 memory
"ready to commit" → Load task_completion_checklist memory
```

### Progressive Disclosure

1. **Start minimal** - Use CLAUDE.md context first
2. **Expand as needed** - Load specific memories based on questions
3. **Deep dive selectively** - Read source files only when implementing

## Anti-Patterns

### Don't Do This

```
# Loading everything upfront (wastes tokens)
"Let me read all Serena memories first..."
"Let me explore the entire codebase..."
"Let me read CLAUDE.md again..."  # Already in context!
```

### Do This Instead

```
# Load on-demand
"For auth provider work, let me load the auth_provider_implementation memory..."
"To understand this controller, let me check the handler at pkg/controller/..."
```

## File Reading Strategy

### Use Symbolic Tools First

```
# Instead of reading entire file
mcp__plugin_serena_serena__read_file "pkg/controller/routes.go"

# Get symbol overview first
mcp__plugin_serena_serena__get_symbols_overview "pkg/controller/routes.go"

# Then read specific symbols
mcp__plugin_serena_serena__find_symbol "setupRoutes" include_body=true
```

### Search Before Reading

```
# Instead of reading files hoping to find something
grep -r "something" pkg/

# Use targeted search
mcp__plugin_serena_serena__search_for_pattern "FetchUserIconURL"
```

## Project-Specific Shortcuts

### Auth Provider Work

1. Load `auth_provider_implementation` memory
2. Check specific provider: `tools/<provider>-auth-provider/`
3. Reference integration: `pkg/proxy/proxy.go`, `pkg/gateway/client/user.go`

### Controller Work

1. Check handler: `pkg/controller/handlers/<name>/`
2. Check routes: `pkg/controller/routes.go`
3. Check types: `pkg/storage/apis/obot.obot.ai/v1/`

### Frontend Work

1. Check components: `ui/user/src/lib/components/`
2. Check routes: `ui/user/src/routes/`
3. Check services: `ui/user/src/lib/services/`

### API Work

1. Check handlers: `pkg/api/handlers/`
2. Check types: `pkg/storage/apis/obot.obot.ai/v1/`
3. Check client: `apiclient/`

## Expert Mode Optimization

When running `/expert-mode`:

1. Activate Serena project (required for symbolic tools)
2. Read `project_overview` memory (general context)
3. **Don't load other memories yet** - wait for specific task
4. Check git status for current state

## Context Budget Guidelines

| Task Type | Target Budget | Load Strategy |
|-----------|---------------|---------------|
| Quick fix | ~5K tokens | CLAUDE.md + specific file |
| Feature implementation | ~15K tokens | CLAUDE.md + relevant memory + source files |
| Code review | ~10K tokens | CLAUDE.md + review memory + changed files |
| Architecture exploration | ~20K tokens | Full explore with symbolic tools |

## Measuring Context Usage

Check token usage periodically:

- If approaching limits, summarize and release context
- Prefer symbolic reads over full file reads
- Unload memories no longer needed for current task
