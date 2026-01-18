# tool.gpt Template

Template for auth provider GPTScript tool definition.

## Complete Template

```gpt
Name: <Provider> Auth Provider
Description: Obot authentication provider using <Provider Name> (<detail>)
Metadata: daemon: true
Metadata: envVars: OBOT_<PROVIDER>_CLIENT_ID,OBOT_<PROVIDER>_CLIENT_SECRET,OBOT_AUTH_PROVIDER_COOKIE_SECRET,OBOT_AUTH_PROVIDER_EMAIL_DOMAINS
Metadata: optionalEnvVars: <provider-specific optional vars>
Credential: ../placeholder-credential

#!/usr/bin/env ${GPTSCRIPT_TOOL_DIR}/bin/<provider>-auth-provider
```

## Field Reference

### Name (required)

The display name for the auth provider.

```gpt
Name: Entra Auth Provider
Name: Keycloak Auth Provider
Name: Google Auth Provider
```

### Description (required)

One-line description of what the provider does.

```gpt
Description: Obot authentication provider using Microsoft Entra ID (Azure AD)
Description: Obot authentication provider using Keycloak
Description: Obot authentication provider using Google OAuth2
```

### Metadata: daemon (required)

Marks this as a long-running daemon tool.

```gpt
Metadata: daemon: true
```

### Metadata: envVars (required)

Comma-separated list of required environment variables.

**Always include:**

- `OBOT_<PROVIDER>_CLIENT_ID`
- `OBOT_<PROVIDER>_CLIENT_SECRET`
- `OBOT_AUTH_PROVIDER_COOKIE_SECRET`
- `OBOT_AUTH_PROVIDER_EMAIL_DOMAINS`

```gpt
Metadata: envVars: OBOT_ENTRA_AUTH_PROVIDER_CLIENT_ID,OBOT_ENTRA_AUTH_PROVIDER_CLIENT_SECRET,OBOT_AUTH_PROVIDER_COOKIE_SECRET,OBOT_AUTH_PROVIDER_EMAIL_DOMAINS
```

### Metadata: optionalEnvVars (optional)

Comma-separated list of optional environment variables.

```gpt
# Entra - tenant ID is optional (defaults to "common")
Metadata: optionalEnvVars: OBOT_ENTRA_AUTH_PROVIDER_TENANT_ID

# Keycloak - realm and base URL
Metadata: optionalEnvVars: OBOT_KEYCLOAK_AUTH_PROVIDER_REALM,OBOT_KEYCLOAK_AUTH_PROVIDER_BASE_URL

# Okta - custom domain
Metadata: optionalEnvVars: OBOT_OKTA_AUTH_PROVIDER_DOMAIN
```

### Credential (required)

Reference to placeholder credential for GPTScript.

```gpt
Credential: ../placeholder-credential
```

### Execution Line (required)

The shebang line that runs the compiled binary.

```gpt
#!/usr/bin/env ${GPTSCRIPT_TOOL_DIR}/bin/<provider>-auth-provider
```

## Provider-Specific Examples

### Microsoft Entra ID

```gpt
Name: Entra Auth Provider
Description: Obot authentication provider using Microsoft Entra ID (Azure AD)
Metadata: daemon: true
Metadata: envVars: OBOT_ENTRA_AUTH_PROVIDER_CLIENT_ID,OBOT_ENTRA_AUTH_PROVIDER_CLIENT_SECRET,OBOT_AUTH_PROVIDER_COOKIE_SECRET,OBOT_AUTH_PROVIDER_EMAIL_DOMAINS
Metadata: optionalEnvVars: OBOT_ENTRA_AUTH_PROVIDER_TENANT_ID
Credential: ../placeholder-credential

#!/usr/bin/env ${GPTSCRIPT_TOOL_DIR}/bin/entra-auth-provider
```

### Keycloak

```gpt
Name: Keycloak Auth Provider
Description: Obot authentication provider using Keycloak
Metadata: daemon: true
Metadata: envVars: OBOT_KEYCLOAK_AUTH_PROVIDER_CLIENT_ID,OBOT_KEYCLOAK_AUTH_PROVIDER_CLIENT_SECRET,OBOT_AUTH_PROVIDER_COOKIE_SECRET,OBOT_AUTH_PROVIDER_EMAIL_DOMAINS
Metadata: optionalEnvVars: OBOT_KEYCLOAK_AUTH_PROVIDER_REALM,OBOT_KEYCLOAK_AUTH_PROVIDER_BASE_URL
Credential: ../placeholder-credential

#!/usr/bin/env ${GPTSCRIPT_TOOL_DIR}/bin/keycloak-auth-provider
```

### Google

```gpt
Name: Google Auth Provider
Description: Obot authentication provider using Google OAuth2
Metadata: daemon: true
Metadata: envVars: OBOT_GOOGLE_AUTH_PROVIDER_CLIENT_ID,OBOT_GOOGLE_AUTH_PROVIDER_CLIENT_SECRET,OBOT_AUTH_PROVIDER_COOKIE_SECRET,OBOT_AUTH_PROVIDER_EMAIL_DOMAINS
Credential: ../placeholder-credential

#!/usr/bin/env ${GPTSCRIPT_TOOL_DIR}/bin/google-auth-provider
```

## Validation

Before deployment, verify:

1. **Name field present** - Tool won't register without it
2. **daemon: true set** - Required for long-running process
3. **envVars complete** - Missing vars cause runtime failures
4. **Credential path correct** - Must point to placeholder-credential
5. **Binary name matches** - Execution line must match go.mod module

## Testing

```bash
# Verify tool.gpt syntax
cd tools/<provider>-auth-provider
cat tool.gpt

# Test with gptscript (requires env vars)
gptscript tool.gpt --help
```
