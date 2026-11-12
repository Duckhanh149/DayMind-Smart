bool isCharacterAssetName(String? name) =>
    name != null &&
    RegExp(r'^[a-f0-9]{64}\.(png|webp|jpeg|bmp|character)$').hasMatch(name);

enum Personality { gentle, practical, cheerful }

enum CompanionEvent {
  appOpen,
  reminderDue,
  taskCompleted,
  taskOverdueVisible,
  dailyDigest,
  quietHours,
}

enum CompanionExpression { neutral, happy, focused, resting }

enum CompanionPlacement { automatic, left, right }

const companionEventLabels = {
  CompanionEvent.appOpen: 'Mở ứng dụng',
  CompanionEvent.reminderDue: 'Đến giờ nhắc',
  CompanionEvent.taskCompleted: 'Hoàn thành công việc',
  CompanionEvent.taskOverdueVisible: 'Xem việc quá hạn',
  CompanionEvent.dailyDigest: 'Tóm tắt hằng ngày',
  CompanionEvent.quietHours: 'Giờ yên lặng',
};
const companionExpressionLabels = {
  CompanionExpression.neutral: 'Bình thản',
  CompanionExpression.happy: 'Vui mừng',
  CompanionExpression.focused: 'Tập trung',
  CompanionExpression.resting: 'Nghỉ ngơi',
};
const personalityLabels = {
  Personality.gentle: 'Dịu dàng',
  Personality.practical: 'Thực tế',
  Personality.cheerful: 'Vui vẻ',
};

class CompanionValidation implements Exception {
  const CompanionValidation(this.message);
  final String message;
  @override
  String toString() => message;
}

String defaultDialogue(CompanionEvent event, Personality personality) =>
    switch ((event, personality)) {
      (CompanionEvent.taskCompleted, Personality.gentle) =>
        'Xong một việc rồi. Thả lỏng vai một chút nhé.',
      (CompanionEvent.taskCompleted, Personality.practical) =>
        'Đã hoàn thành. Bạn có thể chọn việc quan trọng tiếp theo.',
      (CompanionEvent.taskCompleted, Personality.cheerful) =>
        'Thêm một bước tiến! Mình ghi nhận nỗ lực của bạn 🌱',
      (CompanionEvent.reminderDue, Personality.gentle) =>
        'Đến giờ rồi: {task}. Cứ bắt đầu từ một bước nhỏ nhé.',
      (CompanionEvent.reminderDue, Personality.practical) =>
        'Đến giờ: {task}. Bạn có thể mở việc hoặc chọn hoãn.',
      (CompanionEvent.reminderDue, Personality.cheerful) =>
        'Mình nhắc nhẹ nhé: {task}. Cùng tiến một chút nào!',
      (CompanionEvent.taskOverdueVisible, Personality.gentle) =>
        'Có việc đang quá hạn. Mình cùng chọn một việc vừa sức nhé.',
      (CompanionEvent.taskOverdueVisible, Personality.practical) =>
        'Xem lại việc quá hạn và chọn việc cần xử lý trước.',
      (CompanionEvent.taskOverdueVisible, Personality.cheerful) =>
        'Một bước nhỏ cũng đáng ghi nhận. Chọn một việc để tiếp tục nhé!',
      (CompanionEvent.dailyDigest, _) => '{summary}',
      (CompanionEvent.quietHours, _) =>
        '{name} đang nghỉ. Công việc của bạn vẫn ở đây.',
      (_, Personality.gentle) =>
        'Không cần làm tất cả. Bắt đầu bằng một việc nhỏ thôi.',
      (_, Personality.practical) =>
        'Chọn một việc quan trọng, rồi dành thời gian cho nó.',
      (_, Personality.cheerful) =>
        'Mình ở đây rồi! Hôm nay cùng tiến một chút nhé.',
    };

