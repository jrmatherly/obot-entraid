---
name: new-auth-provider
description: Scaffold a new Obot authentication provider with proper structure and endpoints
version: 1.0.0
author: obot-entraid team
tags: [auth, oauth2, provider, scaffolding]
---

# New Auth Provider

Scaffold a new OAuth2 authentication provider for obot-entraid.

## When to Use

- Adding support for a new identity provider (Google, Okta, Auth0, etc.)
- Understanding the auth provider structure
- Implementing custom OAuth2 flows

## Prerequisites

Before scaffolding:

1. **OAuth2 Application Created** - Client ID and Secret from the identity provider
2. **Scopes Identified** - Required OAuth2 scopes for profile, email, photo
3. **Endpoints Known** - Authorization, token, userinfo URLs

## Instructions

### Step 1: Create Directory Structure

```bash
mkdir -p tools/<provider>-auth-provider/pkg/{profile,state}
```

**Target structure:**

```
tools/<provider>-auth-provider/
├── main.go              # HTTP handlers, OAuth2 proxy setup
├── pkg/
│   ├── profile/
│   │   └── profile.go   # FetchUserIconURL, field mapping
│   └── state/
│       └── state.go     # Session state handling
├── tool.gpt             # GPTScript tool definition
├── go.mod
└── README.md
```

### Step 2: Create tool.gpt

Use the template in `references/tool-gpt-template.md`.

**Required sections:**

- Name and Description
- `daemon: true` metadata
- `envVars` and `optionalEnvVars` metadata
- Credential reference
- Binary execution line

### Step 3: Initialize Go Module

```bash
cd tools/<provider>-auth-provider
go mod init github.com/obot-platform/obot/tools/<provider>-auth-provider
```

### Step 4: Implement Required Endpoints

See `references/endpoint-spec.md` for complete specification.

| Endpoint | Purpose |
|----------|---------|
| `/{$}` | Return daemon address |
| `/oauth2/start` | Start OAuth2 flow |
| `/oauth2/callback` | Handle callback |
| `/oauth2/sign_out` | Clear session |
| `/obot-get-state` | Return session state |
| `/obot-get-user-info` | Return user profile |
| `/obot-get-icon-url` | Return profile picture |

### Step 5: Implement Profile Picture Handling

**CRITICAL**: Never return external API URLs that require authentication.

```go
func FetchUserIconURL(ctx context.Context, accessToken string) (string, error) {
    // Fetch image server-side
    resp, err := httpClient.Do(req)  // with Bearer token
    imageData, _ := io.ReadAll(resp.Body)

    // Return as data URL
    return fmt.Sprintf("data:%s;base64,%s",
        resp.Header.Get("Content-Type"),
        base64.StdEncoding.EncodeToString(imageData)), nil
}
```

### Step 6: Implement Field Mapping

Map provider fields to Obot's expected fields:

```go
// Example: Map provider's "displayName" to Obot's "name"
if displayName, ok := result["displayName"].(string); ok {
    result["name"] = displayName
}
```

### Step 7: Test Locally

```bash
cd tools/<provider>-auth-provider

# Set environment variables
export OBOT_<PROVIDER>_CLIENT_ID="your-client-id"
export OBOT_<PROVIDER>_CLIENT_SECRET="your-secret"
export OBOT_AUTH_PROVIDER_COOKIE_SECRET="$(openssl rand -base64 32)"
export PORT="9999"

# Run
go run .

# Test endpoints
curl http://localhost:9999/
curl -v http://localhost:9999/oauth2/start
```

### Step 8: Build Verification

```bash
go build -o /dev/null .
go mod tidy
go vet ./...
```

## Resources

Load these Level 3 resources:

- `references/tool-gpt-template.md` - GPTScript tool definition template
- `references/endpoint-spec.md` - Complete endpoint specification

## Examples

### Example 1: Google Auth Provider

```bash
mkdir -p tools/google-auth-provider/pkg/{profile,state}
cd tools/google-auth-provider
go mod init github.com/obot-platform/obot/tools/google-auth-provider
```

**Required scopes:** `openid profile email`
**Photo endpoint:** `https://people.googleapis.com/v1/people/me?personFields=photos`

### Example 2: Okta Auth Provider

```bash
mkdir -p tools/okta-auth-provider/pkg/{profile,state}
cd tools/okta-auth-provider
go mod init github.com/obot-platform/obot/tools/okta-auth-provider
```

**Required scopes:** `openid profile email`
**Custom domain:** `https://{domain}.okta.com`

## Checklist

Before considering the provider complete:

- [ ] All 7 required endpoints implemented
- [ ] Token cookie named `obot_access_token`
- [ ] Cookie encryption working
- [ ] Profile pictures as base64 data URLs
- [ ] Field mapping correct (name, email, icon_url)
- [ ] `tool.gpt` has all required metadata
- [ ] Build succeeds without errors
- [ ] Local testing passes all endpoints
- [ ] README.md documents configuration

## Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Profile picture 401 | Returning API URL | Fetch server-side, return base64 |
| Name not showing | Field mismatch | Map provider field to `name` |
| Cookie not persisting | Secure flag | Only set for HTTPS |
| Build fails | Missing dependency | Run `go mod tidy` |

## Serena Memory Reference

For detailed implementation patterns, read:

- `auth_provider_implementation` memory
