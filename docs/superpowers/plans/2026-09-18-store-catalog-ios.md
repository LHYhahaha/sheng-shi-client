# iOS Store Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Query and render the active store's product pricing for Apple and Google catalog items.

**Architecture:** The backend continues to define the business catalog and provides platform-specific product IDs. The client filters by the active platform, queries Flutter's store-neutral IAP facade, and merges returned `ProductDetails` into existing display models.

**Tech Stack:** Flutter, Riverpod, `in_app_purchase`, Flutter tests.

**Spec:** `docs/superpowers/specs/2026-09-18-store-catalog-ios-design.md`

## Global Constraints

- Do not change backend API request or response fields.
- Do not add Apple purchase or verification behavior in this change.
- Use App Store/Google Play returned prices for platform-IAP display values.
- Preserve Android Google offer extraction behavior.

---

### Task 1: Make the catalog service store-neutral

**Files:**
- Modify: `lib/features/pay/application/iap_price_service.dart`
- Modify: consumers of `isGooglePlayBillingAvailable`
- Test: `test/features/pay/vip_product_load_classification_test.dart`

**Interfaces:**
- Produces: `Future<bool> IapPriceService.isStoreAvailable()`.
- Consumes: `InAppPurchase.isAvailable()` and `queryProductDetails`.

- [ ] **Step 1: Write the failing test**

Add a fake `IapPriceService` exposing `isStoreAvailable`, then load an iOS
Apple-channel membership plan and expect its returned product price to render.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/features/pay/vip_product_load_classification_test.dart`

Expected: FAIL because the iOS product ID is not collected for a store query.

- [ ] **Step 3: Write minimal implementation**

Rename the availability method and update callers. Select Apple IDs on iOS and
Google IDs on Android before calling the existing `queryProducts` facade.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/features/pay/vip_product_load_classification_test.dart`

Expected: PASS.

### Task 2: Render StoreKit catalog values in membership and player recharge

**Files:**
- Modify: `lib/features/membership/application/membership_controller.dart`
- Modify: `lib/features/player/data/remote/player_recharge_unlock_repository_impl.dart`
- Modify: `lib/features/player/data/mapper/player_recharge_unlock_mapper.dart`
- Test: existing membership and player recharge tests.

**Interfaces:**
- Consumes: `IapPriceService.queryProducts` and `queryProductsWithPromo`.
- Produces: platform IAP prices in existing membership and recharge display
  models.

- [ ] **Step 1: Write the failing tests**

Cover an iOS Apple-channel membership plan and Apple-channel recharge package
with a StoreKit `ProductDetails` price. Assert the rendered models contain the
store-provided price.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --no-pub test/features/membership/membership_controller_test.dart test/features/player/player_recharge_unlock_controller_test.dart`

Expected: FAIL because Apple IDs are filtered from catalog queries.

- [ ] **Step 3: Write minimal implementation**

Use the same active-store ID selector in membership and player recharge.
Extend mapper visibility to require returned details for either active IAP
channel, then merge generic StoreKit price/title values while retaining the
existing Android promotion fields.

- [ ] **Step 4: Run focused tests to verify they pass**

Run: `flutter test --no-pub test/features/membership/membership_controller_test.dart test/features/player/player_recharge_unlock_controller_test.dart`

Expected: PASS.

### Task 3: Verify affected IAP flows

**Files:**
- Test: `test/features/pay/vip_product_load_classification_test.dart`
- Test: `test/features/membership/membership_page_test.dart`
- Test: `test/features/player/player_page_test.dart`

- [ ] **Step 1: Run targeted regression suite**

Run: `flutter test --no-pub test/features/pay test/features/membership test/features/player/player_recharge_unlock_controller_test.dart`

- [ ] **Step 2: Run static analysis for changed modules**

Run: `flutter analyze --no-pub lib/features/pay lib/features/membership/application/membership_controller.dart lib/features/player/data/remote/player_recharge_unlock_repository_impl.dart lib/features/player/data/mapper/player_recharge_unlock_mapper.dart`

