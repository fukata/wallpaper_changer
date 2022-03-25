import 'package:realm/realm.dart';
import 'package:wallpaper_changer/app.dart';

/// Realmのインスタンスをシングルトンで提供するためのクラス
class RealmProvider {
  static final RealmProvider _singleton = RealmProvider._internal();

  late final Realm _realm;

  factory RealmProvider() {
    return _singleton;
  }

  RealmProvider._internal();

  /// Realmのセットアップ
  void init() {
    var realmConfig = Configuration([User.schema, MediaItem.schema]);
    realmConfig.schemaVersion = 1;
    _realm = Realm(realmConfig);
  }

  Realm realm() {
    return _realm;
  }
}

/// 簡単にアクセスするためのメソッド
Realm realm() {
  return RealmProvider().realm();
}