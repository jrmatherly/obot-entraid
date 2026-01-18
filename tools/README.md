# Tools Directory

This directory contains development utilities and supporting files for the obot-entraid project.

> **Note**: Authentication providers (EntraID, Keycloak) have been migrated to the [obot-tools fork](https://github.com/jrmatherly/obot-tools). See the archive directory for historical reference.

## Directory Structure

```
tools/
├── combine-envrc.sh           # Script to merge .envrc files in container builds
├── dev.sh                     # Development server launcher
├── devmode-kubeconfig         # Kubeconfig for local development
├── index.yaml                 # Tool registry (now empty - providers in obot-tools)
├── tool.gpt                   # GPTScript wrapper
└── vendor.go                  # Go import dependencies for code generation
```

## Auth Provider Locations

All authentication providers are now in the obot-tools fork:

| Provider | Location |
| -------- | -------- |
| Microsoft EntraID | `github.com/jrmatherly/obot-tools/entra-auth-provider` |
| Keycloak | `github.com/jrmatherly/obot-tools/keycloak-auth-provider` |
| GitHub | `github.com/jrmatherly/obot-tools/github-auth-provider` |
| Google | `github.com/jrmatherly/obot-tools/google-auth-provider` |

## Local Development

### Running Obot with Auth Providers

From the project root:

```bash
# Run in development mode
make dev

# Or with browser tabs auto-opening
make dev-open
```

The `.envrc.dev` file configures the tool registry:

```bash
export OBOT_SERVER_TOOL_REGISTRIES=github.com/jrmatherly/obot-tools
```

All auth providers are automatically available from the obot-tools fork.

### Container Build

The Dockerfile pulls all tools (including auth providers) from the obot-tools image:

```bash
docker build -t obot-test .
```

Verify auth providers are available:

```bash
docker run --rm --entrypoint sh obot-test -c 'grep -A 10 "authProviders:" /obot-tools/tools/index.yaml'
```

## Auth Provider Configuration

### Microsoft Entra ID

Required environment variables:

- `OBOT_ENTRA_AUTH_PROVIDER_CLIENT_ID` - Azure App Registration client ID
- `OBOT_ENTRA_AUTH_PROVIDER_CLIENT_SECRET` - Azure App Registration client secret
- `OBOT_ENTRA_AUTH_PROVIDER_TENANT_ID` - Azure tenant ID (or 'common'/'organizations')
- `OBOT_AUTH_PROVIDER_COOKIE_SECRET` - Base64-encoded 16/24/32 byte secret
- `OBOT_AUTH_PROVIDER_EMAIL_DOMAINS` - Allowed email domains (use `*` for all)

See the [obot-tools entra-auth-provider README](https://github.com/jrmatherly/obot-tools/tree/main/entra-auth-provider) for detailed configuration.

### Keycloak

Required environment variables:

- `OBOT_KEYCLOAK_AUTH_PROVIDER_CLIENT_ID` - Keycloak client ID
- `OBOT_KEYCLOAK_AUTH_PROVIDER_CLIENT_SECRET` - Keycloak client secret
- `OBOT_KEYCLOAK_AUTH_PROVIDER_URL` - Keycloak base URL
- `OBOT_KEYCLOAK_AUTH_PROVIDER_REALM` - Keycloak realm name
- `OBOT_AUTH_PROVIDER_COOKIE_SECRET` - Base64-encoded 16/24/32 byte secret
- `OBOT_AUTH_PROVIDER_EMAIL_DOMAINS` - Allowed email domains (use `*` for all)

## Migration History

The auth providers were originally developed in this repository and migrated to obot-tools in January 2026. See `archive/tools-migration-2026-01-18/` for the original implementation.

## Troubleshooting

### Auth provider not appearing in UI

1. Verify the tool registry is correctly configured in `.envrc.dev`
2. Check that obot-tools fork has the latest provider code
3. Review the obot-tools CI/CD to ensure images are published

### OAuth errors

1. Verify environment variables are set correctly
2. Check Azure/Keycloak redirect URI matches `{OBOT_SERVER_URL}/oauth2/callback`
3. Review provider logs for detailed error messages
