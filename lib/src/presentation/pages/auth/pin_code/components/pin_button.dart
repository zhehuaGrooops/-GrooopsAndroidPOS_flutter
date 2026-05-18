import 'package:admin_desktop/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../components/buttons/animation_button_effect.dart';

class PinButton extends StatelessWidget {
  final Key? fieldKey;
  final String? title;
  final IconData? iconData;
  final VoidCallback onTap;

  const PinButton(
      {super.key,
      this.fieldKey,
      this.title,
      this.iconData,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimationButtonEffect(
      child: Semantics(
        label: title?.toLowerCase(),
        button: true,
        child: InkWell(
          key: fieldKey,
          borderRadius: BorderRadius.circular(5.r),
          onTap: onTap,
          child: Container(
            height: 68.r,
            width: 68.r,
            decoration: BoxDecoration(
                border:
                    Border.all(width: 2, color: AppStyle.outlineButtonBorder),
                borderRadius: BorderRadius.circular(5.r)),
            child: Center(
              child: title != null
                  ? Text(
                      title!,
                      style: GoogleFonts.inter(
                        color: AppStyle.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 26.sp,
                      ),
                    )
                  : iconData != null
                      ? Icon(
                          iconData!,
                          size: 26.r,
                        )
                      : const Placeholder(),
            ),
          ),
        ),
      ),
    );
  }
}
