import 'package:admin_desktop/src/presentation/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomButton extends StatelessWidget {
  final Color? border;
  final Color? textColor;
  final Color? background;
  final String? title;
  final Function()? onTap;
  final bool? isLoading;
  final Widget? loadingwidget;
  const CustomButton(
      {super.key,
      this.border,
      this.title,
      this.textColor,
      this.background,
      this.onTap,
      this.isLoading,
      this.loadingwidget});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40.r,
        width: 148.r,
        decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: border ?? AppStyle.transparent)),
        child: Center(
          child: isLoading ?? false
              ? loadingwidget
              : Text(
                  title ?? '',
                  style: GoogleFonts.inter(
                      fontSize: 16.sp,
                      color: textColor,
                      fontWeight: FontWeight.w500),
                ),
        ),
      ),
    );
  }
}
