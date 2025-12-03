import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'config.dart';
import 'models.dart';

/// SetBit Feature Flag Client for Flutter
///
/// Use this client to evaluate feature flags, run A/B tests,
/// and track conversion events in your Flutter app.
///
/// ```dart
/// final client = SetBitClient(
///   apiKey: 'pk_your_api_key',
///   tags: {'env': 'production', 'app': 'my-app'},
/// );
///
/// await client.init();
///
/// if (await client.enabled('new-feature', userId: 'user123')) {
///   // Show new feature
/// }
/// ```
class SetBitClient {
  /// Configuration for the client
  final SetBitConfig config;

  /// HTTP client for making requests
  final http.Client _httpClient;

  /// Whether the SDK has been initialized
  bool _initialized = false;

  /// Cached flag evaluations
  final Map<String, Map<String, FlagResult>> _cache = {};

  /// Cache timestamps
  final Map<String, int> _cacheTimestamps = {};

  /// Auto-generated user ID (stored in shared preferences)
  String? _autoUserId;

  /// Shared preferences key for storing the user ID
  static const String _userIdKey = 'setbit_uid';

  /// Create a new SetBit client
  ///
  /// [apiKey] - Your SetBit API key (read-only key starting with pk_)
  /// [tags] - Tags to filter flags (e.g., {'env': 'prod', 'app': 'mobile'})
  /// [apiUrl] - Custom API URL (optional)
  /// [cacheEnabled] - Enable client-side caching (default: true)
  /// [cacheTtl] - Cache TTL in milliseconds (default: 5 minutes)
  /// [silent] - Suppress error logs (default: true)
  SetBitClient({
    required String apiKey,
    required Map<String, String> tags,
    String apiUrl = SetBitConfig.defaultApiUrl,
    bool cacheEnabled = true,
    int cacheTtl = SetBitConfig.defaultCacheTtl,
    int retryAttempts = 2,
    int retryDelay = 1000,
    bool silent = true,
    http.Client? httpClient,
  })  : config = SetBitConfig(
          apiKey: apiKey,
          tags: tags,
          apiUrl: apiUrl,
          cacheEnabled: cacheEnabled,
          cacheTtl: cacheTtl,
          retryAttempts: retryAttempts,
          retryDelay: retryDelay,
          silent: silent,
        ),
        _httpClient = httpClient ?? http.Client();

  /// Initialize the SDK
  ///
  /// This loads or generates a persistent user ID for anonymous users.
  /// Call this before using other methods.
  Future<void> init() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _autoUserId = prefs.getString(_userIdKey);

      if (_autoUserId == null) {
        _autoUserId = const Uuid().v4();
        await prefs.setString(_userIdKey, _autoUserId!);
      }

