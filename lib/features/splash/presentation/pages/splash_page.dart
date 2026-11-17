import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/services/firebase_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // The GIF plays for 0.9 s and then holds the finished logo — 2 s lets it
    // settle before handing over to login/dashboard.
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    if (AuthService.isLoggedIn) {
      context.go(RouteNames.dashboard);
    } else {
      context.go(RouteNames.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Background colour and the 300dp-wide logo match the native launch
    // screen exactly, so the OS splash cuts straight into the animation.
    return Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: Center(
        child: Image.asset(
          AppAssets.splashAnimation,
          width: 300,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}