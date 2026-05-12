import 'drama.dart';

abstract interface class DramaRepository {
  Future<List<Drama>> listDramas({String? category});
}
