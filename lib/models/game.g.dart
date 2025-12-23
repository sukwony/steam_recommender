// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GameAdapter extends TypeAdapter<Game> {
  @override
  final int typeId = 0;

  @override
  Game read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Game(
      id: fields[0] as String,
      name: fields[1] as String,
      headerImageUrl: fields[2] as String?,
      steamRating: fields[3] as double,
      steamReviewCount: fields[4] as int,
      metacriticScore: fields[5] as double?,
      hltbMainHours: fields[6] as double?,
      hltbExtraHours: fields[7] as double?,
      hltbCompletionistHours: fields[8] as double?,
      playtimeMinutes: fields[9] as int,
      lastPlayed: fields[10] as DateTime?,
      genres: (fields[11] as List).cast<String>(),
      isCompleted: fields[12] as bool,
      userProgress: fields[13] as double?,
      addedAt: fields[14] as DateTime,
      lastSynced: fields[15] as DateTime?,
      isHidden: fields[16] as bool,
      notes: fields[17] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Game obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.headerImageUrl)
      ..writeByte(3)
      ..write(obj.steamRating)
      ..writeByte(4)
      ..write(obj.steamReviewCount)
      ..writeByte(5)
      ..write(obj.metacriticScore)
      ..writeByte(6)
      ..write(obj.hltbMainHours)
      ..writeByte(7)
      ..write(obj.hltbExtraHours)
      ..writeByte(8)
      ..write(obj.hltbCompletionistHours)
      ..writeByte(9)
      ..write(obj.playtimeMinutes)
      ..writeByte(10)
      ..write(obj.lastPlayed)
      ..writeByte(11)
      ..write(obj.genres)
      ..writeByte(12)
      ..write(obj.isCompleted)
      ..writeByte(13)
      ..write(obj.userProgress)
      ..writeByte(14)
      ..write(obj.addedAt)
      ..writeByte(15)
      ..write(obj.lastSynced)
      ..writeByte(16)
      ..write(obj.isHidden)
      ..writeByte(17)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
