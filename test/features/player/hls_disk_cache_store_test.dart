import 'package:drama_client/features/player/data/hls_disk_cache_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default disk cache budget favors reusable media segments', () {
    final cacheStore = HlsDiskCacheStore();

    expect(cacheStore.maxBytes, 1024 * 1024 * 1024);
  });

  test('cache key ignores signatures but keeps playback query params', () {
    final firstSigned = HlsDiskCacheStore.keyForUri(
      Uri.parse(
        'https://cdn.example.test/drama/ep1/seg.ts?quality=720p&expires=1&verify=a',
      ),
    );
    final secondSigned = HlsDiskCacheStore.keyForUri(
      Uri.parse(
        'https://cdn.example.test/drama/ep1/seg.ts?quality=720p&expires=2&verify=b',
      ),
    );
    final differentQuality = HlsDiskCacheStore.keyForUri(
      Uri.parse(
        'https://cdn.example.test/drama/ep1/seg.ts?quality=1080p&expires=2&verify=b',
      ),
    );

    expect(firstSigned, secondSigned);
    expect(firstSigned, contains('quality=720p'));
    expect(firstSigned, isNot(contains('expires=')));
    expect(firstSigned, isNot(contains('verify=')));
    expect(differentQuality, isNot(firstSigned));
  });
}
