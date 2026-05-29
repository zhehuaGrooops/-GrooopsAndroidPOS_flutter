import 'package:admin_desktop/generated/assets.dart';
import 'package:admin_desktop/src/core/utils/validator_utils.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/riverpod/tables_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/widgets/table_form_field.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../../core/constants/constants.dart';
import '../../../../../../core/utils/app_helpers.dart';
import '../../../../../components/components.dart';
import '../../../../../theme/theme.dart';

class AddNewSection extends ConsumerStatefulWidget {
  const AddNewSection({super.key});

  @override
  ConsumerState<AddNewSection> createState() => _AddNewSectionState();
}

class _AddNewSectionState extends ConsumerState<AddNewSection> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late TextEditingController name;

  @override
  void initState() {
    name = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    name.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: REdgeInsets.only(top: 5),
                child: Text(
                  AppHelpers.getTranslation(TrKeys.addNewSection),
                  style: GoogleFonts.inter(
                    color: AppStyle.black,
                    fontWeight: FontWeight.w500,
                    fontSize: 16.sp,
                  ),
                ),
              ),
              InkWell(
                  borderRadius: BorderRadius.circular(10.r),
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: AppStyle.black, size: 24.r)),
            ],
          ),
          Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  24.verticalSpace,
                  TableFormField(
                    prefixSvg: Assets.svgDine,
                    validator: ValidatorUtils.validateEmpty,
                    hintText: TrKeys.sectionName,
                    textEditingController: name,
                  ),
                  12.verticalSpace,
                  30.verticalSpace,
                  LoginButton(
                      title: AppHelpers.getTranslation(TrKeys.create),
                      onPressed: () {
                        final notifier = ref.read(tablesProvider.notifier);
                        if (formKey.currentState?.validate() ?? false) {
                          notifier.addNewSection(
                            name: name.text,
                            area: 0,
                            context: context,
                          );
                          context.maybePop();
                        }
                      }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
