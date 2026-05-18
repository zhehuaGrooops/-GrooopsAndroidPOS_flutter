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
import 'new_order_screen.dart';

class TablesBoard extends ConsumerWidget {
  const TablesBoard({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final tableListData = ref.watch(tablesProvider).tableListData;
    final state = ref.watch(tablesProvider);
    final notifier = ref.read(tablesProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _topWidgets(ref.watch(tablesProvider),
            ref.read(tablesProvider.notifier), context),
        16.verticalSpace,
        if (tableListData.isNotEmpty || !state.isLoading)
          Expanded(
            child: ListView(
              children: [
                Wrap(
                  children: [
                    for (int i = 0; i < tableListData.length; i++)
                      Padding(
                          padding:
                              REdgeInsets.only(right: 12, bottom: 12, top: 16),
                          child: Draggable<int>(
                            data: i,
                            feedback: CustomTable(
                              tableModel: TableModel(
                                name: tableListData[i]?.name ?? "",
                                chairCount: tableListData[i]?.chairCount ?? 0,
                                tax: tableListData[i]?.tax ?? 0,
                                shopSectionId:
                                    tableListData[i]?.shopSectionId ?? 0,
                              ),
                              type: (state.tableStatistic?.occupiedIds.contains(
                                          tableListData[i]?.id ?? 0) ??
                                      false)
                                  ? TrKeys.occupied
                                  : (state.tableStatistic?.bookedIds.contains(
                                              tableListData[i]?.id ?? 0) ??
                                          false)
                                      ? TrKeys.booked
                                      : TrKeys.available,
                            ),
                            childWhenDragging: const SizedBox.shrink(),
                            child: GestureDetector(
                              onTap: () {
                                notifier.setSelectTable(i);
                                AppHelpers.showAlertDialog(
                                    context: context,
                                    child: const NewOrderScreen());
                              },
                              child: CustomTable(
                                tableModel: TableModel(
                                  name: tableListData[i]?.name ?? "",
                                  chairCount: tableListData[i]?.chairCount ?? 0,
                                  tax: tableListData[i]?.tax ?? 0,
                                  shopSectionId:
                                      tableListData[i]?.shopSectionId ?? 0,
                                ),
                                type: (state.tableStatistic?.occupiedIds
                                            .contains(
                                                tableListData[i]?.id ?? 0) ??
                                        false)
                                    ? TrKeys.occupied
                                    : (state.tableStatistic?.bookedIds.contains(
                                                tableListData[i]?.id ?? 0) ??
                                            false)
                                        ? TrKeys.booked
                                        : TrKeys.available,
                              ),
                            ),
                          ))
                  ],
                ),
                if (state.isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: AppStyle.primary),
                  ),
              ],
            ),
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

  Widget _topWidgets(
      TablesState state, TablesNotifier notifier, BuildContext context) {
    List statusList = [
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
