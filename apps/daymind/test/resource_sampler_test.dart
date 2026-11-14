import 'package:flutter_test/flutter_test.dart';

import 'dart:io';

import '../integration_test/support/resource_sampler.dart';

void main() {
  test('real CPU accounting increases with work and reports unavailable explicitly', () {
    final sampler = ResourceSampler();
    final clock = Stopwatch()..start();
    var value = 1;
    while (clock.elapsedMilliseconds < 80) {
      value = (value * 1664525 + 1013904223) & 0xffffffff;
      sampler.sample();
    }
    final result = sampler.finish();
    expect(value, isNonNegative);
    expect(result['elapsedMs'] as int, greaterThanOrEqualTo(80));
    expect(result['rssSamplePeak'] as int, greaterThan(0));
    if (Platform.isLinux || Platform.isWindows || Platform.isAndroid) {
      expect(result['cpuSupported'], isTrue);
    }
    if (result['cpuSupported'] == true) {
      expect(result['cpuMs'] as int, greaterThan(0));
      expect(result['cpuPercentOneCore'] as num, greaterThan(0));
    } else {
      expect(result['cpuMs'], isNull);
    }
  });
}
