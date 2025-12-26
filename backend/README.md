# WNTP Backend

Vercel serverless backend for WNTP (What Next To Play) Flutter app.

Handles Steam OAuth authentication and proxies authenticated Steam API calls.

## Features

- **Steam OpenID 2.0 Authentication**: Secure user authentication via Steam
- **JWT Session Management**: Stateless session tokens with 30-day expiry
- **Minimal API Surface**: Only 2 endpoints (authentication required APIs only)

**Note:** Public Steam APIs (appdetails, appreviews) are called directly from Flutter client for better performance and lower costs.

## API Endpoints

### Authentication

#### `GET /api/auth/steam-callback`
Handles OpenID callback from Steam. Creates JWT session token and redirects to app.

**Flow:**
1. Flutter app opens Steam OpenID login URL (generated client-side)
2. User authenticates with Steam
3. Steam redirects to this endpoint with OpenID response
4. Backend verifies OpenID response
5. Backend creates JWT token
6. Backend redirects to `wntp://auth/success?token=<jwt>&steamId=<id>`

**Query Parameters:** OpenID response parameters from Steam

**Redirects to:** `wntp://auth/success?token=<jwt>&steamId=<id>`

### Games API

#### `GET /api/games/owned`
Proxies Steam `GetOwnedGames` API (requires authentication).

**Headers:**
- `Authorization: Bearer <jwt_token>`

**Response:** Steam GetOwnedGames API response (user's game library with playtime)

## Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Environment Variables

Set these in Vercel dashboard (Settings > Environment Variables):

- `STEAM_API_KEY`: Your Steam Web API key from https://steamcommunity.com/dev/apikey
- `JWT_SECRET`: Random secret key for JWT signing (generate with `openssl rand -base64 32`)
- `APP_CALLBACK_SCHEME`: `wntp://auth/success` (already set in vercel.json)

### 3. Local Development

```bash
# Install Vercel CLI
npm install -g vercel

# Link to your Vercel project (first time only)
vercel link

# Pull environment variables from Vercel
vercel env pull

# Run local dev server
vercel dev
```

The server will run on `http://localhost:3000`.

### 4. Deploy to Vercel

```bash
# Deploy to preview environment
vercel

# Deploy to production
vercel --prod
```

## Project Structure

```
backend/
├── api/
│   ├── auth/
│   │   └── steam-callback.ts   # Handle OpenID callback + JWT creation
│   ├── games/
│   │   └── owned.ts            # Proxy GetOwnedGames (authenticated)
│   └── utils/
│       ├── session.ts          # JWT token management
│       └── openid.ts           # OpenID 2.0 verification
├── package.json
├── tsconfig.json
└── vercel.json                 # Vercel configuration
```

**Why so minimal?**
- Steam OpenID URL is generated client-side (standard format, never changes)
- Public APIs (appdetails, appreviews) are called directly from Flutter (faster, cheaper)
- Only authenticated APIs need backend proxy

## Security

### Production Checklist

- ✅ API key stored server-side (never exposed to client)
- ✅ JWT tokens for stateless sessions
- ✅ Steam ID verified via OpenID
- ⚠️ OpenID signature verification (simplified - enhance for production)
- ⚠️ CORS configuration (currently allows all origins)
- ⚠️ Rate limiting (consider adding Vercel rate limiting)

### Recommendations for Production

1. **Enable CORS restrictions** in `vercel.json`:
   ```json
   {
     "headers": [
       {
         "source": "/api/(.*)",
         "headers": [
           { "key": "Access-Control-Allow-Origin", "value": "wntp://*" }
         ]
       }
     ]
   }
   ```

2. **Add rate limiting** using Vercel Edge Config or external service

3. **Implement full OpenID signature verification** in `api/utils/openid.ts`

4. **Add logging and monitoring** (Vercel Analytics, Sentry, etc.)

## License

Part of the WNTP project.
