import 'package:admin_desktop/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'buttons/animation_button_effect.dart';

class LoginButton extends StatelessWidget {
  final Key? fieldKey;
  final String title;
  final bool isLoading;
  final bool isActive;
  final Color bgColor;
  final Color titleColor;
  final Function()? onPressed;

  const LoginButton({
    super.key,
    this.fieldKey,
    required this.title,
    required this.onPressed,
    this.isLoading = false,
    this.isActive = true,
    this.bgColor = AppStyle.primary,
    this.titleColor = AppStyle.black,
  });

  @override
  Widget build(BuildContext context) {
    return AnimationButtonEffect(
      child: Material(
        borderRadius: BorderRadius.circular(8.r),
        color: isActive ? bgColor : AppStyle.selectedItemsText,
        child: Semantics(
          label: title.toLowerCase(),
          button: true,
          enabled: isActive,
          child: InkWell(
            key: fieldKey,
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8.r),
            child: Container(
              height: 56.r,
              padding: EdgeInsets.symmetric(horizontal: 12.r),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                      color: bgColor == AppStyle.transparent
                          ? AppStyle.selectedItemsText
                          : AppStyle.transparent)),
              alignment: Alignment.center,
              child: isLoading
                  ? SizedBox(
                      height: 24.r,
                      width: 24.r,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.r,
                        color: AppStyle.white,
                      ),
                    )
                  : Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
                        color: isActive ? titleColor : AppStyle.black,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
