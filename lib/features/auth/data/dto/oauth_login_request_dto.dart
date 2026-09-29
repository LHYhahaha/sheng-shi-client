import '../../../../core/oauth/oauth_service.dart';

class OAuthLoginRequestDto {
  const OAuthLoginRequestDto({
    required this.provider,
    required this.token,
    this.facebookCredentialType,
  });

  OAuthLoginRequestDto.facebook(FacebookLoginCredential credential)
    : provider = 'facebook',
      token = credential.token,
      facebookCredentialType = credential.type;

  final String provider;
  final String token;
  final FacebookLoginCredentialType? facebookCredentialType;

  Map<String, Object?> toJson() {
    return switch (provider) {
      'google' => {'googleToken': token},
      'facebook' => switch (facebookCredentialType) {
        FacebookLoginCredentialType.limited => {'authenticationToken': token},
        _ => {'facebookToken': token},
      },
      'apple' => {'identityToken': token},
      _ => throw ArgumentError.value(
        provider,
        'provider',
        'Unsupported OAuth provider',
      ),
    };
  }
}
