/// 语言包信息
class LanguagePackage {
  final String languageCode;
  final String languageName;
  final int version;
  final String updatedAt;
  final String filePath;

  LanguagePackage({
    required this.languageCode,
    required this.languageName,
    required this.version,
    required this.updatedAt,
    required this.filePath,
  });

  Map<String, dynamic> toJson() => {
    'languageCode': languageCode,
    'languageName': languageName,
    'version': version,
    'updatedAt': updatedAt,
    'filePath': filePath,
  };

  factory LanguagePackage.fromJson(Map<String, dynamic> json) => LanguagePackage(
    languageCode: json['languageCode'] as String,
    languageName: json['languageName'] as String,
    version: json['version'] as int,
    updatedAt: json['updatedAt'] as String,
    filePath: json['filePath'] as String,
  );
}
