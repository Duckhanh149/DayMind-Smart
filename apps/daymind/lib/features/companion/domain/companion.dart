enum Personality { gentle, practical, cheerful }

enum CompanionEvent { appOpen, taskCompleted }

class CompanionBehavior {
  CompanionBehavior({DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final DateTime Function() clock;
  DateTime? _lastSpokenAt;
  String? respond(CompanionEvent event, Personality personality) {
    final now = clock();
    if (_lastSpokenAt != null &&
        now.difference(_lastSpokenAt!) < const Duration(seconds: 30)) {
      return null;
    }
    _lastSpokenAt = now;
    return switch ((event, personality)) {
      (CompanionEvent.taskCompleted, Personality.gentle) =>
        'Xong một việc rồi. Thả lỏng vai một chút nhé.',
      (CompanionEvent.taskCompleted, Personality.practical) =>
        'Đã hoàn thành. Bạn có thể chọn việc quan trọng tiếp theo.',
      (CompanionEvent.taskCompleted, Personality.cheerful) =>
        'Thêm một bước tiến! Mình ghi nhận nỗ lực của bạn 🌱',
      (_, Personality.gentle) =>
        'Không cần làm tất cả. Bắt đầu bằng một việc nhỏ thôi.',
      (_, Personality.practical) =>
        'Chọn một việc quan trọng, rồi dành thời gian cho nó.',
      (_, Personality.cheerful) =>
        'Mình ở đây rồi! Hôm nay cùng tiến một chút nhé.',
    };
  }
}

class AppPreferences {
  const AppPreferences({
    this.theme = 'system',
    this.companionEnabled = true,
    this.personality = Personality.gentle,
    this.assetName,
    this.companionSize = 80,
    this.windowsTrayEnabled = true,
  });
  factory AppPreferences.fromJson(Map<String, dynamic> json) => AppPreferences(
    theme: ['system', 'light', 'dark'].contains(json['theme'])
        ? json['theme'] as String
        : 'system',
    companionEnabled: json['companionEnabled'] != false,
    windowsTrayEnabled: json['windowsTrayEnabled'] != false,
    personality:
        Personality.values
            .where((p) => p.name == json['personality'])
            .firstOrNull ??
        Personality.gentle,
    assetName:
        json['assetName'] is String &&
            RegExp(r'^[a-f0-9]{64}\.(png|webp)$')
                .hasMatch(json['assetName'] as String)
        ? json['assetName'] as String
        : null,
    companionSize: json['companionSize'] is num
        ? (json['companionSize'] as num).toDouble().clamp(48, 112)
        : 80,
  );
  final String theme;
  final bool companionEnabled;
  final bool windowsTrayEnabled;
  final Personality personality;
  final String? assetName;
  final double companionSize;
  AppPreferences copyWith({
    String? theme,
    bool? companionEnabled,
    Personality? personality,
    String? assetName,
    bool resetAsset = false,
    double? companionSize,
    bool? windowsTrayEnabled,
  }) => AppPreferences(
    theme: theme ?? this.theme,
    companionEnabled: companionEnabled ?? this.companionEnabled,
    personality: personality ?? this.personality,
    assetName: resetAsset ? null : assetName ?? this.assetName,
    companionSize: companionSize ?? this.companionSize,
    windowsTrayEnabled: windowsTrayEnabled ?? this.windowsTrayEnabled,
  );
  Map<String, dynamic> toJson() => {
    'theme': theme,
    'companionEnabled': companionEnabled,
    'personality': personality.name,
    'assetName': assetName,
    'companionSize': companionSize,
    'windowsTrayEnabled': windowsTrayEnabled,
  };
}
