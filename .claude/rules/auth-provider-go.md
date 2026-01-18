---
globs: tools/*-auth-provider/**/*.go, tools/auth-providers-common/**/*.go
description: Go conventions for obot auth providers
---

# Auth Provider Go Conventions

## Field Mapping (CRITICAL)

Obot expects specific field names. Map provider fields:

| Provider Field | Obot Field | Notes |
| -------------- | ---------- | ----- |
| `displayName` | `name` | Must map explicitly |
| Graph API URL | `icon_url` | Must be base64 data URL |
| `mail` | `email` | Direct mapping |

```go
// Map displayName to "name" for obot compatibility
if displayName, ok := result["displayName"].(string); ok {
    result["name"] = displayName
}

// icon_url must be base64 data URL (NOT external API URL)
iconURL, err := profile.FetchUserIconURL(ctx, accessToken)
if iconURL != "" {
    result["icon_url"] = iconURL  // data:image/jpeg;base64,...
}
```

## Profile Pictures

**NEVER** return external API URLs that require authentication. Fetch server-side, return base64:

```go
func FetchUserIconURL(ctx context.Context, accessToken string) (string, error) {
    resp, err := graphClient.Do(req) // with Bearer token
    imageData, _ := io.ReadAll(resp.Body)
    return fmt.Sprintf("data:%s;base64,%s",
        resp.Header.Get("Content-Type"),
        base64.StdEncoding.EncodeToString(imageData)), nil
}
```

## Linting

Uses golangci-lint v2.4.0: errcheck, govet, revive, staticcheck, unused, whitespace.

## Modern Go

- Use `map[string]any` not `map[string]interface{}`
- Always check and handle errors
- Use context.Context for cancellation

## Required Endpoints

| Endpoint | Method | Purpose |
| -------- | ------ | ------- |
| `/{$}` | GET | Return daemon address |
| `/oauth2/start` | GET | Start OAuth2 flow |
| `/oauth2/callback` | GET | Handle callback, set cookie |
| `/oauth2/sign_out` | GET | Clear cookie |
| `/obot-get-state` | POST | Return user session |
| `/obot-get-user-info` | GET | Return user profile |
| `/obot-get-icon-url` | GET | Return profile picture |

## Token Cookie

- Name: `obot_access_token`
- Encryption: `OBOT_AUTH_PROVIDER_COOKIE_SECRET`
- Secure flag: Only if HTTPS

## Testing

```bash
go build -o /dev/null .
go mod tidy
go run .
curl http://localhost:9999/
curl -H "Authorization: Bearer <token>" http://localhost:9999/obot-get-user-info
```
