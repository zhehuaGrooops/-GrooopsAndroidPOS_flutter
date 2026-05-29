import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../../core/utils/table_timer_utils.dart';
import '../../../../../theme/theme.dart';

class TableTimerDisplay extends StatefulWidget {
  final DateTime? startDate;
  final DateTime Function()? clock;

  const TableTimerDisplay({super.key, required this.startDate, this.clock});

  @override
  State<TableTimerDisplay> createState() => _TableTimerDisplayState();
}

class _TableTimerDisplayState extends State<TableTimerDisplay> {
  late Duration _elapsed;
  Timer? _timer;

  DateTime Function() get _clock => widget.clock ?? DateTime.now;

  @override
  void initState() {
    super.initState();
    _elapsed = _compute();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed = _compute());
    });
  }

  Duration _compute() => widget.startDate != null
      ? _clock().difference(widget.startDate!)
      : Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppStyle.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: AppStyle.white, size: 16),
          const SizedBox(width: 6),
          Text(
            formatElapsedTime(_elapsed),
            style: GoogleFonts.inter(
              color: AppStyle.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
