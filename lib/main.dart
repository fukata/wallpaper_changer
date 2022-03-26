import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:wallpaper_changer/helpers/RealmProvider.dart';
import 'package:wallpaper_changer/app.dart' as app;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:realm/realm.dart';

import 'HomePage.dart';

late Realm realm;

void main() async {
  // Dot env
  await dotenv.load(fileName: '.env');

  WidgetsFlutterBinding.ensureInitialized();

  // Realmのセットアップ
  RealmProvider().init();

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
