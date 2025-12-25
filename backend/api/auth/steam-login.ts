import { VercelRequest, VercelResponse } from '@vercel/node';
import { buildAuthUrl } from '../utils/openid';

/**
 * GET /api/auth/steam-login
 *
 * Returns the Steam OpenID authentication URL for the client to redirect to
 */
export default function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // Build callback URL - this is where Steam will redirect after auth
    const baseUrl = process.env.VERCEL_URL
      ? `https://${process.env.VERCEL_URL}`
      : 'http://localhost:3000';

    const callbackUrl = `${baseUrl}/api/auth/steam-callback`;
    const realm = baseUrl;

    // Generate OpenID auth URL
    const authUrl = buildAuthUrl(callbackUrl, realm);

    return res.status(200).json({
      authUrl,
      message: 'Redirect user to this URL to authenticate with Steam'
    });
  } catch (error) {
    console.error('Error generating auth URL:', error);
    return res.status(500).json({
      error: 'Failed to generate authentication URL'
    });
  }
}
