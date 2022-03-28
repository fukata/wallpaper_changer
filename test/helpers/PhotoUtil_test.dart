import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/photoslibrary/v1.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wallpaper_changer/app.dart' as app;
import 'package:wallpaper_changer/helpers/PhotoUtil.dart';

import 'PhotoUtil_test.mocks.dart';

@GenerateMocks([PhotosLibraryApi, AlbumsResource])
void main() {
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