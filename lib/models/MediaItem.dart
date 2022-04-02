import 'package:realm/realm.dart';
part 'MediaItem.g.dart';

@RealmModel()
class _MediaItem {
  @PrimaryKey()
  late String id;

  late String filename;
  late String mimeType;
  late int width;
  late int height;
  late int creationTimestamp;
  late bool cached;
}