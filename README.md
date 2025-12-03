# SetBit Flutter SDK

Official Flutter SDK for [SetBit](https://setbit.io) feature flags. Simple, fast feature flags for mobile and web apps.

## Features

- Boolean feature flags (on/off toggles)
- A/B testing experiments with variants
- Percentage-based rollouts
- Conversion tracking for analytics
- Automatic user ID generation and persistence
- Client-side caching with configurable TTL
- Fail-open design (defaults when API unreachable)
- Full TypeScript-style type safety with Dart

## Installation

Add `setbit` to your `pubspec.yaml`:

```yaml
dependencies:
  setbit: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

```dart
import 'package:setbit/setbit.dart';

// Create a client
final client = SetBitClient(
  apiKey: 'pk_your_api_key',
  tags: {'env': 'production', 'app': 'my-app'},
);

// Initialize (loads/generates persistent user ID)
await client.init();

// Check if a feature is enabled
if (await client.enabled('new-checkout')) {
  // Show new checkout flow
}

// Get experiment variant (result is cached for tracking)
final variant = await client.variant('pricing-experiment');
switch (variant) {
  case 'variant_a':
    showPrice(99);
    break;
  case 'variant_b':
    showPrice(149);
    break;
  default:
    showPrice(129); // control
}

// Track conversions (variant auto-included from cache for A/B attribution)
await client.track(
  'purchase_completed',
  flagName: 'pricing-experiment',
  metadata: {'amount': 99.99, 'currency': 'USD'},
);
```

## API Reference

### SetBitClient

#### Constructor

```dart
SetBitClient({
  required String apiKey,        // Your API key (pk_xxx)
  required Map<String, String> tags,  // Tags for flag filtering
  String apiUrl,                 // Custom API URL (optional)
  bool cacheEnabled = true,      // Enable caching
  int cacheTtl = 300000,         // Cache TTL in ms (5 min)
  int retryAttempts = 2,         // Retry attempts
  int retryDelay = 1000,         // Retry delay in ms
  bool silent = true,            // Suppress error logs
})
```

#### init()

Initialize the SDK. This must be called before using other methods.

```dart
await client.init();
```

This method:
- Loads or generates a persistent user ID (stored in SharedPreferences)
- Prepares the client for flag evaluation

#### enabled()

Check if a boolean feature flag is enabled.

```dart
Future<bool> enabled(
  String flagName, {
  String? userId,           // Optional user ID (uses auto-generated if not provided)
  bool defaultValue = false, // Default if flag not found
})
```

Example:

```dart
if (await client.enabled('dark-mode', userId: user.id)) {
  enableDarkMode();
}
```

#### variant()

Get the variant for an experiment or rollout flag.

```dart
Future<String> variant(
  String flagName, {
  String? userId,                  // Optional user ID
  String defaultVariant = 'control', // Default variant
})
```

Example:

```dart
final variant = await client.variant('onboarding-flow');
if (variant == 'streamlined') {
  showStreamlinedOnboarding();
} else {
  showStandardOnboarding();
}
```

#### track()

Track a conversion event for analytics.

```dart
Future<void> track(
  String eventName, {
  String? userId,                    // Optional user ID
  String? flagName,                  // Associate with a flag (auto-includes variant from cache)
  Map<String, dynamic>? metadata,    // Additional data
})
```

> **Note:** When you pass `flagName`, the SDK automatically includes the variant from cached evaluations for proper A/B test attribution. Make sure to call `variant()` before `track()` so the variant is in cache.

Example:

```dart
// 1. Get variant first (caches the result)
final variant = await client.variant('signup-experiment');

// 2. Show appropriate experience based on variant
// ...

// 3. Track conversion - variant is auto-included from cache
await client.track(
  'signup_completed',
  flagName: 'signup-experiment',
  metadata: {
    'plan': 'premium',
    'source': 'mobile',
  },
);
```

#### refresh()

Clear the cache and force fresh flag values on next evaluation.

```dart
await client.refresh();
```

#### clearCache()

Clear the local cache.

```dart
client.clearCache();
```

#### Properties

```dart
String? autoUserId    // The auto-generated persistent user ID
bool isInitialized    // Whether init() has been called
```

## User ID Handling

The SDK automatically generates and persists a user ID for anonymous users:

```dart
// Auto-generated user ID is used
await client.enabled('feature');

// Or provide your own user ID
await client.enabled('feature', userId: authenticatedUser.id);
```

The auto-generated ID is stored in `SharedPreferences` and persists across app restarts, ensuring consistent flag evaluations for the same user.

## Tags

Tags filter which flags are returned. Use them to:

- Target specific environments (`env: 'production'`)
- Target specific apps (`app: 'mobile'`)
- Target platforms (`platform: 'ios'`)
- Target regions (`region: 'us-east'`)

```dart
final client = SetBitClient(
  apiKey: 'pk_xxx',
  tags: {
    'env': 'production',
    'app': 'flutter-app',
    'platform': Platform.isIOS ? 'ios' : 'android',
  },
);
```

## Caching

The SDK caches flag evaluations for 5 minutes by default:

```dart
// Disable caching
final client = SetBitClient(
  apiKey: 'pk_xxx',
  tags: {'env': 'prod'},
  cacheEnabled: false,
);

// Custom cache TTL (1 minute)
final client = SetBitClient(
  apiKey: 'pk_xxx',
  tags: {'env': 'prod'},
  cacheTtl: 60000,
);
```

## Error Handling

The SDK is designed to fail-open:

- If the API is unreachable, it returns cached values (if available) or defaults
- Tracking failures are logged but don't throw exceptions
- Your app keeps working even if SetBit is unavailable

```dart
// Returns false (default) if API fails and no cache
final enabled = await client.enabled('feature', defaultValue: false);

// Returns 'control' (default) if API fails
final variant = await client.variant('experiment', defaultVariant: 'control');
```

## Example App

See the [example](example/) directory for a complete Flutter app demonstrating all SDK features.

```bash
cd example
flutter run
```

## Support

- Documentation: https://docs.setbit.io
- Issues: https://github.com/setbit-io/setbit-flutter/issues
- Email: support@setbit.io
