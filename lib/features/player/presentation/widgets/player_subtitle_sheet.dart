import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/player_playback_controller.dart';

/// 字幕选择器底部面板。
///
/// 展示当前可用的字幕轨道列表，并允许用户在字幕间切换或关闭字幕。
class PlayerSubtitleSheet extends ConsumerWidget {
  const PlayerSubtitleSheet({
    super.key,
    required this.sessionKey,
  });

  final String sessionKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 使用 watch 监听状态变化，确保 UI 实时更新
    final state = ref.watch(playerPlaybackControllerProvider(sessionKey));
    final subtitles = state.availableSubtitles;
    final currentUrl = state.currentSubtitleUrl;

    // 添加调试日志
    developer.log(
      'PlayerSubtitleSheet: build - currentUrl=$currentUrl, '
      'availableSubtitles=${subtitles.length}',
    );

    if (subtitles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 手柄条
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // 标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  _localizedLabel(context),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 22 / 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 关闭字幕选项
          _SubtitleOption(
            label: _localizedOffLabel(context),
            isSelected: currentUrl == null,
            onTap: () async {
              developer.log('PlayerSubtitleSheet: 关闭字幕 - currentUrl=$currentUrl');
              final controller = ref.read(playerPlaybackControllerProvider(sessionKey).notifier);
              await controller.setSubtitle(null);
              developer.log('PlayerSubtitleSheet: 关闭字幕完成');
            },
          ),
          // 字幕轨道列表
          ...subtitles.map((subtitle) {
            return _SubtitleOption(
              label: subtitle.name.isNotEmpty
                  ? subtitle.name
                  : subtitle.language,
              isSelected: currentUrl == subtitle.url,
              onTap: () async {
                developer.log(
                  'PlayerSubtitleSheet: 选择字幕 - ${subtitle.name}, url=${subtitle.url}',
                );
                final controller = ref.read(playerPlaybackControllerProvider(sessionKey).notifier);
                await controller.setSubtitle(subtitle.url);
                developer.log('PlayerSubtitleSheet: 字幕切换完成');
              },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _localizedLabel(BuildContext context) {
    // 使用 AppLocalizations 如果需要国际化
    return '字幕';
  }

  String _localizedOffLabel(BuildContext context) {
    // 使用 AppLocalizations 如果需要国际化
    return '关闭字幕';
  }
}

class _SubtitleOption extends StatelessWidget {
  const _SubtitleOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  height: 20 / 14,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
