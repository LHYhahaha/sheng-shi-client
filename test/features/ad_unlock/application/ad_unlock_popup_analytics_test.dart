import 'package:drama_client/features/ad_unlock/application/ad_unlock_popup_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps popup and button analytics to the same ad unlock context', () {
    final params = adUnlockPopupAnalyticsParameters(
      dramaId: '722',
      episodeId: '1101',
      dramaAccessType: 'vip',
      adMaterialId: '300',
    );

    expect(params, {
      'drama_id': '722',
      'episode_id': '1101',
      'drama_access_type': 'vip',
      'ad_material_id': '300',
    });
  });
}
