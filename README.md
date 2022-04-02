# wallpaper_changer

これは Google Photos の写真を壁紙に設定するためのGUIアプリです。

## 変更履歴

[CHANGELOG](./CHANGELOG.md)

## 対応OS

- Windows

## デモ

[動画](https://gyazo.com/b43e84122321498834c30caba8029777)

## Setup

.env

```dotenv
GOOGLE_CLIENT_ID='<YOUR GOOGLE CLIENT ID>'
GOOGLE_CLIENT_SECRET='<YOUR GOOGLE CLIENT SECRET>'
```

## データディレクトリを変更する

環境変数 `APP_DATA_DIR` にディレクトリのパスを指定することでデータディレクトリを変更することが出来ます。

```shell
# .env
APP_DATA_DIR='C:\Users\fukata\Documents\WallpaperChanger_dev'
```

## Realm Modelを生成する

```shell
$ flutter pub run realm generate
```

## msixパッケージを作る

```shell
$ flutter pub run msix:create
```

## テスト

```shell
$ flutter pub run build_runner build
$ flutter test
```

### realm_dart.dllが読み込めない時

`flutter test` を実行した時に下記のようなエラーが出た場合、 `realm_dart.dll` を `C:\Windows\System32` にコピーすることで認識するようになります。

`realm_dart.dll` は `windows/flutter/ephemeral/.plugin_symlinks/realm/windows/binary/windows/realm_dart.dll` にあります。

```shell
Invalid argument(s): Failed to load dynamic library 'realm_dart.dll': error code 126
```