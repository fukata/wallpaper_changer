import 'dart:async';
import 'dart:developer';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis/oauth2/v2.dart';
import 'package:googleapis/photoslibrary/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis_auth/src/auth_http_utils.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_tray/system_tray.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wallpaper_changer/app.dart' as app;
import 'package:wallpaper_changer/helpers/Setting.dart';
import 'package:wallpaper_changer/helpers/TimerUtil.dart';
import 'package:win32/win32.dart';

import 'helpers/RealmProvider.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SystemTray _systemTray = SystemTray();
  final AppWindow _appWindow = AppWindow();
  SharedPreferences? _sp;

  /// 現在の壁紙のファイルパス
  String _wallpaperFilePath = "";

  app.User? _currentUser;
  int _mediaItemCount = 0;

  /// 壁紙を自動更新する時に使用するタイマー
  Timer? _autoChangeWallpaperTimer;

  /// 画像データを定期的に取得するためのタイマー
  Timer? _syncPhotosTimer;

  /// 画像データを取得する
  void _handleSync() async {
    var client = _makeAuthClientFromUser(_currentUser!);
    var maxFetchNum = _sp?.getInt(SP_SYNC_PHOTOS_PER_TIME) ?? 100;
    await _loadGooglePhotos(client, maxFetchNum);
    setState(() {
      _mediaItemCount = realm().all<app.MediaItem>().length;
    });
  }

  void _setWallpaper(String filePath) async {
    var file = File(filePath);
    if (!file.existsSync()) {
      // ファイルが存在しない
      log("画像が存在しません。 filePath=$filePath");
      return;
    }

    log("壁紙を変更します。 filePath=$filePath");

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

    var maxFetchNum = _sp?.getInt(SP_SYNC_PHOTOS_PER_TIME) ?? 100;
    await _loadGooglePhotos(client, maxFetchNum);
    setState(() {
      _mediaItemCount = realm().all<app.MediaItem>().length;
    });
  }

  /// 最後に認証したユーザーを返す
  app.User? _getCurrentUser() {
    var users = realm().all<app.User>();
    if (users.isEmpty) {
      return null;
    } else {
      return users.first;
    }
  }

  app.User _registerUser(AccessCredentials credentials, Userinfo userInfo) {
    var users = realm().query<app.User>(r'id == $0', [userInfo.id!]);
    late app.User user;
    if (users.isNotEmpty) {
      user = users.first;
      realm().write(() {
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
      realm().write(() {
        realm().deleteAll<app.User>();
        realm().deleteAll<app.MediaItem>();
        realm().add(user);
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
  Future _loadGooglePhotos(AuthClient client, int maxFetchNum) async {
    var photosApi = PhotosLibraryApi(client);

    int fetchedMediaItemsNum = 0;
    String? nextPageToken;
    while (fetchedMediaItemsNum < maxFetchNum) {
      SearchMediaItemsRequest request = SearchMediaItemsRequest(
        filters:
            Filters(mediaTypeFilter: MediaTypeFilter(mediaTypes: ['PHOTO'])),
        orderBy: 'MediaMetadata.creation_time desc',
        pageSize: 100,
        pageToken: nextPageToken,
      );

      var response = await photosApi.mediaItems.search(request);
      if (response.mediaItems == null) {
        break;
      }

      var mediaItems = response.mediaItems!;
      if (mediaItems.isEmpty) {
        break;
      }

      fetchedMediaItemsNum += mediaItems.length;

      for (var mediaItem in mediaItems) {
        log("mediaItem=${mediaItem.toJson()}");
        _registerMediaItem(mediaItem);
      }

      if (fetchedMediaItemsNum > maxFetchNum) {
        break;
      }

      nextPageToken = response.nextPageToken;
      if (nextPageToken == null) {
        break;
      }
    }
  }

  /// 画像データを登録する
  app.MediaItem _registerMediaItem(MediaItem mediaItem) {
    var mediaItems = realm().query<app.MediaItem>(r'id == $0', [mediaItem.id!]);
    if (mediaItems.isNotEmpty) {
      return mediaItems.first;
    }

    var meta = mediaItem.mediaMetadata!;
    var newMediaItem = app.MediaItem(
        mediaItem.id!,
        mediaItem.filename!,
        mediaItem.mimeType!,
        meta.width == null ? 0 : int.parse(meta.width!),
        meta.height == null ? 0 : int.parse(meta.height!),
        false);
    realm().write(() {
      realm().add(newMediaItem);
    });

    return newMediaItem;
  }

  /// MediaItem の中からランダムに画像を選定して壁紙に設定する
  void _handleChangeRandomWallpaper() async {
    var mediaItem = _pickupRandomMediaItem();
    if (mediaItem == null) {
      return;
    }

    var filePath = await _savedMediaItemFilePath(mediaItem);
    realm().write(() {
      mediaItem.cached = true;
    });

    _setWallpaper(filePath);
    setState(() {
      _wallpaperFilePath = filePath;
    });
  }

  /// 壁紙に使用する画像をランダムに選定する
  app.MediaItem? _pickupRandomMediaItem() {
    var mediaItems = realm().all<app.MediaItem>();
    var total = mediaItems.length;
    log("MediaItem total is $total");
    if (total == 0) {
      return null;
    }

    // フィルタリング
    var filterOnlyLandscape = _sp?.getBool(SP_FILTER_ONLY_LANDSCAPE) ?? false;
    var filterWidth = _sp?.getInt(SP_FILTER_WIDTH) ?? 0;
    log("フィルタリング：横向きのみ=$filterOnlyLandscape, 幅=$filterWidth");
    var filteredMediaItems = mediaItems.where((mediaItem) {
      if (filterWidth > 0 && mediaItem.width < filterWidth) {
        return false;
      }
      if (filterOnlyLandscape && mediaItem.width <= mediaItem.height) {
        return false;
      }

      return true;
    });
    if (filteredMediaItems.length == 0) {
      log("フィルタリングの結果、対象の画像がありませんでした。");
      return null;
    }

    var idx = math.Random.secure().nextInt(filteredMediaItems.length);
    var mediaItem = filteredMediaItems.elementAt(idx);
    log("Choose mediaItem. id=${mediaItem.id}, filename=${mediaItem.filename}, width=${mediaItem.width}, height=${mediaItem.height}");

    return mediaItem;
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
    if (response.statusCode >= 200 ||
        response.statusCode <= 399 && response.bodyBytes.isNotEmpty) {
      File(path).writeAsBytesSync(response.bodyBytes);
    }

    return path;
  }

  /// googleapis の呼び出しに必要な AuthClient を User から生成する
  AutoRefreshingAuthClient _makeAuthClientFromUser(app.User user) {
    var accessToken =
        AccessToken('Bearer', user.accessToken, DateTime(2022, 1, 1).toUtc());
    var credentials = AccessCredentials(
        accessToken, user.refreshToken, user.scope.split(','));
    return AutoRefreshingClient(
        http.Client(),
        ClientId(dotenv.env["GOOGLE_CLIENT_ID"]!,
            dotenv.env["GOOGLE_CLIENT_SECRET"]!),
        credentials);
  }

  /// MediaItem の画像をダウンロードしてローカルのファイルパスを返す
  Future<String> _fetchMediaItemFilePath(app.MediaItem mediaItem) async {
    var dir = await _getMediaItemDir();
    return path.join(dir.path, "${mediaItem.id}-${mediaItem.filename}");
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
    _initSystemTray();
    _currentUser = _getCurrentUser();
    _mediaItemCount = realm().all<app.MediaItem>().length;

    SharedPreferences.getInstance().then((value) => {
          setState(() {
            _sp = value;
            if (_sp?.getBool(SP_AUTO_CHANGE_WALLPAPER) ?? false) {
              _startChangeWallpaperTimer(
                  _sp?.getString(SP_AUTO_CHANGE_WALLPAPER_DURATION) ?? "");
            }
            if (_sp?.getBool(SP_AUTO_SYNC_PHOTOS) ?? false) {
              _startSyncPhotosTimer(
                  _sp?.getString(SP_AUTO_SYNC_PHOTOS_DURATION) ?? "");
            }
          })
        });
  }

  Future<void> _initSystemTray() async {
    String iconPath =
        Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png';

    final menus = <MenuItemBase>[
      MenuItem(label: "Show", onClicked: _appWindow.show),
      MenuItem(label: "Hide", onClicked: _appWindow.hide),
    ];

    await _systemTray.initSystemTray(
        title: "system tray", iconPath: iconPath, toolTip: "Wallpaper Changer");
    await _systemTray.setContextMenu(menus);

    // handle system tray event
    _systemTray.registerSystemTrayEventHandler((eventName) {
      debugPrint("eventName: $eventName");
      switch (eventName) {
        case "leftMouseUp":
          _appWindow.show();
          break;
        case "rightMouseUp":
          _systemTray.popUpContextMenu();
          break;
      }
    });
  }

  void _startChangeWallpaperTimer(String duration) {
    _autoChangeWallpaperTimer?.cancel();
    if (duration == "") {
      log("壁紙更新のタイマーの設定をキャンセルしました。duration=$duration");
      return;
    }

    var seconds = convertDurationToSeconds(duration);
    if (seconds == 0) {
      log("壁紙更新のタイマーの設定をキャンセルしました。duration=$duration");
      return;
    }

    setState(() {
      log("壁紙更新のタイマーを設定しました。duration=$duration");
      _autoChangeWallpaperTimer =
          Timer.periodic(Duration(seconds: seconds), (timer) {
        var changedAt = DateTime.now().toIso8601String();
        log("壁紙を変更します。changedAt=$changedAt");
        setState(() {
          _sp?.setString(SP_LAST_WALLPAPER_CHANGED_AT, changedAt);
        });
        _handleChangeRandomWallpaper();
      });
    });
  }

  void _stopChangeWallpaperTimer() {
    _autoChangeWallpaperTimer?.cancel();
    log("壁紙更新のタイマーを停止しました。");
  }

  void _resetUserData() {
    realm().write(() {
      realm().deleteAll<app.MediaItem>();
    });
    setState(() {
      _mediaItemCount = 0;
    });
  }

  void _startSyncPhotosTimer(String duration) {
    _syncPhotosTimer?.cancel();
    if (duration == "") {
      log("写真の自動同期のタイマーの設定をキャンセルしました。duration=$duration");
      return;
    }

    var seconds = convertDurationToSeconds(duration);
    if (seconds == 0) {
      log("写真の自動同期のタイマーの設定をキャンセルしました。duration=$duration");
      return;
    }

    setState(() {
      log("写真の自動同期のタイマーを設定しました。duration=$duration");
      _syncPhotosTimer = Timer.periodic(Duration(seconds: seconds), (timer) {
        var syncedAt = DateTime.now().toIso8601String();
        log("写真の自動同期を開始します。syncedAt=$syncedAt");
        setState(() {
          _sp?.setString(SP_LAST_PHOTOS_SYNCED_AT, syncedAt);
        });
        _handleSync();
      });
    });
  }

  void _stopSyncPhotosTimer() {
    _syncPhotosTimer?.cancel();
    log("写真の自動同期のタイマーを停止しました。");
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
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              _buildWidgetConnectedUser(context),
              _buildWidgetActions(context),
              _buildWidgetSummaryData(context),
              _buildWidgetAutomaticallyChangeSettings(context),
              _buildWidgetFilterSettings(context),
              _buildWidgetAutomaticallySyncSettings(context),
            ],
          ),
        ),
      ),
    );
  }

  /// 実行アクションを表示する
  Widget _buildWidgetActions(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          TextButton(
            onPressed: _handleChangeRandomWallpaper,
            child: const Text("壁紙を変更する"),
          ),
          TextButton(
            onPressed: _handleSync,
            child: const Text("同期する"),
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
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: [
              _paddingRight(const Text("最終更新")),
              Text(_sp?.getString(SP_LAST_WALLPAPER_CHANGED_AT) ?? "-")
            ],
          ),
          Row(
            children: [
              _paddingRight(const Text("最終同期")),
              Text(_sp?.getString(SP_LAST_PHOTOS_SYNCED_AT) ?? "-")
            ],
          ),
          Row(
            children: [
              _paddingRight(const Text("写真")),
              _paddingRight(Text("$_mediaItemCount")),
              TextButton(onPressed: _resetUserData, child: Text("リセットする"))
            ],
          ),
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

  /// 自動更新設定
  Widget _buildWidgetAutomaticallyChangeSettings(BuildContext context) {
    return _buildWithSection(
        context: context,
        label: "自動更新",
        child: _buildDefaultContainer(
          context: context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _paddingRight(const Text("間隔")),
                  DropdownButton<String>(
                      value:
                          _sp?.getString(SP_AUTO_CHANGE_WALLPAPER_DURATION) ??
                              "5m",
                      items: <String>["10s", "5m", "1h", "3h", "6h", "1d"]
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                            child: Text(value), value: value);
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _sp?.setString(SP_AUTO_CHANGE_WALLPAPER_DURATION,
                              newValue ?? "");
                        });
                        if (_sp?.getBool(SP_AUTO_CHANGE_WALLPAPER) ?? false) {
                          _startChangeWallpaperTimer(newValue ?? "");
                        }
                      }),
                  Switch(
                    value: _sp?.getBool(SP_AUTO_CHANGE_WALLPAPER) ?? false,
                    onChanged: (value) {
                      setState(() {
                        _sp?.setBool(SP_AUTO_CHANGE_WALLPAPER, value);
                      });
                      if (value) {
                        _startChangeWallpaperTimer(
                            _sp?.getString(SP_AUTO_CHANGE_WALLPAPER_DURATION) ??
                                "");
                      } else {
                        _stopChangeWallpaperTimer();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ));
  }

  /// 壁紙の対象となる画像のフィルタリング設定を表示する
  Widget _buildWidgetFilterSettings(BuildContext context) {
    return _buildWithSection(
      context: context,
      label: "フィルタリング",
      child: _buildDefaultContainer(
          context: context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text("壁紙として使用する画像のフィルタリングを設定できます。"),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  _paddingRight(const Text("横向きの画像のみ使用する")),
                  Switch(
                    value: _sp?.getBool(SP_FILTER_ONLY_LANDSCAPE) ?? false,
                    onChanged: (value) {
                      setState(() {
                        _sp?.setBool(SP_FILTER_ONLY_LANDSCAPE, value);
                      });
                    },
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  _paddingRight(const Text("width > ")),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      controller: TextEditingController(
                          text: _sp?.getInt(SP_FILTER_WIDTH).toString() ?? ""),
                      onSubmitted: (value) {
                        setState(() {
                          try {
                            _sp?.setInt(SP_FILTER_WIDTH, int.parse(value));
                          } on Exception catch (e) {
                            log(e.toString());
                          }
                        });
                      },
                    ),
                  ),
                  const Text("px"),
                ],
              ),
            ],
          )),
    );
  }

  /// 画像の自動同期設定を表示する
  Widget _buildWidgetAutomaticallySyncSettings(BuildContext context) {
    return _buildWithSection(
      context: context,
      label: "写真の自動同期",
      child: _buildDefaultContainer(
          context: context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _paddingRight(const Text("間隔")),
                  DropdownButton<String>(
                      value:
                          _sp?.getString(SP_AUTO_SYNC_PHOTOS_DURATION) ?? "1h",
                      items: <String>["1h", "3h", "6h", "1d"]
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                            child: Text(value), value: value);
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _sp?.setString(
                              SP_AUTO_SYNC_PHOTOS_DURATION, newValue ?? "");
                        });
                        if (_sp?.getBool(SP_AUTO_SYNC_PHOTOS) ?? false) {
                          _startSyncPhotosTimer(newValue ?? "");
                        }
                      }),
                  Switch(
                    value: _sp?.getBool(SP_AUTO_SYNC_PHOTOS) ?? false,
                    onChanged: (value) {
                      setState(() {
                        _sp?.setBool(SP_AUTO_SYNC_PHOTOS, value);
                      });
                      if (value) {
                        _startSyncPhotosTimer(
                            _sp?.getString(SP_AUTO_SYNC_PHOTOS_DURATION) ?? "");
                      } else {
                        _stopSyncPhotosTimer();
                      }
                    },
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  _paddingRight(const Text("取得する枚数")),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      controller: TextEditingController(
                          text: (_sp?.getInt(SP_SYNC_PHOTOS_PER_TIME) ?? 100)
                              .toString()),
                      onSubmitted: (value) {
                        setState(() {
                          try {
                            _sp?.setInt(
                                SP_SYNC_PHOTOS_PER_TIME, int.parse(value));
                          } on Exception catch (e) {
                            log(e.toString());
                          }
                        });
                      },
                    ),
                  ),
                  const Text("枚"),
                ],
              ),
            ],
          )),
    );
  }

  ///
  Widget _buildDefaultContainer({
    required BuildContext context,
    required Widget child,
  }) {
    return Container(
      color: Colors.black26,
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      child: child,
    );
  }

  /// セクション付きのウィジェットを返す
  ///
  /// @param child セクションのウィジェット
  /// @param context コンテキスト
  /// @param label セクション名
  Widget _buildWithSection({
    required BuildContext context,
    required String label,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [Text(label)],
          ),
          child,
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
            child: const Text("Google Photosに接続する"),
          ),
        ],
      ),
    );
  }

  /// 右に余白があるウィジェットを生成
  Widget _paddingRight(Widget child) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: child,
    );
  }
}
