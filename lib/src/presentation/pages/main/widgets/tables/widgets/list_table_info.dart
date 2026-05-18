import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/riverpod/tables_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../../core/constants/constants.dart';
import '../../../../../../core/utils/utils.dart';
import '../../../../../../models/data/table_bookings_data.dart';
import '../../../../../components/components.dart';
import '../../../../../theme/theme.dart';

class ListTableInfo extends ConsumerWidget {
  const ListTableInfo({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final state = ref.watch(tablesProvider);
    final notifier = ref.read(tablesProvider.notifier);
    TableBookingData? bookingData;
    if (state.tableBookingData.isNotEmpty) {
      bookingData = state.tableBookingData[state.selectOrderIndex!];
    }

    return Container(
      height: double.infinity,
      margin: EdgeInsets.only(right: 16.r, top: 16.r, bottom: 16.r),
      decoration: BoxDecoration(
          color: AppStyle.white, borderRadius: BorderRadius.circular(10)),
      child: state.isInfoLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppStyle.primary,
              ),
            )
          : bookingData != null || state.selectOrderIndex != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 16.r, left: 16.r),
                      child: Row(
                        children: [
                          CommonImage(
                            imageUrl: bookingData?.user?.img ?? "",
                            width: 40.r,
                            height: 40.r,
                            radius: 20.r,
                          ),
                          10.horizontalSpace,
                          Text(
                            "${bookingData?.user?.firstname ?? ""} ${bookingData?.user?.lastname ?? ""}",
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600, fontSize: 16.sp),
                          )
                        ],
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: EdgeInsets.only(left: 16.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          6.verticalSpace,
                          Text(
                            AppHelpers.getTranslation(TrKeys.order),
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600, fontSize: 18.sp),
                          ),
                          10.verticalSpace,
                          Row(
                            children: [
                              Text(
                                "#${AppHelpers.getTranslation(TrKeys.id)}${bookingData?.id}",
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16.sp,
                                    color: AppStyle.icon),
                              ),
                              12.horizontalSpace,
                              Container(
                                width: 8.r,
                                height: 8.r,
                                decoration: const BoxDecoration(
                                    color: AppStyle.icon,
                                    shape: BoxShape.circle),
                              ),
                              12.horizontalSpace,
                              Text(
                                DateFormat("MMM d, h:mm a").format(
                                    bookingData?.startDate?.toLocal() ??
                                        DateTime.now()),
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16.sp,
                                    color: AppStyle.icon),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: EdgeInsets.only(left: 16.r, right: 16.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: REdgeInsets.symmetric(
                                    horizontal: 10, vertical: 12),
                                decoration: BoxDecoration(
                                    color: bookingData?.status == TrKeys.newKey
                                        ? AppStyle.blue
                                        : bookingData?.status == TrKeys.accepted
                                            ? AppStyle.deepPurple
                                            : AppStyle.red,
                                    borderRadius: BorderRadius.circular(5.r)),
                                child: Text(bookingData?.table?.name ?? "",
                                    style: GoogleFonts.inter(
                                      fontSize: 12.sp,
                                      color: AppStyle.white,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ),
                              8.horizontalSpace,
                              Expanded(
                                child: Text(bookingData?.user?.firstname ?? "",
                                    style: GoogleFonts.inter(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    )),
                              ),
                              Text(
                                  "${bookingData?.table?.chairCount} ${AppHelpers.getTranslation(TrKeys.person)}",
                                  style: GoogleFonts.inter(
                                    fontSize: 12.sp,
                                    color: AppStyle.hint,
                                    fontWeight: FontWeight.w500,
                                  )),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    const Spacer(),
                    24.verticalSpace,
                    Column(
                      children: [
                        if ((bookingData?.status != TrKeys.newKey))
                          Padding(
                            padding: REdgeInsets.symmetric(
                                horizontal: 22, vertical: 6),
                            child: LoginButton(
                                title: AppHelpers.getTranslation(TrKeys.newKey),
                                onPressed: () {
                                  notifier.changeStatus(TrKeys.newKey);
                                }),
                          ),
                        if ((bookingData?.status != TrKeys.accepted))
                          Padding(
                            padding: REdgeInsets.symmetric(
                                horizontal: 22, vertical: 6),
                            child: LoginButton(
                                title:
                                    AppHelpers.getTranslation(TrKeys.accepted),
                                onPressed: () {
                                  notifier.changeStatus(TrKeys.accepted);
                                }),
                          ),
                        if ((bookingData?.status != TrKeys.canceled))
                          Padding(
                            padding: REdgeInsets.symmetric(
                                horizontal: 22, vertical: 6),
                            child: LoginButton(
                              title: AppHelpers.getTranslation(TrKeys.canceled),
                              onPressed: () {
                                notifier.changeStatus(TrKeys.canceled);
                              },
                              bgColor: AppStyle.red,
                              titleColor: AppStyle.white,
                            ),
                          ),
                      ],
                    ),
                    24.verticalSpace,
                  ],
                )
              : Center(
                  child:
                      Text(AppHelpers.getTranslation(TrKeys.thereAreNoOrders))),
    );
  }
}
