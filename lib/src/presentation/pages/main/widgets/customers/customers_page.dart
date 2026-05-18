import 'package:admin_desktop/src/core/utils/app_helpers.dart';
import 'package:admin_desktop/src/presentation/components/components.dart';
import 'package:admin_desktop/src/presentation/components/custom_scaffold.dart';
import 'package:admin_desktop/src/presentation/components/shimmers/lines_shimmer.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/customers/components/customers_list.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/customers/components/not_found.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/customers/riverpod/provider/customer_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/notifications/components/view_more_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../../../../core/constants/constants.dart';
import 'package:admin_desktop/src/presentation/theme/theme.dart';
import 'components/custom_add_customer_dialog.dart';
import 'view_customer.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  RefreshController refreshController = RefreshController();

  @override
  void initState() {
    ref.read(customerProvider.notifier).fetchAllUsers();
    super.initState();
  }

  @override
  void dispose() {
    refreshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(customerProvider.notifier);
    final state = ref.watch(customerProvider);
    return CustomScaffold(
      body: (c) => Padding(
        padding: REdgeInsets.symmetric(horizontal: 16),
        child: state.isLoading
            ? Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3.r,
                  color: AppStyle.black,
                ),
              )
            : state.selectUser == null
                ? state.users.isNotEmpty
                    ? ListView(
                        padding: REdgeInsets.only(top: 16),
                        shrinkWrap: true,
                        children: [
                          state.query.isNotEmpty
                              ? const SizedBox.shrink()
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      AppHelpers.getTranslation(
                                          TrKeys.customers),
                                      style: GoogleFonts.inter(
                                          fontSize: 22.sp,
                                          color: AppStyle.black,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    IconTextButton(
                                        radius: BorderRadius.circular(10.r),
                                        height: 56.r,
                                        backgroundColor: AppStyle.primary,
                                        iconData: Icons.add,
                                        icon: AppStyle.black,
                                        title: AppHelpers.getTranslation(
                                            TrKeys.addCustomer),
                                        textColor: AppStyle.black,
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) =>
                                                const AddCustomerDialog(),
                                          );
                                        })
                                  ],
                                ),
                          24.verticalSpace,
                          InkWell(
                            onTap: () => notifier.setUser(state.users.first),
                            child: state.query.isNotEmpty
                                ? const SizedBox.shrink()
                                : Container(
                                    height: 164.r,
                                    decoration: BoxDecoration(
                                        color: AppStyle.white,
                                        borderRadius:
                                            BorderRadius.circular(10.r)),
                                    child: Row(
                                      children: [
                                        16.r.horizontalSpace,
                                        CommonImage(
                                          width: 108,
                                          height: 108,
                                          radius: 54,
                                          imageUrl: state.users[0].img ?? '',
                                        ),
                                        20.r.horizontalSpace,
                                        Padding(
                                          padding: REdgeInsets.only(top: 41),
                                          child: Padding(
                                            padding: REdgeInsets.only(left: 20),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      '${state.users.first.firstname ?? ''} ${state.users.first.lastname?.substring(0, 1) ?? ''}.',
                                                      style: GoogleFonts.inter(
                                                          fontSize: 24.sp,
                                                          color: AppStyle.black,
                                                          fontWeight:
                                                              FontWeight.w600),
                                                    ),
                                                    12.r.horizontalSpace,
                                                    Text(
                                                      '#${AppHelpers.getTranslation(TrKeys.id)}${state.users.first.id}',
                                                      style: GoogleFonts.inter(
                                                          fontSize: 16.sp,
                                                          color: AppStyle.icon,
                                                          fontWeight:
                                                              FontWeight.w500),
                                                    ),
                                                  ],
                                                ),
                                                12.verticalSpace,
                                                Text(
                                                  state.users.first.email ?? '',
                                                  style: GoogleFonts.inter(
                                                      fontSize: 14.sp,
                                                      color: AppStyle.icon,
                                                      fontWeight:
                                                          FontWeight.w500),
                                                ),
                                                6.verticalSpace,
                                                Text(
                                                  state.users.first.phone ?? '',
                                                  style: GoogleFonts.inter(
                                                      fontSize: 14.sp,
                                                      color: AppStyle.icon,
                                                      fontWeight:
                                                          FontWeight.w500),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          state.query.isNotEmpty
                              ? 1.verticalSpace
                              : 16.verticalSpace,
                          Container(
                            width: double.infinity,
                            padding: REdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                                color: AppStyle.white,
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(10.r),
                                    topRight: Radius.circular(10.r))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                16.verticalSpace,
                                Text(
                                  state.query.isNotEmpty
                                      ? AppHelpers.getTranslation(
                                          TrKeys.searchResults)
                                      : AppHelpers.getTranslation(
                                          TrKeys.recentCustomers),
                                  style: GoogleFonts.inter(
                                      fontSize: 22.sp,
                                      color: AppStyle.black,
                                      fontWeight: FontWeight.w600),
                                ),
                                8.verticalSpace,
                                Column(
                                  children: [
                                    AnimationLimiter(
                                      child: ListView.builder(
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        shrinkWrap: true,
                                        itemCount: state.query.isNotEmpty
                                            ? state.users.length
                                            : state.users.length - 1,
                                        itemBuilder:
                                            (BuildContext context, int index) =>
                                                InkWell(
                                          onTap: () {
                                            notifier.setUser(
                                                state.query.isNotEmpty
                                                    ? state.users[index]
                                                    : state.users[index + 1]);
                                          },
                                          child: AnimationConfiguration
                                              .staggeredList(
                                            position: index,
                                            duration: const Duration(
                                                milliseconds: 375),
                                            child: FadeInAnimation(
                                              child: SlideAnimation(
                                                child: CustomersList(
                                                  user: state.query.isNotEmpty
                                                      ? state.users[index]
                                                      : state.users[index + 1],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    28.verticalSpace,
                                    state.isMoreLoading
                                        ? const LineShimmer(isActiveLine: false)
                                        : state.hasMore &&
                                                state.users.isNotEmpty
                                            ? ViewMoreButton(
                                                onTap: () {
                                                  notifier.fetchAllUsers();
                                                },
                                              )
                                            : const SizedBox(),
                                    28.verticalSpace,
                                  ],
                                )
                              ],
                            ),
                          )
                        ],
                      )
                    : const Center(child: NotFound())
                : ViewCustomer(
                    user: state.selectUser,
                    back: () {
                      notifier.setUser(null);
                    },
                  ),
      ),
    );
  }
}
