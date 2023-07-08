

import 'package:flutter/material.dart';
import 'dart:async';

import 'homescreen.dart';

class AnimatedSplashScreen extends StatefulWidget {
  @override
  _AnimatedSplashScreenState createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  startTime() async {
    var duration = const Duration(seconds: 2);
    return  Timer(duration, navigationPage);
  }

  void navigationPage() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) =>const HomePageScreen(),));
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration:const Duration(seconds: 2));
    _animation = Tween(begin: 0.0, end: 1.0).animate(_controller);

    _controller.forward();

    startTime();
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Center(
          child: FadeTransition(
            opacity: _animation,
            child:const FlutterLogo(
              size: 200.0,
            ),
          ),
        ),
      ),
    );
  }
}
