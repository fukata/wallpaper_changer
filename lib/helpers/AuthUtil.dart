import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:googleapis_auth/src/auth_http_utils.dart';
import 'package:http/http.dart' as http;
import 'package:wallpaper_changer/helpers/RealmUtil.dart';
import 'package:wallpaper_changer/models/User.dart';

/// googleapis の呼び出しに必要な AuthClient を User から生成する
AutoRefreshingAuthClient makeGoogleAuthClientFromUser(User user) {
  var accessToken =
      AccessToken('Bearer', user.accessToken, DateTime(2022, 1, 1).toUtc());
  var credentials =
      AccessCredentials(accessToken, user.refreshToken, user.scope.split(','));
  return AutoRefreshingClient(
      http.Client(),
      ClientId(
          dotenv.env["GOOGLE_CLIENT_ID"]!, dotenv.env["GOOGLE_CLIENT_SECRET"]!),
      credentials);
}

/// 最後に認証したユーザーを返す
User? getCurrentUser() {
  var users = realm().all<User>();
  if (users.isEmpty) {
    return null;
  } else {
    return users.first;
  }
}