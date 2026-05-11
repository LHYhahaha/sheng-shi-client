abstract final class RoutePaths {
  static const home = '/';
  static const player = '/player/:dramaId/:episodeId';

  static String playerLocation({
    required String dramaId,
    required String episodeId,
  }) {
    return '/player/$dramaId/$episodeId';
  }
}
