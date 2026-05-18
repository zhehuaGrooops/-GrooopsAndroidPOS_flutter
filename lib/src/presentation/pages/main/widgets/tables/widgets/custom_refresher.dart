import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';

import '../../../../../../../generated/assets.dart';
import '../../../../../components/buttons/animation_button_effect.dart';
import '../../../../../theme/theme.dart';

class CustomRefresher extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLoading;

  const CustomRefresher(
      {super.key, required this.onTap, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return AnimationButtonEffect(
      child: InkWell(
        borderRadius: BorderRadius.circular(10.r),
        onTap: onTap,
        child: Container(
          height: 44.r,
          width: 44.r,
          decoration: BoxDecoration(
              color: AppStyle.white,
              borderRadius: BorderRadiusDirectional.circular(10.r)),
          child: Center(
            child: isLoading
                ? Lottie.asset(
                    Assets.lottieRefresh,
                    width: 36.r,
                    height: 36.r,
                    fit: BoxFit.fill,
                  )
                : const Icon(FlutterRemix.refresh_line),
          ),
        ),
      ),
    );
  }
}
