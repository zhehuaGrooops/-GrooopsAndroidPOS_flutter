import 'package:admin_desktop/src/core/utils/time_service.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:admin_desktop/src/presentation/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:admin_desktop/src/presentation/theme/theme.dart';

class CustomersList extends StatelessWidget {
  final UserData? user;

  const CustomersList({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        14.verticalSpace,
        Row(
          children: [
            Expanded(
              child: Divider(color: AppStyle.black.withOpacity(0.2)),
            )
          ],
        ),
        14.verticalSpace,
        Row(
          children: [
            CommonImage(
              imageUrl: user?.img,
              radius: 25,
              height: 50,
              width: 50,
            ),
            14.horizontalSpace,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user?.firstname ?? ''} ${user?.lastname ?? ''}',
                  style: GoogleFonts.inter(
                      fontSize: 16.sp,
                      color: AppStyle.black,
                      fontWeight: FontWeight.w600),
                ),
                4.verticalSpace,
                Text(
                  user?.email ?? '',
                  style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: AppStyle.icon,
                      fontWeight: FontWeight.w400),
                )
              ],
            ),
            const Spacer(),
            Text(
              TimeService.dateFormatYMDHm(
                  DateTime.tryParse(user?.registeredAt ?? '')),
              style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: AppStyle.icon,
                  fontWeight: FontWeight.w400),
            ),
            8.r.horizontalSpace,
          ],
        ),
      ],
    );
  }
}
