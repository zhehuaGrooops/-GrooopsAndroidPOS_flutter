// ignore_for_file: constant_identifier_names

import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/core/utils/app_helpers.dart';

abstract class ValidatorUtils {
  static String? validateEmpty(String? input) {
    if (input == null || input.isEmpty) {
      return AppHelpers.getTranslation(TrKeys.fieldRequired);
    } else {
      return null;
    }
  }

  static String? validateChairCount(String? input) {
    if (input == null || input.isEmpty) {
      return AppHelpers.getTranslation(TrKeys.fieldRequired);
    }
    final value = int.tryParse(input);
    if (value == null || value < 1) {
      return 'Chair count must be at least 1';
    }
    if (value > 100) {
      return 'Chair count cannot exceed 100';
    }
    return null;
  }
}
