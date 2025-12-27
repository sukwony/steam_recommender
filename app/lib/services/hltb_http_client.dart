import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/hltb_game_data.dart';

/// HTTP client for direct HLTB API access
/// Bypasses WebView by calling search API directly with proper authentication
class HltbHttpClient {
  final http.Client _client;
  String? _authToken; // Cached auth token
  DateTime? _tokenExpiry; // Token expiry time (estimate)

  HltbHttpClient() : _client = http.Client();

  /// Initialize auth token by calling /api/search/init
  /// Token is required for all search API calls
  Future<String?> _getAuthToken() async {
    // Return cached token if still valid (estimate 5 minutes lifetime)
    if (_authToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      debugPrint('[HltbHttp] 🔑 Using cached auth token');
      return _authToken;
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = 'https://howlongtobeat.com/api/search/init?t=$timestamp';

      debugPrint('[HltbHttp] 🔑 Fetching auth token...');

      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': 'https://howlongtobeat.com/',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final token = jsonData['token'] as String?;

        if (token != null && token.isNotEmpty) {
          _authToken = token;
          _tokenExpiry = DateTime.now().add(const Duration(minutes: 5));
          debugPrint('[HltbHttp] ✅ Got auth token');
          return token;
        }
      }

      debugPrint('[HltbHttp] ❌ Failed to get auth token: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[HltbHttp] ❌ Auth token error: $e');
      return null;
    }
  }

  /// Search for games using HLTB API
  /// Returns list of matching games (usually first result is most relevant)
  Future<List<HltbGameData>> searchGames(String gameName) async {
    if (gameName.isEmpty) {
      debugPrint('[HltbHttp] ❌ Empty game name');
      return [];
    }

    try {
      // Get auth token first
      final token = await _getAuthToken();
      if (token == null) {
        debugPrint('[HltbHttp] ❌ No auth token available');
        return [];
      }

      // Build search request body (matching captured API format)
      // IMPORTANT: searchTerms must be an array of words, not a single string
      // Also normalize the name: replace colons with spaces (HLTB uses spaces instead of colons)
      final normalizedName = gameName
          .replaceAll(':', ' ')  // "F.E.A.R.: Extraction" → "F.E.A.R. Extraction"
          .replaceAll(RegExp(r'\s+'), ' ')  // Normalize multiple spaces
          .trim();

      final searchBody = {
        'searchType': 'games',
        'searchTerms': normalizedName.split(' ').where((s) => s.isNotEmpty).toList(),
        'searchPage': 1,
        'size': 20,
        'searchOptions': {
          'games': {
            'userId': 0,
            'platform': '',
            'sortCategory': 'popular',
            'rangeCategory': 'main',
            'rangeTime': {'min': null, 'max': null},
            'gameplay': {
              'perspective': '',
              'flow': '',
              'genre': '',
              'difficulty': ''
            },
            'rangeYear': {'min': '', 'max': ''},
            'modifier': ''
          },
          'users': {'sortCategory': 'postcount'},
          'lists': {'sortCategory': 'follows'},
          'filter': '',
          'sort': 0,
          'randomizer': 0
        },
        'useCache': true
      };

      debugPrint('[HltbHttp] 🔍 Searching for "$gameName" (normalized: "$normalizedName")...');

      final response = await _client.post(
        Uri.parse('https://howlongtobeat.com/api/search'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Content-Type': 'application/json',
          'Referer': 'https://howlongtobeat.com/?q=${Uri.encodeComponent(gameName)}',
          'x-auth-token': token,
        },
        body: json.encode(searchBody),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final dataList = jsonData['data'] as List<dynamic>?;

        if (dataList == null || dataList.isEmpty) {
          debugPrint('[HltbHttp] ⚠️ No results for "$gameName"');
          return [];
        }

        debugPrint('[HltbHttp] ✅ Found ${dataList.length} results for "$gameName"');

        // Parse all results
        final results = <HltbGameData>[];
        for (final item in dataList) {
          final gameData = _parseSearchResult(item as Map<String, dynamic>);
          if (gameData != null) {
            results.add(gameData);
          }
        }

        return results;
      } else if (response.statusCode == 401) {
        // Unauthorized - clear token and retry once
        debugPrint('[HltbHttp] ⚠️ Unauthorized (401) - clearing token');
        _authToken = null;
        _tokenExpiry = null;
        return [];
      } else {
        debugPrint('[HltbHttp] ❌ Search failed: ${response.statusCode} - ${response.body}');
        return [];
      }
    } on TimeoutException {
      debugPrint('[HltbHttp] ⏱️ Search timeout');
      return [];
    } catch (e) {
      debugPrint('[HltbHttp] ❌ Search error: $e');
      return [];
    }
  }

  /// Fetch game data directly by HLTB game ID
  /// More reliable than search when ID is known (from Wikidata or previous search)
  ///
  /// Returns HltbGameData if successful, null if fetch/parse fails
  Future<HltbGameData?> fetchByGameId(String hltbId) async {
    try {
      debugPrint('[HltbHttp] 🎯 Fetching game data by ID: $hltbId');

      // Step 1: Fetch game page HTML
      final html = await fetchGamePage(hltbId);
      if (html == null) {
        debugPrint('[HltbHttp] ❌ Failed to fetch page for ID: $hltbId');
        return null;
      }

      // Step 2: Extract JSON from __NEXT_DATA__ script tag
      final jsonData = extractJsonFromHtml(html);
      if (jsonData == null) {
        debugPrint('[HltbHttp] ❌ Failed to extract JSON for ID: $hltbId');
        return null;
      }

      // Step 3: Parse game data from JSON
      final gameData = parseGameData(jsonData);
      if (gameData == null) {
        debugPrint('[HltbHttp] ❌ Failed to parse game data for ID: $hltbId');
        return null;
      }

      debugPrint('[HltbHttp] ✅ Fetched by ID: ${gameData.name}');
      return gameData;
    } catch (e) {
      debugPrint('[HltbHttp] ❌ Error fetching by ID $hltbId: $e');
      return null;
    }
  }

  /// Parse search result item into HltbGameData
  HltbGameData? _parseSearchResult(Map<String, dynamic> item) {
    try {
      final gameId = item['game_id']?.toString() ?? '';
      final gameName = item['game_name']?.toString() ?? '';

      if (gameId.isEmpty || gameName.isEmpty) {
        return null;
      }

      // Parse times (in seconds)
      final compMain = _parseTimeInSeconds(item['comp_main']);
      final compPlus = _parseTimeInSeconds(item['comp_plus']);
      final comp100 = _parseTimeInSeconds(item['comp_100']);

      // Extract image URL
      final gameImage = item['game_image']?.toString();

      return HltbGameData(
        id: gameId,
        name: gameName,
        mainHours: compMain,
        mainExtraHours: compPlus,
        completionistHours: comp100,
        imageUrl: gameImage,
      );
    } catch (e) {
      debugPrint('[HltbHttp] ❌ Parse search result error: $e');
      return null;
    }
  }

  /// Fetch game page HTML from https://howlongtobeat.com/game/{gameId}
  Future<String?> fetchGamePage(String gameId) async {
    if (gameId.isEmpty) {
      debugPrint('[HltbHttp] ❌ Empty game ID');
      return null;
    }

    final url = 'https://howlongtobeat.com/game/$gameId';

    try {
      debugPrint('[HltbHttp] 🌐 Fetching: $url');

      final response = await _client
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
              'Accept-Language': 'en-US,en;q=0.9',
              'Accept-Encoding': 'gzip, deflate, br',
              'Sec-Fetch-Dest': 'document',
              'Sec-Fetch-Mode': 'navigate',
              'Sec-Fetch-Site': 'none',
              'Sec-Fetch-User': '?1',
              'Upgrade-Insecure-Requests': '1',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('[HltbHttp] ✅ Fetched ${response.body.length} bytes');
        return response.body;
      } else {
        debugPrint(
            '[HltbHttp] ❌ HTTP ${response.statusCode}: ${response.reasonPhrase}');
        return null;
      }
    } on TimeoutException {
      debugPrint('[HltbHttp] ⏱️ Timeout after 10s');
      return null;
    } catch (e) {
      debugPrint('[HltbHttp] ❌ Error: $e');
      return null;
    }
  }

  /// Extract JSON from <script id="__NEXT_DATA__"> tag
  /// Next.js embeds page data as server-rendered JSON in this script tag
  Map<String, dynamic>? extractJsonFromHtml(String html) {
    try {
      // Find <script id="__NEXT_DATA__" type="application/json">...</script>
      final regex = RegExp(
        r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>',
        dotAll: true,
      );

      final match = regex.firstMatch(html);
      if (match == null) {
        debugPrint('[HltbHttp] ❌ No __NEXT_DATA__ script found');
        return null;
      }

      final jsonString = match.group(1);
      if (jsonString == null || jsonString.isEmpty) {
        debugPrint('[HltbHttp] ❌ Empty __NEXT_DATA__ content');
        return null;
      }

      // Parse JSON
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      debugPrint('[HltbHttp] ✅ Extracted JSON with keys: ${jsonData.keys}');

      return jsonData;
    } catch (e) {
      debugPrint('[HltbHttp] ❌ JSON extraction error: $e');
      return null;
    }
  }

  /// Parse HltbGameData from Next.js JSON structure
  /// Actual structure: {"props":{"pageProps":{"game":{"data":{"game":[{...}]}}}}}
  HltbGameData? parseGameData(Map<String, dynamic> json) {
    try {
      // Navigate through Next.js structure: props → pageProps → game → data → game (array)
      final props = json['props'] as Map<String, dynamic>?;
      if (props == null) {
        debugPrint('[HltbHttp] ❌ No "props" key');
        return null;
      }

      final pageProps = props['pageProps'] as Map<String, dynamic>?;
      if (pageProps == null) {
        debugPrint('[HltbHttp] ❌ No "pageProps" key');
        return null;
      }

      final game = pageProps['game'] as Map<String, dynamic>?;
      if (game == null) {
        debugPrint('[HltbHttp] ❌ No "game" key');
        return null;
      }

      final data = game['data'] as Map<String, dynamic>?;
      if (data == null) {
        debugPrint('[HltbHttp] ❌ No "data" key');
        return null;
      }

      // Game data is an array - get first element
      final gameArray = data['game'] as List<dynamic>?;
      if (gameArray == null || gameArray.isEmpty) {
        debugPrint('[HltbHttp] ❌ No "game" array or empty array');
        return null;
      }

      final gameObject = gameArray[0] as Map<String, dynamic>;

      // Extract game fields
      final gameId = gameObject['game_id']?.toString() ?? '';
      final gameName = gameObject['game_name']?.toString() ?? '';

      if (gameId.isEmpty || gameName.isEmpty) {
        debugPrint(
            '[HltbHttp] ❌ Missing game_id or game_name (id: "$gameId", name: "$gameName")');
        return null;
      }

      // Parse completion times - times are in SECONDS, convert to hours
      final compMain = _parseTimeInSeconds(gameObject['comp_main']);
      final compPlus = _parseTimeInSeconds(gameObject['comp_plus']);
      final comp100 = _parseTimeInSeconds(gameObject['comp_100']);

      // Extract image URL
      final gameImage = gameObject['game_image']?.toString();

      final gameData = HltbGameData(
        id: gameId,
        name: gameName,
        mainHours: compMain,
        mainExtraHours: compPlus,
        completionistHours: comp100,
        imageUrl: gameImage,
      );

      debugPrint(
          '[HltbHttp] ✅ Parsed: $gameName (${compMain}h / ${compPlus}h / ${comp100}h)');

      return gameData;
    } catch (e) {
      debugPrint('[HltbHttp] ❌ Parse error: $e');
      return null;
    }
  }

  /// Parse time value in seconds and convert to hours
  /// HLTB stores times in seconds - we convert to hours for consistency
  double? _parseTimeInSeconds(dynamic value) {
    if (value == null) return null;

    // Try parsing as number (seconds)
    if (value is num) {
      final seconds = value.toDouble();

      // Return null for 0 or negative values
      if (seconds <= 0) return null;

      // Convert seconds to hours
      return seconds / 3600;
    }

    // Try parsing string
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null && parsed > 0) {
        return parsed / 3600;
      }
    }

    return null;
  }

  /// Clean up HTTP client
  void dispose() {
    _client.close();
    debugPrint('[HltbHttp] 🔌 Client disposed');
  }
}
