import 'package:admin_desktop/generated/assets.dart';
import 'package:admin_desktop/src/core/utils/validator_utils.dart';
import 'package:admin_desktop/src/models/data/table_data.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/riverpod/tables_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/widgets/table_form_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../../core/constants/constants.dart';
import '../../../../../../core/utils/app_helpers.dart';
import '../../../../../components/components.dart';
import '../../../../../theme/theme.dart';

class EditTableDialog extends ConsumerStatefulWidget {
  final TableData table;
  final int tableIndex;

  const EditTableDialog(
      {super.key, required this.table, required this.tableIndex});

  @override
  ConsumerState<EditTableDialog> createState() => _EditTableDialogState();
}

class _EditTableDialogState extends ConsumerState<EditTableDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _count;

  @override
  void initState() {
    _name = TextEditingController(text: widget.table.name ?? '');
    _count =
        TextEditingController(text: '${widget.table.chairCount ?? 0}');
    super.initState();
  }

  @override
  void dispose() {
    _name.dispose();
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(tablesProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: REdgeInsets.only(top: 5),
              child: Text(
                AppHelpers.getTranslation(TrKeys.editTable),
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
              child: Icon(Icons.close, color: AppStyle.black, size: 24.r),
            ),
          ],
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  24.verticalSpace,
                  TableFormField(
                    prefixSvg: Assets.svgDine,
                    validator: ValidatorUtils.validateEmpty,
                    hintText: TrKeys.tableName,
                    textEditingController: _name,
                  ),
                  12.verticalSpace,
                  TableFormField(
                    prefixSvg: Assets.svgAvatar,
                    inputType: TextInputType.number,
                    validator: ValidatorUtils.validateEmpty,
                    hintText: TrKeys.personCount,
                    textEditingController: _count,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  30.verticalSpace,
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppStyle.red,
                            side: const BorderSide(color: AppStyle.red),
                            padding: REdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            notifier.deleteTable(index: widget.tableIndex);
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
                            final id = widget.table.id;
                            if (id == null) return;
                            if (_formKey.currentState?.validate() ?? false) {
                              notifier.updateTable(
                                id: id,
                                name: _name.text,
                                chairCount:
                                    int.tryParse(_count.text) ?? 0,
                                context: context,
                              );
                              Navigator.pop(context);
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
        ),
      ],
    );
  }
}
