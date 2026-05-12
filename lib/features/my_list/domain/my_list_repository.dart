import 'my_list_item.dart';

abstract interface class MyListRepository {
  Future<List<MyListItem>> fetchItems({required MyListTab tab});
}
