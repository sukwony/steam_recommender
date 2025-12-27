import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/wikidata_mapping.dart';

/// Service for querying Wikidata Steam AppID → HLTB ID mappings
///
/// Uses Wikidata's SPARQL endpoint to fetch mappings between:
/// - P1733 (Steam Application ID)
/// - P2816 (HowLongToBeat game ID)
///
/// Mappings are cached locally in Hive with a 30-day TTL to minimize
/// repeated queries. Null mappings are also cached to avoid re-querying
/// games that don't exist in Wikidata.
class WikidataService {
  final http.Client _client;
  late Box<WikidataMapping> _mappingsBox;

  static const _cacheTtlDays = 30;
  static const _wikidataEndpoint = 'https://query.wikidata.org/sparql';
  static const _userAgent = 'WNTP/1.0 (Steam Game Priority App)';

  WikidataService({http.Client? client})
      : _client = client ?? http.Client();

  /// Initialize the service by opening the Hive box
  Future<void> initialize() async {
    _mappingsBox = await Hive.openBox<WikidataMapping>('wikidata_mappings');
    debugPrint('[Wikidata] Initialized with ${_mappingsBox.length} cached mappings');
  }

  /// Get HLTB ID for a Steam AppID (with caching)
  ///
  /// Returns:
  /// - HLTB ID string if mapping exists in Wikidata
  /// - null if no mapping exists (cached to avoid re-querying)
  ///
  /// Throws:
  /// - Exception if network error or parsing fails (caller should handle)
  Future<String?> getHltbId(String steamAppId) async {
    // Check cache first
    final cached = _mappingsBox.get(steamAppId);
    if (cached != null && !_isStale(cached)) {
      if (cached.isNullMapping) {
        debugPrint('[Wikidata] Cache hit (null mapping): $steamAppId');
        return null;
      }
      debugPrint('[Wikidata] Cache hit: $steamAppId → ${cached.hltbId}');
      return cached.hltbId;
    }

    // Query Wikidata
    debugPrint('[Wikidata] Cache miss, querying for Steam AppID $steamAppId');
    final hltbId = await _queryWikidata(steamAppId);

    // Cache result (even if null)
    await _cacheMapping(steamAppId, hltbId);

    if (hltbId != null) {
      debugPrint('[Wikidata] Query result: $steamAppId → $hltbId');
    } else {
      debugPrint('[Wikidata] Query result: $steamAppId → no mapping');
    }

    return hltbId;
  }

  /// Query Wikidata SPARQL endpoint for Steam AppID → HLTB ID mapping
  Future<String?> _queryWikidata(String steamAppId) async {
    final query = '''
      SELECT ?hltbId WHERE {
        ?game wdt:P1733 "$steamAppId" .
        ?game wdt:P2816 ?hltbId .
      }
      LIMIT 1
    ''';

    try {
      final response = await _client.get(
        Uri.parse(_wikidataEndpoint).replace(queryParameters: {
          'query': query,
          'format': 'json',
        }),
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final bindings = json['results']?['bindings'] as List?;

        if (bindings != null && bindings.isNotEmpty) {
          final hltbId = bindings[0]['hltbId']?['value'] as String?;
          return hltbId;
        }
      } else {
        debugPrint('[Wikidata] HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[Wikidata] Query error: $e');
      rethrow; // Let caller handle network errors
    }

    return null; // No mapping found
  }

  /// Cache a mapping result (including null mappings)
  Future<void> _cacheMapping(String steamAppId, String? hltbId) async {
    await _mappingsBox.put(
      steamAppId,
      WikidataMapping(
        steamAppId: steamAppId,
        hltbId: hltbId,
        fetchedAt: DateTime.now(),
        isNullMapping: hltbId == null,
      ),
    );
  }

  /// Check if a cached mapping is stale (older than TTL)
  bool _isStale(WikidataMapping mapping) {
    final age = DateTime.now().difference(mapping.fetchedAt);
    return age.inDays > _cacheTtlDays;
  }

  /// Get the number of cached mappings
  int getCacheSize() => _mappingsBox.length;

  /// Clear all cached mappings
  Future<void> clearCache() async {
    await _mappingsBox.clear();
    debugPrint('[Wikidata] Cache cleared');
  }

  /// Close the Hive box
  Future<void> close() async {
    await _mappingsBox.close();
  }
}
