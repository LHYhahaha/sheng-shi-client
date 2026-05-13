# Auth UI MVP Plan

## Scope

Build the Login / Account UI MVP with mock state only. Figma currently has a main login screen (`登录`) with the social login CTA near the lower half of the screen; this MVP follows that visual direction and expands the login actions required by product.

## Goals

- Add feature-first auth structure:

```text
lib/features/auth/
  application/
    auth_controller.dart
  data/
    mock_auth_repository.dart
    auth_repository_provider.dart
  domain/
    auth_session.dart
    auth_repository.dart
  presentation/
    pages/
      auth_page.dart
      account_page.dart
    widgets/
      auth_action_button.dart
```

- Add login route and account route through `RoutePaths` / `RouteNames`.
- Connect Profile `Log in >` to the auth page.
- Provide Device login, Google login, and Facebook login UI.
- Support guest and logged-in mock states.
- Support logout UI.
- Support delete account confirmation UI.
- Keep all mock session data in auth data/application layers, not widgets.

## Out Of Scope

- No real Google SDK.
- No real Facebook SDK.
- No backend API.
- No token storage.
- No Store / Wallet / Membership / Payment changes.
- No ARB/gen-l10n migration.

## Acceptance

- Profile `Log in >` opens auth page.
- Login buttons render and one can switch mock state to logged-in.
- Logged-in auth page can open account page.
- Account page can log out.
- Account page can show delete account confirmation and confirm deletion.
- Controller tests cover mock login, logout, and delete account state.
- Widget tests cover Profile -> Auth, mock login, logout, and delete account confirmation.
- `dart format lib test`, `flutter analyze`, and `flutter test` pass.
