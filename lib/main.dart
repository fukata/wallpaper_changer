import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:wallpaper_changer/helpers/RealmUtil.dart';

import 'pages/HomePage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dot env
  await dotenv.load(fileName: '.env');

  await SentryFlutter.init(
    (options) {
      options.dsn = dotenv.env["SENTRY_DSN"];
    },
    appRunner: () async {
      // Realmのセットアップ
      await initRealm();

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
  );
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
