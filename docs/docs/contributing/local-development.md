---
sidebar_position: 3
title: Local Development
description: Running Obot locally with authentication providers and tool registries
---

# Local Development

This guide explains how to run Obot locally for development, including working with authentication providers from the obot-tools fork.

## Prerequisites

Before starting local development, ensure you have:

1. **Go 1.25.3 or later** - Required for building the server
2. **Node.js and pnpm** - Required for UI development
3. **Docker** - Required for container builds and dependencies
4. **Git** - For version control

## Quick Start

The fastest way to start Obot in development mode:

```bash
# Run in development mode
make dev

# Or with browser tabs auto-opening
make dev-open
```

This command:

- Starts the Obot server with hot reload
- Serves the UI in development mode
- Configures the tool registry from obot-tools fork
- Opens browser tabs for UI and admin interface (with `dev-open`)

---

## Tool Registry Configuration

Obot uses tool registries to discover authentication providers and MCP servers. In development mode, the tool registry is configured via `.envrc.dev`:

```bash
export OBOT_SERVER_TOOL_REGISTRIES=github.com/jrmatherly/obot-tools
```

This configuration pulls all tools (including authentication providers) from the obot-tools fork:

- **Authentication Providers**: Entra ID, Keycloak, GitHub, Google
- **Core Tools**: Knowledge, memory, tasks, workspace files, etc.
- **Model Providers**: OpenAI, Anthropic, Azure, and more

---

## Authentication Providers

