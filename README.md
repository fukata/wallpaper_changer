# wallpaper_changer

これは Google Photos の写真を壁紙に設定するためのGUIアプリです。

## 対応OS

- Windows

## DEMO

[DEMO](https://gyazo.com/3eba8cd1e27cd520059fb07f88eed8a4)

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