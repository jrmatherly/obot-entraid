# Auth Provider Migration Archive

This directory contains the original auth provider implementations that were migrated from `obot-entraid/tools/` to the `jrmatherly/obot-tools` fork.

## Migration Date

January 18, 2026

## Archived Components

| Directory | Description | New Location |
| --------- | ----------- | ------------ |
| `entra-auth-provider/` | Microsoft Entra ID (Azure AD) auth provider | `obot-tools/entra-auth-provider/` |
| `keycloak-auth-provider/` | Keycloak OIDC auth provider | `obot-tools/keycloak-auth-provider/` |
| `auth-providers-common/` | Shared utilities for auth providers | `obot-tools/auth-providers-common/` |
| `placeholder-credential/` | Fake credential tool (required by providers) | `obot-tools/placeholder-credential/` |

## Why This Migration?

1. **Canonical Location**: Auth providers are now in the official tools repository alongside GitHub and Google providers
2. **Simplified Dockerfile**: No longer need to build and merge local providers
3. **Single Registry**: All tools available from one `OBOT_SERVER_TOOL_REGISTRIES` source
4. **Easier Maintenance**: Updates to providers go through standard obot-tools CI/CD

## Current Configuration

After migration, obot-entraid uses:

```bash
# .envrc.dev
export OBOT_SERVER_TOOL_REGISTRIES=github.com/jrmatherly/obot-tools
```

The Dockerfile now pulls all tools (including auth providers) from the obot-tools image without local builds.

## Reverting (If Needed)

To restore local development with these archived providers:

1. Move directories back: `mv archive/tools-migration-2026-01-18/* tools/`
2. Update `.envrc.dev`: Add `./tools` back to registries
3. Update `Dockerfile`: Re-add local provider build steps
4. Update `tools/index.yaml`: Restore provider references

See `docs/AUTH_PROVIDER_MIGRATION_GUIDE.md` in obot-tools for the detailed migration documentation.
