import 'dart:developer';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/oauth2/v2.dart';
import 'package:googleapis/photoslibrary/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:win32/win32.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData.dark(),
      home: const MyHomePage(title: 'Wallpaper Changer'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  /// 現在の壁紙のファイルパス
  // TODO: ユーザーが画像を選択できるようにする
  String wallpaperFilePath = path.join(
      "C:", "Users", "tatsu", "Desktop", "wallpaper_changer_sample.jpg");

  /// 壁紙を変更するボタンが押された時の処理。
  void _handleChangeWallpaper() {
    var file = File(wallpaperFilePath);
    if (!file.existsSync()) {
      // ファイルが存在しない
      log("画像が存在しない。 filePath=$wallpaperFilePath");
      return;
    }

    log("壁紙を変更する。 filePath=$wallpaperFilePath");

    final hr = CoInitializeEx(
        nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
    if (FAILED(hr)) {
      throw WindowsException(hr);
    }

    var desktopWallpaper = DesktopWallpaper.createInstance();
    Pointer<Utf16> wallpaperFilePathPtr = wallpaperFilePath.toNativeUtf16();
    try {
      int result = FALSE;

      // モニタの数を取得する
      Pointer<Uint32> monitorDevicePathCountPtr = calloc<Uint32>();
      result =
          desktopWallpaper.GetMonitorDevicePathCount(monitorDevicePathCountPtr);
      if (result != S_OK) {
        free(monitorDevicePathCountPtr);
        throw WindowsException(result);
      }
      log("result=$result, monitorDevicePathCountPtr.value=${monitorDevicePathCountPtr.value}");

      // すべてのモニタに壁紙を設定する
      for (var i = 0; i < monitorDevicePathCountPtr.value; i++) {
        Pointer<Pointer<Utf16>> monitorIdPtr = calloc<Pointer<Utf16>>();
        result = desktopWallpaper.GetMonitorDevicePathAt(i, monitorIdPtr);
        if (result != S_OK) {
          free(monitorIdPtr);
          throw WindowsException(result);
        }
        log("result=$result, monitorIdPtr=${monitorIdPtr}");

        log("change wallpaper. i=$i");
        result = desktopWallpaper.SetWallpaper(
            monitorIdPtr.value, wallpaperFilePathPtr);
        if (result != S_OK) {
          free(monitorIdPtr);
          throw WindowsException(result);
        }

        free(monitorIdPtr);
      }

      free(monitorDevicePathCountPtr);
    } finally {
      free(wallpaperFilePathPtr);
      free(desktopWallpaper.ptr);
      CoUninitialize();
    }
  }

  /// Google Photos と OAuthを行う
  void _handleGooglePhotosAuth() async {
    AuthClient client = await _obtainCredentials();
    log("credentials=${client.credentials.toJson()}");

    var oauth2Api = Oauth2Api(client);
    var userInfo = await oauth2Api.userinfo.v2.me.get();
    log("profile. id=${userInfo.id}, username=${userInfo.name}");

    _loadGooglePhotos(client);
  }

  Future<AuthClient> _obtainCredentials() async {
    String clientId = dotenv.env["GOOGLE_CLIENT_ID"]!;
    String clientSecret = dotenv.env["GOOGLE_CLIENT_SECRET"]!;
    return await clientViaUserConsent(
      ClientId(clientId, clientSecret),
      [
        'https://www.googleapis.com/auth/userinfo.profile',
        'https://www.googleapis.com/auth/photoslibrary.readonly',
      ],
      (String url) {
        log("url=$url");
        launch(url);
      },
    );
  }

  /// Google Photos から写真を読み込む
  void _loadGooglePhotos(AuthClient client) async {
    var photosApi = PhotosLibraryApi(client);
    SearchMediaItemsRequest request = SearchMediaItemsRequest(
      filters: Filters(mediaTypeFilter: MediaTypeFilter(mediaTypes: ['PHOTO'])),
      orderBy: 'MediaMetadata.creation_time desc',
      pageSize: 50,
    );
    var response = await photosApi.mediaItems.search(request);
    if (response.mediaItems != null) {
      for(var mediaItem in response.mediaItems!) {
        log("mediaItem=${mediaItem.toJson()}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(wallpaperFilePath),
            TextButton(
              onPressed: _handleChangeWallpaper,
              child: const Text("Change Wallpaper"),
            ),
            TextButton(
              onPressed: _handleGooglePhotosAuth,
              child: const Text("Connect to Google Photos"),
            ),
          ],
        ),
      ),
    );
  }
}
