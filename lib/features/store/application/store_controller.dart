import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store_repository_provider.dart';
import '../domain/store_package.dart';

final storeControllerProvider = NotifierProvider<StoreController, StoreState>(
  StoreController.new,
);

enum StorePurchaseStatus { idle, processing, success, cancelled }

/// 商店页状态，覆盖充值套餐、余额和 mock 购买确认弹窗。
///
/// 购买状态只服务 MVP 交互演示，不代表真实支付结果。接真实支付时，success 必须由
/// 服务端订单/收据校验后回写，不能只信客户端按钮点击或本地延迟完成。
class StoreState {
  const StoreState({
    required this.isLoading,
    required this.balance,
    required this.coinPackages,
    required this.vipPackages,
    required this.tips,
    required this.selectedPackageId,
    required this.confirmationPackageId,
    required this.purchaseStatus,
    this.error,
  });

  const StoreState.initial()
    : isLoading = true,
      balance = 0,
      coinPackages = const [],
      vipPackages = const [],
      tips = null,
      selectedPackageId = null,
      confirmationPackageId = null,
      purchaseStatus = StorePurchaseStatus.idle,
      error = null;

  final bool isLoading;
  final int balance;
  final List<StorePackage> coinPackages;
  final List<StorePackage> vipPackages;
  final StoreTips? tips;
  final String? selectedPackageId;
  final String? confirmationPackageId;
  final StorePurchaseStatus purchaseStatus;
  final Object? error;

  List<StorePackage> get packages => [...coinPackages, ...vipPackages];

  StorePackage? get selectedPackage => packageById(selectedPackageId);

  StorePackage? get confirmationPackage => packageById(confirmationPackageId);

  bool get hasContent => !isLoading && error == null;

  StorePackage? packageById(String? id) {
    if (id == null) {
      return null;
    }

    for (final package in packages) {
      if (package.id == id) {
        return package;
      }
    }
    return null;
  }

  StoreState copyWith({
    bool? isLoading,
    int? balance,
    List<StorePackage>? coinPackages,
    List<StorePackage>? vipPackages,
    StoreTips? tips,
    String? selectedPackageId,
    String? confirmationPackageId,
    StorePurchaseStatus? purchaseStatus,
    Object? error,
    bool clearError = false,
    bool clearConfirmation = false,
  }) {
    return StoreState(
      isLoading: isLoading ?? this.isLoading,
      balance: balance ?? this.balance,
      coinPackages: coinPackages ?? this.coinPackages,
      vipPackages: vipPackages ?? this.vipPackages,
      tips: tips ?? this.tips,
      selectedPackageId: selectedPackageId ?? this.selectedPackageId,
      confirmationPackageId: clearConfirmation
          ? null
          : confirmationPackageId ?? this.confirmationPackageId,
      purchaseStatus: purchaseStatus ?? this.purchaseStatus,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// 商店页控制器。
///
/// 这里集中管理套餐加载、选择和确认弹窗状态。UI 只读写 controller，不直接 new
/// repository，是为了后续接支付 SDK、订单接口和风控校验时仍能保持单一状态机入口。
class StoreController extends Notifier<StoreState> {
  int _generation = 0;
  int _purchaseGeneration = 0;

  @override
  StoreState build() => const StoreState.initial();

  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearConfirmation: true,
    );

    try {
      final data = await ref.read(storeRepositoryProvider).fetchRechargeData();
      if (!_isCurrent(generation)) {
        return;
      }

      // 默认选择第一个金币包，金币为空再退到 VIP 包。这个策略只影响 UI 初始态，
      // 不代表服务端推荐或最终下单项，真实支付仍要以 confirmationPackageId 为准。
      final selectedId = data.coinPackages.isNotEmpty
          ? data.coinPackages.first.id
          : data.vipPackages.isNotEmpty
          ? data.vipPackages.first.id
          : null;
      state = state.copyWith(
        isLoading: false,
        balance: data.balance,
        coinPackages: List<StorePackage>.unmodifiable(data.coinPackages),
        vipPackages: List<StorePackage>.unmodifiable(data.vipPackages),
        tips: data.tips,
        selectedPackageId: selectedId,
        clearError: true,
      );
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }

      state = state.copyWith(isLoading: false, error: error);
    }
  }

  Future<void> retry() => load();

  void selectPackage(String id) {
    if (state.packageById(id) == null) {
      return;
    }

    state = state.copyWith(selectedPackageId: id);
  }

  void showConfirmation() {
    final selectedPackage = state.selectedPackage;
    if (selectedPackage == null) {
      return;
    }

    // 每次打开确认弹窗都递增 purchaseGeneration，使旧的 processing 延迟结果失效。
    // 否则用户关闭 A 包再打开 B 包时，A 包的异步 success 可能落到 B 包弹窗上。
    _purchaseGeneration++;
    state = state.copyWith(
      confirmationPackageId: selectedPackage.id,
      purchaseStatus: StorePurchaseStatus.idle,
    );
  }

  void hideConfirmation() {
    _purchaseGeneration++;
    state = state.copyWith(
      purchaseStatus: StorePurchaseStatus.idle,
      clearConfirmation: true,
    );
  }

  Future<void> confirmMockPurchase() async {
    if (state.confirmationPackage == null ||
        state.purchaseStatus != StorePurchaseStatus.idle) {
      return;
    }

    // mock 只模拟“processing -> success”的 UI 节奏。真实支付不能在这里直接加余额：
    // 必须等服务端校验支付渠道回调/订单状态后，再刷新钱包和会员权益。
    final purchaseGeneration = _purchaseGeneration;
    final packageId = state.confirmationPackageId;
    state = state.copyWith(purchaseStatus: StorePurchaseStatus.processing);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (purchaseGeneration != _purchaseGeneration ||
        state.confirmationPackageId != packageId ||
        state.purchaseStatus != StorePurchaseStatus.processing) {
      return;
    }

    state = state.copyWith(purchaseStatus: StorePurchaseStatus.success);
  }

  void cancelMockPurchase() {
    if (state.purchaseStatus != StorePurchaseStatus.idle) {
      return;
    }

    // 取消只在 idle 允许，processing 期间不允许把本地状态改成 cancelled，
    // 避免真实支付接入后出现“渠道仍在处理中但 UI 已取消”的错觉。
    state = state.copyWith(purchaseStatus: StorePurchaseStatus.cancelled);
  }

  bool _isCurrent(int generation) => generation == _generation;
}
