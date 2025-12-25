# WNTP Backend

Backend API for What Next To Play - Steam OAuth proxy and API gateway.

## Features

- **Steam OpenID 2.0 Authentication**: Secure user authentication via Steam
- **JWT Session Management**: Stateless session tokens with 30-day expiry
- **Steam API Proxy**: Secure proxy for Steam Web API calls
  - GetOwnedGames (authenticated)
  - App Details (public)
  - App Reviews (public)

## API Endpoints

### Authentication

#### `GET /api/auth/steam-login`
Returns Steam OpenID authentication URL.

**Response:**
```json
{
  "authUrl": "https://steamcommunity.com/openid/login?...",
  "message": "Redirect user to this URL to authenticate with Steam"
}
```

#### `GET /api/auth/steam-callback`
Handles OpenID callback from Steam. Creates JWT session token and redirects to app.

**Query Parameters:** OpenID response parameters from Steam

**Redirects to:** `wntp://auth/success?token=<jwt>&steamId=<id>`

### Games API

#### `GET /api/games/owned`
Get user's owned games from Steam.

**Headers:**
- `Authorization: Bearer <jwt_token>`

**Response:** Steam GetOwnedGames API response

#### `GET /api/games/details?appId=<appId>`
Get detailed game information.

**Query Parameters:**
- `appId` (required): Steam App ID

**Response:** Steam appdetails API response

#### `GET /api/games/reviews?appId=<appId>`
Get game review statistics.

**Query Parameters:**
- `appId` (required): Steam App ID

**Response:** Steam appreviews API response

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
│   │   ├── steam-login.ts      # Generate Steam OpenID URL
│   │   └── steam-callback.ts   # Handle OpenID callback
│   ├── games/
│   │   ├── owned.ts            # Proxy GetOwnedGames
│   │   ├── details.ts          # Proxy appdetails
│   │   └── reviews.ts          # Proxy appreviews
│   └── utils/
│       ├── session.ts          # JWT token management
│       └── openid.ts           # OpenID 2.0 verification
├── package.json
├── tsconfig.json
└── vercel.json                 # Vercel configuration
```

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
