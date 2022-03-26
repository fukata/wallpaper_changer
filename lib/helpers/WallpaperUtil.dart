import 'dart:developer';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:googleapis/photoslibrary/v1.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallpaper_changer/app.dart' as app;
import 'package:wallpaper_changer/helpers/AuthUtil.dart';
import 'package:wallpaper_changer/helpers/RealmUtil.dart';
import 'package:wallpaper_changer/helpers/Setting.dart';
import 'package:win32/win32.dart';

/// 壁紙に使用する画像をランダムに選定する
app.MediaItem? pickupRandomMediaItem(SharedPreferences? sp) {
  var mediaItems = realm().all<app.MediaItem>();
  var total = mediaItems.length;
  log("MediaItem total is $total");
  if (total == 0) {
    return null;
  }

  // フィルタリング
  var filterOnlyLandscape = sp?.getBool(SP_FILTER_ONLY_LANDSCAPE) ?? false;
  var filterWidth = sp?.getInt(SP_FILTER_WIDTH) ?? 0;
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
  if (filteredMediaItems.isEmpty) {
    log("フィルタリングの結果、対象の画像がありませんでした。");
    return null;
  }

  var idx = math.Random.secure().nextInt(filteredMediaItems.length);
  var mediaItem = filteredMediaItems.elementAt(idx);
  log("Choose mediaItem. id=${mediaItem.id}, filename=${mediaItem.filename}, width=${mediaItem.width}, height=${mediaItem.height}");

  return mediaItem;
}

void setWallpaper(String filePath) async {
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
      log("result=$result, monitorIdPtr=$monitorIdPtr");

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

Future<String> savedMediaItemFilePath(app.MediaItem mediaItem) async {
  var path = await fetchMediaItemFilePath(mediaItem);
  log("path=$path");

  // 画像が既に存在すればそれを利用する
  if (File(path).existsSync()) {
    return path;
  }

  // 画像がなければダウンロードする
  var photosApi =
      PhotosLibraryApi(makeGoogleAuthClientFromUser(getCurrentUser()!));
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

/// MediaItem の画像をダウンロードしてローカルのファイルパスを返す
Future<String> fetchMediaItemFilePath(app.MediaItem mediaItem) async {
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
