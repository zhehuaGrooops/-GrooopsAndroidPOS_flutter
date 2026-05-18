import 'package:admin_desktop/src/presentation/components/buttons/animation_button_effect.dart';
import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../theme/app_style.dart';

class PopButton extends StatelessWidget {
  final String heroTag;

  const PopButton({
    super.key,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return AnimationButtonEffect(
      child: Hero(
        tag: heroTag,
        child: GestureDetector(
          onTap: context.maybePop,
          child: Container(
            width: 56.r,
            height: 56.r,
            decoration: BoxDecoration(
              color: AppStyle.black,
              borderRadius: BorderRadius.circular(10.r),
            ),
            alignment: Alignment.center,
            child: Icon(
              FlutterRemix.arrow_left_s_line,
              color: AppStyle.white,
              size: 20.r,
            ),
          ),
        ),
      ),
    );
  }
}
