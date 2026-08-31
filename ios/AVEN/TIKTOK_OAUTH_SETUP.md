# TikTok OAuth Setup for AVEN

## What works now (no external accounts needed)
- TikTok connect button opens the `TikTokConnectSheet`
- If `AVEN_API_URL` is not set → `.unconfigured` state with clear message
- All error states surface descriptive German messages
- Correct architecture: no secrets in iOS app

---

## To enable live TikTok login (step by step)

### Step 1: Register TikTok Developer App
1. Go to https://developers.tiktok.com → Create App
2. Product: **Login Kit** (apply and wait for approval — 1–4 weeks)
3. Note your **Client Key** (public) and **Client Secret** (private, server-only)
4. Add redirect URI: `https://api.avengrowth.app/auth/tiktok/callback`
   - Must be HTTPS — TikTok does not allow localhost redirect URIs
   - You need a public domain with a valid SSL certificate

### Step 2: Configure the backend
```bash
export TIKTOK_CLIENT_KEY="your_client_key"
export TIKTOK_CLIENT_SECRET="your_client_secret"
export TIKTOK_REDIRECT_URI="https://api.avengrowth.app/auth/tiktok/callback"
```

### Step 3: Register URL scheme in Xcode
1. Open AVEN target → **Info** tab → **URL Types** → click **+**
2. URL Schemes: `avengrowth`
3. Identifier: `com.aven.app`

This enables `avengrowth://auth/tiktok/complete?...` deep links.

### Step 4: Configure the iOS app
In Xcode: **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**

| Name | Value |
|------|-------|
| `AVEN_API_URL` | `http://localhost:3000` (local) or `https://api.avengrowth.app` (staging) |

### Step 5: Start the backend
```bash
cd packages/backend
TIKTOK_CLIENT_KEY=xxx TIKTOK_CLIENT_SECRET=yyy node dist/server.js
```

### Step 6: Test in Simulator
1. Run the AVEN app in Xcode Simulator
2. Tab → Profil → TikTok → Mit TikTok verbinden
3. TikTok login opens in a secure browser session
4. After login, the backend exchanges the code and redirects to `avengrowth://...`
5. The app receives the result and shows "Verbunden"

---

## How the flow works technically

```
iOS ASWebAuthenticationSession opens:
  https://www.tiktok.com/v2/auth/authorize/?...&redirect_uri=BACKEND_URL&state=CSRF_TOKEN

User logs in on TikTok →
  TikTok redirects to: https://api.avengrowth.app/auth/tiktok/callback?code=XXX&state=YYY

Backend:
  1. Validates state token (CSRF check)
  2. Retrieves PKCE verifier stored in memory
  3. Exchanges code for access token (never leaves backend)
  4. Fetches user identity from TikTok API
  5. Links account in database
  6. Redirects to: avengrowth://auth/tiktok/complete?success=true&...

ASWebAuthenticationSession intercepts avengrowth:// →
  iOS parseCallback() → .connected(username:, accountId:)
```

## Security properties
- ✅ Client secret never touches iOS
- ✅ Access tokens never leave backend
- ✅ PKCE prevents code interception
- ✅ State token prevents CSRF
- ✅ `avengrowth://` deep link can only be intercepted by the registered app

---

## Common errors

| Error | Cause | Fix |
|-------|-------|-----|
| `.unconfigured` | `AVEN_API_URL` not set | Set in Xcode scheme env vars |
| "Backend nicht erreichbar" | Backend not running | Start with `node dist/server.js` |
| "Backend antwortete mit Status 401" | Auth token invalid | Use a real session token |
| "Ungültige Auth-URL vom Backend" | `TIKTOK_CLIENT_KEY` not set | Set backend env var |
| `invalid_state` | PKCE state expired (>10 min) | Retry immediately |
| Session opens then closes | URL scheme `avengrowth` not registered | Add to Xcode → Info → URL Types |
