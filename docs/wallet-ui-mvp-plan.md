# Wallet UI MVP Plan

## Scope

Build the Wallet UI MVP using mock data, based on the Figma Wallet / Record / History screens:

- `My Wallet`
- `Transaction history`
- `Consumption history`
- `Record Coins`

This round covers wallet display, entry navigation, and basic mock record lists only.

## Goals

- Replace `/wallet` placeholder with `WalletPage`.
- Show wallet coin balance and bonus balance.
- Show wallet action entries:
  - Transaction history
  - Consumption history
  - Record Coins
  - Auto-unlock next episode toggle
- Keep Profile `Wallet >` navigation through `RoutePaths.wallet`.
- Implement record pages for transaction, consumption, and coin records when available in Figma.
- Keep mock data outside widgets.
- Keep route usage centralized through `RoutePaths`.

## Architecture

Use feature-first structure:

```text
lib/features/wallet/
  application/
    wallet_controller.dart
  data/
    mock_wallet_repository.dart
    wallet_repository_provider.dart
  domain/
    wallet_record.dart
    wallet_repository.dart
  presentation/
    pages/
      wallet_page.dart
      wallet_history_page.dart
```

## Out Of Scope

- No real backend integration.
- No payment SDK integration.
- No order reconciliation.
- No refunds.
- No entitlement granting.
- No Store or Membership behavior changes.

## Acceptance

- `/wallet` opens Wallet page instead of placeholder.
- Wallet page shows coins, bonus, top up CTA, and record entries.
- Profile `Wallet >` still opens Wallet.
- Record pages render mock list data.
- UI labels are localizable through the current handwritten `AppLocalizations`.
- Controller tests cover loading and toggle state.
- Widget tests cover Profile -> Wallet and Wallet -> record page navigation.
- `dart format lib test`, `flutter analyze`, and `flutter test` pass.
