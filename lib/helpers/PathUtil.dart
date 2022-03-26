import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// アプリケーションのデータを格納するディレクトリを返す。
Future<Directory> getAppDataDir({bool createDir = false}) async {
  var dir = await getApplicationDocumentsDirectory();
  var appDir = Directory(path.join(dir.path, 'WallpaperChanger'));

  if (createDir && !appDir.existsSync()) {
    appDir.createSync(recursive: true);
  }

  return appDir;
}

/// Realmのファイルのパスを返す。
Future<String> getRealmPath() async {
  var appDir = await getAppDataDir(createDir: true);
  return path.join(appDir.path, "default.realm");
}