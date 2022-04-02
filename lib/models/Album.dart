import 'package:realm/realm.dart';
part 'Album.g.dart';

@RealmModel()
class _Album {
  @PrimaryKey()
  late String id;

  late String title;
  late String mediaItemsCount;
}