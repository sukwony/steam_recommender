// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'priority_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PrioritySettingsAdapter extends TypeAdapter<PrioritySettings> {
  @override
  final int typeId = 1;

  @override
  PrioritySettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrioritySettings(
      steamRatingWeight: fields[0] as double,
      hltbTimeWeight: fields[1] as double,
      lastPlayedWeight: fields[2] as double,
      progressWeight: fields[3] as double,
      metacriticWeight: fields[4] as double,
      genreWeight: fields[5] as double,
      preferredGenres: (fields[6] as List).cast<String>(),
      hltbType: fields[7] as int,
      maxHltbHours: fields[8] as double,
      includeNoHltbGames: fields[9] as bool,
      showCompletedGames: fields[10] as bool,
      showHiddenGames: fields[11] as bool,
      steamId: fields[12] as String?,
      steamApiKey: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PrioritySettings obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.steamRatingWeight)
      ..writeByte(1)
      ..write(obj.hltbTimeWeight)
      ..writeByte(2)
      ..write(obj.lastPlayedWeight)
      ..writeByte(3)
      ..write(obj.progressWeight)
      ..writeByte(4)
      ..write(obj.metacriticWeight)
      ..writeByte(5)
      ..write(obj.genreWeight)
      ..writeByte(6)
      ..write(obj.preferredGenres)
      ..writeByte(7)
      ..write(obj.hltbType)
      ..writeByte(8)
      ..write(obj.maxHltbHours)
      ..writeByte(9)
      ..write(obj.includeNoHltbGames)
      ..writeByte(10)
      ..write(obj.showCompletedGames)
      ..writeByte(11)
      ..write(obj.showHiddenGames)
      ..writeByte(12)
      ..write(obj.steamId)
      ..writeByte(13)
      ..write(obj.steamApiKey);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrioritySettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
