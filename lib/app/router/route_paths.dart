abstract final class RoutePaths {
  static const home = '/';
  static const forYou = '/for-you';
  static const player = '/player/:dramaId/:episodeId';
  static const myList = '/my-list';
  static const profile = '/profile';
  static const store = '/store';
  static const wallet = '/wallet';
  static const membership = '/membership';
  static const language = '/language';
  static const transactionHistory = '/wallet/transaction-history';
  static const consumptionHistory = '/wallet/consumption-history';
  static const recordCoins = '/wallet/record-coins';

  static String playerLocation({
    required String dramaId,
    required String episodeId,
  }) {
    return '/player/$dramaId/$episodeId';
  }
}
