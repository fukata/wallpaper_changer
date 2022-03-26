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

  void init() {
    var realmConfig = Configuration([User.schema, MediaItem.schema]);
    realmConfig.schemaVersion = 3;
    _realm = Realm(realmConfig);
  }

  Realm realm() {
    return _realm;
  }
}

/// Realmのセットアップ
void initRealm() {
  RealmProvider().init();
}

/// 簡単にアクセスするためのメソッド
Realm realm() {
  return RealmProvider().realm();
}