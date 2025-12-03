/// Flag evaluation result from the API
class FlagResult {
  /// Whether the flag is enabled
  final bool enabled;

  /// The variant for experiment/rollout flags
  final String? variant;

  const FlagResult({
    required this.enabled,
    this.variant,
  });

  factory FlagResult.fromJson(Map<String, dynamic> json) {
    return FlagResult(
      enabled: json['enabled'] as bool? ?? false,
      variant: json['variant'] as String?,
    );
  }

  @override
  String toString() => 'FlagResult(enabled: $enabled, variant: $variant)';
}

/// Track event metadata
class TrackEvent {
  /// Name of the event
  final String eventName;

  /// User ID associated with the event
  final String userId;

  /// Optional flag name to associate with the event
  final String? flagName;

  /// Optional variant to associate with the event
  final String? variant;

  /// Optional metadata for the event
  final Map<String, dynamic>? metadata;

  const TrackEvent({
    required this.eventName,
    required this.userId,
    this.flagName,
    this.variant,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'eventName': eventName,
      'userId': userId,
    };
    if (flagName != null) json['flagName'] = flagName;
    if (variant != null) json['variant'] = variant;
    if (metadata != null) json['metadata'] = metadata;
    return json;
  }
}
