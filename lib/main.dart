import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wallpaper_changer/helpers/RealmUtil.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'HomePage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dot env
  await dotenv.load(fileName: '.env');

  // 自動起動
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  LaunchAtStartup.instance.setup(
    appName: packageInfo.appName,
    appPath: Platform.resolvedExecutable,
  );

  // Realmのセットアップ
  initRealm();

  // アプリ実行
  runApp(const MyApp());

  // ウィンドウサイズと初回起動時の位置を設定する
  doWhenWindowReady(() {
    final win = appWindow;
    const initialSize = Size(500, 800);
    win.minSize = initialSize;
    win.size = initialSize;
    win.alignment = Alignment.center;
    win.title = "Wallpaper Changer";
    win.show();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallpaper Changer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData.dark(),
      home: const HomePage(title: 'Wallpaper Changer'),
    );
  }
}
