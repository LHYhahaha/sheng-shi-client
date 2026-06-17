/// A display text value that can either be remote/server-provided raw text or
/// a fixed UI copy key resolved by the presentation layer.
class UiText {
  const UiText._({
    this.rawValue,
    this.key,
    this.fallbackEn = '',
    this.fallbackZh = '',
    this.args = const {},
  });

  const UiText.raw(String value) : this._(rawValue: value);

  const UiText.key(
    String key, {
    required String fallbackEn,
    required String fallbackZh,
    Map<String, Object?> args = const {},
  }) : this._(
         key: key,
         fallbackEn: fallbackEn,
         fallbackZh: fallbackZh,
         args: args,
       );

  final String? rawValue;
  final String? key;
  final String fallbackEn;
  final String fallbackZh;
  final Map<String, Object?> args;

  bool get isRaw => rawValue != null;
}
