class LogoutRequestDto {
  const LogoutRequestDto({this.reason});

  final String? reason;

  Map<String, Object?> toJson() => {if (reason != null) 'reason': reason};
}
