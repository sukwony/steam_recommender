import '../models/hltb_game_data.dart';

/// Utility class for HLTB web scraping
/// Contains JavaScript generation and response parsing for WebView
class HltbScraper {
  /// Generate JavaScript to check if search results have loaded
  /// Returns a boolean indicating if game cards are present on the page
  static String checkResultsLoaded() {
    return '''
      (function() {
        const cards = document.querySelectorAll('li[class*="search_list"]');
        return cards.length > 0;
      })();
    ''';
  }

  /// Generate JavaScript to extract game data from first search result
  /// Returns JSON string with game data or null if not found
  ///
  /// DOM Structure (discovered via Playwright):
  /// - Game cards: li[class*="search_list"]
  /// - Game link: a.text_blue (href: /game/{id})
  /// - Details container: div[class*="search_list_details"]
  /// - Text format: "Game Name Main Story8½ HoursMain + Extra14½ HoursCompletionist39 Hours"
  static String extractGameData() {
    return r'''
      (function() {
        try {
          var firstCard = document.querySelector('li[class*="search_list"]');
          if (!firstCard) {
            return JSON.stringify({debug: 'no_card'});
          }

          var detailsDiv = firstCard.querySelector('div[class*="search_list_details"]');
          if (!detailsDiv) {
            return JSON.stringify({debug: 'no_details_div'});
          }

          var titleLink = null;
          var gameLinks = firstCard.querySelectorAll('a[href^="/game/"]');
          for (var i = 0; i < gameLinks.length; i++) {
            if (gameLinks[i].textContent.trim().length > 0) {
              titleLink = gameLinks[i];
              break;
            }
          }

          if (!titleLink) {
            return JSON.stringify({debug: 'no_title_link', linkCount: gameLinks.length});
          }

          var text = detailsDiv.textContent.trim();
          var nameMatch = text.match(/^(.+?)\s+Main Story/);
          var name = nameMatch ? nameMatch[1].trim() : null;

          if (!name) {
            return JSON.stringify({debug: 'no_name', text: text.substring(0, 100)});
          }

          var mainMatch = text.match(/Main Story\s*([\d½]+|--)/);
          var extraMatch = text.match(/Main \+ Extra\s*([\d½]+|--)/);
          var compMatch = text.match(/Completionist\s*([\d½]+|--)/);

          var parseHours = function(str) {
            if (!str || str === '--') return null;
            return parseFloat(str.replace('½', '.5'));
          };

          var href = titleLink.getAttribute('href');
          var gameId = href ? href.replace('/game/', '') : '';

          var result = {
            game_id: gameId,
            game_name: name,
            comp_main: parseHours(mainMatch && mainMatch[1]),
            comp_plus: parseHours(extraMatch && extraMatch[1]),
            comp_100: parseHours(compMatch && compMatch[1])
          };

          return JSON.stringify(result);
        } catch (e) {
          return JSON.stringify({error: e.toString()});
        }
      })();
    ''';
  }

  /// Parse JavaScript response string into HltbGameData
  /// Returns null if parsing fails or no data found
  static HltbGameData? parseResponse(String? jsResult) {
    if (jsResult == null || jsResult == 'null') return null;

    try {
      // Remove quotes if the result is a quoted string
      final jsonString = jsResult.trim();
      if (jsonString.isEmpty) return null;

      // The JavaScript returns a JSON string, so we need to parse it
      final data = _parseJson(jsonString);
      if (data == null) return null;

      // Check if JavaScript returned debug info or error
      if (data.containsKey('error') || data.containsKey('debug')) {
        return null;
      }

      final gameId = data['game_id'] as String?;
      final gameName = data['game_name'] as String?;
      final compMain = data['comp_main'] as num?;
      final compPlus = data['comp_plus'] as num?;
      final comp100 = data['comp_100'] as num?;

      if (gameName == null) return null;

      return HltbGameData(
        id: gameId ?? '',
        name: gameName,
        mainHours: compMain?.toDouble(),
        mainExtraHours: compPlus?.toDouble(),
        completionistHours: comp100?.toDouble(),
        imageUrl: null, // Not extracted from search results
      );
    } catch (e) {
      return null;
    }
  }

  /// Simple JSON parser (avoids dart:convert import for minimal dependencies)
  static Map<String, dynamic>? _parseJson(String jsonString) {
    try {
      // Use dart:convert for proper JSON parsing
      final json = _simpleJsonDecode(jsonString);
      return json is Map ? Map<String, dynamic>.from(json) : null;
    } catch (e) {
      return null;
    }
  }

  /// Minimal JSON decoder for the specific format we expect
  /// This is a simplified version that handles our specific data structure
  static dynamic _simpleJsonDecode(String str) {
    // For our use case, we'll just use a regex-based parser
    // This handles the format: {"game_id":"123","game_name":"Name",...}

    if (str.trim() == 'null') return null;

    final Map<String, dynamic> result = {};

    // Extract string values
    final stringPattern = RegExp(r'"(\w+)":"([^"]*)"');
    for (final match in stringPattern.allMatches(str)) {
      result[match.group(1)!] = match.group(2);
    }

    // Extract numeric values (including null)
    final numPattern = RegExp(r'"(\w+)":(null|[\d.]+)');
    for (final match in numPattern.allMatches(str)) {
      final value = match.group(2)!;
      result[match.group(1)!] = value == 'null' ? null : num.parse(value);
    }

    return result.isEmpty ? null : result;
  }
}
