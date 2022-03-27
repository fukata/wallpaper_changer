// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app.dart';

// **************************************************************************
// RealmObjectGenerator
// **************************************************************************

class User extends _User with RealmEntity, RealmObject {
  User(
    String id,
    String name,
    String pictureUrl,
    String accessToken,
    String refreshToken,
    String idToken,
    String scope,
  ) {
    RealmObject.set(this, 'id', id);
    RealmObject.set(this, 'name', name);
    RealmObject.set(this, 'pictureUrl', pictureUrl);
    RealmObject.set(this, 'accessToken', accessToken);
    RealmObject.set(this, 'refreshToken', refreshToken);
    RealmObject.set(this, 'idToken', idToken);
    RealmObject.set(this, 'scope', scope);
  }

  User._();

  @override
  String get id => RealmObject.get<String>(this, 'id') as String;
  @override
  set id(String value) => RealmObject.set(this, 'id', value);

  @override
  String get name => RealmObject.get<String>(this, 'name') as String;
  @override
  set name(String value) => RealmObject.set(this, 'name', value);

  @override
  String get pictureUrl =>
      RealmObject.get<String>(this, 'pictureUrl') as String;
  @override
  set pictureUrl(String value) => RealmObject.set(this, 'pictureUrl', value);

  @override
  String get accessToken =>
      RealmObject.get<String>(this, 'accessToken') as String;
  @override
  set accessToken(String value) => RealmObject.set(this, 'accessToken', value);

  @override
  String get refreshToken =>
      RealmObject.get<String>(this, 'refreshToken') as String;
  @override
  set refreshToken(String value) =>
      RealmObject.set(this, 'refreshToken', value);

  @override
  String get idToken => RealmObject.get<String>(this, 'idToken') as String;
  @override
  set idToken(String value) => RealmObject.set(this, 'idToken', value);

  @override
  String get scope => RealmObject.get<String>(this, 'scope') as String;
  @override
  set scope(String value) => RealmObject.set(this, 'scope', value);

  @override
  Stream<RealmObjectChanges<User>> get changes =>
      RealmObject.getChanges<User>(this);

  static SchemaObject get schema => _schema ??= _initSchema();
  static SchemaObject? _schema;
  static SchemaObject _initSchema() {
    RealmObject.registerFactory(User._);
    return const SchemaObject(User, [
      SchemaProperty('id', RealmPropertyType.string),
      SchemaProperty('name', RealmPropertyType.string),
      SchemaProperty('pictureUrl', RealmPropertyType.string),
      SchemaProperty('accessToken', RealmPropertyType.string),
      SchemaProperty('refreshToken', RealmPropertyType.string),
      SchemaProperty('idToken', RealmPropertyType.string),
      SchemaProperty('scope', RealmPropertyType.string),
    ]);
  }
}

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
  set id(String value) => RealmObject.set(this, 'id', value);

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
      SchemaProperty('id', RealmPropertyType.string),
      SchemaProperty('filename', RealmPropertyType.string),
      SchemaProperty('mimeType', RealmPropertyType.string),
      SchemaProperty('width', RealmPropertyType.int),
      SchemaProperty('height', RealmPropertyType.int),
      SchemaProperty('creationTimestamp', RealmPropertyType.int),
      SchemaProperty('cached', RealmPropertyType.bool),
    ]);
  }
}
