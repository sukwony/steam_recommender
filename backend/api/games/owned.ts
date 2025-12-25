import { VercelRequest, VercelResponse } from '@vercel/node';
import { extractBearerToken, verifySessionToken } from '../utils/session';

/**
 * GET /api/games/owned
 *
 * Proxies the Steam GetOwnedGames API call
 * Requires: Authorization header with JWT token
 * Returns: User's owned games from Steam
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // Extract and verify JWT token
    const token = extractBearerToken(req.headers.authorization);
    if (!token) {
      return res.status(401).json({ error: 'No authorization token provided' });
    }

    const session = verifySessionToken(token);
    if (!session) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }

    // Get Steam API key from environment
    const steamApiKey = process.env.STEAM_API_KEY;
    if (!steamApiKey) {
      console.error('STEAM_API_KEY not configured');
      return res.status(500).json({ error: 'Server configuration error' });
    }

    // Call Steam API
    const steamUrl = new URL('https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/');
    steamUrl.searchParams.set('key', steamApiKey);
    steamUrl.searchParams.set('steamid', session.steamId);
    steamUrl.searchParams.set('include_appinfo', '1');
    steamUrl.searchParams.set('include_played_free_games', '1');
    steamUrl.searchParams.set('format', 'json');

    const response = await fetch(steamUrl.toString());

    if (!response.ok) {
      console.error('Steam API error:', response.status, response.statusText);
      return res.status(response.status).json({
        error: 'Steam API request failed',
        details: response.statusText
      });
    }

    const data = await response.json();

    // Return the Steam API response
    return res.status(200).json(data);
  } catch (error) {
    console.error('Error fetching owned games:', error);
    return res.status(500).json({
      error: 'Failed to fetch owned games'
    });
  }
}
