import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../../core/constants/constants.dart';
import '../../../../../../core/utils/app_helpers.dart';
import '../../../../../../core/utils/local_storage.dart';
import '../../../../../theme/theme.dart';

class ManagerPinDialog extends StatefulWidget {
  final VoidCallback onVerified;

  const ManagerPinDialog({super.key, required this.onVerified});

  @override
  State<ManagerPinDialog> createState() => _ManagerPinDialogState();
}

class _ManagerPinDialogState extends State<ManagerPinDialog> {
  String _entered = '';
  bool _error = false;

  void _onKey(String digit) {
    if (_entered.length >= 4) return;
    setState(() {
      _entered += digit;
      _error = false;
    });
    if (_entered.length == 4) _verify();
  }

  void _onDelete() {
    if (_entered.isEmpty) return;
    setState(() {
      _entered = _entered.substring(0, _entered.length - 1);
      _error = false;
    });
  }

  void _verify() {
    final saved = LocalStorage.getPinCode();
    if (_entered == saved) {
      Navigator.pop(context);
      widget.onVerified();
    } else {
      setState(() {
        _entered = '';
        _error = true;
      });
    }
  }

  Widget _dot(bool filled) => Container(
        width: 14.r,
        height: 14.r,
        margin: REdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? AppStyle.primary : AppStyle.shimmerBase,
        ),
      );

  Widget _pinKey(String label, {VoidCallback? onTap, Widget? child}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72.r,
          height: 72.r,
          decoration: BoxDecoration(
            color: AppStyle.white,
            borderRadius: BorderRadius.circular(36.r),
            boxShadow: [
              BoxShadow(
                color: AppStyle.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: child ??
                Text(
                  label,
                  style: GoogleFonts.inter(
                      fontSize: 22.sp, fontWeight: FontWeight.w600),
                ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppHelpers.getTranslation(TrKeys.enterPinCode),
              style: GoogleFonts.inter(
                  fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.close, size: 24.r, color: AppStyle.black),
            ),
          ],
        ),
        24.verticalSpace,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) => _dot(i < _entered.length)),
        ),
        if (_error) ...[
          8.verticalSpace,
          Text(
            AppHelpers.getTranslation(TrKeys.enterPinCodeError),
            style: GoogleFonts.inter(color: AppStyle.red, fontSize: 13.sp),
          ),
        ],
        24.verticalSpace,
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', 'del'],
        ])
          Padding(
            padding: REdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((k) {
                if (k.isEmpty) return SizedBox(width: 72.r, height: 72.r);
                if (k == 'del') {
                  return _pinKey('',
                      onTap: _onDelete,
                      child: Icon(Icons.backspace_outlined,
                          size: 22.r, color: AppStyle.black));
                }
                return Padding(
                  padding: REdgeInsets.symmetric(horizontal: 12),
                  child: _pinKey(k, onTap: () => _onKey(k)),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
