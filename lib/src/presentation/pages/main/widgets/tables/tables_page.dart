import 'package:admin_desktop/src/presentation/pages/main/widgets/orders_table/widgets/view_mode.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/widgets/board_table_info.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/riverpod/tables_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/widgets/custom_refresher.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/widgets/list_table_info.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/widgets/tables_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/constants/constants.dart';
import '../../../../../core/utils/utils.dart';
import '../../../../components/filter_screen.dart';
import '../../../../theme/app_style.dart';
import '../orders_table/widgets/start_end_date.dart';
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
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tablesProvider);
    final notifier = ref.read(tablesProvider.notifier);
    return Padding(
      padding: REdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
              flex: !state.isListView ? 15 : 15,
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
                            onTap: () {
                              notifier.refresh();
                            },
                            isLoading: state.isLoading,
                          ),
                          const Spacer(),
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
                                        ? const TablesBoard()
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
                                        _tableStatus(
                                          tableStatus: TrKeys.available,
                                          tableCount:
                                              state.tableStatistic?.available ??
                                                  0,
                                          statusColor: AppStyle.hint,
                                          isLoading: state.isStatisticLoading,
                                        ),
                                        _tableStatus(
                                          tableStatus: TrKeys.booked,
                                          tableCount:
                                              state.tableStatistic?.booked ?? 0,
                                          statusColor: AppStyle.starColor,
                                          isLoading: state.isStatisticLoading,
                                        ),
                                        _tableStatus(
                                          tableStatus: TrKeys.occupied,
                                          tableCount:
                                              state.tableStatistic?.occupied ??
                                                  0,
                                          statusColor: AppStyle.red,
                                          isLoading: state.isStatisticLoading,
                                        ),
                                      ],
                                    ),
                                  )
                              ],
                            ),
                          ),
                          if (!state.isListView)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Consumer(builder: (context, ref, child) {
                                return DragTarget<int>(
                                  builder: (
                                    BuildContext context,
                                    List<dynamic> accepted,
                                    List<dynamic> rejected,
                                  ) {
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
                                    debugPrint(index.toString());
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
              flex: !state.isListView ? 7 : 7,
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
}
