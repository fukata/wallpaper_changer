import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wallpaper_changer/helpers/RealmUtil.dart';
import 'package:wallpaper_changer/pages/HomePage.dart';

void main() {
  setUp(() async {
    WidgetsFlutterBinding.ensureInitialized();

    var tempDir = await getTemporaryDirectory();
    var testEnv = {
      'GOOGLE_CLIENT_ID': 'dummy',
      'GOOGLE_CLIENT_SECRET': 'dummy',
      'SENTRY_DSN': 'dummy',
      'APP_DATA_DIR': tempDir.path,
    };
    dotenv.testLoad(mergeWith: testEnv);
    await initRealm();
  });

  testWidgets("Show login button if not logined", (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HomePage(title: "My first widget test"),
    ));

    final loginTextFinder = find.text("Google Photosに接続する");

    expect(loginTextFinder, findsOneWidget);
  });
}