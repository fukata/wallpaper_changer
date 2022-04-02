import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:googleapis/oauth2/v2.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_tray/system_tray.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wallpaper_changer/helpers/AuthUtil.dart';
import 'package:wallpaper_changer/helpers/PhotoUtil.dart';
import 'package:wallpaper_changer/helpers/RealmUtil.dart';
import 'package:wallpaper_changer/helpers/Setting.dart';
import 'package:wallpaper_changer/helpers/TimerUtil.dart';
import 'package:wallpaper_changer/helpers/WallpaperUtil.dart';
import 'package:wallpaper_changer/models/Album.dart';
import 'package:wallpaper_changer/models/MediaItem.dart';
import 'package:wallpaper_changer/models/User.dart';

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

  User? _currentUser;
  int _mediaItemCount = 0;

  /// 壁紙を自動更新する時に使用するタイマー
  Timer? _autoChangeWallpaperTimer;
  bool _changeWallpaperProcessing = false;

  /// 画像データを定期的に取得するためのタイマー
  Timer? _syncPhotosTimer;
  bool _syncPhotosProcessing = false;
  bool _syncAlbumsProcessing = false;

  String? _filterFilenameRegexError;

  /// 画像データを取得する
  ///
  /// 現在の取得先（最近 or アルバム）から自動判別してデータを取得する
  Future<void> _handleSync() async {
    var target = _sp?.getString(SP_PHOTOS_CONDITION_TARGET);
    if (target == PHOTOS_CONDITION_TARGET_ALBUM) {
      var albumId = _sp?.getString(SP_PHOTOS_CONDITION_SELECTED_ALBUM);
      if (albumId != null && albumId.isNotEmpty) {
        var albums = realm().query<Album>(r'id == $0', [albumId]);
        if (albums.isNotEmpty) {
          var album = albums.first;
          await _handleSyncPhotos(albumId: album.id);
        }
      }
    } else {
      await _handleSyncPhotos();
    }
  }

  /// 画像データを取得する
  Future<void> _handleSyncPhotos({int? maxFetchNum, String? albumId}) async {
    if (_syncPhotosProcessing) {
      log("既に写真の同期中なので処理を中断します。");
      return;
    }

    if (_currentUser == null) {
      log("Google Photosに接続されていないので処理を中断します。");
      return;
    }

    try {
      setState(() {
        _syncPhotosProcessing = true;
      });

      var client = makeGoogleAuthClientFromUser(_currentUser!);
      var photosApi = makePhotosLibraryApi(client);
      maxFetchNum = maxFetchNum ?? _sp?.getInt(SP_SYNC_PHOTOS_PER_TIME) ?? 100;
      await loadGooglePhotos(
        photosApi: photosApi,
        maxFetchNum: maxFetchNum,
        request: makeSearchMediaItemsRequest(albumId: albumId),
      );
      setState(() {
        _mediaItemCount = realm().all<MediaItem>().length;
      });
    } finally {
      setState(() {
        _syncPhotosProcessing = false;
      });
    }
  }

  /// アルバムデータを取得する
  Future<void> _handleSyncAlbums() async {
    if (_syncAlbumsProcessing) {
      log("既にアルバムの同期中なので処理を中断します。");
      return;
    }

    if (_currentUser == null) {
      log("Google Photosに接続されていないので処理を中断します。");
      return;
    }

    try {
      setState(() {
        _syncAlbumsProcessing = true;
      });

      var client = makeGoogleAuthClientFromUser(_currentUser!);
      var photosApi = makePhotosLibraryApi(client);
      await loadGooglePhotoAlbums(photosApi: photosApi);
    } finally {
      setState(() {
        _syncAlbumsProcessing = false;
      });
    }
  }

  /// アルバムに属している写真データを全て取得する
  Future<void> _handleSyncAlbumData(String albumId) async {
    var albums = realm().query<Album>(r'id == $0', [albumId]);
    if (albums.isNotEmpty) {
      var album = albums.first;
      await _handleSyncPhotos(maxFetchNum: int.parse(album.mediaItemsCount), albumId: album.id);
    }
  }

  /// Google Photos と OAuthを行う
  Future<void> _handleGooglePhotosAuth() async {
    AuthClient client = await _obtainCredentials();
    log("credentials=${client.credentials.toJson()}");

    var oauth2Api = Oauth2Api(client);
    var userInfo = await oauth2Api.userinfo.v2.me.get();
    log("profile. id=${userInfo.id}, username=${userInfo.name}");

    var user = _registerUser(client.credentials, userInfo);
    setState(() {
      _currentUser = user;
    });

    if (user.isValidPermission()) {
      await _handleSync();
      await _handleSyncAlbums();
    }
  }

  User _registerUser(AccessCredentials credentials, Userinfo userInfo) {
    var users = realm().query<User>(r'id == $0', [userInfo.id!]);
    late User user;
    if (users.isNotEmpty) {
      user = users.first;
      realm().write(() {
        user.name = userInfo.name!;
        user.pictureUrl = userInfo.picture!;
        user.accessToken = credentials.accessToken.data;
        user.refreshToken = credentials.refreshToken!;
        user.idToken = credentials.idToken!;
        user.scope = credentials.scopes.join(',');
      });
    } else {
      user = User(
        userInfo.id!,
        userInfo.name!,
        userInfo.picture!,
        credentials.accessToken.data,
        credentials.refreshToken!,
        credentials.idToken!,
        credentials.scopes.join(','),
      );
      _sp?.clear();
      realm().write(() {
        realm().deleteAll<User>();
        realm().deleteAll<MediaItem>();
        realm().deleteAll<Album>();
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

  /// MediaItem の中からランダムに画像を選定して壁紙に設定する
  void _handleChangeRandomWallpaper() async {
    if (_changeWallpaperProcessing) {
      log("既に壁紙を変更中なので処理を中断します。");
      return;
    }

    try {
      setState(() {
        _changeWallpaperProcessing = true;
      });

      var mediaItem = pickupRandomMediaItem(_sp);
      if (mediaItem == null) {
        return;
      }

      var filePath = await savedMediaItemFilePath(mediaItem);
      realm().write(() {
        mediaItem.cached = true;
      });

      setWallpaper(filePath);
      setState(() {
        _wallpaperFilePath = filePath;
      });
    } finally {
      setState(() {
        _changeWallpaperProcessing = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _initSystemTray();
    _currentUser = getCurrentUser();
    _mediaItemCount = realm().all<MediaItem>().length;

    SharedPreferences.getInstance().then((value) => {
          setState(() {
            _sp = value;
            initChangeWallpaperState();
            initSyncPhotosState();
          })
        });
  }

  void initChangeWallpaperState() {
    if (!(_sp?.getBool(SP_AUTO_CHANGE_WALLPAPER) ?? false)) {
      return;
    }

    // 最終更新日時からduration分過ぎていれば処理を実行する
    var duration = _sp?.getString(SP_AUTO_CHANGE_WALLPAPER_DURATION) ?? "";
    if (duration.isEmpty) {
      return;
    }

    try {
      var lastChangedAtStr = _sp?.getString(SP_LAST_WALLPAPER_CHANGED_AT) ?? "";
      if (lastChangedAtStr.isNotEmpty) {
        var lastChangedAt = DateTime.parse(lastChangedAtStr);
        var now = DateTime.now();
        if (now.compareTo(lastChangedAt.add(Duration(seconds: convertDurationToSeconds(duration)))) == 1) {
          log("前回の変更時刻 $lastChangedAt から $duration を過ぎているので壁紙を更新します。");
          setState(() {
            _sp?.setString(SP_LAST_WALLPAPER_CHANGED_AT, now.toIso8601String());
          });
          _handleChangeRandomWallpaper();
        }
      }
    } on Exception catch (e) {
      log(e.toString());
    }

    _startChangeWallpaperTimer(duration);
  }

  void initSyncPhotosState() {
    if (!(_sp?.getBool(SP_AUTO_SYNC_PHOTOS) ?? false)) {
      return;
    }

    // 最終更新日時からduration分過ぎていれば処理を実行する
    var duration = _sp?.getString(SP_AUTO_SYNC_PHOTOS_DURATION) ?? "";
    if (duration.isEmpty) {
      return;
    }

    try {
      var lastSyncedAtStr = _sp?.getString(SP_LAST_PHOTOS_SYNCED_AT) ?? "";
      if (lastSyncedAtStr.isNotEmpty) {
        var lastSyncedAt = DateTime.parse(lastSyncedAtStr);
        var now = DateTime.now();
        if (now.compareTo(lastSyncedAt.add(Duration(seconds: convertDurationToSeconds(duration)))) == 1) {
          log("前回の同期時刻 $lastSyncedAt から $duration を過ぎているので同期します。");
          setState(() {
            _sp?.setString(SP_LAST_PHOTOS_SYNCED_AT, now.toIso8601String());
          });
          _handleSync();
        }
      }
    } on Exception catch (e) {
      log(e.toString());
    }
    _startSyncPhotosTimer(duration);
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
      realm().deleteAll<MediaItem>();
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

    if (_currentUser!.isInvalidPermission()) {
      return _buildBodyInvalidPermission(context);
    }

    return Center(
      child: SizedBox(
        width: 440,
        height: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ListView(
            padding: const EdgeInsets.only(left: 20, right: 20),
            scrollDirection: Axis.vertical,
            children: [
              _buildWidgetConnectedUser(context),
              _buildWidgetActions(context),
              _buildWidgetSummaryData(context),
              _buildWidgetPhotosConditionSettings(context),
              _buildWidgetAutomaticallyChangeSettings(context),
              _buildWidgetAutomaticallySyncSettings(context),
              _buildWidgetFilterSettings(context),
            ]
          ),
        ),
      ),
    );
  }

  /// 実行アクションを表示する
  Widget _buildWidgetActions(BuildContext context) {
    List<Widget> children = [];

    // 壁紙を変更する
    if (_changeWallpaperProcessing) {
      children.add(
          Row(
            children: [
              _loadingIcon(),
              const Text("壁紙を変更中..."),
            ],
          )
      );
    } else {
      children.add(
        TextButton(
          onPressed: _handleChangeRandomWallpaper,
          child: const Text("壁紙を変更する"),
        )
      );
    }

    // 同期する
    if (_syncPhotosProcessing) {
      children.add(
        Row(
          children: [
            _loadingIcon(),
            const Text("同期中..."),
          ],
        )
      );
    } else {
      children.add(
        TextButton(
          onPressed: _handleSync,
          child: const Text("同期する"),
        )
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: children,
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
              TextButton(onPressed: _syncPhotosProcessing ? null : _resetUserData, child: const Text("リセットする"))
            ],
          ),
        ],
      ),
    );
  }

  /// 認証済みのアカウント情報を表示する
  Widget _buildWidgetConnectedUser(BuildContext context) {
    User user = _currentUser!;
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          _paddingRight(
            TextButton(onPressed: _handleGooglePhotosAuth, child: const Text("再認証"))
          ),
          const Text("Hello, "),
          Text(user.name),
          CircleAvatar(
            backgroundImage: NetworkImage(user.pictureUrl),
          ),
        ],
      ),
    );
  }

  /// 最近 or アルバムの条件を表示する
  Widget _buildWidgetPhotosConditionSettings(BuildContext context) {
    var target = getSettingStringValue(
      value: _sp?.getString(SP_PHOTOS_CONDITION_TARGET),
      defaultValue: DEFAULT_PHOTOS_CONDITION_TARGET,
      values: PHOTOS_CONDITION_TARGET_LIST
    );
    List<Widget> children = <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _paddingRight(const Text("次のどちらから写真を選択しますか？")),
              DropdownButton<String>(
                value: target,
                items: PHOTOS_CONDITION_TARGET_LIST
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                      child: Text(PHOTOS_CONDITION_TARGET_LABELS[value] ?? value), value: value);
                }).toList(),
                onChanged: _syncPhotosProcessing ? null : (newValue) {
                  setState(() {
                    _sp?.setString(SP_PHOTOS_CONDITION_TARGET, newValue ?? DEFAULT_PHOTOS_CONDITION_TARGET);
                  });
                },
              ),
            ],
          )
        ],
      ),
    ];

    // アルバムが選択されている場合は対象のアルバム一覧を表示する。
    if (target == PHOTOS_CONDITION_TARGET_ALBUM) {
      var albums = realm().all<Album>();
      List<DropdownMenuItem<String>> albumDropdownItems = albums.map<DropdownMenuItem<String>>((album) {
        return DropdownMenuItem<String>(child: Text("${album.title} (${album.mediaItemsCount})"), value: album.id);
      }).toList();

      // DropdownButton はitemsに存在しない値の場合、エラーになるので事前に存在チェックを行う
      var selectedAlbumId = _sp?.getString(SP_PHOTOS_CONDITION_SELECTED_ALBUM);
      if (selectedAlbumId != null) {
        var albumIds = albums.map((album) => album.id).toList();
        if (!albumIds.contains(selectedAlbumId)) {
          selectedAlbumId = null;
        }
      }

      children.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _syncAlbumsProcessing ? null : _handleSyncAlbums,
              child: _syncAlbumsProcessing ?
                Row(
                  children: [
                    _loadingIcon(),
                    const Text("同期中..."),
                  ],
                ) :
                const Text("アルバム一覧を更新する")
            ),
          ],
        )
      );
      children.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            DropdownButton<String>(
              value: selectedAlbumId,
              items: albumDropdownItems,
              onChanged: _syncPhotosProcessing ? null : (newValue) {
                setState(() {
                  if (newValue == null) {
                    _sp?.remove(SP_PHOTOS_CONDITION_SELECTED_ALBUM);
                  } else {
                    _sp?.setString(SP_PHOTOS_CONDITION_SELECTED_ALBUM, newValue);
                  }
                });
              }
            ),
            _syncPhotosProcessing ?
              Row(
                children: [
                  _loadingIcon(),
                  const Text("同期中..."),
                ],
              ) :
              TextButton(
                onPressed: () {
                  _handleSyncAlbumData(selectedAlbumId!);
                },
                child: const Text("同期する"),
              ),
          ],
        )
      );
    }

    return _buildWithSection(
      context: context,
      label: "最近 or アルバム",
      child: _buildDefaultContainer(
        context: context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      )
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
                              DEFAULT_AUTO_CHANGE_WALLPAPER_DURATION,
                      items: AUTO_CHANGE_WALLPAPER_DURATION_LIST
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
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const <Widget>[
                    Text("ファイル名が次のパターンに一致する（正規表現）"),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Flexible(
                    child: TextField(
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      controller: TextEditingController(
                          text: _sp?.getString(SP_FILTER_FILENAME_REGEX) ?? ""),
                      onSubmitted: (value) {
                        setState(() {
                          try {
                            RegExp(value);
                            _sp?.setString(SP_FILTER_FILENAME_REGEX, value);
                            _filterFilenameRegexError = null;
                          } on Exception catch (e) {
                            _filterFilenameRegexError = "$value は正規表現として正しくありません。";
                            log(e.toString());
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_filterFilenameRegexError != null)
                _errorText(_filterFilenameRegexError!),
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
                          _sp?.getString(SP_AUTO_SYNC_PHOTOS_DURATION) ?? DEFAULT_AUTO_SYNC_PHOTOS_DURATION,
                      items: AUTO_SYNC_PHOTOS_DURATION_LIST
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

  /// デフォルトの背景色を持つウィジェットを返す
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

  /// 権限が足りず再認証が必要な画面を表示する
  Widget _buildBodyInvalidPermission(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[Column(
            children: [
              const Text("Google Photosへのアクセス権限が付与されていないので再認証を行ってください。"),
              const Text("認証時にGoogle Photosへのアクセスへの許可をしてください。"),
              TextButton(onPressed: _handleGooglePhotosAuth, child: const Text("再認証"))
            ],
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

  /// デフォルトのローディングアイコンを返す
  Widget _loadingIcon() {
    return const SpinKitFadingCircle(
      color: Colors.white,
      size: 16,
    );
  }

  Widget _errorText(final String message) {
    return Text(
      message,
      style: const TextStyle(
        color: Colors.red,
      ),
    );
  }
}
