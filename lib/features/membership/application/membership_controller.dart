import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_cleanup_types.dart';
import '../../entitlement/application/entitlement_controller.dart';
import '../data/membership_repository_provider.dart';
import '../domain/membership_plan.dart';

/// Membership feature 的唯一页面状态入口。
///
/// 会员页展示、套餐选择和 mock 开通弹窗都通过这里管理。真实订阅接入后，客户端只能
/// 触发订单/验单流程，会员权益是否生效必须由服务端权益刷新决定。
final membershipControllerProvider =
    NotifierProvider<MembershipController, MembershipState>(
      MembershipController.new,
    );

/// 会员 mock 开通确认弹窗的本地流程状态。
///
/// 只用于按钮禁用、loading 和完成态展示，不代表 App Store/Google Play 或服务端
/// 已经确认权益。不要用这个 enum 直接驱动 Profile 的会员 active 状态。
enum MembershipPurchaseStatus { idle, processing, success, cancelled }

/// 会员页状态，包含权益展示、套餐选择和 mock 开通确认。
///
/// `isActive` 来自会员接口，不应由客户端 mock purchase success 直接推断。真实接入时，
/// 开通成功必须以服务端权益刷新为准，否则会出现支付成功/失败与会员态不一致。
class MembershipState {
  const MembershipState({
    required this.isLoading,
    required this.isActive,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.plans,
    required this.benefits,
    required this.tips,
    required this.selectedPlanId,
    required this.confirmationPlanId,
    required this.purchaseStatus,
    this.error,
  });

  const MembershipState.initial()
    : isLoading = true,
      isActive = false,
      heroTitle = '',
      heroSubtitle = '',
      plans = const [],
      benefits = const [],
      tips = null,
      selectedPlanId = null,
      confirmationPlanId = null,
      purchaseStatus = MembershipPurchaseStatus.idle,
      error = null;

  /// 会员页是否正在加载权益和套餐数据。
  ///
  /// 不表示购买 processing；购买流程只通过 `purchaseStatus` 表达，避免整页 loading
  /// 遮住确认弹窗状态。
  final bool isLoading;

  /// 当前账号是否已经是会员。
  ///
  /// 这个字段来自会员接口，不应由本地 mock purchase success 直接改写。真实支付后
  /// 需要重新拉取权益或等待服务端回写。
  final bool isActive;

  /// 会员页 hero 主标题。
  ///
  /// 属于营销展示文案，不参与权益判断。后续多语言或远程配置只应影响展示。
  final String heroTitle;

  /// 会员页 hero 副标题。
  ///
  /// 与 `heroTitle` 一样只用于展示，不要在业务逻辑中解析文案判断套餐类型。
  final String heroSubtitle;

  /// 可购买会员套餐列表。
  ///
  /// 套餐价格、周期和标签都以接口返回为准；UI 不应根据数组顺序推断真实推荐策略，
  /// 当前默认选第一个只是 MVP 初始态。
  final List<MembershipPlan> plans;

  /// 会员权益展示列表。
  ///
  /// 只用于说明权益，不代表实际授权开关。播放器解锁仍需要 source/账号权益接口确认。
  final List<MembershipBenefit> benefits;

  /// 会员页提示文案。
  ///
  /// 当前为展示数据，不能作为支付条款或风控判断来源。
  final MembershipTips? tips;

  /// 当前选中的套餐 id。
  ///
  /// 用于卡片高亮；打开确认弹窗后应以 `confirmationPlanId` 为准，防止切换选择影响
  /// 正在处理的购买流程。
  final String? selectedPlanId;

  /// 确认弹窗锁定的套餐 id。
  ///
  /// processing 延迟完成时会再次校验它，避免旧弹窗结果污染新套餐。
  final String? confirmationPlanId;

  /// mock 会员购买流程状态。
  ///
  /// success 只说明客户端确认流程完成，不说明会员权益已生效。真实接入时必须通过
  /// 服务端订单/权益刷新更新 `isActive`。
  final MembershipPurchaseStatus purchaseStatus;

  /// 加载会员页数据时的错误。
  ///
  /// 购买错误未来应与加载错误分开，否则支付失败会错误地把权益页面置为整页失败。
  final Object? error;

  bool get hasContent => !isLoading && error == null;

  MembershipPlan? get selectedPlan => planById(selectedPlanId);

  MembershipPlan? get confirmationPlan => planById(confirmationPlanId);

  MembershipPlan? planById(String? id) {
    if (id == null) {
      return null;
    }

    for (final plan in plans) {
      if (plan.id == id) {
        return plan;
      }
    }
    return null;
  }

