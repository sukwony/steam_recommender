import { VercelRequest, VercelResponse } from '@vercel/node';
import { verifyOpenIdResponse } from '../utils/openid';
import { createSessionToken } from '../utils/session';

/**
 * GET /api/auth/steam-callback
 *
 * Handles the OpenID callback from Steam
 * Verifies the response, creates a JWT session token, and redirects to the app
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // Extract OpenID parameters from query
    const openIdParams: Record<string, string> = {};
    for (const [key, value] of Object.entries(req.query)) {
      if (typeof value === 'string') {
        openIdParams[key] = value;
      } else if (Array.isArray(value) && value.length > 0) {
        openIdParams[key] = value[0];
      }
    }

    // Verify OpenID response
    const steamId = await verifyOpenIdResponse(openIdParams);

    console.log('[steam-callback] Steam ID:', steamId);

    if (!steamId) {
      return res.status(401).send(`
        <html>
          <body>
            <h1>Authentication Failed</h1>
            <p>Could not verify your Steam identity. Please try again.</p>
            <script>
              setTimeout(() => {
                window.location.href = 'com.wntp://auth/error?message=verification_failed';
              }, 2000);
            </script>
          </body>
        </html>
      `);
    }

    // Create JWT session token
    const token = createSessionToken(steamId);

    // Redirect to app with token
    const redirectUrl = `com.wntp://auth/success?token=${encodeURIComponent(token)}&steamId=${steamId}`;

    // Auto-redirect to app
    return res.status(200).send(`
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Redirecting...</title>
          <style>
            body { font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto; text-align: center; }
            .success { color: green; }
          </style>
        </head>
        <body>
          <h1 class="success">✓ Authentication Successful!</h1>
          <p>Redirecting to WNTP app...</p>

          <script>
            // Auto-redirect immediately
            window.location.assign('${redirectUrl}');
          </script>
        </body>
      </html>
    `);
  } catch (error) {
    console.error('Error in Steam callback:', error);
    return res.status(500).send(`
      <html>
        <body>
          <h1>Error</h1>
          <p>An error occurred during authentication. Please try again.</p>
          <script>
            setTimeout(() => {
              window.location.href = 'com.wntp://auth/error?message=server_error';
            }, 2000);
          </script>
        </body>
      </html>
    `);
  }
}