      _initialized = true;
    } catch (e) {
      // If shared preferences fails, generate a temporary ID
      _autoUserId = const Uuid().v4();
      _initialized = true;
      _log('Failed to persist user ID: $e');
    }
  }

  /// Get the user ID to use for requests
  String _getUserId(String? providedUserId) {
    if (providedUserId != null && providedUserId.isNotEmpty) {
      return providedUserId;
    }
    return _autoUserId ?? const Uuid().v4();
  }

  /// Check if a feature flag is enabled
  ///
  /// [flagName] - Name of the flag to check
  /// [userId] - User ID for consistent bucketing (optional, auto-generated if not provided)
  /// [defaultValue] - Value to return if flag not found (default: false)
  ///
  /// Returns true if the flag is enabled, false otherwise.
  ///
  /// ```dart
  /// if (await client.enabled('new-checkout', userId: user.id)) {
  ///   // Show new checkout flow
  /// }
  /// ```
  Future<bool> enabled(
    String flagName, {
    String? userId,
    bool defaultValue = false,
  }) async {
    if (!_initialized) {
      _log('SDK not initialized. Call init() first.');
      return defaultValue;
    }

    final effectiveUserId = _getUserId(userId);
    final result = await _evaluateFlag(flagName, effectiveUserId);

    if (result == null) {
      return defaultValue;
    }

    return result.enabled;
  }

  /// Get the variant for an experiment or rollout flag
  ///
  /// [flagName] - Name of the flag to check
  /// [userId] - User ID for consistent bucketing (optional, auto-generated if not provided)
  /// [defaultVariant] - Variant to return if flag not found (default: 'control')
  ///
  /// Returns the variant name (e.g., 'control', 'variant_a', 'enabled', 'disabled')
  ///
  /// ```dart
  /// final variant = await client.variant('pricing-experiment', userId: user.id);
  /// switch (variant) {
  ///   case 'variant_a':
  ///     showPricing(99);
  ///     break;
  ///   case 'variant_b':
  ///     showPricing(149);
  ///     break;
  ///   default:
  ///     showPricing(129);
  /// }
  /// ```
  Future<String> variant(
    String flagName, {
    String? userId,
    String defaultVariant = 'control',
  }) async {
    if (!_initialized) {
      _log('SDK not initialized. Call init() first.');
      return defaultVariant;
    }

    final effectiveUserId = _getUserId(userId);
    final result = await _evaluateFlag(flagName, effectiveUserId);

    if (result == null || !result.enabled) {
      return defaultVariant;
    }

    return result.variant ?? defaultVariant;
  }

  /// Track a conversion event
  ///
  /// [eventName] - Name of the event (e.g., 'purchase_completed')
  /// [userId] - User ID (optional, auto-generated if not provided)
  /// [flagName] - Optional flag name to associate with the event
  /// [metadata] - Optional metadata for the event
  ///
  /// ```dart
  /// await client.track(
  ///   'purchase_completed',
  ///   userId: user.id,
  ///   flagName: 'pricing-experiment',
  ///   metadata: {'amount': 99.99, 'currency': 'USD'},
  /// );
  /// ```
  Future<void> track(
    String eventName, {
    String? userId,
    String? flagName,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_initialized) {
      _log('SDK not initialized. Call init() first.');
      return;
    }

    final effectiveUserId = _getUserId(userId);

    // Get variant from cache if flagName is provided
    String? variant;
    if (flagName != null) {
      final cacheKey = _getCacheKey(effectiveUserId);
      final cachedFlags = _cache[cacheKey];
      if (cachedFlags != null && cachedFlags.containsKey(flagName)) {
        variant = cachedFlags[flagName]?.variant;
      }
    }

    final event = TrackEvent(
      eventName: eventName,
      userId: effectiveUserId,
      flagName: flagName,
      variant: variant,
      metadata: metadata,
    );

    try {
      final url = Uri.parse('${config.apiUrl}/v1/track');
      final body = {
        'apiKey': config.apiKey,
        ...event.toJson(),
      };

      final response = await _httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        _log('Failed to track event: HTTP ${response.statusCode}');
      }
    } catch (e) {
      _log('Failed to track event: $e');
      // Don't throw - tracking failures shouldn't break the app
    }
  }

  /// Refresh flags from the API
  ///
  /// Clears the cache and fetches fresh flag values.
  Future<void> refresh() async {
    clearCache();
  }

  /// Clear the local cache
  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  /// Get the auto-generated user ID
  ///
  /// Returns the persistent user ID stored on the device.
  /// Useful for debugging or displaying to users.
  String? get autoUserId => _autoUserId;

  /// Whether the SDK has been initialized
  bool get isInitialized => _initialized;

  /// Evaluate a flag for a user
  Future<FlagResult?> _evaluateFlag(String flagName, String userId) async {
    final cacheKey = _getCacheKey(userId);

    // Check cache first
    if (config.cacheEnabled && _isCacheValid(cacheKey)) {
      final cachedFlags = _cache[cacheKey];
      if (cachedFlags != null && cachedFlags.containsKey(flagName)) {
        return cachedFlags[flagName];
      }
    }

    // Fetch from API
    try {
      final flags = await _fetchFlags(userId);
      return flags[flagName];
    } catch (e) {
      _log('Failed to evaluate flag "$flagName": $e');

      // Return cached value if available, even if expired
      final cachedFlags = _cache[cacheKey];
      if (cachedFlags != null && cachedFlags.containsKey(flagName)) {
        return cachedFlags[flagName];
      }

      return null;
    }
  }

  /// Fetch flags from the API
  Future<Map<String, FlagResult>> _fetchFlags(String userId) async {
    final cacheKey = _getCacheKey(userId);

    final params = {
      'apiKey': config.apiKey,
      'userId': userId,
      'tags': jsonEncode(config.tags),
    };

    final url = Uri.parse('${config.apiUrl}/v1/evaluate')
        .replace(queryParameters: params);

    final response = await _fetchWithRetry(url);

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final flags = <String, FlagResult>{};

    for (final entry in data.entries) {
      if (entry.value is Map<String, dynamic>) {
        flags[entry.key] = FlagResult.fromJson(entry.value);
      }
    }

    // Update cache
    if (config.cacheEnabled) {
      _cache[cacheKey] = flags;
      _cacheTimestamps[cacheKey] = DateTime.now().millisecondsSinceEpoch;
    }

    return flags;
  }

  /// Fetch with retry logic
  Future<http.Response> _fetchWithRetry(Uri url, {int attempt = 1}) async {
    try {
      return await _httpClient.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      if (attempt < config.retryAttempts) {
        await Future.delayed(Duration(milliseconds: config.retryDelay));
        return _fetchWithRetry(url, attempt: attempt + 1);
      }
      rethrow;
    }
  }

  /// Get cache key for a user
  String _getCacheKey(String userId) {
    final sortedTags = Map.fromEntries(
      config.tags.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return '${jsonEncode(sortedTags)}:$userId';
  }

  /// Check if cache is valid
  bool _isCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;

    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    return age < config.cacheTtl;
  }

  /// Log a message (if not in silent mode)
  void _log(String message) {
    if (!config.silent) {
      // ignore: avoid_print
      print('SetBit: $message');
    }
  }

  /// Dispose of resources
  void dispose() {
    _httpClient.close();
  }
}
