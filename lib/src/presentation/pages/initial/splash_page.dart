import 'package:admin_desktop/src/presentation/theme/app_style.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/constants.dart';
import '../../../core/utils/utils.dart';
import 'riverpod/provider/splash_provider.dart';

@RoutePage()
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(
      Duration.zero,
      () {
        if (!mounted) return;
        ref.read(splashProvider.notifier).fetchGlobalSettings(
          context,
          checkYourNetwork: () {
            AppHelpers.showSnackBar(
              context,
              TrKeys.checkYourNetworkConnection,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppStyle.white,
      body: Center(
        child: CircularProgressIndicator(color: AppStyle.black),
      ),
    );
  }
}