  MembershipState copyWith({
    bool? isLoading,
    bool? isActive,
    String? heroTitle,
    String? heroSubtitle,
    List<MembershipPlan>? plans,
    List<MembershipBenefit>? benefits,
    MembershipTips? tips,
    String? selectedPlanId,
    String? confirmationPlanId,
    MembershipPurchaseStatus? purchaseStatus,
    Object? error,
    bool clearError = false,
    bool clearConfirmation = false,
  }) {
    return MembershipState(
      isLoading: isLoading ?? this.isLoading,
      isActive: isActive ?? this.isActive,
      heroTitle: heroTitle ?? this.heroTitle,
      heroSubtitle: heroSubtitle ?? this.heroSubtitle,
      plans: plans ?? this.plans,
      benefits: benefits ?? this.benefits,
      tips: tips ?? this.tips,
      selectedPlanId: selectedPlanId ?? this.selectedPlanId,
      confirmationPlanId: clearConfirmation
          ? null
          : confirmationPlanId ?? this.confirmationPlanId,
      purchaseStatus: purchaseStatus ?? this.purchaseStatus,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// 会员页控制器。
///
/// 控制器保持“加载会员权益”和“购买确认状态”分离。这样接支付后可以先完成订单流程，
/// 再通过 membership repository 重新拉取权益，而不是在 UI 层临时拼会员态。
class MembershipController extends Notifier<MembershipState> {
  int _generation = 0;
  int _purchaseGeneration = 0;

  @override
  MembershipState build() => const MembershipState.initial();

  void resetForSessionCleanup(SessionCleanupReason reason) {
    ++_generation;
    ++_purchaseGeneration;
    state = const MembershipState.initial();
  }

  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearConfirmation: true,
    );

    try {
      final data = await ref
          .read(membershipRepositoryProvider)
          .fetchMembership();
      if (!_isCurrent(generation)) {
        return;
      }

      state = state.copyWith(
        isLoading: false,
        isActive: data.isActive,
        heroTitle: data.heroTitle,
        heroSubtitle: data.heroSubtitle,
        plans: List<MembershipPlan>.unmodifiable(data.plans),
        benefits: List<MembershipBenefit>.unmodifiable(data.benefits),
        tips: data.tips,
        selectedPlanId: data.plans.isEmpty ? null : data.plans.first.id,
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

  void selectPlan(String id) {
    if (state.planById(id) == null) {
      return;
    }

    state = state.copyWith(selectedPlanId: id);
  }

  void showConfirmation() {
    final selectedPlan = state.selectedPlan;
    if (selectedPlan == null) {
      return;
    }

    // 打开确认弹窗即刷新购买代次，防止旧弹窗的异步 processing 结果污染新套餐。
    _purchaseGeneration++;
    state = state.copyWith(
      confirmationPlanId: selectedPlan.id,
      purchaseStatus: MembershipPurchaseStatus.idle,
    );
  }

  void hideConfirmation() {
    _purchaseGeneration++;
    state = state.copyWith(
      purchaseStatus: MembershipPurchaseStatus.idle,
      clearConfirmation: true,
    );
  }

  Future<void> confirmMockPurchase() async {
    if (state.confirmationPlan == null ||
        state.purchaseStatus != MembershipPurchaseStatus.idle) {
      return;
    }

    // mock success 会写入共享 EntitlementState，让 Player/Profile/Wallet 后续读取同一份
    // 会员状态。真实接入时这里仍应等待服务端订单确认或触发权益刷新，不能只信客户端状态。
    final purchaseGeneration = _purchaseGeneration;
    final planId = state.confirmationPlanId;
    state = state.copyWith(purchaseStatus: MembershipPurchaseStatus.processing);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (purchaseGeneration != _purchaseGeneration ||
        state.confirmationPlanId != planId ||
        state.purchaseStatus != MembershipPurchaseStatus.processing) {
      return;
    }

    await ref
        .read(entitlementControllerProvider.notifier)
        .grantMockMembership(source: 'membership:$planId');

    if (purchaseGeneration != _purchaseGeneration ||
        state.confirmationPlanId != planId ||
        state.purchaseStatus != MembershipPurchaseStatus.processing) {
      return;
    }

    state = state.copyWith(purchaseStatus: MembershipPurchaseStatus.success);
  }

  void cancelMockPurchase() {
    if (state.purchaseStatus != MembershipPurchaseStatus.idle) {
      return;
    }

    // processing 中不允许取消本地状态，避免支付渠道仍在处理时 UI 先进入 cancelled。
    state = state.copyWith(purchaseStatus: MembershipPurchaseStatus.cancelled);
  }

  bool _isCurrent(int generation) => generation == _generation;
}
