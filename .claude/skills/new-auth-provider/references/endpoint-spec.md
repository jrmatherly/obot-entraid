# Auth Provider Endpoint Specification

Complete specification for all required auth provider endpoints.

## Endpoint Overview

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/{$}` | GET | Return daemon address |
| `/oauth2/start` | GET | Start OAuth2 authorization flow |
| `/oauth2/callback` | GET | Handle OAuth2 callback |
| `/oauth2/sign_out` | GET | Sign out user |
| `/obot-get-state` | POST | Get session state from headers |
| `/obot-get-user-info` | GET | Get user profile |
| `/obot-get-icon-url` | GET | Get profile picture |

---

## GET `/{$}`

Returns the daemon's address for health checks.

**Request:**

```
GET / HTTP/1.1
Host: localhost:9999
```

**Response:**

```
HTTP/1.1 200 OK
Content-Type: text/plain

http://localhost:9999
```

**Implementation:**

```go
func handleRoot(w http.ResponseWriter, r *http.Request) {
    addr := fmt.Sprintf("http://localhost:%s", os.Getenv("PORT"))
    w.Write([]byte(addr))
}
```

---

## GET `/oauth2/start`

Initiates the OAuth2 authorization code flow.

**Request:**

```
GET /oauth2/start?rd=https://obot.example.com/callback HTTP/1.1
Host: localhost:9999
```

**Parameters:**

- `rd` (required): Redirect URL after successful authentication

**Response:**

```
HTTP/1.1 302 Found
Location: https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=...&redirect_uri=...&scope=...&state=...
```

**Implementation:**

```go
func handleStart(w http.ResponseWriter, r *http.Request) {
    rd := r.URL.Query().Get("rd")
    if rd == "" {
        http.Error(w, "missing rd parameter", http.StatusBadRequest)
        return
    }
    // Store rd in state parameter
    state := encodeState(rd)
    authURL := oauth2Config.AuthCodeURL(state)
    http.Redirect(w, r, authURL, http.StatusFound)
}
```

---

## GET `/oauth2/callback`

Handles the OAuth2 callback, exchanges code for tokens, sets cookie.

**Request:**

```
GET /oauth2/callback?code=abc123&state=xyz789 HTTP/1.1
Host: localhost:9999
```

**Parameters:**

- `code`: Authorization code from IdP
- `state`: State parameter (contains `rd` URL)

**Response:**

```
HTTP/1.1 302 Found
Set-Cookie: obot_access_token=<encrypted>; Path=/; HttpOnly; SameSite=Lax
Location: https://obot.example.com/callback
```

**Implementation:**

```go
func handleCallback(w http.ResponseWriter, r *http.Request) {
    code := r.URL.Query().Get("code")
    state := r.URL.Query().Get("state")

    // Exchange code for tokens
    token, err := oauth2Config.Exchange(r.Context(), code)
    if err != nil {
        http.Error(w, "token exchange failed", http.StatusInternalServerError)
        return
    }

    // Encrypt and set cookie
    encrypted := encryptToken(token.AccessToken)
    http.SetCookie(w, &http.Cookie{
        Name:     "obot_access_token",
        Value:    encrypted,
        Path:     "/",
        HttpOnly: true,
        Secure:   isHTTPS(),
        SameSite: http.SameSiteLaxMode,
    })

    // Redirect to original destination
    rd := decodeState(state)
    http.Redirect(w, r, rd, http.StatusFound)
}
```

---

## GET `/oauth2/sign_out`

Clears the authentication cookie.

**Request:**

```
GET /oauth2/sign_out?rd=https://obot.example.com/ HTTP/1.1
Host: localhost:9999
Cookie: obot_access_token=<encrypted>
```

**Response:**

```
HTTP/1.1 302 Found
Set-Cookie: obot_access_token=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT
Location: https://obot.example.com/
```

**Implementation:**

```go
func handleSignOut(w http.ResponseWriter, r *http.Request) {
    http.SetCookie(w, &http.Cookie{
        Name:    "obot_access_token",
        Value:   "",
        Path:    "/",
        MaxAge:  -1,
        Expires: time.Unix(0, 0),
    })

    rd := r.URL.Query().Get("rd")
    if rd == "" {
        rd = "/"
    }
    http.Redirect(w, r, rd, http.StatusFound)
}
```

---

## POST `/obot-get-state`

Returns session state from request headers. Called by Obot gateway.

**Request:**

```
POST /obot-get-state HTTP/1.1
Content-Type: application/json

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

**Response (error):**

```
HTTP/1.1 400 Bad Request
Content-Type: text/plain

invalid or missing cookie
```

**Implementation:**

