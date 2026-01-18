# Claude Documentation Directory

This directory contains technical documentation generated during Claude Code sessions.

## Archived Projects

### Kubernetes v0.35.0 Upgrade (January 2026)

**Status**: ✅ COMPLETED
**Location**: [archive/k8s-v035-upgrade-2026-01/](./archive/k8s-v035-upgrade-2026-01/)

The K8s v0.35.0 upgrade project successfully resolved dependency blockers:

- Forked nah and kinm frameworks with K8s v0.35.0 support
- Implemented Apply() method for client.WithWatch interface
- Fixed bookmark interval (60s → 5s) for client-go compatibility
- Fixed ContentType for REST client protobuf negotiation
- Upgraded Cloud Storage to v1.59.1, otelgrpc to v0.63.0+
- Unblocked 17+ Renovate dependency updates

**Archive Contents** (17 files):

| File | Description |
|------|-------------|
| nah-fork-k8s-upgrade-implementation-plan.md | Main implementation plan (1,587 lines) |
| comprehensive-remediation-plan.md | Root cause analysis and remediation |
| validated-implementation-checklist.md | Final implementation checklist |
| ci-failure-root-cause-bookmark-interval-*.md | Bookmark timing issue analysis |
| kubernetes-v035-upgrade-research-*.md | K8s v0.35.0 breaking changes research |
| controller-runtime-v018-v022-research-*.md | Controller-runtime upgrade research |
| ci-failure-analysis-*.md | CI debugging records (multiple) |
| configuration-analysis-database-dsn-*.md | Database configuration analysis |
| integration-test-failure-analysis-*.md | Integration test debugging |
| validation-report.md | Plan validation report |
| reflection-*.md | Task reflection documents |

**Key Patterns Extracted**: See `.claude/rules/kubernetes-upgrade.md`

---

## Directory Structure

```
claudedocs/
├── README.md                    # This file
└── archive/
    └── k8s-v035-upgrade-2026-01/  # Completed K8s upgrade project
```

## Usage

### Accessing Archives

Archives contain comprehensive documentation of completed projects. Reference them for:

- Historical context on past decisions
- Patterns for similar future work
- Debugging approaches that worked

### Adding New Documentation

Claude Code generates documentation during implementation sessions. Add new documents to the root of this directory, then archive when complete.

---

**Project**: obot-entraid (github.com/jrmatherly/obot-entraid)
