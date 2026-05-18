import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../components/buttons/animation_button_effect.dart';
import '../../../../../theme/app_style.dart';

class ViewMode extends StatelessWidget {
  final String title;
  final bool isActive;
  final bool isLeft;
  final IconData icon;
  final VoidCallback onTap;

  const ViewMode({
    super.key,
    required this.title,
    required this.isActive,
    this.isLeft = true,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimationButtonEffect(
      child: ClipRRect(
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(isLeft ? 12.r : 0),
          right: Radius.circular(isLeft ? 0 : 12.r),
        ),
        child: InkWell(
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(isLeft ? 12.r : 0),
            right: Radius.circular(isLeft ? 0 : 12.r),
          ),
          onTap: onTap,
          child: Container(
            width: 100.w,
            padding: EdgeInsets.symmetric(vertical: 10.r),
            decoration: BoxDecoration(
                color: isActive ? AppStyle.primary : AppStyle.transparent,
                border: Border.all(
                    color: isActive ? AppStyle.primary : AppStyle.border),
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(isLeft ? 12.r : 0),
                  right: Radius.circular(isLeft ? 0 : 12.r),
                )),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isActive ? AppStyle.black : AppStyle.reviewText,
                  size: 20.r,
                ),
                14.horizontalSpace,
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w500,
                    color: isActive ? AppStyle.black : AppStyle.reviewText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
