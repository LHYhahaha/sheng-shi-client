import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../features/bottom_tab_config/application/bottom_tab_config_controller.dart';
import '../../../features/bottom_tab_config/application/dynamic_tab_analytics.dart';
import '../../../features/bottom_tab_config/data/dto/bottom_tab_response_dto.dart';
import '../../../l10n/app_localizations.dart';

/// 应用底部主导航。
///
/// 只服务五个 shell tab。播放器全屏、My List 编辑等场景应通过 shell chrome provider
/// 隐藏它，不要在单个页面里复制导航栏。
class AppBottomNavigation extends ConsumerWidget {
  const AppBottomNavigation({
    required this.currentIndex,
    required this.onDestinationSelected,
    super.key,
  });

  static const _contentWidth = 354.0;
  static const _itemWidth = 64.0;
  static const _iconSize = 24.0;
  static const _standardBackgroundColor = Color(0x33000000);
  static const _standardInactiveColor = Color(0x52FFFFFF);
  static const _specialInactiveColor = Color(0xFF807F7F);

  static const _items = [
    _BottomNavigationItem(
      label: _BottomNavigationLabel.home,
      slot: 'home',
      selectedAssetPath: 'assets/navigation/home_selected.png',
      unselectedAssetPath: 'assets/navigation/home_unselected.png',
      specialUnselectedAssetPath: 'assets/navigation/home_special.png',
      fallbackIcon: Icons.home_rounded,
    ),
    _BottomNavigationItem(
      label: _BottomNavigationLabel.forYou,
      slot: 'recommend_tab',
      selectedAssetPath: 'assets/navigation/for_you_selected.png',
      unselectedAssetPath: 'assets/navigation/for_you_unselected.png',
      specialUnselectedAssetPath: 'assets/navigation/for_you_special.png',
      fallbackIcon: Icons.play_circle_fill_rounded,
    ),
    _BottomNavigationItem(
      label: _BottomNavigationLabel.member,
      slot: 'member_tab',
      selectedAssetPath: 'assets/navigation/member_selected.png',
      unselectedAssetPath: 'assets/navigation/member_unselected.png',
      specialUnselectedAssetPath: 'assets/navigation/member_special.png',
      fallbackIcon: Icons.card_membership_rounded,
    ),
    _BottomNavigationItem(
      label: _BottomNavigationLabel.myList,
      slot: 'favorites',
      selectedAssetPath: 'assets/navigation/my_list_selected.png',
      unselectedAssetPath: 'assets/navigation/my_list_unselected.png',
      specialUnselectedAssetPath: 'assets/navigation/my_list_special.png',
      fallbackIcon: Icons.explore_rounded,
    ),
    _BottomNavigationItem(
      label: _BottomNavigationLabel.profile,
      slot: 'profile',
      selectedAssetPath: 'assets/navigation/profile_selected.png',
      unselectedAssetPath: 'assets/navigation/profile_unselected.png',
      specialUnselectedAssetPath: 'assets/navigation/profile_special.png',
      fallbackIcon: Icons.person_rounded,
    ),
  ];

  /// 当前选中 tab 索引。
  final int currentIndex;

  /// tab 点击回调。
  ///
  /// Shell 会在这里处理 For You pauseForVisibility，再交给 navigationShell 切换。
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaQuery = MediaQuery.of(context);
    final platform = Theme.of(context).platform;
    final isIos = platform == TargetPlatform.iOS;
    final contentHeight = isIos ? 84.w : 64.w;
    final bottomInset = isIos ? 0.0 : mediaQuery.viewPadding.bottom;
    final selectedItem = _items[currentIndex];
    final isSpecialSlot = currentIndex == 1 || currentIndex == 2;
    final isDefaultSpecialPage = _tabFor(ref, selectedItem) == null;
    final usesSpecialPalette = isSpecialSlot && isDefaultSpecialPage;
    final dynamicTabs = _items
        .map((item) => _tabFor(ref, item))
        .whereType<BottomTabDto>()
        .toList(growable: false);

