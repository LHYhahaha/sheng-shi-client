import 'dart:async';

import '../domain/ad_unlock_models.dart';
import '../domain/ad_unlock_repository.dart';

abstract interface class AdMaterialDownloader {
  Future<String> download(AdMaterial material);
}

/// Keeps one downloaded ad material ready for the next unlock session.
class AdMaterialPreloader {
  AdMaterialPreloader({required this.repository, required this.downloader});

  final AdUnlockRepository repository;
  final AdMaterialDownloader downloader;

  AdMaterial? _cachedMaterial;
  String? _cachedFilePath;
  Future<void>? _inFlight;

  AdMaterial? get cachedMaterial => _cachedMaterial;

  String? get cachedFilePath => _cachedFilePath;

  Future<void> ensureCachedMaterial() {
    if (_cachedMaterial != null && _cachedFilePath != null) {
      return Future<void>.value();
    }
    return _inFlight ??= _ensureCachedMaterial().whenComplete(() {
      _inFlight = null;
    });
  }

  Future<bool> tryEnsureCachedMaterial() async {
    try {
      await ensureCachedMaterial();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureCachedMaterial() async {
    final material = await repository.preloadMaterial(
      materialId: _cachedMaterial?.id,
    );
    if (_cachedMaterial?.id == material.id && _cachedFilePath != null) {
      return;
    }
    final filePath = await downloader.download(material);
    _cachedMaterial = material;
    _cachedFilePath = filePath;
  }

  AdUnlockSession applyCachedMaterial(AdUnlockSession session) {
    if (_cachedMaterial?.id != session.material.id || _cachedFilePath == null) {
      return session;
    }
    return session.copyWith(materialFilePath: _cachedFilePath);
  }

  void consumeMaterial(AdUnlockSession session) {
    if (_cachedMaterial?.id != session.material.id) return;
    _cachedMaterial = null;
    _cachedFilePath = null;
    unawaited(ensureCachedMaterial());
  }
}
