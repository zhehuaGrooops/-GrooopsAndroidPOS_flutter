import 'package:admin_desktop/generated/assets.dart';
import 'package:admin_desktop/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OrderStatusItem extends StatelessWidget {
  final Widget icon;
  final bool isActive;
  final bool isProgress;
  final Color bgColor;

  const OrderStatusItem(
      {super.key,
      required this.icon,
      required this.isActive,
      required this.isProgress,
      this.bgColor = AppStyle.primary});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
          color: isActive ? bgColor : AppStyle.white, shape: BoxShape.circle),
      child: Stack(
        children: [
          Positioned(
              top: 12.r, left: 12.r, bottom: 10.r, right: 10.r, child: icon),
          isProgress
              ? SvgPicture.asset(
                  Assets.svgOrderTime,
                  color: AppStyle.primary,
                  width: 52.r,
                  height: 52.r,
                )
              : SizedBox(
                  width: 52.r,
                  height: 52.r,
                ),
        ],
      ),
    );
  }
}
