abstract final class RoutePaths {
  static const home = '/';
  static const forYou = '/for-you';
  static const player = '/player/:dramaId/:episodeId';
  static const myList = '/my-list';
  static const member = '/member';
  static const profile = '/profile';
  static const auth = '/auth';
  static const account = '/account';
  static const store = '/store';
  static const wallet = '/wallet';
  static const membership = '/membership';

  /// 构建会员页面路径，可选参数 [returnToProfile] 控制购买成功后是否跳转到"我的"页面
  static String membershipLocation({bool returnToProfile = false}) {
    if (returnToProfile) {
      return '$membership?returnToProfile=true';
    }
    return membership;
  }

  static const language = '/language';
  static const settings = '/settings';
  static const accountCancellation = '/settings/account-cancellation';
  static const userAgreement = '/settings/user-agreement';
  static const privacyPolicy = '/settings/privacy-policy';
  static const transactionHistory = '/wallet/transaction-history';
  static const consumptionHistory = '/wallet/consumption-history';
  static const recordCoins = '/wallet/record-coins';

  static String playerLocation({
    required String dramaId,
    required String episodeId,
    String? trigger,
    int? userActionAtMs,
  }) {
    final location = '/player/$dramaId/$episodeId';
    final triggerKey = trigger == null ? null : 'trigger';
    final userActionKey = userActionAtMs == null ? null : 'userActionAtMs';
    final queryParameters = <String, String>{
      ?triggerKey: '$trigger',
      ?userActionKey: '$userActionAtMs',
    };
    if (queryParameters.isEmpty) {
      return location;
    }
    return Uri(path: location, queryParameters: queryParameters).toString();
  }
}
