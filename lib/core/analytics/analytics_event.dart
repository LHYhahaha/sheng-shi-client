class AnalyticsEvent {
  const AnalyticsEvent(this.name, [this.parameters = const {}]);

  final String name;
  final Map<String, Object?> parameters;
}
