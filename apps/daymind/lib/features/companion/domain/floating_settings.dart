import 'companion.dart';

/// Device-local only. Cloud profile DTOs never receive window geometry or art.
class FloatingCompanionSettings {
  const FloatingCompanionSettings({
    this.enabled = false,
    this.topmost = false,
    this.clickThrough = false,
    this.size = 112,
    this.x,
    this.y,
  });
  final bool enabled, topmost, clickThrough;
  final int size;
  final int? x, y;
  void validate() {
    if (size < 80 ||
        size > 256 ||
        (x == null) != (y == null) ||
        (x != null && (x!.abs() > 100000 || y!.abs() > 100000))) {
      throw const CompanionValidation(
        'Vị trí hoặc kích thước cửa sổ nổi không hợp lệ.',
      );
    }
  }

  FloatingCompanionSettings copy({
    bool? enabled,
    bool? topmost,
    bool? clickThrough,
    int? size,
    int? x,
    int? y,
    bool resetPosition = false,
  }) => FloatingCompanionSettings(
    enabled: enabled ?? this.enabled,
    topmost: topmost ?? this.topmost,
    clickThrough: clickThrough ?? this.clickThrough,
    size: size ?? this.size,
    x: resetPosition ? null : x ?? this.x,
    y: resetPosition ? null : y ?? this.y,
  );
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'topmost': topmost,
    'clickThrough': clickThrough,
    'size': size,
    if (x != null) 'x': x,
    if (y != null) 'y': y,
  };
  factory FloatingCompanionSettings.fromJson(Map<String, dynamic>? j) {
    final s = FloatingCompanionSettings(
      enabled: j?['enabled'] == true,
      topmost: j?['topmost'] == true,
      clickThrough: j?['clickThrough'] == true,
      size: j?['size'] is int ? j!['size'] as int : 112,
      x: j?['x'] is int ? j!['x'] as int : null,
      y: j?['y'] is int ? j!['y'] as int : null,
    );
    s.validate();
    return s;
  }
}
