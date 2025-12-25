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

    if (!steamId) {
      return res.status(401).send(`
        <html>
          <body>
            <h1>Authentication Failed</h1>
            <p>Could not verify your Steam identity. Please try again.</p>
            <script>
              setTimeout(() => {
                window.location.href = 'wntp://auth/error?message=verification_failed';
              }, 2000);
            </script>
          </body>
        </html>
      `);
    }

    // Create JWT session token
    const token = createSessionToken(steamId);

    // Get app callback scheme from environment
    const callbackScheme = process.env.APP_CALLBACK_SCHEME || 'wntp://auth/success';

    // Redirect to app with token
    const redirectUrl = `${callbackScheme}?token=${encodeURIComponent(token)}&steamId=${steamId}`;

    return res.status(200).send(`
      <html>
        <head>
          <title>Authentication Successful</title>
          <meta http-equiv="refresh" content="0;url=${redirectUrl}">
        </head>
        <body>
          <h1>Authentication Successful!</h1>
          <p>Redirecting back to WNTP...</p>
          <p>Steam ID: ${steamId}</p>
          <script>
            // Try immediate redirect
            window.location.href = '${redirectUrl}';

            // Fallback: Show manual link if redirect doesn't work
            setTimeout(() => {
              document.body.innerHTML += '<p><a href="${redirectUrl}">Click here if you are not redirected automatically</a></p>';
            }, 2000);
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
              window.location.href = 'wntp://auth/error?message=server_error';
            }, 2000);
          </script>
        </body>
      </html>
    `);
  }
}
