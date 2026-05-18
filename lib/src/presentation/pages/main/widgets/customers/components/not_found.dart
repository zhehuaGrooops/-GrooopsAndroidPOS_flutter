import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../../../../../../core/constants/constants.dart';
import '../../../../../../core/utils/app_helpers.dart';
import 'package:admin_desktop/src/presentation/theme/theme.dart';

class NotFound extends StatelessWidget {
  const NotFound({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Lottie.asset("assets/lottie/not-found.json", height: 200.h),
        Text(
          AppHelpers.getTranslation(TrKeys.notFound),
          style: GoogleFonts.inter(
              fontSize: 18.sp,
              color: AppStyle.black,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
