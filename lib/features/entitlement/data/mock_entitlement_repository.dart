import '../domain/entitlement_repository.dart';
import '../domain/episode_unlock_type.dart';
import '../domain/user_entitlement_state.dart';

/// Entitlement mock repository。
///
/// 它刻意模拟了余额、会员、自动解锁、已解锁集合、扣费失败和 operationId 幂等等
/// 真实服务端必须支持的边界。测试可以直接构造不同 fixture，但 UI/Controller 不应该
/// 依赖这个具体类。
class MockEntitlementRepository implements EntitlementRepository {
  MockEntitlementRepository({UserEntitlementState? initialState})
    : _state = initialState ?? loggedInNonMemberEnoughCoinsAutoOffState();

  factory MockEntitlementRepository.guest() => MockEntitlementRepository(
    initialState: const UserEntitlementState.guest(),
  );

  factory MockEntitlementRepository.loggedInNonMemberEnoughCoinsAutoOn() =>
      MockEntitlementRepository(
        initialState: loggedInNonMemberEnoughCoinsAutoOnState(),
      );

  factory MockEntitlementRepository.loggedInNonMemberEnoughCoinsAutoOff() =>
      MockEntitlementRepository(
        initialState: loggedInNonMemberEnoughCoinsAutoOffState(),
      );

  factory MockEntitlementRepository.loggedInNonMemberLowCoins() =>
      MockEntitlementRepository(initialState: loggedInNonMemberLowCoinsState());

  factory MockEntitlementRepository.loggedInMember() =>
      MockEntitlementRepository(initialState: loggedInMemberState());

  factory MockEntitlementRepository.partialUnlocks() =>
      MockEntitlementRepository(initialState: partialUnlocksState());

  factory MockEntitlementRepository.deductFailsOnce() {
    return MockEntitlementRepository(
      initialState: loggedInNonMemberEnoughCoinsAutoOnState(),
    )..failNextCoinDeduction = true;
  }

  static UserEntitlementState loggedInNonMemberEnoughCoinsAutoOnState() {
    return const UserEntitlementState(
      isGuest: false,
      isMember: false,
      coinBalance: 120,
      autoUnlockEnabled: true,
      unlockedEpisodeIds: <String>{},
    );
  }

  static UserEntitlementState loggedInNonMemberEnoughCoinsAutoOffState() {
    return const UserEntitlementState(
      isGuest: false,
      isMember: false,
      coinBalance: 120,
      autoUnlockEnabled: false,
      unlockedEpisodeIds: <String>{},
    );
  }

  static UserEntitlementState loggedInNonMemberLowCoinsState() {
    return const UserEntitlementState(
      isGuest: false,
      isMember: false,
      coinBalance: 10,
      autoUnlockEnabled: false,
      unlockedEpisodeIds: <String>{},
    );
  }

  static UserEntitlementState loggedInMemberState() {
    return const UserEntitlementState(
      isGuest: false,
      isMember: true,
      coinBalance: 20,
      autoUnlockEnabled: false,
      unlockedEpisodeIds: <String>{},
    );
  }

  static UserEntitlementState partialUnlocksState() {
    return const UserEntitlementState(
      isGuest: false,
      isMember: false,
      coinBalance: 120,
      autoUnlockEnabled: false,
      unlockedEpisodeIds: <String>{'found-you-ep-4'},
    );
  }

  UserEntitlementState _state;

  /// 下一次金币扣费是否失败。
  ///
  /// 用来覆盖“扣费失败不应添加已解锁集合”的测试；真实阶段应由服务端错误码表达。
  bool failNextCoinDeduction = false;

  final Map<String, UserEntitlementState> _operationResultsById =
      <String, UserEntitlementState>{};

  @override
  Future<UserEntitlementState> fetchState() async => _state;

  @override
  Future<UserEntitlementState> setAutoUnlockEnabled(bool enabled) async {
    _state = _state.copyWith(
      autoUnlockEnabled: enabled,
      clearLastUnlockError: true,
    );
    return _state;
  }

  @override
  Future<UserEntitlementState> grantMockMembership({
    required String source,
  }) async {
    _state = _state.copyWith(
      isGuest: false,
      isMember: true,
      clearLastUnlockError: true,
    );
    return _state;
  }

