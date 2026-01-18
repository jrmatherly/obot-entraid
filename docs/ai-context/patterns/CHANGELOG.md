# Obot-Entraid Patterns Changelog

All notable changes to implementation patterns will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned

- SvelteKit component patterns
- API endpoint implementation patterns
- Database migration patterns

## [1.0.0] - 2026-01-16

### Added

- **auth-provider-setup.md** - OAuth2 authentication provider integration pattern
- **mcp-server-deployment.md** - MCP server configuration and deployment pattern
- **keycloak-oidc-integration.md** - Keycloak SSO setup and configuration pattern
- Pattern README with version tracking and selection guide
- Pattern template for consistent structure

### Documentation

- Created patterns/ directory structure
- Established semantic versioning for patterns
- Added CHANGELOG.md for tracking pattern evolution

---

## Version Guidelines

### Major Version (X.0.0)

- Breaking changes to pattern structure
- Incompatible API or configuration changes
- Complete rewrites of implementation approach

### Minor Version (X.Y.0)

- New features or steps added to pattern
- Additional troubleshooting guidance
- Enhanced code examples or diagrams
- Backwards-compatible improvements

### Patch Version (X.Y.Z)

- Bug fixes in procedures or code examples
- Typo corrections and clarifications
- Updated component versions or links
- Minor documentation improvements

---

## Deprecation Policy

Patterns marked as deprecated will:

1. Remain available for 2 minor versions
2. Include migration guide to replacement pattern
3. Display deprecation notice at top of document
4. Be moved to `patterns/archive/` after removal

---

**Maintainer:** Obot-Entraid Development Team
**Last Updated:** 2026-01-16
