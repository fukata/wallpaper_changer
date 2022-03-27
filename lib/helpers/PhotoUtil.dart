import 'dart:developer';

import 'package:googleapis/photoslibrary/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:wallpaper_changer/app.dart' as app;
import 'package:wallpaper_changer/helpers/RealmUtil.dart';


/// Google Photos から写真を読み込む
Future loadGooglePhotos({
  required AuthClient client,
  required int maxFetchNum,
  String? albumId,
}) async {
  var photosApi = PhotosLibraryApi(client);

  int fetchedMediaItemsNum = 0;
  String? nextPageToken;
  while (fetchedMediaItemsNum < maxFetchNum) {
    SearchMediaItemsRequest request = SearchMediaItemsRequest(
      orderBy: 'MediaMetadata.creation_time desc',
      pageSize: 100,
      pageToken: nextPageToken,
    );

    // APIの制限でalbumIdとfiltersは併用できない
    if (albumId != null && albumId.isNotEmpty) {
      request.albumId = albumId;
    } else {
      request.filters = Filters(mediaTypeFilter: MediaTypeFilter(mediaTypes: ['PHOTO']));
    }

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
      // 画像のみ対応するのでvideoの場合はスキップ
      if (mediaItem.mediaMetadata?.photo == null) {
        continue;
      }

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

/// Google Photos からアルバム一覧を読み込む
Future loadGooglePhotoAlbums({
  required AuthClient client
}) async {
  var photosApi = PhotosLibraryApi(client);

  String? nextPageToken;
  while (true) {
    var response = await photosApi.albums.list(
      pageToken: nextPageToken,
      pageSize: 50,
    );

    if (response.albums == null) {
      log("1");
      break;
    }

    for (var album in response.albums!) {
      log("album=${album.toJson()}");
      _registerAlbum(album);
    }

    nextPageToken = response.nextPageToken;
    if (nextPageToken == null || nextPageToken.isEmpty) {
      log("2");
      break;
    }
  }
}

/// アルバムデータを登録する
app.Album _registerAlbum(Album album) {
  var albums = realm().query<app.Album>(r'id == $0', [album.id!]);
  if (albums.isNotEmpty) {
    var _album = albums.first;
    realm().write(() {
      _album.mediaItemsCount = album.mediaItemsCount!;
    });
    return _album;
  }

  var newAlbum = app.Album(
    album.id!,
    album.title!,
    album.mediaItemsCount!
  );
  realm().write(() {
    realm().add(newAlbum);
  });

  return newAlbum;
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
      DateTime.parse(meta.creationTime!).microsecondsSinceEpoch,
      false);
  realm().write(() {
    realm().add(newMediaItem);
  });

  return newMediaItem;
}
