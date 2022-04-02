// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'MediaItem.dart';

// **************************************************************************
// RealmObjectGenerator
// **************************************************************************

class MediaItem extends _MediaItem with RealmEntity, RealmObject {
  MediaItem(
    String id,
    String filename,
    String mimeType,
    int width,
    int height,
    int creationTimestamp,
    bool cached,
  ) {
    RealmObject.set(this, 'id', id);
    RealmObject.set(this, 'filename', filename);
    RealmObject.set(this, 'mimeType', mimeType);
    RealmObject.set(this, 'width', width);
    RealmObject.set(this, 'height', height);
    RealmObject.set(this, 'creationTimestamp', creationTimestamp);
    RealmObject.set(this, 'cached', cached);
  }

  MediaItem._();

  @override
  String get id => RealmObject.get<String>(this, 'id') as String;
  @override
  set id(String value) => throw RealmUnsupportedSetError();

  @override
  String get filename => RealmObject.get<String>(this, 'filename') as String;
  @override
  set filename(String value) => RealmObject.set(this, 'filename', value);

  @override
  String get mimeType => RealmObject.get<String>(this, 'mimeType') as String;
  @override
  set mimeType(String value) => RealmObject.set(this, 'mimeType', value);

  @override
  int get width => RealmObject.get<int>(this, 'width') as int;
  @override
  set width(int value) => RealmObject.set(this, 'width', value);

  @override
  int get height => RealmObject.get<int>(this, 'height') as int;
  @override
  set height(int value) => RealmObject.set(this, 'height', value);

  @override
  int get creationTimestamp =>
      RealmObject.get<int>(this, 'creationTimestamp') as int;
  @override
  set creationTimestamp(int value) =>
      RealmObject.set(this, 'creationTimestamp', value);

  @override
  bool get cached => RealmObject.get<bool>(this, 'cached') as bool;
  @override
  set cached(bool value) => RealmObject.set(this, 'cached', value);

  @override
  Stream<RealmObjectChanges<MediaItem>> get changes =>
      RealmObject.getChanges<MediaItem>(this);

  static SchemaObject get schema => _schema ??= _initSchema();
  static SchemaObject? _schema;
  static SchemaObject _initSchema() {
    RealmObject.registerFactory(MediaItem._);
    return const SchemaObject(MediaItem, [
      SchemaProperty('id', RealmPropertyType.string, primaryKey: true),
      SchemaProperty('filename', RealmPropertyType.string),
      SchemaProperty('mimeType', RealmPropertyType.string),
      SchemaProperty('width', RealmPropertyType.int),
      SchemaProperty('height', RealmPropertyType.int),
      SchemaProperty('creationTimestamp', RealmPropertyType.int),
      SchemaProperty('cached', RealmPropertyType.bool),
    ]);
  }
}
