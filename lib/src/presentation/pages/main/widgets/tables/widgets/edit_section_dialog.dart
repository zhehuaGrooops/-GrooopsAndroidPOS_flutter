import 'package:admin_desktop/generated/assets.dart';
import 'package:admin_desktop/src/core/utils/validator_utils.dart';
import 'package:admin_desktop/src/models/data/table_data.dart';
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

class EditSectionDialog extends ConsumerStatefulWidget {
  final ShopSection section;

  const EditSectionDialog({super.key, required this.section});

  @override
  ConsumerState<EditSectionDialog> createState() => _EditSectionDialogState();
}

class _EditSectionDialogState extends ConsumerState<EditSectionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _area;

  @override
  void initState() {
    _name = TextEditingController(
        text: widget.section.translation?.title ?? '');
    _area = TextEditingController(text: widget.section.area ?? '');
    super.initState();
  }

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(tablesProvider.notifier);
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
                  AppHelpers.getTranslation(TrKeys.editSection),
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
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  24.verticalSpace,
                  TableFormField(
                    prefixSvg: Assets.svgDine,
                    validator: ValidatorUtils.validateEmpty,
                    hintText: TrKeys.sectionName,
                    textEditingController: _name,
                  ),
                  12.verticalSpace,
                  TableFormField(
                    prefixSvg: Assets.svgAreaIcon,
                    inputType: TextInputType.number,
                    validator: ValidatorUtils.validateEmpty,
                    hintText: TrKeys.area,
                    textEditingController: _area,
                  ),
                  30.verticalSpace,
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppStyle.red,
                            side: BorderSide(color: AppStyle.red),
                            padding: REdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                          onPressed: () {
                            final id = widget.section.id;
                            if (id == null) return;
                            Navigator.pop(context);
                            notifier.deleteSectionById(
                                id: id, context: context);
                          },
                          child: Text(
                            AppHelpers.getTranslation(TrKeys.delete),
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      12.horizontalSpace,
                      Expanded(
                        child: LoginButton(
                          title: AppHelpers.getTranslation(TrKeys.save),
                          onPressed: () {
                            final id = widget.section.id;
                            if (id == null) return;
                            if (_formKey.currentState?.validate() ?? false) {
                              notifier.updateSectionById(
                                id: id,
                                name: _name.text,
                                area: double.tryParse(_area.text) ?? 0,
                                context: context,
                              );
                              context.maybePop();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
