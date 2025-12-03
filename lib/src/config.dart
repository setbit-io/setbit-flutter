/// Configuration for the SetBit client
class SetBitConfig {
  /// Your SetBit API key (read-only key starting with pk_)
  final String apiKey;

  /// Tags to filter flags (e.g., {'env': 'prod', 'app': 'mobile'})
  final Map<String, String> tags;

  /// Custom API URL (optional, defaults to https://flags.setbit.io)
  final String apiUrl;

  /// Enable client-side caching (default: true)
  final bool cacheEnabled;

  /// Cache TTL in milliseconds (default: 5 minutes)
  final int cacheTtl;

  /// Number of retry attempts for failed requests (default: 2)
  final int retryAttempts;

  /// Delay between retries in milliseconds (default: 1000)
  final int retryDelay;

  /// Silent mode - suppress error logs (default: true)
  final bool silent;

  /// Default API URL
  static const String defaultApiUrl = 'https://flags.setbit.io';

  /// Default cache TTL (5 minutes)
  static const int defaultCacheTtl = 300000;

  const SetBitConfig({
    required this.apiKey,
    required this.tags,
    this.apiUrl = defaultApiUrl,
    this.cacheEnabled = true,
    this.cacheTtl = defaultCacheTtl,
    this.retryAttempts = 2,
    this.retryDelay = 1000,
    this.silent = true,
  });

  /// Create a copy with updated values
  SetBitConfig copyWith({
    String? apiKey,
    Map<String, String>? tags,
    String? apiUrl,
    bool? cacheEnabled,
    int? cacheTtl,
    int? retryAttempts,
    int? retryDelay,
    bool? silent,
  }) {
    return SetBitConfig(
      apiKey: apiKey ?? this.apiKey,
      tags: tags ?? this.tags,
      apiUrl: apiUrl ?? this.apiUrl,
      cacheEnabled: cacheEnabled ?? this.cacheEnabled,
      cacheTtl: cacheTtl ?? this.cacheTtl,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      retryDelay: retryDelay ?? this.retryDelay,
      silent: silent ?? this.silent,
    );
  }
}
