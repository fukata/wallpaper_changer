// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'User.dart';

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
  set id(String value) => throw RealmUnsupportedSetError();

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
      SchemaProperty('id', RealmPropertyType.string, primaryKey: true),
      SchemaProperty('name', RealmPropertyType.string),
      SchemaProperty('pictureUrl', RealmPropertyType.string),
      SchemaProperty('accessToken', RealmPropertyType.string),
      SchemaProperty('refreshToken', RealmPropertyType.string),
      SchemaProperty('idToken', RealmPropertyType.string),
      SchemaProperty('scope', RealmPropertyType.string),
    ]);
  }
}
