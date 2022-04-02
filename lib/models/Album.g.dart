// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Album.dart';

// **************************************************************************
// RealmObjectGenerator
// **************************************************************************

class Album extends _Album with RealmEntity, RealmObject {
  Album(
    String id,
    String title,
    String mediaItemsCount,
  ) {
    RealmObject.set(this, 'id', id);
    RealmObject.set(this, 'title', title);
    RealmObject.set(this, 'mediaItemsCount', mediaItemsCount);
  }

  Album._();

  @override
  String get id => RealmObject.get<String>(this, 'id') as String;
  @override
  set id(String value) => throw RealmUnsupportedSetError();

  @override
  String get title => RealmObject.get<String>(this, 'title') as String;
  @override
  set title(String value) => RealmObject.set(this, 'title', value);

  @override
  String get mediaItemsCount =>
      RealmObject.get<String>(this, 'mediaItemsCount') as String;
  @override
  set mediaItemsCount(String value) =>
      RealmObject.set(this, 'mediaItemsCount', value);

  @override
  Stream<RealmObjectChanges<Album>> get changes =>
      RealmObject.getChanges<Album>(this);

  static SchemaObject get schema => _schema ??= _initSchema();
  static SchemaObject? _schema;
  static SchemaObject _initSchema() {
    RealmObject.registerFactory(Album._);
    return const SchemaObject(Album, [
      SchemaProperty('id', RealmPropertyType.string, primaryKey: true),
      SchemaProperty('title', RealmPropertyType.string),
      SchemaProperty('mediaItemsCount', RealmPropertyType.string),
    ]);
  }
}
