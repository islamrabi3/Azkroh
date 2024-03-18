import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:azkroh_app/features/presentation/screens/homescreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:page_transition/page_transition.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedSplashScreen(
      splash: SvgPicture.asset(
        'assets/images/pray-day-islam-svgrepo-com.svg',
        height: 200,
        width: 200,
      ),
      nextScreen: HomePageScreen(),
      pageTransitionType: PageTransitionType.bottomToTop,
    );
  }
}
