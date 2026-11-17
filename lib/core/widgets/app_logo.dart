import 'package:flutter/material.dart';

import '../../app/theme/app_typography.dart';


class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Expenty',
      style: AppTypography.displayLarge,
    );
  }
}