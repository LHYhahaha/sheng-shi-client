import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import 'language_package.dart';

/// I18n 服务 - 管理语言包的下载、缓存和切换

class I18nService {
  final ApiClient _apiClient;
  final SharedPreferences _prefs;

  I18nService({required ApiClient apiClient, required SharedPreferences prefs})
    : _apiClient = apiClient,
      _prefs = prefs;

  static const String _cacheKey = 'i18n_packages';
  static const String _dirName = 'i18n_packages';

  /// 获取语言包存储目录
  Future<Directory> _getPackageDir() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDocDir.path}/$_dirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 初始化语言包（App启动时调用）
  Future<LanguagePackage> initialize(String languageCode) async {
    try {
      // 获取服务器版本信息
      final versionInfo = await _getVersionInfo();

      // 检查本地缓存
      final localPackage = _getLocalPackage(languageCode);
      if (localPackage != null &&
          localPackage.version == versionInfo['version'] &&
          await File(localPackage.filePath).exists()) {
        return localPackage;
      }

      // 下载新语言包
      return await _downloadAndSave(versionInfo);
    } catch (e) {
      // 网络失败，使用本地缓存
      final localPackage = _getLocalPackage(languageCode);
      if (localPackage != null) {
        return localPackage;
      }
      rethrow;
    }
  }

  /// 切换语言
  Future<LanguagePackage> switchLanguage(String languageCode) async {
    try {
      final versionInfo = await _getVersionInfo();
      final localPackage = _getLocalPackage(languageCode);

      if (localPackage != null &&
          localPackage.version == versionInfo['version'] &&
          await File(localPackage.filePath).exists()) {
        return localPackage;
      }

      return await _downloadAndSave(versionInfo);
    } catch (e) {
      final localPackage = _getLocalPackage(languageCode);
      if (localPackage != null) {
        return localPackage;
      }
      rethrow;
    }
  }

  /// 获取服务器版本信息
  Future<Map<String, dynamic>> _getVersionInfo() async {
    return await _apiClient.get<Map<String, dynamic>>(
      '/i18n/version',
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) {
        if (data is Map<String, dynamic>) {
          return data;
        }
        throw Exception('Invalid version info format');
      },
    );
  }

  /// 下载并保存语言包
  Future<LanguagePackage> _downloadAndSave(
    Map<String, dynamic> versionInfo,
  ) async {
    final languageCode = versionInfo['language_code'] as String;
    final contentUrl = versionInfo['content_url'] as String;

    // 获取当前的请求上下文以获取 token
    final context = _apiClient.requestContext;
    final token = context.accessToken;

    // 下载文件 - 使用 Dio 直接下载，但添加认证头
    final response = await _apiClient.dio.get<String>(
      contentUrl,
      options: Options(
        responseType: ResponseType.plain,
        headers: token != null && token.isNotEmpty
            ? {'Authorization': 'Bearer $token'}
            : {},
      ),
    );

    final content = response.data ?? '';

    // 验证JSON
    jsonDecode(content);

    // 保存文件
    final dir = await _getPackageDir();
    final file = File('${dir.path}/$languageCode.json');
    await file.writeAsString(content);

    // 保存元数据
    final package = LanguagePackage(
      languageCode: languageCode,
      languageName: versionInfo['language_name'] as String,
      version: versionInfo['version'] as int,
      updatedAt: versionInfo['updated_at'] as String,
      filePath: file.path,
    );

    _saveLocalPackage(package);
    return package;
  }

  /// 获取本地缓存的语言包
  LanguagePackage? _getLocalPackage(String languageCode) {
    final json = _prefs.getString(_cacheKey);
    if (json == null) return null;

    try {
      final packages = (jsonDecode(json) as List)
          .map((p) => LanguagePackage.fromJson(p as Map<String, dynamic>))
          .toList();
      return packages.firstWhere(
        (p) => p.languageCode == languageCode,
        orElse: () => throw Exception('Not found'),
      );
    } catch (e) {
      return null;
    }
  }

  /// 保存本地缓存
  void _saveLocalPackage(LanguagePackage package) {
    final json = _prefs.getString(_cacheKey);
    final packages = json != null
        ? (jsonDecode(json) as List)
              .map((p) => LanguagePackage.fromJson(p as Map<String, dynamic>))
              .toList()
        : <LanguagePackage>[];

    final index = packages.indexWhere(
      (p) => p.languageCode == package.languageCode,
    );
    if (index >= 0) {
      packages[index] = package;
    } else {
      packages.add(package);
    }

    _prefs.setString(
      _cacheKey,
      jsonEncode(packages.map((p) => p.toJson()).toList()),
    );
  }

  /// 检查是否需要更新
  Future<bool> needsUpdate(String languageCode) async {
    try {
      final versionInfo = await _getVersionInfo();
      final localPackage = _getLocalPackage(languageCode);

      if (localPackage == null) return true;
      return localPackage.version != versionInfo['version'];
    } catch (e) {
      return false;
    }
  }

  /// 清空所有缓存
  Future<void> clearCache() async {
    await _prefs.remove(_cacheKey);
    final dir = await _getPackageDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