```go
func handleGetState(w http.ResponseWriter, r *http.Request) {
    var req struct {
        Header map[string][]string `json:"header"`
    }
    json.NewDecoder(r.Body).Decode(&req)

    // Extract cookie from headers
    cookies := req.Header["Cookie"]
    token := extractToken(cookies)
    if token == "" {
        http.Error(w, "invalid or missing cookie", http.StatusBadRequest)
        return
    }

    // Decrypt token
    accessToken, err := decryptToken(token)
    if err != nil {
        http.Error(w, "invalid cookie", http.StatusBadRequest)
        return
    }

    // Parse claims (from JWT or fetch from userinfo)
    claims := parseClaims(accessToken)

    json.NewEncoder(w).Encode(map[string]string{
        "accessToken":       accessToken,
        "preferredUsername": claims.PreferredUsername,
        "user":              claims.Username,
        "email":             claims.Email,
    })
}
```

---

## GET `/obot-get-user-info`

Returns detailed user profile. Called with Bearer token.

**Request:**

```
GET /obot-get-user-info HTTP/1.1
Authorization: Bearer eyJ...
```

**Response:**

```json
{
  "name": "John Doe",
  "email": "johndoe@example.com",
  "preferred_username": "johndoe",
  "icon_url": "data:image/jpeg;base64,/9j/4AAQ..."
}
```

**Critical:** `icon_url` MUST be a base64 data URL, not an external API URL.

**Implementation:**

```go
func handleGetUserInfo(w http.ResponseWriter, r *http.Request) {
    token := extractBearerToken(r)
    if token == "" {
        http.Error(w, "unauthorized", http.StatusUnauthorized)
        return
    }

    // Fetch user info from provider
    userInfo, err := fetchUserInfo(r.Context(), token)
    if err != nil {
        http.Error(w, "failed to fetch user info", http.StatusInternalServerError)
        return
    }

    // Map provider fields to obot fields
    result := map[string]any{
        "email":              userInfo.Email,
        "preferred_username": userInfo.PreferredUsername,
    }

    // Map displayName to name (CRITICAL)
    if userInfo.DisplayName != "" {
        result["name"] = userInfo.DisplayName
    }

    // Fetch and encode profile picture (CRITICAL)
    iconURL, err := fetchIconAsDataURL(r.Context(), token)
    if err == nil && iconURL != "" {
        result["icon_url"] = iconURL
    }

    json.NewEncoder(w).Encode(result)
}
```

---

## GET `/obot-get-icon-url`

Returns user profile picture as base64 data URL.

**Request:**

```
GET /obot-get-icon-url HTTP/1.1
Authorization: Bearer eyJ...
```

**Response:**

```
HTTP/1.1 200 OK
Content-Type: text/plain

data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD...
```

**Implementation:**

```go
func handleGetIconURL(w http.ResponseWriter, r *http.Request) {
    token := extractBearerToken(r)
    if token == "" {
        http.Error(w, "unauthorized", http.StatusUnauthorized)
        return
    }

    // Fetch photo from provider API
    photoURL := getPhotoEndpoint() // e.g., Graph API, People API
    req, _ := http.NewRequestWithContext(r.Context(), "GET", photoURL, nil)
    req.Header.Set("Authorization", "Bearer "+token)

    resp, err := http.DefaultClient.Do(req)
    if err != nil || resp.StatusCode != http.StatusOK {
        // Return empty or default avatar
        w.WriteHeader(http.StatusNoContent)
        return
    }
    defer resp.Body.Close()

    imageData, _ := io.ReadAll(resp.Body)
    contentType := resp.Header.Get("Content-Type")
    if contentType == "" {
        contentType = "image/jpeg"
    }

    dataURL := fmt.Sprintf("data:%s;base64,%s",
        contentType,
        base64.StdEncoding.EncodeToString(imageData))

    w.Header().Set("Content-Type", "text/plain")
    w.Write([]byte(dataURL))
}
```

---

## Cookie Encryption

Use AES-GCM encryption for the access token cookie.

```go
func encryptToken(token string) string {
    secret := os.Getenv("OBOT_AUTH_PROVIDER_COOKIE_SECRET")
    key, _ := base64.StdEncoding.DecodeString(secret)

    block, _ := aes.NewCipher(key)
    gcm, _ := cipher.NewGCM(block)

    nonce := make([]byte, gcm.NonceSize())
    io.ReadFull(rand.Reader, nonce)

    encrypted := gcm.Seal(nonce, nonce, []byte(token), nil)
    return base64.StdEncoding.EncodeToString(encrypted)
}

func decryptToken(encrypted string) (string, error) {
    secret := os.Getenv("OBOT_AUTH_PROVIDER_COOKIE_SECRET")
    key, _ := base64.StdEncoding.DecodeString(secret)

    data, _ := base64.StdEncoding.DecodeString(encrypted)

    block, _ := aes.NewCipher(key)
    gcm, _ := cipher.NewGCM(block)

    nonceSize := gcm.NonceSize()
    nonce, ciphertext := data[:nonceSize], data[nonceSize:]

    plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
    return string(plaintext), err
}
```

---

## Error Handling

| Status | When | Response |
|--------|------|----------|
| 400 | Missing parameters, invalid cookie | Plain text error |
| 401 | Invalid/missing Bearer token | `unauthorized` |
| 500 | Provider API error, encryption error | Generic error |
| 302 | Successful auth/signout | Redirect |