  @override
  Future<UserEntitlementState> grantMockCoins({
    required int amount,
    required String source,
  }) async {
    _state = _state.copyWith(
      isGuest: false,
      coinBalance: _state.coinBalance + amount,
      clearLastUnlockError: true,
    );
    return _state;
  }

  @override
  Future<UserEntitlementState> unlockEpisodeWithCoins({
    required String dramaId,
    required String episodeId,
    required int price,
    required String operationId,
  }) async {
    final existingResult = _operationResultsById[operationId];
    if (existingResult != null) {
      _state = existingResult;
      return _state;
    }

    if (_state.unlockedEpisodeIds.contains(episodeId)) {
      _operationResultsById[operationId] = _state;
      return _state;
    }

    if (failNextCoinDeduction) {
      failNextCoinDeduction = false;
      throw StateError('Mock coin deduction failed');
    }

    if (_state.coinBalance < price) {
      throw StateError('Insufficient coins');
    }

    _state = _state.copyWith(
      isGuest: false,
      coinBalance: _state.coinBalance - price,
      unlockedEpisodeIds: <String>{..._state.unlockedEpisodeIds, episodeId},
      clearLastUnlockError: true,
    );
    _operationResultsById[operationId] = _state;
    return _state;
  }
}

/// Entitlement 单测和 mock UI 共用的剧集 fixture。
///
/// 后续接真实内容接口后，这些 fixture 可以迁移到测试专用 builders；当前放在 data 层
/// 是为了让 E1 决策矩阵有稳定、可读的输入。
class MockEntitlementEpisodeFixture {
  const MockEntitlementEpisodeFixture({
    required this.dramaId,
    required this.episodeId,
    required this.itemId,
    required this.unlockType,
    this.price = 0,
    this.isUnavailable = false,
  });

  final String dramaId;
  final String episodeId;
  final String itemId;
  final EpisodeUnlockType unlockType;
  final int price;
  final bool isUnavailable;
}

const mockEntitlementEpisodeFixtures = <MockEntitlementEpisodeFixture>[
  MockEntitlementEpisodeFixture(
    dramaId: 'found-you',
    episodeId: 'found-you-ep-1',
    itemId: 'found-you-0-ep-1',
    unlockType: EpisodeUnlockType.free,
  ),
  MockEntitlementEpisodeFixture(
    dramaId: 'found-you',
    episodeId: 'found-you-ep-2',
    itemId: 'found-you-0-ep-2',
    unlockType: EpisodeUnlockType.free,
  ),
  MockEntitlementEpisodeFixture(
    dramaId: 'found-you',
    episodeId: 'found-you-ep-3',
    itemId: 'found-you-0-ep-3',
    unlockType: EpisodeUnlockType.free,
  ),
  MockEntitlementEpisodeFixture(
    dramaId: 'found-you',
    episodeId: 'found-you-ep-4',
    itemId: 'found-you-0-ep-4',
    unlockType: EpisodeUnlockType.coins,
    price: 30,
  ),
  MockEntitlementEpisodeFixture(
    dramaId: 'found-you',
    episodeId: 'found-you-ep-5',
    itemId: 'found-you-0-ep-5',
    unlockType: EpisodeUnlockType.coins,
    price: 50,
  ),
  MockEntitlementEpisodeFixture(
    dramaId: 'found-you',
    episodeId: 'found-you-ep-6',
    itemId: 'found-you-0-ep-6',
    unlockType: EpisodeUnlockType.coins,
    price: 80,
  ),
  MockEntitlementEpisodeFixture(
    dramaId: 'heart-thief',
    episodeId: 'heart-thief-ep-1',
    itemId: 'heart-thief-0-ep-1',
    unlockType: EpisodeUnlockType.membership,
  ),
  MockEntitlementEpisodeFixture(
    dramaId: 'reborn-love',
    episodeId: 'reborn-love-ep-1',
    itemId: 'reborn-love-0-ep-1',
    unlockType: EpisodeUnlockType.free,
  ),
  MockEntitlementEpisodeFixture(
    dramaId: 'found-you',
    episodeId: 'found-you-ep-unavailable',
    itemId: 'found-you-0-ep-unavailable',
    unlockType: EpisodeUnlockType.coins,
    price: 30,
    isUnavailable: true,
  ),
];

MockEntitlementEpisodeFixture mockEntitlementEpisodeFixture(String episodeId) {
  return mockEntitlementEpisodeFixtures.firstWhere(
    (fixture) => fixture.episodeId == episodeId,
  );
}