    // Shell 仅在底部导航实际可见时创建本组件；post-frame 后代表动态 Tab 已进入
    // 当前底部导航的可见区域。生命周期去重由 tracker 负责。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) {
        return;
      }
      final tracker = ref.read(dynamicTabExposureTrackerProvider);
      for (final tab in dynamicTabs) {
        unawaited(tracker.trackVisible(tab));
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: usesSpecialPalette ? Colors.black : _standardBackgroundColor,
        border: Border(
          top: BorderSide(color: Color(0x14FFFFFF), width: 1.w),
        ),
      ),
      child: SizedBox(
        height: contentHeight + bottomInset,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: contentHeight,
              child: SizedBox(
                width: _contentWidth.w,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final item in _items.indexed)
                      _AppBottomNavigationItem(
                        key: ValueKey('bottom_nav_${item.$2.label.name}'),
                        label: _labelFor(context, ref, item.$2),
                        selectedAssetPath: item.$2.selectedAssetPath,
                        unselectedAssetPath: item.$2.unselectedAssetPath,
                        specialUnselectedAssetPath:
                            item.$2.specialUnselectedAssetPath,
                        normalIconUrl: _tabFor(ref, item.$2)?.normalIconUrl,
                        selectedIconUrl: _tabFor(ref, item.$2)?.selectedIconUrl,
                        fallbackIcon: item.$2.fallbackIcon,
                        selected: item.$1 == currentIndex,
                        specialUnselected:
                            usesSpecialPalette && item.$1 != currentIndex,
                        height: contentHeight,
                        onTap: () => onDestinationSelected(item.$1),
                      ),
                  ],
                ),
              ),
            ),
            if (isIos)
              Positioned(
                left: 120.w,
                bottom: 9.w,
                child: const _HomeIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  BottomTabDto? _tabFor(WidgetRef ref, _BottomNavigationItem item) {
    ref.watch(bottomTabConfigControllerProvider);
    return ref
        .read(bottomTabConfigControllerProvider.notifier)
        .tabForSlot(item.slot);
  }

  String _labelFor(
    BuildContext context,
    WidgetRef ref,
    _BottomNavigationItem item,
  ) {
    final defaultLabel = item.label.resolve(context.l10n);
    final tab = _tabFor(ref, item);
    if (tab == null) {
      return defaultLabel;
    }
    return context.l10n.resolveDynamicTabText(
      tab.nameI18nKey,
      fallback: defaultLabel,
    );
  }
}

class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.w),
      ),
      child: SizedBox(width: 135.w, height: 5.w),
    );
  }
}

class _AppBottomNavigationItem extends StatelessWidget {
  const _AppBottomNavigationItem({
    required this.label,
    required this.selectedAssetPath,
    required this.unselectedAssetPath,
    required this.specialUnselectedAssetPath,
    required this.normalIconUrl,
    required this.selectedIconUrl,
    required this.fallbackIcon,
    required this.selected,
    required this.specialUnselected,
    required this.height,
    required this.onTap,
    super.key,
  });

  final String label;
  final String selectedAssetPath;
  final String unselectedAssetPath;
  final String specialUnselectedAssetPath;
  final String? normalIconUrl;
  final String? selectedIconUrl;
  final IconData fallbackIcon;
  final bool selected;
  final bool specialUnselected;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Colors.white
        : specialUnselected
        ? AppBottomNavigation._specialInactiveColor
        : AppBottomNavigation._standardInactiveColor;

    return SizedBox(
      width: AppBottomNavigation._itemWidth.w,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 9.w,
              child: SizedBox.square(
                dimension: AppBottomNavigation._iconSize.w,
                child: _icon(color),
              ),
            ),
            Positioned(
              top: 36.w,
              left: 0,
              right: 0,
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.visible,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _icon(Color color) {
    final url = selected
        ? selectedIconUrl
        : specialUnselected
        ? null
        : normalIconUrl;
    if (url != null && url.trim().isNotEmpty) {
      return _RemoteBottomTabIcon(
        imageUrl: url,
        preloadImageUrls: [normalIconUrl, selectedIconUrl],
        width: AppBottomNavigation._iconSize.w,
        height: AppBottomNavigation._iconSize.w,
        fallback: _localIcon(color),
      );
    }
    return _localIcon(color);
  }

  Widget _localIcon(Color color) {
    final assetPath = selected
        ? selectedAssetPath
        : specialUnselected
        ? specialUnselectedAssetPath
        : unselectedAssetPath;
    return Image.asset(
      assetPath,
      width: AppBottomNavigation._iconSize.w,
      height: AppBottomNavigation._iconSize.w,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.low,
      errorBuilder: (context, error, stackTrace) => Icon(
        fallbackIcon,
        size: AppBottomNavigation._iconSize.w,
        color: color,
      ),
    );
  }
}

/// 动态底部 Tab 图标先下载到与 [CachedNetworkImage] 相同的默认磁盘缓存，再根据
/// 实际字节判断格式。SVG 必须先解析成功，位图必须先完成 Flutter 解码，避免把
/// “看起来像 SVG/PNG 的 URL”直接展示成空白图标。
class _RemoteBottomTabIcon extends StatefulWidget {
  const _RemoteBottomTabIcon({
    required this.imageUrl,
    required this.preloadImageUrls,
    required this.width,
    required this.height,
    required this.fallback,
  });

