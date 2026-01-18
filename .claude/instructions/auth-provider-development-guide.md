# Auth Provider Development Guide

Complete guide for developing Obot authentication providers in obot-entraid.

## Overview

Auth providers are HTTP daemon tools that handle OAuth2 authentication flows. They translate provider-specific responses (Microsoft Entra ID, Keycloak, Google, GitHub) into Obot's expected format.

## Architecture

```
┌─────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Browser   │────▶│  Obot Gateway   │────▶│  Auth Provider  │
│             │     │  (pkg/proxy)    │     │  (HTTP Daemon)  │
└─────────────┘     └─────────────────┘     └─────────────────┘
                           │                        │
                           ▼                        ▼
                    /obot-get-state          Identity Provider
                    /obot-get-user-info      (Entra, Keycloak)
```

## Required Endpoints

| Endpoint | Method | Request | Response |
|----------|--------|---------|----------|
| `/{$}` | GET | - | Daemon address (string) |
| `/oauth2/start` | GET | `?rd=<redirect>` | 302 to IdP |
| `/oauth2/callback` | GET | OAuth callback params | Set cookie, 302 to `rd` |
| `/oauth2/sign_out` | GET | `?rd=<redirect>` | Clear cookie, 302 to `rd` |
| `/obot-get-state` | POST | JSON with headers | Session state JSON |
| `/obot-get-user-info` | GET | `Authorization: Bearer <token>` | User profile JSON |
| `/obot-get-icon-url` | GET | `Authorization: Bearer <token>` | Profile picture (data URL) |

## Token Cookie Specification

```go
const CookieName = "obot_access_token"

cookie := &http.Cookie{
    Name:     CookieName,
    Value:    encryptedToken, // AES-GCM encrypted
    Path:     "/",
    HttpOnly: true,
    Secure:   strings.HasPrefix(os.Getenv("OBOT_SERVER_PUBLIC_URL"), "https://"),
    SameSite: http.SameSiteLaxMode,
}
```

**Encryption**: Use `OBOT_AUTH_PROVIDER_COOKIE_SECRET` (base64-encoded 32-byte key) for AES-GCM encryption.

## /obot-get-state Implementation

**Request:**

```json
{
  "method": "GET",
  "url": "https://obot.example.com/api/projects",
  "header": {
    "Cookie": ["obot_access_token=<encrypted>"],
    "Accept": ["application/json"]
  }
}
```

**Response (success):**

```json
{
  "accessToken": "eyJ...",
  "preferredUsername": "johndoe",
  "user": "johndoe",
  "email": "johndoe@example.com"
}
```

**Response (error):** HTTP 400 if cookie missing/invalid.

## Field Mapping (CRITICAL)

Obot's `pkg/gateway/client/user.go` expects specific field names:

| Obot Field | Provider Field | Notes |
|------------|---------------|-------|
| `name` | `displayName` (Entra) / `preferred_username` (Keycloak) | Must map explicitly |
| `email` | `mail` (Entra) / `email` (Keycloak) | Direct or mapped |
| `icon_url` | N/A | Must be base64 data URL |

```go
// Map provider fields to obot fields
if displayName, ok := result["displayName"].(string); ok {
    result["name"] = displayName  // REQUIRED mapping
}
```

## Profile Picture Handling (CRITICAL)

**The #1 mistake**: Returning external API URLs that require authentication.

```go
// WRONG - Browser cannot authenticate to Graph API
result["icon_url"] = "https://graph.microsoft.com/v1.0/me/photo/$value"

// CORRECT - Fetch server-side, return as data URL
iconURL, err := FetchUserIconURL(ctx, accessToken)
if err == nil && iconURL != "" {
    result["icon_url"] = iconURL  // "data:image/jpeg;base64,/9j/4AAQ..."
}
```

**Implementation:**

```go
func FetchUserIconURL(ctx context.Context, accessToken string) (string, error) {
    req, _ := http.NewRequestWithContext(ctx, "GET", photoURL, nil)
    req.Header.Set("Authorization", "Bearer "+accessToken)

    resp, err := http.DefaultClient.Do(req)
    if err != nil || resp.StatusCode != http.StatusOK {
        return "", err
    }
    defer resp.Body.Close()

    imageData, _ := io.ReadAll(resp.Body)
    contentType := resp.Header.Get("Content-Type")
    if contentType == "" {
        contentType = "image/jpeg"
    }

    return fmt.Sprintf("data:%s;base64,%s",
        contentType,
        base64.StdEncoding.EncodeToString(imageData)), nil
}
```

