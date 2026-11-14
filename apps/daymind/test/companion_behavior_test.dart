import 'package:flutter_test/flutter_test.dart';
import 'package:daymind_smart/features/companion/domain/companion.dart';
import 'package:daymind_smart/platform/notification_scheduler.dart';

void main() {
  test('quiet hours suppress dialogue without consuming the next permitted reaction', () {
    var now = DateTime.utc(2026, 1, 5, 6, 59);
    final behavior = CompanionBehavior(clock: () => now),
        profile = CompanionProfile();
    expect(
      behavior.react(CompanionEvent.reminderDue, profile, quiet: true).text,
      isNull,
    );
    expect(
      behavior
          .react(CompanionEvent.reminderDue, profile, quiet: true)
          .expression,
      CompanionExpression.resting,
    );
    now = now.add(const Duration(minutes: 1));
    expect(
      behavior
          .react(CompanionEvent.reminderDue, profile, task: 'Đọc sách')
          .text,
      contains('Đọc sách'),
    );
  });
  test('global cooldown applies across event types and handles a corrected device clock', () {
    var now = DateTime.utc(2026, 1, 5, 9);
    final behavior = CompanionBehavior(clock: () => now),
        profile = CompanionProfile();
    expect(behavior.react(CompanionEvent.appOpen, profile).text, isNotNull);
    now = now.add(const Duration(seconds: 29));
    expect(behavior.react(CompanionEvent.taskCompleted, profile).text, isNull);
    now = now.add(const Duration(seconds: 1));
    expect(
      behavior.react(CompanionEvent.taskCompleted, profile).text,
      isNotNull,
    );
    now = now.subtract(const Duration(hours: 1));
    expect(behavior.react(CompanionEvent.appOpen, profile).text, isNotNull);
  });
  test('overdue dialogue requires a visible event and is limited to one per local day', () {
    var now = DateTime.utc(2026, 1, 5, 9);
    final behavior = CompanionBehavior(clock: () => now),
        profile = CompanionProfile();
    expect(
      behavior
          .react(CompanionEvent.taskOverdueVisible, profile, day: '2026-01-05')
          .text,
      isNotNull,
    );
    now = now.add(const Duration(hours: 2));
    expect(
      behavior
          .react(CompanionEvent.taskOverdueVisible, profile, day: '2026-01-05')
          .text,
      isNull,
    );
    expect(
      behavior
          .react(CompanionEvent.taskOverdueVisible, profile, day: '2026-01-06')
          .text,
      isNotNull,
    );
  });
  test(
    'template variables are replaced once; task text and names stay literal',
    () {
      final profile = CompanionProfile(
        name: 'Bạn {task}',
        templates: {
          CompanionProfile.templateKey(
            Personality.gentle,
            CompanionEvent.reminderDue,
          ): '{name} nhắc {task} · {summary}',
        },
      );
      expect(
        profile.messageFor(
          CompanionEvent.reminderDue,
          task: 'Giữ {summary}',
          summary: 'Hai việc',
        ),
        'Bạn {task} nhắc Giữ {summary} · Hai việc',
      );
      final before = profile.toJson();
      profile.messageFor(CompanionEvent.taskCompleted);
      expect(profile.toJson(), before);
    },
  );
  test('malformed templates, unknown profile fields and oversized text are rejected', () {
    for (final invalid in ['', 'x' * 501, '{unknown}', '{{name}}']) {
      expect(
        () => CompanionProfile(templates: {'gentle:appOpen': invalid}),
        throwsA(isA<CompanionValidation>()),
      );
    }
    final profile = CompanionProfile();
    expect(
      () => CompanionProfile.fromJson({
        ...profile.toJson(),
        'assetName': 'private.png',
      }),
      throwsA(isA<CompanionValidation>()),
    );
    expect(
      () => profile.templates['gentle:appOpen'] = 'changed',
      throwsUnsupportedError,
    );
  });
  test('custom personality and expression mappings round trip without local asset names', () {
    final profile = CompanionProfile(
      name: 'Lá nhỏ',
      personality: Personality.practical,
      templates: {'practical:taskCompleted': '{name}: xong {task}.'},
      expressions: {CompanionEvent.taskCompleted: CompanionExpression.focused},
    );
    final loaded = CompanionProfile.fromJson(profile.toJson());
    expect(
      loaded.messageFor(CompanionEvent.taskCompleted, task: 'Báo cáo'),
      'Lá nhỏ: xong Báo cáo.',
    );
    expect(
      loaded.expressionFor(CompanionEvent.taskCompleted),
      CompanionExpression.focused,
    );
    expect(loaded.toJson().keys, isNot(contains('assetName')));
  });
  test('manual layout persists while small screens and large text enforce a safe size', () {
    const requested = CompanionLayout(
      placement: CompanionPlacement.right,
      size: 144,
    );
    final loaded = CompanionLayout.fromJson(requested.toJson());
    expect(loaded.placement, CompanionPlacement.right);
    expect(loaded.effectiveSize(width: 1440, textScale: 1), 144);
    expect(loaded.effectiveSize(width: 390, textScale: 1), 96);
    expect(loaded.effectiveSize(width: 390, textScale: 2), 56);
    expect(
      loaded.copy(lowResource: true).effectiveSize(width: 1440, textScale: 1),
      56,
    );
    expect(
      () => requested.copy(size: double.nan).validate(),
      throwsA(isA<CompanionValidation>()),
    );
  });
  test(
    'native foreground payload keeps digest separate from a task reaction',
    () {
      final work = PlatformNotificationScheduler.foregroundCue({
        'kind': 'reminder',
        'title': 'Việc đến hạn',
      })!;
      final digest = PlatformNotificationScheduler.foregroundCue({
        'kind': 'digest',
        'title': 'Hôm nay: 2 việc cần làm',
      })!;
      expect(work.event, CompanionEvent.reminderDue);
      expect(work.task, 'Việc đến hạn');
      expect(work.summary, isNull);
      expect(digest.event, CompanionEvent.dailyDigest);
      expect(digest.task, isNull);
      expect(digest.summary, 'Hôm nay: 2 việc cần làm');
      expect(
        PlatformNotificationScheduler.foregroundCue({'title': 45}),
        isNull,
      );
      expect(PlatformNotificationScheduler.foregroundCue('Cũ')!.task, 'Cũ');
    },
  );
}
