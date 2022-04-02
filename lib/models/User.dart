import 'package:realm/realm.dart';
part 'User.g.dart';

@RealmModel()
class _User {
  @PrimaryKey()
  late String id;

  late String name;
  late String pictureUrl;

  // OAuth関連
  late String accessToken;
  late String refreshToken;
  late String idToken;
  late String scope;

  /// パーミッションが正しいか返す
  ///
  /// パーミッション一覧
  /// https://www.googleapis.com/auth/photoslibrary.readonly
  /// https://www.googleapis.com/auth/userinfo.profile
  bool isValidPermission() {
    return scope.split(",").contains("https://www.googleapis.com/auth/photoslibrary.readonly");
  }

  bool isInvalidPermission() {
    return !isValidPermission();
  }
}