## tool.gpt Template

```gpt
Name: Entra Auth Provider
Description: Obot authentication provider using Microsoft Entra ID (Azure AD)
Metadata: daemon: true
Metadata: envVars: OBOT_ENTRA_AUTH_PROVIDER_CLIENT_ID,OBOT_ENTRA_AUTH_PROVIDER_CLIENT_SECRET,OBOT_AUTH_PROVIDER_COOKIE_SECRET,OBOT_AUTH_PROVIDER_EMAIL_DOMAINS
Metadata: optionalEnvVars: OBOT_ENTRA_AUTH_PROVIDER_TENANT_ID
Credential: ../placeholder-credential

#!/usr/bin/env ${GPTSCRIPT_TOOL_DIR}/bin/entra-auth-provider
```

**Required metadata:**

- `daemon: true` - Marks as long-running process
- `envVars` - Required environment variables
- `optionalEnvVars` - Optional environment variables
- `Credential` - Reference to placeholder credential

## Directory Structure

```
tools/entra-auth-provider/
├── main.go              # HTTP handlers, OAuth2 proxy setup
├── pkg/
│   ├── profile/
│   │   └── profile.go   # FetchUserIconURL, ParseIDToken
│   └── state/
│       └── state.go     # Session state handling
├── tool.gpt             # GPTScript tool definition
├── go.mod
└── README.md
```

## Environment Variables

### Required (all providers)

| Variable | Description |
|----------|-------------|
| `OBOT_<PROVIDER>_CLIENT_ID` | OAuth2 client ID |
| `OBOT_<PROVIDER>_CLIENT_SECRET` | OAuth2 client secret |
| `OBOT_AUTH_PROVIDER_COOKIE_SECRET` | Cookie encryption key (32 bytes, base64) |
| `OBOT_AUTH_PROVIDER_EMAIL_DOMAINS` | Allowed domains ("*" for all) |

### Optional

| Variable | Description |
|----------|-------------|
| `OBOT_SERVER_URL` | Obot server URL (for callback) |
| `OBOT_SERVER_PUBLIC_URL` | Public URL (for Secure cookie flag) |
| `PORT` | HTTP server port (default varies) |

## Testing

### Local Testing

```bash
cd tools/entra-auth-provider

# Set required env vars
export OBOT_ENTRA_AUTH_PROVIDER_CLIENT_ID="your-client-id"
export OBOT_ENTRA_AUTH_PROVIDER_CLIENT_SECRET="your-secret"
export OBOT_AUTH_PROVIDER_COOKIE_SECRET="$(openssl rand -base64 32)"
export OBOT_SERVER_URL="http://localhost:8080"
export PORT="9999"

# Run
go run .

# Test endpoints
curl http://localhost:9999/                    # Should return address
curl -v http://localhost:9999/oauth2/start     # Should redirect to IdP
```

### Build Verification

```bash
go build -o /dev/null .
go mod tidy
go vet ./...
```

## Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| 401 on profile pictures | External API URL returned | Fetch server-side, return base64 |
| User name not showing | Field name mismatch | Map `displayName` to `name` |
| Cookie not persisting | Secure flag mismatch | Only set Secure for HTTPS |
| Token decryption failed | Secret changed | Use consistent secret |
| "invalid cookie" error | Cookie encryption issue | Check secret is 32 bytes base64 |

## Integration Points

Key files in obot that interact with auth providers:

```
pkg/proxy/proxy.go           # AuthenticateRequest → /obot-get-state
pkg/gateway/client/user.go   # UpdateProfileIfNeeded → /obot-get-user-info
pkg/auth/auth.go             # GroupInfo, ContextWithProviderURL
```

## Serena Memory Reference

For complete implementation details, read these memories:

- `auth_provider_implementation` - Full Obot specification
- `gptscript_credential_store` - Credential storage patterns
