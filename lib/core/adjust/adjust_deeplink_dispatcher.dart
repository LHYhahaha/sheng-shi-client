/// Converts the raw URL supplied by Adjust into the URI consumed by the app's
/// existing deep-link flow.
class AdjustDeeplinkDispatcher {
  const AdjustDeeplinkDispatcher(this._onDeeplink);

  final void Function(Uri deeplink) _onDeeplink;

  /// Returns whether a usable deep link was forwarded.
  bool dispatch(String? rawDeeplink) {
    final value = rawDeeplink?.trim();
    if (value == null || value.isEmpty) return false;

    final deeplink = Uri.tryParse(value);
    if (deeplink == null) return false;

    _onDeeplink(deeplink);
    return true;
  }
}
