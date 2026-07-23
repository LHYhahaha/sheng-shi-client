import 'package:drama_client/core/locale/app_locale_controller.dart';
import 'package:drama_client/core/runtime/api_lang_provider.dart';
import 'package:drama_client/features/home/application/home_data_controller.dart';
import 'package:drama_client/features/home/data/home_repository.dart';
import 'package:drama_client/features/home/data/home_repository_provider.dart';
import 'package:drama_client/features/home/domain/home_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('reloads home data when API language changes', () async {
    final repository = _FakeHomeRepository();
    final container = ProviderContainer(
      overrides: [homeRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    expect(container.read(apiLangProvider), 'en');
    await _flushMicrotasks();

    await container.read(homeDataControllerProvider.notifier).loadHomeData();

    expect(repository.callCount, 1);
    expect(
      container.read(homeDataControllerProvider).data?.tabs.first.name,
      'Popular',
    );

    container
        .read(appLocaleControllerProvider.notifier)
        .select(const Locale('zh'));
    await _flushMicrotasks();

    expect(repository.callCount, 2);
    expect(container.read(apiLangProvider), 'zh');
    expect(
      container.read(homeDataControllerProvider).data?.tabs.first.name,
      '热门',
    );
  });
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeHomeRepository implements HomeRepository {
  int callCount = 0;

  @override
  Future<List<String>> getHotSearchKeywords() async => const [
    'English Drama',
    '中文剧',
  ];

  @override
  Future<HomeData> getHomeData({
    int? page,
    int pageSize = 20,
    int? tabId,
  }) async {
    callCount += 1;
    final isChinese = callCount >= 2;
    return _homeData(
      tabName: isChinese ? '热门' : 'Popular',
      dramaTitle: isChinese ? '中文剧' : 'English Drama',
    );
  }
}

HomeData _homeData({required String tabName, required String dramaTitle}) {
  return HomeData(
    id: 1,
    name: 'Home',
    status: 1,
    tabs: [
      HomeTab(
        id: 10,
        name: tabName,
        flag: 'popular',
        sort: 1,
        status: 1,
        page: 1,
        pageSize: 20,
        dramaTotal: 1,
        dramas: [
          HomeDrama(
            id: 'drama-1',
            sort: 1,
            coverUrl: 'https://example.com/cover.jpg',
            title: dramaTitle,
            summary: '',
            playCount: 100,
            trailerEpisodeNum: 1,
            isVipOnly: false,
            status: 1,
            episodeTotal: 10,
            tags: const [],
          ),
        ],
      ),
    ],
  );
}