class CompanionProfile {
  CompanionProfile({
    this.name = 'Mầm',
    this.personality = Personality.gentle,
    Map<String, String> templates = const {},
    Map<CompanionEvent, CompanionExpression> expressions = const {},
  }) : templates = Map.unmodifiable(templates),
       expressions = Map.unmodifiable(expressions) {
    validate();
  }
  final String name;
  final Personality personality;
  final Map<String, String> templates;
  final Map<CompanionEvent, CompanionExpression> expressions;
  static String templateKey(Personality personality, CompanionEvent event) =>
      '${personality.name}:${event.name}';
  void validate() {
    if (name.trim().isEmpty ||
        name.length > 60 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
      throw const CompanionValidation(
        'Tên bạn đồng hành cần từ 1 đến 60 ký tự.',
      );
    }
    if (templates.length > 18) {
      throw const CompanionValidation('Có quá nhiều mẫu lời thoại.');
    }
    final allowed = {
      for (final p in Personality.values)
        for (final e in CompanionEvent.values) templateKey(p, e),
    };
    for (final entry in templates.entries) {
      if (!allowed.contains(entry.key)) {
        throw const CompanionValidation(
          'Mẫu lời thoại không thuộc tính cách hoặc sự kiện được hỗ trợ.',
        );
      }
      validateTemplate(entry.value);
    }
  }

  static void validateTemplate(String value) {
    if (value.trim().isEmpty || value.length > 500) {
      throw const CompanionValidation('Lời thoại cần từ 1 đến 500 ký tự.');
    }
    final rest = value.replaceAllMapped(
      RegExp(r'\{(name|task|summary)\}'),
      (_) => '',
    );
    if (rest.contains('{') || rest.contains('}')) {
      throw const CompanionValidation(
        'Chỉ dùng {name}, {task} hoặc {summary} trong mẫu lời thoại.',
      );
    }
  }

  CompanionExpression expressionFor(CompanionEvent event) =>
      expressions[event] ??
      switch (event) {
        CompanionEvent.taskCompleted => CompanionExpression.happy,
        CompanionEvent.reminderDue ||
        CompanionEvent.taskOverdueVisible => CompanionExpression.focused,
        CompanionEvent.quietHours => CompanionExpression.resting,
        _ => CompanionExpression.neutral,
      };
  String templateFor(CompanionEvent event, {Personality? tone}) =>
      templates[templateKey(tone ?? personality, event)] ??
      defaultDialogue(event, tone ?? personality);
  String messageFor(
    CompanionEvent event, {
    String? task,
    String? summary,
    Personality? tone,
  }) => templateFor(event, tone: tone).replaceAllMapped(
    RegExp(r'\{(name|task|summary)\}'),
    (match) => switch (match[1]) {
      'name' => name,
      'task' => task ?? 'công việc của bạn',
      _ => summary ?? 'Hôm nay chưa có việc cần nhắc.',
    },
  );
  CompanionProfile copy({
    String? name,
    Personality? personality,
    Map<String, String>? templates,
    Map<CompanionEvent, CompanionExpression>? expressions,
  }) => CompanionProfile(
    name: name ?? this.name,
    personality: personality ?? this.personality,
    templates: templates ?? this.templates,
    expressions: expressions ?? this.expressions,
  );
  bool sameAs(CompanionProfile other) =>
      name == other.name &&
      personality == other.personality &&
      templates.length == other.templates.length &&
      templates.entries.every((e) => other.templates[e.key] == e.value) &&
      expressions.length == other.expressions.length &&
      expressions.entries.every((e) => other.expressions[e.key] == e.value);
  Map<String, dynamic> toJson() => {
    'schema': 1,
    'name': name,
    'personality': personality.name,
    'templates': templates,
    'expressions': {
      for (final e in expressions.entries) e.key.name: e.value.name,
    },
  };
  factory CompanionProfile.fromJson(Map<String, dynamic> j) {
    try {
      if (j['schema'] != 1 ||
          j.keys.any(
            (k) => !{
              'schema',
              'name',
              'personality',
              'templates',
              'expressions',
            }.contains(k),
          )) {
        throw const CompanionValidation(
          'Định dạng hồ sơ Companion chưa được hỗ trợ.',
        );
      }
      final raw = (j['expressions'] as Map).cast<String, String>();
      return CompanionProfile(
        name: j['name'] as String,
        personality: Personality.values.byName(j['personality'] as String),
        templates: (j['templates'] as Map).cast<String, String>(),
        expressions: {
          for (final e in raw.entries)
            CompanionEvent.values.byName(e.key): CompanionExpression.values
                .byName(e.value),
        },
      );
    } on CompanionValidation {
      rethrow;
    } catch (_) {
      throw const CompanionValidation('Hồ sơ Companion không hợp lệ.');
    }
  }
}

