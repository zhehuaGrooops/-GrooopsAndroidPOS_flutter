import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/core/utils/utils.dart';
import 'package:admin_desktop/src/models/data/table_data.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/riverpod/tables_notifier.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/riverpod/tables_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/riverpod/tables_state.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/widgets/custom_table.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/widgets/table_active_dialog.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/widgets/table_timer_display.dart';
import 'package:admin_desktop/src/presentation/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../theme/theme.dart';

class TableLayoutCanvas extends ConsumerStatefulWidget {
  const TableLayoutCanvas({super.key});

  @override
  ConsumerState<TableLayoutCanvas> createState() => _TableLayoutCanvasState();
}

class _TableLayoutCanvasState extends ConsumerState<TableLayoutCanvas> {
  static const double _defaultMapWidth = 800.0;
  static const double _defaultMapHeight = 600.0;
  static const double _snapGrid = 20.0;
  static const double _handleSize = 28.0;

  final TransformationController _transformCtrl = TransformationController();
  final Map<int, Offset> _dragPixels = {};
  int? _draggingId;
  double _viewZoom = 1.0;

  double _snap(double value) => (value / _snapGrid).round() * _snapGrid;

  void _setZoom(double zoom) {
    setState(() => _viewZoom = zoom);
    _transformCtrl.value = Matrix4.identity()..scale(zoom);
  }

  void _onTableTap(
      TableData table, TablesState state, TablesNotifier notifier) {
    final tableId = table.id ?? 0;
    if (state.tableTimers.containsKey(tableId)) {
      AppHelpers.showAlertDialog(
        context: context,
        child: TableActiveDialog(tableData: table),
      );
    } else {
      notifier.enterTableOrdering(table);
    }
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tablesProvider);
    final notifier = ref.read(tablesProvider.notifier);

