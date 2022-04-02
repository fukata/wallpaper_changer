import 'dart:developer';

import 'package:googleapis/photoslibrary/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:wallpaper_changer/helpers/RealmUtil.dart';
import 'package:wallpaper_changer/models/Album.dart' as AlbumModel;
import 'package:wallpaper_changer/models/MediaItem.dart' as MediaItemModel;


/// Google Photos から写真を読み込む
Future loadGooglePhotos({
  required PhotosLibraryApi photosApi,
  required int maxFetchNum,
  required SearchMediaItemsRequest request,
  MediaItemModel.MediaItem Function(MediaItem mediaItem) onRegisterMediaItem = _onRegisterMediaItem
}) async {
  int fetchedMediaItemsNum = 0;
  String? nextPageToken;
  while (fetchedMediaItemsNum < maxFetchNum) {
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
      onRegisterMediaItem(mediaItem);
    }

    if (fetchedMediaItemsNum > maxFetchNum) {
      break;
    }

    nextPageToken = response.nextPageToken;
    if (nextPageToken == null) {
      break;
    }

    request.pageToken = nextPageToken;
  }
}

/// `loadGooglePhotos` に渡すリクエストオブジェクトを生成して返す
SearchMediaItemsRequest makeSearchMediaItemsRequest({
  String orderBy = 'MediaMetadata.creation_time desc',
  int pageSize = 100,
  String? albumId,
  Filters? filters,
  String? pageToken,
}) {
  SearchMediaItemsRequest request = SearchMediaItemsRequest(
    orderBy: orderBy,
    pageSize: pageSize,
    pageToken: pageToken,
  );

  // APIの制限でalbumIdとfiltersは併用できない
  if (albumId != null) {
    request.albumId = albumId;
  } else if (filters != null) {
    request.filters = filters;
  }

  return request;
}

/// Google Photos からアルバム一覧を読み込む
Future loadGooglePhotoAlbums({
  required PhotosLibraryApi photosApi,
  AlbumModel.Album Function(Album album) onRegisterAlbum = _onRegisterAlbum
}) async {
  String? nextPageToken;
  while (true) {
    var response = await photosApi.albums.list(
      pageToken: nextPageToken,
      pageSize: 50,
    );

    if (response.albums == null) {
      break;
    }

    for (var album in response.albums!) {
      log("album=${album.toJson()}");
      onRegisterAlbum(album);
    }

    nextPageToken = response.nextPageToken;
    if (nextPageToken == null || nextPageToken.isEmpty) {
      break;
    }
  }
}

PhotosLibraryApi makePhotosLibraryApi(AuthClient client) => PhotosLibraryApi(client);

/// アルバムデータを登録する
AlbumModel.Album _onRegisterAlbum(Album album) {
  var albums = realm().query<AlbumModel.Album>(r'id == $0', [album.id!]);
  if (albums.isNotEmpty) {
    var _album = albums.first;
    realm().write(() {
      _album.mediaItemsCount = album.mediaItemsCount!;
    });
    return _album;
  }

  var newAlbum = AlbumModel.Album(
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
MediaItemModel.MediaItem _onRegisterMediaItem(MediaItem mediaItem) {
  var mediaItems = realm().query<MediaItemModel.MediaItem>(r'id == $0', [mediaItem.id!]);
  if (mediaItems.isNotEmpty) {
    return mediaItems.first;
  }

  var meta = mediaItem.mediaMetadata!;
  var newMediaItem = MediaItemModel.MediaItem(
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
