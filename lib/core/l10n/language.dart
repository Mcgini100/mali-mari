enum AppLanguage {
  en('English', 'Money, made clear.'),
  sn('chiShona', 'Mari, yakajeka.'),
  nd('isiNdebele', 'Imali, ecacileyo.');

  const AppLanguage(this.nativeName, this.tagline);

  final String nativeName;
  final String tagline;

  static AppLanguage fromName(String? name) =>
      AppLanguage.values.firstWhere((l) => l.name == name, orElse: () => AppLanguage.en);
}
