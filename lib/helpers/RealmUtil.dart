import 'package:realm/realm.dart';
import 'package:wallpaper_changer/helpers/PathUtil.dart';
import 'package:wallpaper_changer/models/Album.dart';
import 'package:wallpaper_changer/models/MediaItem.dart';
import 'package:wallpaper_changer/models/User.dart';

/// Realmのインスタンスをシングルトンで提供するためのクラス
class RealmProvider {
  static final RealmProvider _singleton = RealmProvider._internal();

  late final Realm _realm;

  factory RealmProvider() {
    return _singleton;
  }

  RealmProvider._internal();

  Future<void> init() async {
    var realmConfig = Configuration([User.schema, MediaItem.schema, Album.schema]);
    realmConfig.path = await getRealmPath();
    realmConfig.schemaVersion = 6;
    _realm = Realm(realmConfig);
  }

  Realm realm() {
    return _realm;
  }
}

/// Realmのセットアップ
Future<void> initRealm() async {
  await RealmProvider().init();
}

/// 簡単にアクセスするためのメソッド
Realm realm() {
  return RealmProvider().realm();
}