class CompanionLayout {
  const CompanionLayout({
    this.placement = CompanionPlacement.automatic,
    this.size = 80,
    this.lowResource = false,
  });
  final CompanionPlacement placement;
  final double size;
  final bool lowResource;
  void validate() {
    if (!size.isFinite || size < 40 || size > 144) {
      throw const CompanionValidation(
        'Kích thước Companion cần từ 40 đến 144 dp.',
      );
    }
  }

  CompanionLayout copy({
    CompanionPlacement? placement,
    double? size,
    bool? lowResource,
  }) => CompanionLayout(
    placement: placement ?? this.placement,
    size: size ?? this.size,
    lowResource: lowResource ?? this.lowResource,
  );
  Map<String, dynamic> toJson() => {
    'placement': placement.name,
    'size': size,
    'lowResource': lowResource,
  };
  factory CompanionLayout.fromJson(Map<String, dynamic>? j) {
    final size = (j?['size'] as num?)?.toDouble() ?? 80;
    return CompanionLayout(
      placement:
          CompanionPlacement.values
              .where((p) => p.name == j?['placement'])
              .firstOrNull ??
          CompanionPlacement.automatic,
      size: size.isFinite ? size.clamp(40, 144) : 80,
      lowResource: j?['lowResource'] == true,
    );
  }
  double effectiveSize({required double width, required double textScale}) {
    final preferred = placement == CompanionPlacement.automatic ? 80.0 : size;
    final limit = width < 600 ? (textScale > 1.4 ? 56.0 : 96.0) : 144.0;
    return preferred.clamp(40, lowResource ? 56 : limit);
  }
}

class CompanionReply {
  const CompanionReply(this.text, this.expression);
  final String? text;
  final CompanionExpression expression;
}

class CompanionCue {
  const CompanionCue(this.event, this.announcement, {this.task, this.summary});
  final CompanionEvent event;
  final String announcement;
  final String? task, summary;
}

class CompanionBehavior {
  CompanionBehavior({DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final DateTime Function() clock;
  DateTime? _lastSpokenAt;
  String? _overdueDay;
  CompanionReply react(
    CompanionEvent event,
    CompanionProfile profile, {
    bool quiet = false,
    String? task,
    String? summary,
    String? day,
  }) {
    if (quiet || event == CompanionEvent.quietHours) {
      return CompanionReply(
        null,
        profile.expressionFor(CompanionEvent.quietHours),
      );
    }
    final now = clock();
    final elapsed = _lastSpokenAt == null
        ? null
        : now.difference(_lastSpokenAt!);
    if (elapsed != null &&
        !elapsed.isNegative &&
        elapsed < const Duration(seconds: 30)) {
      return CompanionReply(null, profile.expressionFor(event));
    }
    final key = day ?? '${now.year}-${now.month}-${now.day}';
    if (event == CompanionEvent.taskOverdueVisible && _overdueDay == key) {
      return CompanionReply(null, profile.expressionFor(event));
    }
    _lastSpokenAt = now;
    if (event == CompanionEvent.taskOverdueVisible) _overdueDay = key;
    return CompanionReply(
      profile.messageFor(event, task: task, summary: summary),
      profile.expressionFor(event),
    );
  }

  String? respond(CompanionEvent event, Personality personality) =>
      react(event, CompanionProfile(personality: personality)).text;
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
            isCharacterAssetName(json['assetName'] as String)
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
