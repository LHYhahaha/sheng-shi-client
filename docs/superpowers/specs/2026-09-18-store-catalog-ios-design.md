# iOS Store Catalog Design

## Goal

Render the price and eligible introductory offer returned by the active store
for both Android and iOS. The backend remains the source of the business
catalog and supplies only the active platform's `channelProductId`.

## Scope

- Query App Store product details for `PAY_CHANNEL_APPLE` products on iOS.
- Continue querying Google Play product details for `PAY_CHANNEL_GOOGLE`
  products on Android.
- Merge returned product price and title into membership and player recharge
  presentation data.
- Preserve current backend response fields and do not change payment or
  receipt-verification endpoints.

## Design

`IapPriceService` becomes store-neutral: its availability check and product
query work against `InAppPurchase.instance`, whose platform implementation is
selected by Flutter. Callers select product IDs using `defaultTargetPlatform`
and the backend's payment channel.

Google Play offer extraction remains Android-specific. On iOS, standard
`ProductDetails` supplies the localized price, currency, title, and
description; StoreKit introductory-price metadata is additionally mapped to
the existing promotion display fields. Apple promotional offers that require
server-side signing are deliberately out of scope.

## Non-goals

- Starting Apple purchases, Apple receipt verification, entitlement changes,
  and server notifications.
- New backend fields or API endpoints.
