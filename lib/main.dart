import 'dart:developer';
import 'dart:io';
import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

void main() {
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
  String wallpaperFilePath = path.join("C:", "Users", "tatsu", "Desktop", "wallpaper_changer_sample.jpg");

  /// モニタ
  static List<int> _monitors = [];

  /// 壁紙を変更するボタンが押された時の処理。
  void _handleChangeWallpaper() {
    _monitors.clear();

    var file = File(wallpaperFilePath);
    if (!file.existsSync()) {
      // ファイルが存在しない
      log("画像が存在しない。 filePath=$wallpaperFilePath");
      return;
    }

    // FIXME: Win32 APIを呼び出してシステムの背景画像を変更する
    log("壁紙を変更する。 filePath=$wallpaperFilePath");

    final hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);

    if (FAILED(hr)) {
      throw WindowsException(hr);
    }

    var desktopWallpaper = DesktopWallpaper.createInstance();
    try {
      int result = FALSE;

      // モニタの数を取得する
      Pointer<Uint32> monitorDevicePathCountPtr = calloc<Uint32>();
      result = desktopWallpaper.GetMonitorDevicePathCount(monitorDevicePathCountPtr);
      log("result=$result, monitorDevicePathCountPtr.value=${monitorDevicePathCountPtr.value}");

      // すべてのモニタに壁紙を設定する
      Pointer<Utf16> wallpaperFilePathPtr = wallpaperFilePath.toNativeUtf16();
      for (var i=0; i<monitorDevicePathCountPtr.value; i++) {
        Pointer<Pointer<Utf16>> monitorIdPtr = calloc<Pointer<Utf16>>();
        result = desktopWallpaper.GetMonitorDevicePathAt(i, monitorIdPtr);
        log("result=$result, monitorIdPtr=${monitorIdPtr}");

        log("==>SetWallpaper. i=$i");
        desktopWallpaper.SetWallpaper(monitorIdPtr.value, wallpaperFilePathPtr);
        log("<==SetWallpaper");

        // メモリの開放
        free(monitorIdPtr);
      }

      // メモリの開放
      free(wallpaperFilePathPtr);
      free(monitorDevicePathCountPtr);
    } finally {
      free(desktopWallpaper.ptr);
      CoUninitialize();
    }
  }

  /// メインモニタのIDを返す
  int _getMainMonitorId() {
    // モニタの一覧を取得
    var result = EnumDisplayMonitors(
        NULL, // all displays
        nullptr, // no clipping region
        Pointer.fromFunction<MonitorEnumProc>(
            _enumMonitorCallback, // dwData
            0),
        NULL);
    if (result == FALSE) {
      throw WindowsException(result);
    }

    log('Number of monitors: ${_monitors.length}');

    return _findPrimaryMonitor(_monitors);
  }

  static int _enumMonitorCallback(int hMonitor, int hDC, Pointer lpRect, int lParam) {
    _monitors.add(hMonitor);
    return TRUE;
  }

  int _findPrimaryMonitor(List<int> monitors) {
    final monitorInfo = calloc<MONITORINFO>()..ref.cbSize = sizeOf<MONITORINFO>();

    for (final monitor in monitors) {
      final result = GetMonitorInfo(monitor, monitorInfo);
      if (result == TRUE) {
        if (_testBitmask(monitorInfo.ref.dwFlags, MONITORINFOF_PRIMARY)) {
          free(monitorInfo);
          return monitor;
        }
      }
    }

    free(monitorInfo);
    return 0;
  }

  bool _testBitmask(int bitmask, int value) => bitmask & value == value;

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
          ],
        ),
      ),
    );
  }
}
