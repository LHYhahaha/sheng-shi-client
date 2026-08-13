import '../../../../core/network/json_field_parser.dart';

/// `/api/config/bottom-tabs` 的 data payload。
///
/// API envelope（code/message/data）由 [ApiClient] 统一处理；这里仅对应 data。
class BottomTabResponseDto {
  const BottomTabResponseDto({required this.tabs});

  final List<BottomTabDto> tabs;

  factory BottomTabResponseDto.fromJson(Map<String, Object?> json) {
    final rawTabs = JsonFieldParser.requireList(
      json['tabs'],
      dtoName: 'BottomTabResponseDto',
      field: 'tabs',
    );
    return BottomTabResponseDto(
      tabs: rawTabs
          .map(
            (item) => BottomTabDto.fromJson(
              JsonFieldParser.requireMap(
                item,
                dtoName: 'BottomTabDto',
                field: 'tabs[]',
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

/// 后台下发的一个底部 Tab 配置项。
class BottomTabDto {
  const BottomTabDto({
    required this.h5Url,
    required this.nameI18nKey,
    required this.normalIconUrl,
    required this.replaceTab,
    required this.selectedIconUrl,
    required this.tabConfigId,
  });

  final String h5Url;
  final String nameI18nKey;
  final String normalIconUrl;
  final String replaceTab;
  final String selectedIconUrl;
  final String tabConfigId;

  factory BottomTabDto.fromJson(Map<String, Object?> json) {
    return BottomTabDto(
      h5Url: JsonFieldParser.requireString(
        json,
        'h5_url',
        dtoName: 'BottomTabDto',
      ),
      nameI18nKey: JsonFieldParser.requireString(
        json,
        'name_i18n_key',
        dtoName: 'BottomTabDto',
      ),
      normalIconUrl: JsonFieldParser.requireString(
        json,
        'normal_icon_url',
        dtoName: 'BottomTabDto',
      ),
      replaceTab: JsonFieldParser.requireString(
        json,
        'replace_tab',
        dtoName: 'BottomTabDto',
      ),
      selectedIconUrl: JsonFieldParser.requireString(
        json,
        'selected_icon_url',
        dtoName: 'BottomTabDto',
      ),
      tabConfigId: JsonFieldParser.requireString(
        json,
        'tab_config_id',
        dtoName: 'BottomTabDto',
      ),
    );
  }
}
