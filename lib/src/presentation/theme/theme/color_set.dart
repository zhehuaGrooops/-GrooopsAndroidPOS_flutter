part of 'theme.dart';

class CustomColorSet {
  final Color primary;

  final Color white;

  final Color textHint;

  final Color textBlack;

  final Color textWhite;

  final Color icon;

  final Color success;

  final Color error;

  final Color transparent;

  final Color backgroundColor;

  final Color socialButtonColor;

  final Color newBoxColor;

  final Color bottomBarColor;

  final Color categoryColor;

  final Color categoryTitleColor;

  CustomColorSet._({
    required this.textHint,
    required this.textBlack,
    required this.textWhite,
    required this.primary,
    required this.white,
    required this.icon,
    required this.success,
    required this.error,
    required this.transparent,
    required this.backgroundColor,
    required this.socialButtonColor,
    required this.bottomBarColor,
    required this.categoryColor,
    required this.categoryTitleColor,
    required this.newBoxColor,
  });

  factory CustomColorSet._create(CustomThemeMode mode) {
    final isLight = mode.isLight;

    final textHint = isLight ? AppStyle.hint : AppStyle.white;

    final textBlack = isLight ? AppStyle.black : AppStyle.white;

    final textWhite = isLight ? AppStyle.white : AppStyle.black;

    final categoryColor = isLight ? AppStyle.black : AppStyle.iconButtonBack;

    final categoryTitleColor = isLight ? AppStyle.black : AppStyle.white;

    const primary = AppStyle.primary;

    const white = AppStyle.white;

    const icon = AppStyle.icon;

    final backgroundColor =
        isLight ? AppStyle.mainBack : AppStyle.iconButtonBack;

    final newBoxColor = isLight ? AppStyle.icon : AppStyle.iconButtonBack;

    const success = AppStyle.primary;

    const error = AppStyle.red;

    const transparent = AppStyle.transparent;

    final socialButtonColor = isLight ? AppStyle.icon : AppStyle.iconButtonBack;

    final bottomBarColor =
        isLight ? AppStyle.icon.withOpacity(0.8) : AppStyle.iconButtonBack;

    return CustomColorSet._(
      categoryColor: categoryColor,
      textHint: textHint,
      textBlack: textBlack,
      textWhite: textWhite,
      primary: primary,
      white: white,
      icon: icon,
      backgroundColor: backgroundColor,
      success: success,
      error: error,
      transparent: transparent,
      socialButtonColor: socialButtonColor,
      bottomBarColor: bottomBarColor,
      categoryTitleColor: categoryTitleColor,
      newBoxColor: newBoxColor,
    );
  }

  static CustomColorSet createOrUpdate(CustomThemeMode mode) {
    return CustomColorSet._create(mode);
  }
}
