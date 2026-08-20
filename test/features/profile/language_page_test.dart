import 'package:drama_client/app/router/route_paths.dart';
import 'package:drama_client/core/locale/app_locale_controller.dart';
import 'package:drama_client/core/locale/runtime_supported_locales_provider.dart';
import 'package:drama_client/features/profile/application/language_options_controller.dart';
import 'package:drama_client/features/profile/data/language_options_repository_provider.dart';
import 'package:drama_client/features/profile/domain/language_option.dart';
import 'package:drama_client/features/profile/domain/language_options_repository.dart';
import 'package:drama_client/features/profile/presentation/pages/language_page.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('preserves a server-configured language value', () {
    final locale = AppLocaleController.localeForLanguageCode('zh-Hant');
    expect(AppLocaleController.languageCodeFromLocale(locale), 'zh-Hant');
  });

  test('registers server language codes at runtime', () async {
    final container = ProviderContainer(
      overrides: [
        languageOptionsRepositoryProvider.overrideWithValue(
          const _FakeLanguageOptionsRepository([
            LanguageOption(label: '繁体中文', code: 'zh-Hant'),
            LanguageOption(label: '日本語', code: 'ja'),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(languageOptionsProvider.future);

    expect(
      container.read(runtimeSupportedLocalesProvider),
      contains(AppLocaleController.localeForLanguageCode('zh-Hant')),
    );
    expect(
      container.read(runtimeSupportedLocalesProvider),
      contains(AppLocaleController.localeForLanguageCode('ja')),
    );
  });

  test('saved app language is restored for next launch', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(appLocaleControllerProvider.notifier)
        .selectAndSave(const Locale('zh'));

    expect(await AppLocaleController.readSavedLanguageCode(), 'zh');
  });

  testWidgets('renders remote language labels and selects remote code', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: RoutePaths.language,
      routes: [
        GoRoute(
          path: RoutePaths.language,
          builder: (context, state) => const LanguagePage(),
        ),
        GoRoute(
          path: RoutePaths.profile,
          builder: (context, state) =>
              const Scaffold(body: Text('Profile fallback')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          languageOptionsRepositoryProvider.overrideWithValue(
            const _FakeLanguageOptionsRepository([
              LanguageOption(label: 'English', code: 'en'),
              LanguageOption(label: '中文', code: 'zh'),
            ]),
          ),
        ],
        child: _LanguageTestApp(router: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    expect(find.text('中文'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.text('中文'));
    await tester.pump();

    expect(find.text('Done'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('shows an empty state when the language API returns no options', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          languageOptionsRepositoryProvider.overrideWithValue(
            const _FakeLanguageOptionsRepository([]),
          ),
        ],
        child: _LanguageTestApp(router: _languageRouter()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No data'), findsOneWidget);
    expect(find.text('English'), findsNothing);
  });

  testWidgets(
    'shows Done when switching from traditional to simplified Chinese',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        AppLocaleController.preferenceKey: 'zh-Hant',
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            languageOptionsRepositoryProvider.overrideWithValue(
              const _FakeLanguageOptionsRepository([
                LanguageOption(label: '简体中文', code: 'zh'),
                LanguageOption(label: '繁体中文', code: 'zh-Hant'),
              ]),
            ),
          ],
          child: _LanguageTestApp(router: _languageRouter()),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('简体中文'));
      await tester.pump();

      expect(find.text('Done'), findsOneWidget);
    },
  );

  testWidgets(
    'shows a network-error retry action when the language API fails',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            languageOptionsRepositoryProvider.overrideWithValue(
              const _FailingLanguageOptionsRepository(),
            ),
          ],
          child: _LanguageTestApp(router: _languageRouter()),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Network error. Please try again later.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    },
  );
}

GoRouter _languageRouter() {
  return GoRouter(
    initialLocation: RoutePaths.language,
    routes: [
      GoRoute(
        path: RoutePaths.language,
        builder: (context, state) => const LanguagePage(),
      ),
      GoRoute(
        path: RoutePaths.profile,
        builder: (context, state) =>
            const Scaffold(body: Text('Profile fallback')),
      ),
    ],
  );
}

class _FakeLanguageOptionsRepository implements LanguageOptionsRepository {
  const _FakeLanguageOptionsRepository(this.options);

  final List<LanguageOption> options;

  @override
  Future<List<LanguageOption>> fetchGlobalLanguages() async {
    return options;
  }
}

class _FailingLanguageOptionsRepository implements LanguageOptionsRepository {
  const _FailingLanguageOptionsRepository();

  @override
  Future<List<LanguageOption>> fetchGlobalLanguages() {
    throw Exception('network failure');
  }
}

class _LanguageTestApp extends StatelessWidget {
  const _LanguageTestApp({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
