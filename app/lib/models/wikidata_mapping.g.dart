// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wikidata_mapping.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WikidataMappingAdapter extends TypeAdapter<WikidataMapping> {
  @override
  final int typeId = 2;

  @override
  WikidataMapping read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WikidataMapping(
      steamAppId: fields[0] as String,
      hltbId: fields[1] as String?,
      fetchedAt: fields[2] as DateTime,
      isNullMapping: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, WikidataMapping obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.steamAppId)
      ..writeByte(1)
      ..write(obj.hltbId)
      ..writeByte(2)
      ..write(obj.fetchedAt)
      ..writeByte(3)
      ..write(obj.isNullMapping);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WikidataMappingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
