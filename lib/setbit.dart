/// SetBit Feature Flag SDK for Flutter
///
/// Simple, fast feature flags for mobile and web apps.
///
/// ```dart
/// import 'package:setbit/setbit.dart';
///
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
library setbit;

export 'src/client.dart';
export 'src/config.dart';
export 'src/models.dart';