All authentication providers are in the [obot-tools fork](https://github.com/jrmatherly/obot-tools):

| Provider | Location | Documentation |
|----------|----------|---------------|
| Microsoft Entra ID | `obot-tools/entra-auth-provider/` | [Setup Guide](../configuration/entra-id-authentication.md) |
| Keycloak | `obot-tools/keycloak-auth-provider/` | [Setup Guide](../configuration/keycloak-authentication.md) |
| GitHub | `obot-tools/github-auth-provider/` | Built-in |
| Google | `obot-tools/google-auth-provider/` | Built-in |

### Developing Auth Providers

To modify or develop authentication providers:

1. Clone the obot-tools fork:

   ```bash
   git clone https://github.com/jrmatherly/obot-tools.git
   cd obot-tools
   ```

2. Make changes to the provider:

   ```bash
   cd entra-auth-provider
   # Edit code...
   make build
   make test
   ```

3. Use local obot-tools with Obot:

   ```bash
   # In obot-entraid directory
   export GPTSCRIPT_TOOL_REMAP="github.com/jrmatherly/obot-tools=../obot-tools"
   make dev
   ```

### Building Auth Provider Docker Images

Build the complete Obot image with auth providers:

```bash
docker build -t obot-local .
```

The Docker build pulls all tools (including auth providers) from the obot-tools image.

### Verifying the Container Build

```bash
# Build the image
docker build -t obot-local .

# Verify auth providers are available
docker run --rm --entrypoint sh obot-local -c \
  'grep -A 10 "authProviders:" /obot-tools/tools/index.yaml'

# Expected output shows all providers:
# authProviders:
#   github-auth-provider:
#     reference: ./github-auth-provider
#   google-auth-provider:
#     reference: ./google-auth-provider
#   entra-auth-provider:
#     reference: ./entra-auth-provider
#   keycloak-auth-provider:
#     reference: ./keycloak-auth-provider
```

---

## Environment Variables for Development

### Common Development Variables

```bash
# Server configuration
export OBOT_SERVER_PUBLIC_URL="http://localhost:8080"

# Enable insecure cookies for HTTP (NEVER in production!)
export OBOT_AUTH_INSECURE_COOKIES="true"

# Cookie secret for session encryption
export OBOT_AUTH_PROVIDER_COOKIE_SECRET=$(openssl rand -base64 32)

# Email domain restriction
export OBOT_AUTH_PROVIDER_EMAIL_DOMAINS="*"  # Allow all domains
```

### Entra ID Development Configuration

```bash
export OBOT_ENTRA_AUTH_PROVIDER_CLIENT_ID="your-dev-client-id"
export OBOT_ENTRA_AUTH_PROVIDER_CLIENT_SECRET="your-dev-client-secret"
export OBOT_ENTRA_AUTH_PROVIDER_TENANT_ID="your-tenant-id"

# Optional: restrict to specific groups
export OBOT_ENTRA_AUTH_PROVIDER_ALLOWED_GROUPS="group-id-1,group-id-2"

# Optional: cache tuning
export OBOT_ENTRA_AUTH_PROVIDER_GROUP_CACHE_TTL="1h"
export OBOT_ENTRA_AUTH_PROVIDER_ICON_CACHE_TTL="24h"
```

See [Entra ID Authentication Setup](../configuration/entra-id-authentication.md) for Azure App Registration configuration.

### Keycloak Development Configuration

```bash
export OBOT_KEYCLOAK_AUTH_PROVIDER_CLIENT_ID="obot"
export OBOT_KEYCLOAK_AUTH_PROVIDER_CLIENT_SECRET="your-client-secret"
export OBOT_KEYCLOAK_AUTH_PROVIDER_URL="http://localhost:8180"
export OBOT_KEYCLOAK_AUTH_PROVIDER_REALM="obot"

# Optional: restrict to specific groups/roles
export OBOT_KEYCLOAK_AUTH_PROVIDER_ALLOWED_GROUPS="admin,developers"
export OBOT_KEYCLOAK_AUTH_PROVIDER_ALLOWED_ROLES="obot-user"

# Optional: cache tuning
export OBOT_KEYCLOAK_AUTH_PROVIDER_GROUP_CACHE_TTL="1h"
```

See [Keycloak Authentication Setup](../configuration/keycloak-authentication.md) for Keycloak client configuration.

---

## Development Workflow

### Standard Development Loop

1. **Make code changes** to server code or UI
2. **Rebuild** affected components:

   ```bash
   # For server changes
   make build
   ```

3. **Restart development server**:

   ```bash
   make dev
   ```

4. **Test changes** in browser at http://localhost:8080
5. **Run tests**:

   ```bash
   make test
   ```

### Hot Reload

The UI supports hot reload automatically. Changes to TypeScript/Svelte files will be reflected immediately in the browser.

For server changes, you'll need to restart with `make dev`.

---

## Troubleshooting

### Auth Provider Not Appearing in UI

**Problem**: Authentication provider doesn't show up in the providers list

**Solution**:

1. Verify tool registry configuration:

   ```bash
   cat .envrc.dev | grep TOOL_REGISTRIES
   # Should show: github.com/jrmatherly/obot-tools
   ```

2. Check that obot-tools has the provider registered in `index.yaml`

3. Check Obot server logs for tool registry errors

### OAuth Errors During Local Testing

**Problem**: OAuth flow fails with redirect URI mismatch

**Solution**:

1. Verify redirect URI in Azure/Keycloak matches exactly:

   ```
   http://localhost:8080/oauth2/callback
   ```

2. Ensure `OBOT_AUTH_INSECURE_COOKIES=true` for HTTP

3. Check that `OBOT_SERVER_PUBLIC_URL` matches the redirect URI domain

### Cannot Find Provider Binary

**Problem**: Auth provider binary not found in container

**Solution**: The auth providers are now in obot-tools. Ensure you're using the correct `TOOLS_IMAGE`:

```bash
docker build --build-arg TOOLS_IMAGE=ghcr.io/jrmatherly/obot-tools:latest -t obot-local .
```

---

## Related Documentation

- [Entra ID Authentication](../configuration/entra-id-authentication.md)
- [Keycloak Authentication](../configuration/keycloak-authentication.md)
- [Server Configuration](../configuration/server-configuration.md)
- [obot-tools Repository](https://github.com/jrmatherly/obot-tools)
