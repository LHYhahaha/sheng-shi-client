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
        shortDramaId: 99,
      ),
    );

    expect(params, {
      'popup_name': 'fixed_campaign_popup',
      'popup_target_type': 'drama',
      'popup_config_id': '12',
      'target_drama_id': '99',
    });
  });

  test('close only keeps popup_name', () {
    final popup = const PopupConfig(
      name: 'For You Campaign',
      jumpType: 2,
      shortDramaId: 99,
    );

    expect(popupCloseName(popup), 'fixed_campaign_popup');
  });

  test('accepts API configuration names and rejects unknown jump types', () {
    const popup = PopupConfig(name: 'Home Campaign', jumpType: 2);

    expect(popupShowParams(popup)?['popup_name'], 'fixed_campaign_popup');
    expect(popupCloseName(popup), 'fixed_campaign_popup');
    expect(popupShowParams(const PopupConfig(jumpType: 99)), isNull);
    expect(popupCloseName(const PopupConfig(jumpType: 99)), isNull);
  });
}
