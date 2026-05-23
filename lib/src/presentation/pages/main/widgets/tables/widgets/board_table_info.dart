import 'package:admin_desktop/src/models/data/table_statistics_data.dart';
import 'package:admin_desktop/src/presentation/components/buttons/floor_button.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/widgets/add_new_section.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/widgets/edit_section_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../../core/constants/constants.dart';
import '../../../../../../core/utils/app_helpers.dart';
import '../../../../../components/components.dart';
import '../../../../../theme/theme.dart';
import '../riverpod/tables_provider.dart';

class BoardTableInfo extends ConsumerWidget {
  const BoardTableInfo({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final notifier = ref.read(tablesProvider.notifier);
    final state = ref.watch(tablesProvider);
    return Container(
      padding: REdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppStyle.white, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 48.r,
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                      itemCount: state.isSectionLoading
                          ? 6
                          : state.shopSectionList.length,
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: REdgeInsets.only(right: 12),
                          child: state.isSectionLoading
                              ? Container(
                                  height: 48.r,
                                  width: 66.r,
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15.r),
                                      color: AppStyle.shimmerBase),
                                )
                              : SectionButton(
                                  height: 48.r,
                                  paddingSize: 21,
                                  bgColor: AppStyle.border,
                                  isTab: true,
                                  isActive: state.selectSection == index,
                                  title: state.shopSectionList[index]
                                          ?.translation?.title ??
                                      "",
                                  onTap: () => notifier.changeSection(index)),
                        );
                      }),
                ),
                if (state.shopSectionList.isNotEmpty) ...[
                  8.horizontalSpace,
                  ConfirmButton(
                    icon: Icon(FlutterRemix.edit_line, size: 24.r),
                    paddingSize: 16,
                    title: "",
                    onTap: () {
                      final section =
                          state.shopSectionList[state.selectSection];
                      if (section == null) return;
                      AppHelpers.showAlertDialog(
                          context: context,
                          child: EditSectionDialog(section: section));
                    },
                  ),
                ],
                8.horizontalSpace,
                ConfirmButton(
                    icon: Icon(FlutterRemix.add_line, size: 24.r),
                    paddingSize: 16,
                    title: "",
                    onTap: () => AppHelpers.showAlertDialog(
                        context: context, child: const AddNewSection())),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                TableInfoStatus(
                  status: TrKeys.occupied,
                  dataList: state.tableStatistic?.allOccupied ?? [],
                ),
                if ((state.tableStatistic?.allOccupied.isNotEmpty ?? false) &&
                    (state.tableStatistic?.allBooked.isNotEmpty ?? false))
                  const Divider(),
                TableInfoStatus(
                  status: TrKeys.booked,
                  dataList: state.tableStatistic?.allBooked ?? [],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 7.r, horizontal: 7.r),
            child: LoginButton(
                title: AppHelpers.getTranslation(TrKeys.checkIn),
                onPressed: () {}),
          )
        ],
      ),
    );
  }
}

class TableInfoStatus extends StatelessWidget {
  final String status;
  final List<AllStatisticStatusData> dataList;

  const TableInfoStatus(
      {super.key, required this.status, required this.dataList});

  @override
  Widget build(BuildContext context) {
    if (dataList.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          24.verticalSpace,
          Text(
            AppHelpers.getTranslation(status),
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          8.verticalSpace,
          ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: (dataList.length),
              itemBuilder: (context, index) {
                return Padding(
                  padding: REdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding:
                            REdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                            color: status == TrKeys.occupied
                                ? AppStyle.red
                                : AppStyle.starColor,
                            borderRadius: BorderRadius.circular(5.r)),
                        child: Text(dataList[index].tableName ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: AppStyle.white,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                      8.horizontalSpace,
                      Expanded(
                        child: Text(dataList[index].username ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            )),
                      ),
                      Text(
                          DateFormat("hh:mm a, dd MMMM,yyyy").format(
                              dataList[index].tableStartDate?.toLocal() ??
                                  DateTime.now()),
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: AppStyle.hint,
                            fontWeight: FontWeight.w500,
                          )),
                    ],
                  ),
                );
              }),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}
