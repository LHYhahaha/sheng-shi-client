import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../application/ad_material_preloader.dart';
import '../domain/ad_unlock_models.dart';

class FileAdMaterialDownloader implements AdMaterialDownloader {
  FileAdMaterialDownloader({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<String> download(AdMaterial material) async {
    final cacheDirectory = await getTemporaryDirectory();
    final directory = Directory('${cacheDirectory.path}/ad_unlock_materials');
    await directory.create(recursive: true);
    final target = File('${directory.path}/${material.id}.material');
    if (await target.exists() && await target.length() > 0) {
      return target.path;
    }
    final temporary = File('${target.path}.downloading');
    await _dio.download(material.fileUrl, temporary.path);
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
    return target.path;
  }
}
