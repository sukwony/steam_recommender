import 'package:hive/hive.dart';

part 'wikidata_mapping.g.dart';

/// Hive model for caching Steam AppID → HLTB ID mappings from Wikidata
///
/// Wikidata provides curated mappings between Steam AppID (P1733) and
/// HLTB game ID (P2816) for ~40k games. This cache stores these mappings
/// locally to avoid repeated SPARQL queries.
///
/// Cache TTL: 30 days (configurable in WikidataService)
@HiveType(typeId: 2)
class WikidataMapping extends HiveObject {
  /// Steam App ID (e.g., "400" for Portal)
  @HiveField(0)
  String steamAppId;

  /// HLTB game ID (e.g., "7230" for Portal)
  /// Null if Wikidata has no mapping for this Steam AppID
  @HiveField(1)
  String? hltbId;

  /// Timestamp when this mapping was fetched from Wikidata
  /// Used for cache invalidation (30-day TTL)
  @HiveField(2)
  DateTime fetchedAt;

  /// True if Wikidata explicitly has NO mapping for this Steam AppID
  /// Prevents repeated queries for games that aren't in Wikidata
  @HiveField(3)
  bool isNullMapping;

  WikidataMapping({
    required this.steamAppId,
    this.hltbId,
    required this.fetchedAt,
    this.isNullMapping = false,
  });
}
