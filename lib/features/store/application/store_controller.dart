import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store_repository_provider.dart';
import '../domain/store_package.dart';

/// Store feature 的唯一页面状态入口。
///
/// UI、弹窗和测试都通过这个 provider 读写商店状态，避免各处直接 new repository 或
/// 自行模拟购买流程。后续接真实订单/IAP 时，订单状态、验单和权益刷新都应从这里
/// 统一进入，而不是把支付结果散落到按钮回调里。
final storeControllerProvider = NotifierProvider<StoreController, StoreState>(
  StoreController.new,
);

/// 商店 mock 购买确认弹窗的本地流程状态。
///
/// 这些状态只描述“弹窗交互走到哪一步”，不是支付渠道或服务端订单状态。真实支付接入
/// 后，`success` 也只能代表服务端确认后的结果，不能由客户端延迟任务自行认定。
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

  /// 商店页是否正在加载充值数据。
  ///
  /// 只覆盖套餐/余额初始加载和 retry，不表示支付 processing。支付中的 loading 由
  /// `purchaseStatus` 表达，避免整页 loading 和确认弹窗 loading 混在一起。
  final bool isLoading;

  /// 当前展示的金币余额。
  ///
  /// mock 阶段来自充值页接口数据；真实接入后应以钱包/服务端刷新为准。客户端 mock
  /// purchase success 不能直接累加这个字段。
  final int balance;

  /// 金币充值套餐列表。
  ///
  /// 只用于展示和选择，不代表已创建订单。点击确认时仍要用 `confirmationPackageId`
  /// 锁定下单对象，防止 selected 在弹窗打开后被其他交互改变。
  final List<StorePackage> coinPackages;

  /// VIP 相关售卖套餐列表。
  ///
  /// 与会员页套餐展示可能来自不同接口口径，不能简单和 MembershipPlan 互相替代。
  final List<StorePackage> vipPackages;

  /// 商店提示文案。
  ///
  /// 当前为 mock 固定文案；未来如由服务端下发，仍应作为展示数据处理，不参与支付判断。
  final StoreTips? tips;

  /// 当前页面选中的套餐 id。
  ///
  /// 这是列表选择态，用于高亮卡片；不是最终购买对象。最终购买对象由打开确认弹窗时
  /// 写入的 `confirmationPackageId` 决定。
  final String? selectedPackageId;

  /// 当前确认弹窗锁定的套餐 id。
  ///
  /// 弹窗打开后用它隔离异步 purchase result。用户切换列表选择或关闭弹窗时，旧的
  /// processing 结果不能落到新的确认对象上。
  final String? confirmationPackageId;

  /// mock 购买确认流程状态。
  ///
  /// 只表达客户端弹窗流程：idle/processing/success/cancelled。真实支付成功必须等待
  /// 服务端订单或渠道收据确认，不能只依赖这个字段发放金币/权益。
  final StorePurchaseStatus purchaseStatus;

  /// 加载商店数据时的错误。
  ///
  /// 支付失败未来应单独建订单错误或 purchase error，不要复用整页 error，否则支付
  /// 弹窗错误可能把套餐列表误清空。
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
