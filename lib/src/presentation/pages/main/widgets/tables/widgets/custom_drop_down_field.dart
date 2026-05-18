import 'package:admin_desktop/src/core/utils/app_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../theme/theme.dart';

class CustomDropDownField extends StatelessWidget {
  final String? value;
  final List list;
  final ValueChanged onChanged;
  final IconData iconData;
  final String? Function(String?)? validator;

  const CustomDropDownField({
    super.key,
    this.value,
    required this.list,
    required this.onChanged,
    required this.iconData,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField(
      validator: (s) => validator?.call((s.toString())),
      value: value,
      items: list.map((e) {
        return DropdownMenuItem(
            value: e, child: Text(AppHelpers.getTranslation(e)));
      }).toList(),
      onChanged: onChanged,
      dropdownColor: AppStyle.white,
      iconEnabledColor: AppStyle.black,
      borderRadius: BorderRadius.circular(10.r),
      style: GoogleFonts.inter(
          color: AppStyle.black, fontWeight: FontWeight.w500, fontSize: 14.sp),
      icon: const Icon(FlutterRemix.arrow_down_s_line),
      decoration: InputDecoration(
        contentPadding: REdgeInsets.symmetric(vertical: 12, horizontal: 12),
        prefixIcon: Icon(
          iconData,
          size: 26.r,
          color: AppStyle.black,
        ),
        filled: true,
        fillColor: AppStyle.editProfileCircle,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.r),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.r),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.r),
            borderSide: BorderSide.none),
      ),
    );
  }
}
