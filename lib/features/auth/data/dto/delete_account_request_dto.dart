class DeleteAccountRequestDto {
  const DeleteAccountRequestDto({this.reason});

  final String? reason;

  Map<String, Object?> toJson() => {if (reason != null) 'reason': reason};
}
