import 'package:drama_client/features/popup/application/popup_analytics.dart';
import 'package:drama_client/features/popup/domain/popup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps a drama popup to the defined popup_show parameters', () {
    final params = popupShowParams(
      const PopupConfig(
        id: 12,
        name: 'Home Campaign',
        jumpType: 3,
        shortJumpMode: 1,
        shortDramaId: 99,
      ),
    );

    expect(params, {
      'popup_name': 'fixed_campaign_popup',
      'popup_target_type': 'drama',
      'popup_config_id': '12',
      'target_drama_id': '99',
      'drama_recommend_type': 'specified',
    });
  });

  test('maps an automatic drama popup to the same target parameters', () {
    final params = popupShowParams(
      const PopupConfig(
        id: 13,
        jumpType: 3,
        shortJumpMode: 2,
        shortDramaId: 100,
      ),
    );

    expect(params?['drama_recommend_type'], 'auto');
    expect(params?['target_drama_id'], '100');
  });

  test('maps fixed campaign popup_close with the same target parameters', () {
    const popup = PopupConfig(
      id: 12,
      jumpType: 3,
      shortJumpMode: 1,
      shortDramaId: 99,
    );

    expect(popupCloseParams(popup), popupShowParams(popup));
  });

  test('close only keeps popup_name', () {
    final popup = const PopupConfig(
      id: 12,
      name: 'For You Campaign',
      jumpType: 2,
      shortDramaId: 99,
    );

    expect(popupCloseName(popup), 'fixed_campaign_popup');
  });

  test('accepts API configuration names and rejects unknown jump types', () {
    const popup = PopupConfig(id: 12, name: 'Home Campaign', jumpType: 2);

    expect(popupShowParams(popup)?['popup_name'], 'fixed_campaign_popup');
    expect(popupCloseName(popup), 'fixed_campaign_popup');
    expect(popupShowParams(const PopupConfig(jumpType: 99)), isNull);
    expect(popupCloseName(const PopupConfig(jumpType: 99)), isNull);
  });

  test('rejects incomplete campaign popup analytics parameters', () {
    expect(popupShowParams(const PopupConfig(jumpType: 2)), isNull);
    expect(
      popupShowParams(const PopupConfig(id: 12, jumpType: 3, shortDramaId: 99)),
      isNull,
    );
  });

  test('maps a specified drama campaign click from the popup API', () {
    final params = campaignContentClickParams(
      const PopupConfig(
        id: 12,
        jumpType: 3,
        shortJumpMode: 1,
        shortDramaId: 99,
      ),
    );

    expect(params, {
      'element_name': 'campaign_content',
      'popup_config_id': '12',
      'popup_target_type': 'drama',
      'target_drama_id': '99',
      'drama_recommend_type': 'specified',
    });
  });

  test('maps an automatic drama campaign click from the popup API', () {
    final params = campaignContentClickParams(
      const PopupConfig(
        id: 13,
        jumpType: 3,
        shortJumpMode: 2,
        shortDramaId: 100,
      ),
    );

    expect(params?['drama_recommend_type'], 'auto');
    expect(params?['target_drama_id'], '100');
  });
}
