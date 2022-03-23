import 'dart:developer';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;

import 'package:desktop_window/desktop_window.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/oauth2/v2.dart';
import 'package:googleapis/photoslibrary/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wallpaper_changer/app.dart' as app;
import 'package:win32/win32.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:realm/realm.dart';
import 'package:googleapis_auth/src/auth_http_utils.dart';
import 'package:http/http.dart' as http;

late Realm realm;

void main() async {
  await dotenv.load(fileName: '.env');
  var realmConfig = Configuration([app.User.schema, app.MediaItem.schema]);
  realmConfig.schemaVersion = 1;
  realm = Realm(realmConfig);

  DesktopWindow.setWindowSize(const Size(500, 700));
  DesktopWindow.setMaxWindowSize(const Size(500, 700));
  DesktopWindow.setMinWindowSize(const Size(500, 700));

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
  String _wallpaperFilePath = "";

  app.User? _currentUser;
  int _mediaItemCount = 0;

  /// 画像データを取得する
  void _handleSync() async {
    var client = _makeAuthClientFromUser(_currentUser!);
    await _loadGooglePhotos(client);
    setState(() {
      _mediaItemCount = realm.all<app.MediaItem>().length;
    });
  }

  void _setWallpaper(String filePath) async {
    var file = File(filePath);
    if (!file.existsSync()) {
      // ファイルが存在しない
      log("画像が存在しない。 filePath=$filePath");
      return;
    }

    log("壁紙を変更する。 filePath=$filePath");

    final hr = CoInitializeEx(
        nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
    if (FAILED(hr)) {
      throw WindowsException(hr);
    }

    var desktopWallpaper = DesktopWallpaper.createInstance();
    Pointer<Utf16> wallpaperFilePathPtr = filePath.toNativeUtf16();
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

    var user = _registerUser(client.credentials, userInfo);
    setState(() {
      _currentUser = user;
    });

    await _loadGooglePhotos(client);
    setState(() {
      _mediaItemCount = realm.all<app.MediaItem>().length;
    });
  }

  /// 最後に認証したユーザーを返す
  app.User? _getCurrentUser() {
    var users = realm.all<app.User>();
    if (users.isEmpty) {
      return null;
    } else {
      return users.first;
    }
  }

  app.User _registerUser(AccessCredentials credentials, Userinfo userInfo) {
    var users = realm.query<app.User>(r'id == $0', [userInfo.id!]);
    late app.User user;
    if (users.isNotEmpty) {
      user = users.first;
      realm.write(() {
        user.id = userInfo.id!;
        user.name = userInfo.name!;
        user.pictureUrl = userInfo.picture!;
        user.accessToken = credentials.accessToken.data;
        user.refreshToken = credentials.refreshToken!;
        user.idToken = credentials.idToken!;
        user.scope = credentials.scopes.join(',');
      });
    } else {
      user = app.User(
        userInfo.id!,
        userInfo.name!,
        userInfo.picture!,
        credentials.accessToken.data,
        credentials.refreshToken!,
        credentials.idToken!,
        credentials.scopes.join(','),
      );
      realm.write(() {
        realm.deleteAll<app.User>();
        realm.deleteAll<app.MediaItem>();
        realm.add(user);
      });
    }

    return user;
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
  Future _loadGooglePhotos(AuthClient client) async {
    var photosApi = PhotosLibraryApi(client);
    SearchMediaItemsRequest request = SearchMediaItemsRequest(
      filters: Filters(mediaTypeFilter: MediaTypeFilter(mediaTypes: ['PHOTO'])),
      orderBy: 'MediaMetadata.creation_time desc',
      pageSize: 100,
    );
    var response = await photosApi.mediaItems.search(request);
    if (response.mediaItems != null) {
      for (var mediaItem in response.mediaItems!) {
        log("mediaItem=${mediaItem.toJson()}");
        _registerMediaItem(mediaItem);
      }
    }
  }

  /// 画像データを登録する
  app.MediaItem _registerMediaItem(MediaItem mediaItem) {
    var mediaItems = realm.query<app.MediaItem>(r'id == $0', [mediaItem.id!]);
    if (mediaItems.isNotEmpty) {
      return mediaItems.first;
    }

    var newMediaItem =
        app.MediaItem(mediaItem.id!, mediaItem.filename!, mediaItem.mimeType!);
    realm.write(() {
      realm.add(newMediaItem);
    });

    return newMediaItem;
  }

  /// MediaItem の中からランダムに画像を選定して壁紙に設定する
  void _handleChangeRandomWallpaper() async {
    var mediaItems = realm.all<app.MediaItem>();
    var total = mediaItems.length;
    log("MediaItem total is $total");
    if (total == 0) {
      return;
    }

    var idx = math.Random.secure().nextInt(total);
    var mediaItem = mediaItems.elementAt(idx);

    var filePath = await _savedMediaItemFilePath(mediaItem);
    _setWallpaper(filePath);
    setState(() {
      _wallpaperFilePath = filePath;
    });
  }

  Future<String> _savedMediaItemFilePath(app.MediaItem mediaItem) async {
    var path = await _fetchMediaItemFilePath(mediaItem);
    log("path=$path");

    // 画像が既に存在すればそれを利用する
    if (File(path).existsSync()) {
      return path;
    }

    // 画像がなければダウンロードする
    var photosApi = PhotosLibraryApi(_makeAuthClientFromUser(_currentUser!));
    var _mediaItem = await photosApi.mediaItems.get(mediaItem.id);
    log("baseUrl=${_mediaItem.baseUrl}");
    var extension = "jpg";
    var url = Uri.parse("${_mediaItem.baseUrl}=w10240-h10240-no?.$extension");
    var response = await http.get(url);
    if (response.statusCode >= 200 || response.statusCode <= 399 && response.bodyBytes.isNotEmpty) {
      File(path).writeAsBytesSync(response.bodyBytes);
    }

    return path;
  }

  /// googleapis の呼び出しに必要な AuthClient を User から生成する
  AutoRefreshingAuthClient _makeAuthClientFromUser(app.User user) {
    var accessToken = AccessToken('Bearer', user.accessToken, DateTime(2022, 1, 1).toUtc());
    var credentials = AccessCredentials(accessToken, user.refreshToken, user.scope.split(','));
    return AutoRefreshingClient(
      http.Client(),
      ClientId(dotenv.env["GOOGLE_CLIENT_ID"]!, dotenv.env["GOOGLE_CLIENT_SECRET"]!),
      credentials
    );
  }

  /// MediaItem の画像をダウンロードしてローカルのファイルパスを返す
  Future<String> _fetchMediaItemFilePath(app.MediaItem mediaItem) async {
    var dir = await _getMediaItemDir();
    return path.join(dir.path, mediaItem.filename);
  }

  Future<Directory> _getAppDataDir() async {
    var dir = await getApplicationDocumentsDirectory();
    return Directory(path.join(dir.path, 'WallpaperChanger'));
  }

  Future<Directory> _getMediaItemDir() async {
    var dir = await _getAppDataDir();
    var mediaItemsDir = Directory(path.join(dir.path, 'MediaItems'));
    if (!mediaItemsDir.existsSync()) {
      mediaItemsDir.createSync(recursive: true);
    }

    return mediaItemsDir;
  }

  @override
  void initState() {
    super.initState();
    _currentUser = _getCurrentUser();
    _mediaItemCount = realm.all<app.MediaItem>().length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _buildBody(context),
    );
  }

  /// #7 新しいUI
  Widget _buildBody(BuildContext context) {
    if (_currentUser == null) {
      return _buildBodyLogin(context);
    }

    return Center(
      child: SizedBox(
        width: 400,
        height: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              _buildWidgetConnectedUser(context),
              _buildWidgetActions(context),
              _buildWidgetSummaryData(context),
            ],
          ),
        ),
      ),
    );
  }

  ///
  Widget _buildWidgetActions(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          TextButton(
            onPressed: _handleChangeRandomWallpaper,
            child: const Text("Change Wallpaper"),
          ),
          TextButton(
            onPressed: _handleSync,
            child: const Text("Sync"),
          ),
        ],
      ),
    );
  }

  /// 現在のデータ状況を表示する
  Widget _buildWidgetSummaryData(BuildContext context) {
    return Container(
      color: Colors.black26,
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10.0),
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text("Photos: $_mediaItemCount"),
        ],
      ),
    );
  }

  /// 認証済みのアカウント情報を表示する
  Widget _buildWidgetConnectedUser(BuildContext context) {
    app.User user = _currentUser!;
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          const Text("Hello, "),
          Text(user.name),
          CircleAvatar(
            backgroundImage: NetworkImage(user.pictureUrl),
          ),
        ],
      ),
    );
  }


  /// 認証前の画面を表示する
  Widget _buildBodyLogin(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          TextButton(
            onPressed: _handleGooglePhotosAuth,
            child: const Text("Connect to Google Photos"),
          ),
        ],
      ),

    );
  }
}
