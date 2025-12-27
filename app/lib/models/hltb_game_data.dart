/// Data model for HowLongToBeat game information
class HltbGameData {
  final String id;
  final String name;
  final double? mainHours;
  final double? mainExtraHours;
  final double? completionistHours;
  final String? imageUrl;

  HltbGameData({
    required this.id,
    required this.name,
    this.mainHours,
    this.mainExtraHours,
    this.completionistHours,
    this.imageUrl,
  });
}
