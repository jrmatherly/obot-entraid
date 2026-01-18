# Obot-Entraid Implementation Patterns

**Purpose:** Reusable implementation patterns for common Obot platform procedures
**Last Updated:** 2026-01-16
**Versioning:** Patterns follow [Semantic Versioning](https://semver.org/) - see [CHANGELOG.md](./CHANGELOG.md)

---

## Available Patterns

### 1. [Auth Provider Setup](./auth-provider-setup.md) `v1.0.0`

**Pattern:** OAuth2 Authentication Provider Integration
**Use Case:** Add Entra ID or Keycloak authentication to Obot platform
**Components:** Go backend, SvelteKit frontend, PostgreSQL database

**When to Use:**

- Adding new authentication provider (Microsoft Entra ID, Keycloak, GitHub, Google)
- Implementing OAuth2/OIDC flow
- Configuring user profile fetching and icon display
- Troubleshooting authentication flow issues

**Key Features:**

- ✅ OAuth2/OIDC compliant implementation
- ✅ Profile picture integration
- ✅ Session management with PostgreSQL
- ✅ Frontend auth UI components

---

### 2. [MCP Server Deployment](./mcp-server-deployment.md) `v1.0.0`

**Pattern:** Model Context Protocol Server Configuration
**Use Case:** Deploy and configure MCP servers in Obot platform
**Components:** MCP gateway, Docker/containerd, Node.js/Python/Go runtime

**When to Use:**

- Deploying new MCP server (single-user, multi-user, remote, composite)
- Configuring server environment variables and secrets
- Setting up server dependencies and runtime requirements
- Troubleshooting MCP server connectivity or execution issues

**Key Features:**

- ✅ 4 server types supported (single-user npx/uvx/container, multi-user, remote, composite)
- ✅ Environment variable and secret management
- ✅ Dependency isolation and security
- ✅ Health check and monitoring integration

---

### 3. [Keycloak OIDC Integration](./keycloak-oidc-integration.md) `v1.0.0`

**Pattern:** Keycloak SSO Configuration for Obot Platform
**Use Case:** Set up Keycloak as OIDC provider for Obot authentication
**Components:** Keycloak server, Obot backend, SvelteKit frontend

**When to Use:**

- Setting up Keycloak as identity provider
- Configuring realm, clients, and user federation
- Implementing SSO across multiple applications
- Troubleshooting Keycloak token flow or user sync issues

**Key Features:**

- ✅ Keycloak realm and client configuration
- ✅ User attribute mapping and profile sync
- ✅ Token validation and refresh flow
- ✅ Multi-application SSO support

---

## Pattern Selection Guide

### I need to

**...add authentication provider:**
→ [Auth Provider Setup](./auth-provider-setup.md)

**...deploy MCP server:**
→ [MCP Server Deployment](./mcp-server-deployment.md)

**...configure Keycloak SSO:**
→ [Keycloak OIDC Integration](./keycloak-oidc-integration.md)

**...troubleshoot auth issues:**

- OAuth flow → [Auth Provider Setup](./auth-provider-setup.md) (Troubleshooting section)
- MCP server auth → [MCP Server Deployment](./mcp-server-deployment.md) (Security section)
- Keycloak SSO → [Keycloak OIDC Integration](./keycloak-oidc-integration.md) (Troubleshooting section)

---

## Using Patterns

### Pattern Structure

Each pattern document includes:

1. **Overview**: What the pattern is and key features
2. **Architecture**: Visual diagram of components and flow
3. **Prerequisites**: Required configuration before using pattern
4. **Procedure**: Step-by-step implementation guide
5. **Code Examples**: Actual code snippets and configuration files
6. **Troubleshooting**: Common issues and resolutions
7. **Testing**: Validation steps and test scenarios
8. **Related Documentation**: Links to relevant docs

### Integration with Component Docs

Obot-Entraid CLAUDE.md **references** these patterns instead of duplicating procedures. This provides:

- ✅ **Single Source of Truth**: Updates apply everywhere
- ✅ **Consistent Procedures**: Same steps across all implementations
- ✅ **Easier Maintenance**: Edit patterns once, not in multiple places
- ✅ **Faster Context Loading**: Smaller CLAUDE.md, load patterns on-demand

---

## Contributing Patterns

### When to Create a New Pattern

Create a new pattern when:

1. **Procedure is repeated 3+ times** in codebase or documentation
2. **Common use case** that applies to multiple Obot deployments
3. **Complex multi-step procedure** benefiting from detailed explanation
4. **Best practice** that should be standardized across implementations

### Pattern Template

```markdown
# Pattern Name

**Pattern:** One-line description
**Use Case:** When to use this pattern
**Components:** What components are involved
**Version:** 1.0.0
**Last Updated:** January 2026

---

## Overview
What this pattern is and key features

## Architecture
Visual diagram (Mermaid or ASCII) showing component interaction

## Prerequisites
- Required configuration
- Dependencies that must be installed
- Access/permissions needed

## Procedure

### Step 1: [Task Name]
Detailed step-by-step instructions

### Step 2: [Task Name]
Detailed step-by-step instructions

## Code Examples
Actual code snippets demonstrating implementation

## Testing
How to validate the implementation works

## Troubleshooting
Common issues and their solutions

## Related Documentation
Links to related patterns and docs

---

**Last Updated:** Date
**Pattern Version:** X.Y.Z
**Tested With:** Component versions
```

---

## Related Documentation

### Obot-Entraid Documentation

- [CLAUDE.md](../../CLAUDE.md) - Complete architecture guide
- [README.md](../../README.md) - Project overview
- [docs/](../../docs/) - Detailed documentation

### Component Implementation Guides

- `pkg/cli/server.go` - Server entry point
- `pkg/server/server.go` - Core server implementation
- `pkg/api/` - API handlers
- `pkg/controller/` - Kubernetes controllers
- `pkg/mcp/` - MCP server integration
- `pkg/storage/` - Database layer
- `ui/user/src/lib/components/` - SvelteKit components

---

**Total Patterns:** 3
**Coverage:** Authentication, MCP deployment, SSO integration
**Status:** Active development - patterns versioned and maintained
