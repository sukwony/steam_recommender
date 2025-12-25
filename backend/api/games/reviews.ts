import { VercelRequest, VercelResponse } from '@vercel/node';

/**
 * GET /api/games/reviews?appId=<appId>
 *
 * Proxies the Steam appreviews API call
 * No authentication required (public API)
 * Returns: Game review statistics and ratings
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { appId } = req.query;

    if (!appId || typeof appId !== 'string') {
      return res.status(400).json({ error: 'appId parameter is required' });
    }

    // Call Steam Store API for reviews
    const steamUrl = `https://store.steampowered.com/appreviews/${appId}?json=1&language=all&purchase_type=all`;
    const response = await fetch(steamUrl);

    if (!response.ok) {
      console.error('Steam reviews API error:', response.status, response.statusText);
      return res.status(response.status).json({
        error: 'Steam reviews API request failed',
        details: response.statusText
      });
    }

    const data = await response.json();

    // Return the Steam API response
    return res.status(200).json(data);
  } catch (error) {
    console.error('Error fetching game reviews:', error);
    return res.status(500).json({
      error: 'Failed to fetch game reviews'
    });
  }
}
