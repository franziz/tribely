class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.sentryDsn});

  final String apiBaseUrl;
  final String sentryDsn;

  static const AppConfig dev = AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:3000',
    ),
    sentryDsn: String.fromEnvironment('SENTRY_DSN', defaultValue: ''),
  );
}
