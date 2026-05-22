import 'package:admin_desktop/src/models/data/table_data.dart';
import 'package:admin_desktop/src/presentation/pages/main/riverpod/provider/main_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/left_side.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/order_calculate/order_calculate.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/orders_table/widgets/view_mode.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/right_side/right_side.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/right_side/riverpod/right_side_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/widgets/add_new_table.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/widgets/board_table_info.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/riverpod/tables_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/riverpod/tables_state.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/widgets/custom_refresher.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/widgets/list_table_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/constants/constants.dart';
import '../../../../../core/utils/utils.dart';
import '../../../../components/components.dart';
import '../../../../components/filter_screen.dart';
import '../../../../theme/app_style.dart';
import '../orders_table/widgets/start_end_date.dart';
import 'widgets/table_layout_canvas.dart';
import 'widgets/tables_list.dart';

class TablesPage extends ConsumerStatefulWidget {
  const TablesPage({super.key});

  @override
  ConsumerState<TablesPage> createState() => _TablesPageState();
}

class _TablesPageState extends ConsumerState<TablesPage> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tablesProvider.notifier).initial();
      ref.read(tablesProvider.notifier).loadTableStatuses();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tablesProvider);
    final notifier = ref.read(tablesProvider.notifier);

    ref.listen<TablesState>(tablesProvider, (prev, next) {
      if (prev?.activeOrderTable == null && next.activeOrderTable != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(rightSideProvider.notifier).presetTableContext(
                next.activeOrderTable!,
                section: next.activeOrderTable!.shopSection,
              );
        });
      }

      final activeTable = next.activeOrderTable;
      if (activeTable == null) return;
      final tableId = activeTable.id ?? 0;
      final prevHasTimer = prev?.tableTimers.containsKey(tableId) ?? false;
      final nextHasTimer = next.tableTimers.containsKey(tableId);
      final prevOrder = prev?.tableOrders[tableId];
      final nextOrder = next.tableOrders[tableId];
      final timerJustStarted = !prevHasTimer && nextHasTimer;
      final reorderCompleted =
          prevHasTimer && prevOrder != nextOrder && nextOrder != null;
      if (timerJustStarted || reorderCompleted) {
        ref.read(mainProvider.notifier).setPriceDate(null);
        notifier.exitTableOrdering();
      }
    });

    if (state.activeOrderTable != null) {
      return _TableOrderingView(
        tableData: state.activeOrderTable!,
        onExit: () {
          ref.read(mainProvider.notifier).setPriceDate(null);
          notifier.exitTableOrdering();
        },
      );
    }

    return Padding(
      padding: REdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
              flex: 15,
              child: Padding(
                  padding: REdgeInsets.only(left: 16, right: 17),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            AppHelpers.getTranslation(TrKeys.tables),
                            style: GoogleFonts.inter(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          16.horizontalSpace,
                          StartEndDate(
                            start: state.start,
                            end: state.end,
                            filterScreen: FilterScreen(
                              isTable: !state.isListView ? true : false,
                              isBooking: state.isListView ? true : false,
                            ),
                          ),
                          12.horizontalSpace,
                          CustomRefresher(
                            onTap: () => notifier.refresh(),
                            isLoading: state.isLoading,
                          ),
                          if (!state.isListView) ...[
                            12.horizontalSpace,
                            ConfirmButton(
                              paddingSize: 16,
                              textSize: 14,
                              title: state.isEditMode ? 'Done' : 'Edit Layout',
                              textColor: AppStyle.black,
                              bgColor: state.isEditMode
                                  ? AppStyle.primary
                                  : AppStyle.white,
                              isActive: true,
                              isShadow: true,
                              onTap: () => notifier.toggleEditMode(),
                            ),
                            if (state.isEditMode) ...[
                              8.horizontalSpace,
                              ConfirmButton(
                                paddingSize: 16,
                                textSize: 14,
                                title: 'Map Size',
                                textColor: AppStyle.black,
                                isShadow: true,
                                onTap: () => _showMapSizeDialog(
                                    context, state, notifier),
                              ),
                              8.horizontalSpace,
                              ConfirmButton(
                                paddingSize: 16,
                                textSize: 14,
                                title: AppHelpers.getTranslation(
                                    TrKeys.addNewTable),
                                textColor: AppStyle.black,
                                isShadow: true,
                                onTap: () {
                                  if (!state.isSectionLoading &&
                                      !state.isLoading) {
                                    AppHelpers.showAlertDialog(
                                        context: context,
                                        child: const AddNewTable());
                                  }
                                },
                              ),
                            ],
                          ],
                          const Spacer(),
                          if (!state.isEditMode) ...[
                            ViewMode(
                              title: AppHelpers.getTranslation(TrKeys.board),
                              isActive: !state.isListView,
                              icon: FlutterRemix.dashboard_line,
                              onTap: () => notifier.changeViewMode(0),
                            ),
                            ViewMode(
                              title: AppHelpers.getTranslation(TrKeys.list),
                              isActive: state.isListView,
                              isLeft: false,
                              icon: FlutterRemix.menu_fill,
                              onTap: () => notifier.changeViewMode(1),
                            ),
                          ],
                        ],
                      ),
                      Expanded(
                          child: Stack(
                        children: [
                          SizedBox(
                            height: double.infinity,
                            width: double.infinity,
                            child: Column(
                              children: [
                                16.verticalSpace,
                                Expanded(
                                    child: !state.isListView
                                        ? const TableLayoutCanvas()
                                        : const TablesList()),
                                if (!state.isListView)
                                  Container(
                                    width: double.infinity,
                                    padding: REdgeInsets.symmetric(
                                        vertical: 7, horizontal: 18),
                                    decoration: BoxDecoration(
                                        color: AppStyle.white,
                                        borderRadius:
                                            BorderRadius.circular(10.r)),
                                    child: Row(
                                      children: [
                                        Padding(
                                          padding: REdgeInsets.symmetric(
                                              vertical: 10),
                                          child: Text(
                                              AppHelpers.getTranslation(
                                                TrKeys.tables,
                                              ),
                                              style: GoogleFonts.inter(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w600,
                                              )),
                                        ),
                                        14.horizontalSpace,
                                        SizedBox(
                                          height: 42.r,
                                          child: const VerticalDivider(
                                              color: AppStyle.hint,
                                              thickness: 1),
                                        ),
                                        Builder(builder: (_) {
                                          final localOccupied =
                                              state.tableOrders.length;
                                          final backendBooked =
                                              state.tableStatistic?.booked ?? 0;
                                          final backendTotal =
                                              (state.tableStatistic?.available ??
                                                      0) +
                                                  backendBooked +
                                                  (state.tableStatistic
                                                          ?.occupied ??
                                                      0);
                                          final localAvailable = (backendTotal -
                                                  backendBooked -
                                                  localOccupied)
                                              .clamp(0, backendTotal);
                                          return Row(children: [
                                            _tableStatus(
                                              tableStatus: TrKeys.available,
                                              tableCount: localAvailable,
                                              statusColor: AppStyle.hint,
                                              isLoading:
                                                  state.isStatisticLoading,
                                            ),
                                            _tableStatus(
                                              tableStatus: TrKeys.booked,
                                              tableCount: backendBooked,
                                              statusColor: AppStyle.starColor,
                                              isLoading:
                                                  state.isStatisticLoading,
                                            ),
                                            _tableStatus(
                                              tableStatus: TrKeys.occupied,
                                              tableCount: localOccupied,
                                              statusColor: AppStyle.red,
                                              isLoading:
                                                  state.isStatisticLoading,
                                            ),
                                          ]);
                                        }),
                                      ],
                                    ),
                                  )
                              ],
                            ),
                          ),
                          if (!state.isListView && state.isEditMode)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Consumer(builder: (context, ref, child) {
                                return DragTarget<int>(
                                  builder: (context, accepted, rejected) {
                                    return Padding(
                                      padding: REdgeInsets.only(
                                          top: 100,
                                          left: 48,
                                          right: 36,
                                          bottom: 6),
                                      child: Container(
                                        height: 42.r,
                                        padding: REdgeInsets.symmetric(
                                            horizontal: 16),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          color: AppStyle.shimmerBase,
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.delete,
                                            size: 21.sp,
                                            color: AppStyle.black,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  onAccept: (int index) {
                                    ref
                                        .read(tablesProvider.notifier)
                                        .deleteTable(index: index);
                                  },
                                );
                              }),
                            ),
                        ],
                      )),
                    ],
                  ))),
          Expanded(
              flex: 7,
              child: !state.isListView
                  ? const BoardTableInfo()
                  : const ListTableInfo()),
        ],
      ),
    );
  }

  _tableStatus({
    required String tableStatus,
    required int tableCount,
    required Color statusColor,
    required bool isLoading,
  }) {
    return Padding(
      padding: REdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Container(
            height: 14.r,
            width: 14.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
            ),
          ),
          6.r.horizontalSpace,
          Text(
            "${AppHelpers.getTranslation(tableStatus)} : ",
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppStyle.reviewText,
            ),
          ),
          if (isLoading)
            Padding(
              padding: REdgeInsets.only(left: 3),
              child: SizedBox(
                  height: 18.r,
                  width: 18.r,
                  child: const CircularProgressIndicator(
                    color: AppStyle.primary,
                    strokeWidth: 2.2,
                  )),
            ),
          if (!isLoading)
            Text(
              "$tableCount",
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: AppStyle.reviewText,
              ),
            ),
        ],
      ),
    );
  }

  void _showMapSizeDialog(
      BuildContext context, TablesState state, dynamic notifier) {
    final section = state.shopSectionList.isNotEmpty
        ? state.shopSectionList[state.selectSection]
        : null;
    final wCtrl =
        TextEditingController(text: '${section?.mapWidth ?? 800}');
    final hCtrl =
        TextEditingController(text: '${section?.mapHeight ?? 600}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Map Size',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Width (px)'),
            ),
            8.verticalSpace,
            TextField(
              controller: hCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Height (px)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final w = int.tryParse(wCtrl.text) ?? 800;
              final h = int.tryParse(hCtrl.text) ?? 600;
              if (w >= 200 && w <= 4000 && h >= 200 && h <= 4000) {
                final sectionId = section?.id;
                if (sectionId != null) {
                  notifier.updateMapSize(sectionId, w, h);
                }
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _TableOrderingView extends ConsumerWidget {
  final TableData tableData;
  final VoidCallback onExit;

  const _TableOrderingView({required this.tableData, required this.onExit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priceDate = ref.watch(mainProvider).priceDate;
    final tablesState = ref.watch(tablesProvider);
    final tableId = tableData.id ?? 0;
    final isReorder = tablesState.tableTimers.containsKey(tableId);
    final existingItems = (priceDate == null && isReorder)
        ? LocalStorage.getTableItems(tableId)
        : <Map<String, dynamic>>[];

    return Column(
      children: [
        Container(
          padding: REdgeInsets.symmetric(horizontal: 32, vertical: 14),
          decoration: const BoxDecoration(
            color: AppStyle.white,
            border: Border(
              bottom: BorderSide(color: AppStyle.hint, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              if (priceDate != null)
                GestureDetector(
                  onTap: () =>
                      ref.read(mainProvider.notifier).setPriceDate(null),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 20.r, color: AppStyle.black),
                )
              else
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.r, vertical: 4.r),
                  decoration: BoxDecoration(
                    color: AppStyle.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    'Dine In',
                    style: GoogleFonts.inter(
                      color: AppStyle.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              12.horizontalSpace,
              Expanded(
                child: Text(
                  tableData.name ?? '',
                  style: GoogleFonts.inter(
                    color: AppStyle.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 18.sp,
                  ),
                ),
              ),
              if (priceDate == null)
                GestureDetector(
                  onTap: onExit,
                  child:
                      Icon(Icons.close, color: AppStyle.black, size: 24.r),
                ),
            ],
          ),
        ),
        if (existingItems.isNotEmpty) _ExistingOrderBanner(items: existingItems),
        Expanded(
          child: priceDate != null
              ? const OrderCalculate()
              : Padding(
                  padding: REdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(child: LeftSide()),
                      16.horizontalSpace,
                      SizedBox(
                        width: MediaQuery.of(context).size.width / 3.2,
                        child: const RightSide(),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _ExistingOrderBanner extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  const _ExistingOrderBanner({required this.items});

  @override
  State<_ExistingOrderBanner> createState() => _ExistingOrderBannerState();
}

class _ExistingOrderBannerState extends State<_ExistingOrderBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final num total = widget.items
        .fold<num>(0, (s, i) => s + ((i['totalPrice'] as num?) ?? 0));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppStyle.primary.withValues(alpha: 0.06),
        border: const Border(
          bottom: BorderSide(color: AppStyle.primary, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: REdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 16.r, color: AppStyle.primary),
                  6.horizontalSpace,
                  Text(
                    'Current order · ${widget.items.length} item${widget.items.length == 1 ? '' : 's'}'
                    '  |  ${AppHelpers.numberFormat(total)}',
                    style: GoogleFonts.inter(
                      color: AppStyle.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.sp,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16.r,
                    color: AppStyle.primary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 140.r),
              child: ListView.builder(
                shrinkWrap: true,
                padding:
                    REdgeInsets.symmetric(horizontal: 20, vertical: 4),
                itemCount: widget.items.length,
                itemBuilder: (_, i) {
                  final item = widget.items[i];
                  final name =
                      (item['productName'] as String?)?.isNotEmpty == true
                          ? item['productName'] as String
                          : (item['categoryName'] as String? ?? 'Item');
                  final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                  final price = item['totalPrice'] as num? ?? 0;
                  final addons = List<String>.from(
                      item['addonNames'] as List? ?? []);
                  return Padding(
                    padding: REdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 22.r,
                          height: 22.r,
                          decoration: BoxDecoration(
                            color:
                                AppStyle.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Center(
                            child: Text(
                              'x$qty',
                              style: GoogleFonts.inter(
                                color: AppStyle.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 9.sp,
                              ),
                            ),
                          ),
                        ),
                        6.horizontalSpace,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.inter(
                                  color: AppStyle.black,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (addons.isNotEmpty)
                                Text(
                                  addons.join(', '),
                                  style: GoogleFonts.inter(
                                    color: AppStyle.reviewText,
                                    fontSize: 10.sp,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          AppHelpers.numberFormat(price),
                          style: GoogleFonts.inter(
                            color: AppStyle.black,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
