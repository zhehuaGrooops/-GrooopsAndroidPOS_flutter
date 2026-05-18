import 'package:admin_desktop/src/core/utils/app_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppHelpers.centerAlignText', () {
    test('preserves explicit line breaks', () {
      final result = AppHelpers.centerAlignText('123\n234\n345', 7);

      expect(result.split('\n').map((line) => line.trim()).toList(),
          ['123', '234', '345']);
    });

    test('wraps long lines at word boundaries before centering', () {
      final result = AppHelpers.centerAlignText('123 234 345', 7);

      expect(result.split('\n').map((line) => line.trim()).toList(),
          ['123 234', '345']);
    });

    test('splits long tokens that exceed the target width', () {
      final result = AppHelpers.centerAlignText('123456789', 4);

      expect(result.split('\n').map((line) => line.trim()).toList(),
          ['1234', '5678', '9']);
    });
  });
}