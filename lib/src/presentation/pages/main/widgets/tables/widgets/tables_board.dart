import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../core/constants/constants.dart';
import '../../../../../../core/utils/utils.dart';
import '../../../../../../models/models.dart';
import '../../../../../components/components.dart';
import '../../../../../theme/theme.dart';
import '../riverpod/tables_notifier.dart';
import '../riverpod/tables_provider.dart';
import '../riverpod/tables_state.dart';
import 'add_new_table.dart';
import 'custom_table.dart';
import 'table_active_dialog.dart';
import 'table_timer_display.dart';

class TablesBoard extends ConsumerWidget {
  const TablesBoard({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final tableListData = ref.watch(tablesProvider).tableListData;
    final state = ref.watch(tablesProvider);
    final notifier = ref.read(tablesProvider.notifier);
    final hasPositions = state.tablePositions.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _topWidgets(state, notifier, context),
        16.verticalSpace,
        if (tableListData.isNotEmpty || !state.isLoading)
          Expanded(
            child: hasPositions
                ? _positionedLayout(state, notifier, context)
                : _wrapLayout(state, notifier, context),
          ),
        if (tableListData.isEmpty && state.isLoading)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: AppStyle.primary),
            ),
          ),
      ],
    );
  }

  Widget _positionedLayout(
      TablesState state, TablesNotifier notifier, BuildContext context) {
    final section = state.shopSectionList.isNotEmpty
        ? state.shopSectionList[state.selectSection]
        : null;
    final mapW = section?.mapWidth?.toDouble() ?? 800.0;
    final mapH = section?.mapHeight?.toDouble() ?? 600.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: SizedBox(
          width: mapW,
          height: mapH,
          child: Stack(
            children: state.tableListData.asMap().entries.map((entry) {
              final i = entry.key;
              final table = entry.value;
              if (table == null) return const SizedBox.shrink();
              final tableId = table.id ?? 0;
              final isOccupied = state.tableOrders.containsKey(tableId) ||
                  state.tableTimers.containsKey(tableId);
              final isBooked =
                  state.tableStatistic?.bookedIds.contains(tableId) ?? false;
              if (state.selectTabIndex == 1 && isOccupied) {
                return const SizedBox.shrink();
              }
              if (state.selectTabIndex == 3 && !isOccupied) {
                return const SizedBox.shrink();
              }
              final type = isOccupied
                  ? TrKeys.occupied
                  : isBooked
                      ? TrKeys.booked
                      : TrKeys.available;
              final tableModel = TableModel(
                name: table.name ?? "",
                chairCount: table.chairCount ?? 0,
                tax: table.tax ?? 0,
                shopSectionId: table.shopSectionId ?? 0,
              );
              final norm = state.tablePositions[tableId];
              final x = (norm?.dx ?? 0.0) * mapW;
              final y = (norm?.dy ?? 0.0) * mapH;

              return Positioned(
                left: x.clamp(0.0, mapW - 60),
                top: y.clamp(0.0, mapH - 60),
                child: Draggable<int>(
                  data: i,
                  feedback: CustomTable(tableModel: tableModel, type: type),
                  childWhenDragging: const SizedBox.shrink(),
                  child: GestureDetector(
                    onTap: () {
                      notifier.setSelectTable(i);
                      if (isOccupied) {
                        AppHelpers.showAlertDialog(
                          context: context,
                          child: TableActiveDialog(tableData: table),
                        );
                      } else {
                        notifier.enterTableOrdering(table);
                      }
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CustomTable(tableModel: tableModel, type: type),
                        if (isOccupied)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: TableTimerDisplay(
                              startDate: state.tableTimers[tableId],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _wrapLayout(
      TablesState state, TablesNotifier notifier, BuildContext context) {
    return ListView(
      children: [
        Wrap(
          children: [
            for (int i = 0; i < state.tableListData.length; i++)
              Builder(builder: (context) {
                final tableId = state.tableListData[i]?.id ?? 0;
                final isOccupied = state.tableOrders.containsKey(tableId) ||
                    state.tableTimers.containsKey(tableId);
                final isBooked =
                    state.tableStatistic?.bookedIds.contains(tableId) ?? false;
                if (state.selectTabIndex == 1 && isOccupied) {
                  return const SizedBox.shrink();
                }
                if (state.selectTabIndex == 3 && !isOccupied) {
                  return const SizedBox.shrink();
                }
                final type = isOccupied
                    ? TrKeys.occupied
                    : isBooked
                        ? TrKeys.booked
                        : TrKeys.available;
                final tableModel = TableModel(
                  name: state.tableListData[i]?.name ?? "",
                  chairCount: state.tableListData[i]?.chairCount ?? 0,
                  tax: state.tableListData[i]?.tax ?? 0,
                  shopSectionId: state.tableListData[i]?.shopSectionId ?? 0,
                );
                return Padding(
                  padding: REdgeInsets.only(right: 12, bottom: 12, top: 16),
                  child: Draggable<int>(
                    data: i,
                    feedback: CustomTable(tableModel: tableModel, type: type),
                    childWhenDragging: const SizedBox.shrink(),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: () {
                            notifier.setSelectTable(i);
                            if (isOccupied) {
                              if (state.tableListData[i] != null) {
                                AppHelpers.showAlertDialog(
                                  context: context,
                                  child: TableActiveDialog(
                                      tableData: state.tableListData[i]!),
                                );
                              }
                            } else {
                              notifier.enterTableOrdering(
                                  state.tableListData[i]!);
                            }
                          },
                          child: CustomTable(tableModel: tableModel, type: type),
                        ),
                        if (isOccupied)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: TableTimerDisplay(
                              startDate: state.tableTimers[tableId],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              })
          ],
        ),
        if (state.isLoading)
          const Center(
            child: CircularProgressIndicator(color: AppStyle.primary),
          ),
      ],
    );
  }

  Widget _topWidgets(
      TablesState state, TablesNotifier notifier, BuildContext context) {
    const statusList = [
      TrKeys.allTables,
      TrKeys.available,
      TrKeys.booked,
      TrKeys.occupied,
    ];
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
        ConfirmButton(
          paddingSize: 20,
          prefixIcon: Icon(FlutterRemix.add_fill, size: 28.r),
          textSize: 14,
          title: AppHelpers.getTranslation(TrKeys.addNewTable),
          textColor: AppStyle.black,
          onTap: () {
            if (!state.isSectionLoading && !state.isLoading) {
              AppHelpers.showAlertDialog(
                  context: context, child: const AddNewTable());
            }
          },
        )
      ],
    );
  }
}
