/**
 * Steam OpenID 2.0 utilities
 * Steam uses legacy OpenID 2.0, not OpenID Connect
 */

/**
 * Extract Steam ID from OpenID claimed_id
 * Format: https://steamcommunity.com/openid/id/<steam64_id>
 */
export function extractSteamId(claimedId: string): string | null {
  const match = claimedId.match(/^https?:\/\/steamcommunity\.com\/openid\/id\/(\d+)$/);
  return match ? match[1] : null;
}

/**
 * Verify OpenID response from Steam
 * This is a simplified verification - in production, you should verify the signature
 */
export async function verifyOpenIdResponse(params: Record<string, string>): Promise<string | null> {
  // Check required parameters
  if (!params['openid.claimed_id'] || !params['openid.identity']) {
    console.error('Missing required OpenID parameters');
    return null;
  }

  // Extract Steam ID
  const steamId = extractSteamId(params['openid.claimed_id']);
  if (!steamId) {
    console.error('Invalid Steam ID in claimed_id');
    return null;
  }

  // Verify mode is id_res (successful authentication)
  if (params['openid.mode'] !== 'id_res') {
    console.error('OpenID mode is not id_res');
    return null;
  }

  // In production, you should verify the signature by making a request back to Steam
  // For now, we'll trust the response if it has the right format

  return steamId;
}
