import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/photoslibrary/v1.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wallpaper_changer/app.dart' as app;
import 'package:wallpaper_changer/helpers/PhotoUtil.dart';

import 'PhotoUtil_test.mocks.dart';

@GenerateMocks([PhotosLibraryApi, AlbumsResource, MediaItemsResource])
void main() {
  group("loadGooglePhotos", () {
    test("call 0 times onRegisterMediaItem if mediaItems is null", () async {
      final photosApi = MockPhotosLibraryApi();
      final mediaItems = MockMediaItemsResource();

      SearchMediaItemsRequest request = makeSearchMediaItemsRequest();
      when(photosApi.mediaItems).thenReturn(mediaItems);
      when(
          mediaItems.search(request)
      ).thenAnswer((_) async => SearchMediaItemsResponse());

      var called = 0;
      await loadGooglePhotos(
          photosApi: photosApi,
          maxFetchNum: 10,
          request: request,
          onRegisterMediaItem: (_) {
            called++;
            return app.MediaItem("id", "filename", "mimeType", 0, 0, 0, false);
          }
      );

      expect(called, 0);
    });

    test("call 3 times onRegisterMediaItem if have 3 mediaItems", () async {
      final photosApi = MockPhotosLibraryApi();
      final mediaItems = MockMediaItemsResource();

      SearchMediaItemsRequest request = makeSearchMediaItemsRequest();
      when(photosApi.mediaItems).thenReturn(mediaItems);
      when(
          mediaItems.search(request)
      ).thenAnswer((_) async => SearchMediaItemsResponse(
        mediaItems: [
          MediaItem(mediaMetadata: MediaMetadata(photo: Photo())),
          MediaItem(mediaMetadata: MediaMetadata(photo: Photo())),
          MediaItem(mediaMetadata: MediaMetadata(video: Video())),
          MediaItem(mediaMetadata: MediaMetadata(photo: Photo())),
        ]
      ));

      var called = 0;
      await loadGooglePhotos(
          photosApi: photosApi,
          maxFetchNum: 10,
          request: request,
          onRegisterMediaItem: (_) {
            called++;
            return app.MediaItem("id", "filename", "mimeType", 0, 0, 0, false);
          }
      );

      expect(called, 3);
    });
  });

  group("loadGooglePhotoAlbums", () {
    test("call 0 times onRegisterAlbum if albums is null", () async {
      final photosApi = MockPhotosLibraryApi();
      final albums = MockAlbumsResource();

      when(photosApi.albums).thenReturn(albums);
      when(
        albums.list(pageToken: null, pageSize: 50)
      ).thenAnswer((_) async => ListAlbumsResponse());

      var called = 0;
      await loadGooglePhotoAlbums(
        photosApi: photosApi,
        onRegisterAlbum: (_) {
          called++;
          return app.Album("id", "title", "mediaItemsCount");
        }
      );

      expect(called, 0);
    });

    test("call 3 times onRegisterAlbum if have 3 albums", () async {
      final photosApi = MockPhotosLibraryApi();
      final albums = MockAlbumsResource();

      when(photosApi.albums).thenReturn(albums);
      when(
          albums.list(pageToken: null, pageSize: 50)
      ).thenAnswer((_) async => ListAlbumsResponse(
        albums: <Album>[
          Album(),
          Album(),
          Album(),
        ]
      ));

      var called = 0;
      await loadGooglePhotoAlbums(
          photosApi: photosApi,
          onRegisterAlbum: (_) {
            called++;
            return app.Album("id", "title", "mediaItemsCount");
          }
      );

      expect(called, 3);
    });
  });
}