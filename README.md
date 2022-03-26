# wallpaper_changer

This is Sample Project.

Change wallpaper for Windows.

## DEMO

[DEMO](https://gyazo.com/3eba8cd1e27cd520059fb07f88eed8a4)

## Setup

.env

```dotenv
GOOGLE_CLIENT_ID='<YOUR GOOGLE CLIENT ID>'
GOOGLE_CLIENT_SECRET='<YOUR GOOGLE CLIENT SECRET>'
```

## Generate Realm Model

```shell
$ flutter pub run realm generate
```

## msixパッケージを作る場合の注意点

```shell
$ flutter build windows --release
$ flutter pub run msix:create
```