  final String imageUrl;
  final List<String?> preloadImageUrls;
  final double width;
  final double height;
  final Widget fallback;

  @override
  State<_RemoteBottomTabIcon> createState() => _RemoteBottomTabIconState();
}

class _RemoteBottomTabIconState extends State<_RemoteBottomTabIcon> {
  final Map<String, _RemoteIconAsset> _assets = {};
  final Set<String> _failedUrls = {};
  final Map<String, int> _loadGenerations = {};

  @override
  void initState() {
    super.initState();
    _preloadAll();
  }

  @override
  void didUpdateWidget(covariant _RemoteBottomTabIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _preloadAll();
  }

  void _preloadAll() {
    for (final url in widget.preloadImageUrls) {
      final normalizedUrl = url?.trim();
      if (normalizedUrl == null || normalizedUrl.isEmpty) {
        continue;
      }
      _preload(normalizedUrl);
    }
  }

  Future<void> _preload(String imageUrl) async {
    if (_assets.containsKey(imageUrl) || _failedUrls.contains(imageUrl)) {
      return;
    }
    final generation = (_loadGenerations[imageUrl] ?? 0) + 1;
    _loadGenerations[imageUrl] = generation;
    try {
      final file = await DefaultCacheManager().getSingleFile(imageUrl);
      final bytes = await file.readAsBytes();
      final kind = _RemoteIconAsset.detectKind(bytes);
      if (kind == _RemoteIconKind.svg) {
        if (!mounted || generation != _loadGenerations[imageUrl]) return;
        final picture = await vg.loadPicture(SvgBytesLoader(bytes), context);
        picture.picture.dispose();
      } else {
        final codec = await ui.instantiateImageCodec(bytes);
        codec.dispose();
      }
      if (!mounted || generation != _loadGenerations[imageUrl]) return;
      setState(() {
        _assets[imageUrl] = _RemoteIconAsset(kind: kind, bytes: bytes);
      });
    } catch (error) {
      debugPrint('[BottomTabIcon] preload failed: url=$imageUrl error=$error');
      if (!mounted || generation != _loadGenerations[imageUrl]) return;
      setState(() => _failedUrls.add(imageUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = _assets[widget.imageUrl];
    if (asset == null) {
      // 配置了远程图标时，验证完成前不显示本地图标，避免本地/远程图在切换时
      // 互相闪动；仅当该远程资源明确加载失败才触发兜底。
      return _failedUrls.contains(widget.imageUrl)
          ? widget.fallback
          : const SizedBox.shrink();
    }
    return switch (asset.kind) {
      _RemoteIconKind.svg => SvgPicture.memory(
        asset.bytes,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('[BottomTabIcon] SVG render failed: $error');
          return widget.fallback;
        },
      ),
      _RemoteIconKind.raster => Image.memory(
        asset.bytes,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.low,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('[BottomTabIcon] raster render failed: $error');
          return widget.fallback;
        },
      ),
    };
  }
}

enum _RemoteIconKind { svg, raster }

class _RemoteIconAsset {
  const _RemoteIconAsset({required this.kind, required this.bytes});

  final _RemoteIconKind kind;
  final Uint8List bytes;

  /// 不依赖 URL 后缀；CDN 即使不给 `.svg` 扩展名也能正常识别。
  static _RemoteIconKind detectKind(Uint8List bytes) {
    final probe = String.fromCharCodes(bytes.take(1024)).trimLeft();
    return probe.startsWith('<svg') ||
            probe.startsWith('<?xml') ||
            probe.contains('<svg ')
        ? _RemoteIconKind.svg
        : _RemoteIconKind.raster;
  }
}

class _BottomNavigationItem {
  const _BottomNavigationItem({
    required this.label,
    required this.slot,
    required this.selectedAssetPath,
    required this.unselectedAssetPath,
    required this.specialUnselectedAssetPath,
    required this.fallbackIcon,
  });

  final _BottomNavigationLabel label;
  final String slot;
  final String selectedAssetPath;
  final String unselectedAssetPath;
  final String specialUnselectedAssetPath;
  final IconData fallbackIcon;
}

enum _BottomNavigationLabel {
  home,
  forYou,
  myList,
  game,
  member,
  profile;

  String resolve(AppLocalizations l10n) {
    return switch (this) {
      _BottomNavigationLabel.home => l10n.navHome,
      _BottomNavigationLabel.forYou => l10n.navForYou,
      _BottomNavigationLabel.myList => l10n.navMyList,
      _BottomNavigationLabel.game => l10n.navGame,
      _BottomNavigationLabel.member => l10n.navMember,
      _BottomNavigationLabel.profile => l10n.navProfile,
    };
  }
}