    final section = state.shopSectionList.isNotEmpty
        ? state.shopSectionList[state.selectSection]
        : null;
    final mapW = section?.mapWidth?.toDouble() ?? _defaultMapWidth;
    final mapH = section?.mapHeight?.toDouble() ?? _defaultMapHeight;

    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!state.isEditMode) ...[
          _topWidgets(state, notifier),
          16.verticalSpace,
        ],
        Expanded(
          child: InteractiveViewer(
            transformationController: _transformCtrl,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(200),
            minScale: 0.5,
            maxScale: 2.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppStyle.primary.withValues(alpha: 0.45),
                  width: 2,
                ),
              ),
              position: DecorationPosition.foreground,
              child: SizedBox(
                width: mapW,
                height: mapH,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                          painter: _GridPainter(gridSize: _snapGrid)),
                    ),
                    ...state.tableListData.map((table) {
                      if (table == null) return const SizedBox.shrink();
                      final tableId = table.id ?? 0;

                      final fallbackCol =
                          state.tableListData.indexOf(table) % 5;
                      final fallbackRow =
                          state.tableListData.indexOf(table) ~/ 5;
                      final fallbackOffset = Offset(
                        fallbackCol * 110.0 + 12,
                        fallbackRow * 110.0 + 12,
                      );

                      final savedNorm = state.tablePositions[tableId];
                      final savedPixel = savedNorm != null
                          ? Offset(savedNorm.dx * mapW, savedNorm.dy * mapH)
                          : null;
                      final basePixel = savedPixel ?? fallbackOffset;
                      final pixelPos = _dragPixels[tableId] ?? basePixel;

                      final isOccupied =
                          state.tableOrders.containsKey(tableId) ||
                          state.tableTimers.containsKey(tableId);
                      if (state.selectTabIndex == 1 && isOccupied) {
                        return const SizedBox.shrink();
                      }
                      if (state.selectTabIndex == 3 && !isOccupied) {
                        return const SizedBox.shrink();
                      }
                      final isBooked =
                          state.tableStatistic?.bookedIds.contains(tableId) ??
                              false;
                      final type = isOccupied
                          ? TrKeys.occupied
                          : isBooked
                              ? TrKeys.booked
                              : TrKeys.available;
                      final tableModel = TableModel(
                        name: table.name ?? '',
                        chairCount: table.chairCount ?? 0,
                        tax: table.tax ?? 0,
                        shopSectionId: table.shopSectionId ?? 0,
                      );
                      final isDragging = _draggingId == tableId;

                      return Positioned(
                        left: pixelPos.dx.clamp(0.0, mapW - 60),
                        top: pixelPos.dy.clamp(0.0, mapH - 60),
                        child: RepaintBoundary(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              GestureDetector(
                                onTap: state.isEditMode
                                    ? null
                                    : () =>
                                        _onTableTap(table, state, notifier),
                                child: CustomTable(
                                    tableModel: tableModel, type: type),
                              ),
                              if (state.tableTimers.containsKey(tableId))
                                Positioned(
                                  top: 0,
                                  right:
                                      state.isEditMode ? _handleSize + 2 : 2,
                                  child: TableTimerDisplay(
                                    startDate: state.tableTimers[tableId],
                                  ),
                                ),
                              if (state.isEditMode)
                                Positioned(
                                  top: -4,
                                  left: -4,
                                  child: GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Table'),
                                          content: Text(
                                              'Delete "${table.name ?? ''}"?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                final idx = state.tableListData
                                                    .indexOf(table);
                                                if (idx >= 0) {
                                                  notifier.deleteTable(
                                                      index: idx);
                                                }
                                              },
                                              child: const Text('Delete',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: _handleSize,
                                      height: _handleSize,
                                      decoration: BoxDecoration(
                                        color: AppStyle.red,
                                        borderRadius:
                                            BorderRadius.circular(4.r),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppStyle.black
                                                .withValues(alpha: 0.15),
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.delete_outline,
                                        size: 16.r,
                                        color: AppStyle.white,
                                      ),
                                    ),
                                  ),
                                ),
                              if (state.isEditMode)
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: GestureDetector(
                                    onPanStart: (_) {
                                      setState(() => _draggingId = tableId);
                                    },
                                    onPanUpdate: (details) {
                                      setState(() {
                                        final current =
                                            _dragPixels[tableId] ?? basePixel;
                                        _dragPixels[tableId] =
                                            current + details.delta;
                                      });
                                    },
                                    onPanEnd: (_) {
                                      final raw =
                                          _dragPixels[tableId] ?? basePixel;
                                      final snapped = Offset(
                                        _snap(raw.dx).clamp(0.0, mapW),
                                        _snap(raw.dy).clamp(0.0, mapH),
                                      );
                                      setState(() {
                                        _dragPixels.remove(tableId);
                                        _draggingId = null;
                                      });
                                      notifier.updateTablePosition(
                                        tableId,
                                        (snapped.dx / mapW).clamp(0.0, 1.0),
                                        (snapped.dy / mapH).clamp(0.0, 1.0),
                                      );
                                    },
                                    onPanCancel: () {
                                      setState(() {
                                        _dragPixels.remove(tableId);
                                        _draggingId = null;
                                      });
                                    },
                                    child: Container(
                                      width: _handleSize,
                                      height: _handleSize,
                                      decoration: BoxDecoration(
                                        color: isDragging
                                            ? AppStyle.primary
                                            : AppStyle.white,
                                        borderRadius:
                                            BorderRadius.circular(4.r),
                                        border: Border.all(
                                          color: AppStyle.primary,
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppStyle.black
                                                .withValues(alpha: 0.15),
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        FlutterRemix.drag_move_2_fill,
                                        size: 16.r,
                                        color: isDragging
                                            ? AppStyle.white
                                            : AppStyle.primary,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _topWidgets(TablesState state, TablesNotifier notifier) {
    const statusList = [
      TrKeys.allTables,
      TrKeys.available,
      TrKeys.booked,
      TrKeys.occupied,
    ];
    const zoomLevels = [0.75, 1.0, 1.25];
    return Row(
      children: [
        for (int i = 0; i < statusList.length; i++)
          Padding(
            padding: REdgeInsets.only(left: 8),
            child: ConfirmButton(
              paddingSize: 18,
              textSize: 14,
              isActive: state.selectTabIndex == i,
              title: AppHelpers.getTranslation(statusList[i]),
              textColor: AppStyle.black,
              isTab: true,
              isShadow: true,
              onTap: () => notifier.changeIndex(i),
            ),
          ),
        const Spacer(),
        for (final zoom in zoomLevels)
          Padding(
            padding: REdgeInsets.only(left: 8),
            child: ConfirmButton(
              paddingSize: 16,
              textSize: 14,
              title: '${(zoom * 100).toInt()}%',
              textColor: AppStyle.black,
              isActive: _viewZoom == zoom,
              isShadow: true,
              isTab: true,
              onTap: () => _setZoom(zoom),
            ),
          ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  final double gridSize;

  const _GridPainter({required this.gridSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppStyle.hint.withValues(alpha: 0.12)
      ..strokeWidth = 0.5;

    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.gridSize != gridSize;
}
