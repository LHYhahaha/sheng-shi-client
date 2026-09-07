import 'package:drama_client/features/player/data/hls_video_quality_parser.dart';
import 'package:drama_client/features/player/data/hls_local_proxy_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final master = Uri(
    scheme: 'https',
    host: 'cdn.example.test',
    path: '/a/master.m3u8',
  );

  test('parses, deduplicates and orders HLS renditions by height', () {
    final qualities = HlsVideoQualityParser.parse(master, '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=854x480
480/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1500000,RESOLUTION=1280x720
720/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1920x1080
1080/index.m3u8
''');

    expect(qualities.map((quality) => quality.id), ['1080p', '720p', '480p']);
    expect(qualities.first.isMemberOnly, isTrue);
    expect(
      qualities.last.playlistUrl,
      'https://cdn.example.test/a/480/index.m3u8',
    );
  });

  test('keeps the higher bandwidth entry for duplicated heights', () {
    final qualities = HlsVideoQualityParser.parse(master, '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=1280x720
720-low.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1500000,RESOLUTION=1280x720
720-high.m3u8
''');

    expect(qualities, hasLength(1));
    expect(
      qualities.single.playlistUrl,
      'https://cdn.example.test/a/720-high.m3u8',
    );
    expect(qualities.single.bandwidth, 1500000);
  });

  test('automatic quality cap excludes 1080p but retains lower variants', () {
    final filtered = filterHlsMasterPlaylistByMaxHeight('''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1500000,RESOLUTION=1280x720
720.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1920x1080
1080.m3u8
''', maxHeight: 1079);

    expect(filtered, contains('720.m3u8'));
    expect(filtered, isNot(contains('1080.m3u8')));
  });

  test('automatic quality cap keeps a single 1080p rendition playable', () {
    const master = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1920x1080
1080.m3u8
''';

    expect(filterHlsMasterPlaylistByMaxHeight(master, maxHeight: 1079), master);
  });
}
