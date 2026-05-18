import 'package:admin_desktop/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class SizeItem extends StatelessWidget {
  final VoidCallback onTap;
  final bool isActive;
  final String title;

  const SizeItem({
    super.key,
    required this.onTap,
    required this.isActive,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 16.h),
      child: GestureDetector(
        onTap: () {
          onTap();
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
              color: AppStyle.white,
              borderRadius: BorderRadius.all(Radius.circular(10.r))),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: 20.w,
                    height: 20.h,
                    decoration: BoxDecoration(
                        color:
                            isActive ? AppStyle.primary : AppStyle.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: isActive ? AppStyle.black : AppStyle.icon,
                            width: isActive ? 4.r : 2.r)),
                  ),
                  16.horizontalSpace,
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppStyle.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
