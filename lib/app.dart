import 'package:realm/realm.dart';
part 'app.g.dart';

@RealmModel()
class _User {
  late String id;
  late String name;
  late String pictureUrl;

  // OAuth関連
  late String accessToken;
  late String refreshToken;
  late String idToken;
  late String scope;
}

@RealmModel()
class _Album {
  late String id;
  late String title;
  late String mediaItemsCount;
}

@RealmModel()
class _MediaItem {
  late String id;
  late String filename;
  late String mimeType;
  late int width;
  late int height;
  late int creationTimestamp;
  late bool cached;
}