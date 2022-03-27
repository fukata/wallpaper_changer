import 'dart:developer';

import 'package:googleapis/photoslibrary/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:wallpaper_changer/app.dart' as app;
import 'package:wallpaper_changer/helpers/RealmUtil.dart';


/// Google Photos から写真を読み込む
Future loadGooglePhotos(AuthClient client, int maxFetchNum) async {
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
      DateTime.parse(meta.creationTime!).microsecondsSinceEpoch,
      false);
  realm().write(() {
    realm().add(newMediaItem);
  });

  return newMediaItem;
}
