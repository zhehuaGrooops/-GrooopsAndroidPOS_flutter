import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/widgets/add_new_section.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/widgets/edit_section_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../../core/utils/app_helpers.dart';
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
          // Zone title + edit/add buttons
          Row(
            children: [
              Text(
                'Zone',
                style: GoogleFonts.inter(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (state.shopSectionList.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    final section =
                        state.shopSectionList[state.selectSection];
                    if (section == null) return;
                    AppHelpers.showAlertDialog(
                        context: context,
                        child: EditSectionDialog(section: section));
                  },
                  child: Container(
                    padding: REdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppStyle.bgGrey,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(FlutterRemix.edit_line, size: 20.r),
                  ),
                ),
              8.horizontalSpace,
              GestureDetector(
                onTap: () => AppHelpers.showAlertDialog(
                    context: context, child: const AddNewSection()),
                child: Container(
                  padding: REdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppStyle.bgGrey,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(FlutterRemix.add_line, size: 20.r),
                ),
              ),
            ],
          ),
          12.verticalSpace,
          // 2-column scrollable section grid
          Expanded(
            child: SingleChildScrollView(
              child: state.isSectionLoading
                  ? GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      children: List.generate(
                        6,
                        (_) => Container(
                          decoration: BoxDecoration(
                            color: AppStyle.shimmerBase,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: state.shopSectionList.length,
                      itemBuilder: (context, index) {
                        final isSelected = state.selectSection == index;
                        final title = state.shopSectionList[index]
                                ?.translation?.title ??
                            '';
                        return GestureDetector(
                          onTap: () => notifier.changeSection(index),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppStyle.primary
                                  : AppStyle.bgGrey,
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Center(
                              child: Padding(
                                padding: REdgeInsets.all(8),
                                child: Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppStyle.white
                                        : AppStyle.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

