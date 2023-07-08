import 'dart:async';

import 'package:azkroh_app/features/presentation/screens/homescreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/appstyle.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..forward();
    Timer(
        const Duration(seconds: 4),
        () => Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (context) => HomePageScreen(),
            )));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          color: Colors.blueGrey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _animationController,
                child: SvgPicture.asset(
                    'assets/images/pray-day-islam-svgrepo-com.svg',
                    height: 150),
              ),
              const SizedBox(
                height: 10,
              ),

              // assign action to gestures
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: FadeTransition(
                    opacity: _animationController,
                    child: Text(
                      'أذكروه',
                      style: AppStyle.regularTextStyle.copyWith(
                        fontSize: 50.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
