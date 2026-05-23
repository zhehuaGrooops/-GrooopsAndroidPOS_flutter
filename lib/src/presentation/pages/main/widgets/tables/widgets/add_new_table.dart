import 'package:admin_desktop/generated/assets.dart';
import 'package:admin_desktop/src/models/data/table_model.dart';
import 'package:admin_desktop/src/presentation/components/components.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/widgets/table_form_field.dart';
import 'package:admin_desktop/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../../core/constants/constants.dart';
import '../../../../../../core/utils/utils.dart';
import '../../../../../../core/utils/validator_utils.dart';
import '../riverpod/tables_provider.dart';

class AddNewTable extends ConsumerStatefulWidget {
  const AddNewTable({super.key});

  @override
  ConsumerState<AddNewTable> createState() => _AddNewTableState();
}

class _AddNewTableState extends ConsumerState<AddNewTable> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late TextEditingController name;
  late TextEditingController count;

  @override
  void initState() {
    name = TextEditingController();
    count = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(tablesProvider.notifier)
          .setSection(index: ref.watch(tablesProvider).selectSection);
    });
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    name.dispose();
    count.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(tablesProvider.notifier);
    final state = ref.watch(tablesProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: REdgeInsets.only(top: 5),
              child: Text(
                AppHelpers.getTranslation(TrKeys.addNewTable),
                style: GoogleFonts.inter(
                  color: AppStyle.black,
                  fontWeight: FontWeight.w500,
                  fontSize: 16.sp,
                ),
              ),
            ),
            GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close, color: AppStyle.black, size: 24.r)),
          ],
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  24.verticalSpace,
                  TableFormField(
                    prefixSvg: Assets.svgDine,
                    validator: ValidatorUtils.validateEmpty,
                    hintText: TrKeys.tableName,
                    textEditingController: name,
                  ),
                  12.verticalSpace,
                  TableFormField(
                    prefixSvg: Assets.svgAvatar,
                    inputType: TextInputType.number,
                    validator: ValidatorUtils.validateEmpty,
                    hintText: TrKeys.personCount,
                    textEditingController: count,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  30.verticalSpace,
                  LoginButton(
                      title: AppHelpers.getTranslation(TrKeys.create),
                      onPressed: () {
                        if (formKey.currentState?.validate() ?? false) {
                          notifier.addTable(
                            tableModel: TableModel(
                              name: name.text,
                              chairCount: int.tryParse(count.text) ?? 4,
                              tax: 0,
                              shopSectionId: state.selectAddSection,
                            ),
                            context: context,
                          );
                          Navigator.pop(context);
                        }
                      }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
