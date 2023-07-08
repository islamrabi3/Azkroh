import 'dart:io';

import 'package:admob_flutter/admob_flutter.dart';

class AdMobClass {
  static bool isTest = false;

  static String get appId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-6969271444702752~1629915555';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-6969271444702752~2971954138';
    } else {
      throw new UnsupportedError('Unsupported platform');
    }
  }

  static String get bannerAdUnit {
    if (isTest) {
      return AdmobBanner.testAdUnitId;
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-6969271444702752/7270291791';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-6969271444702752/7584882919';
    } else {
      throw new UnsupportedError('Unsupported');
    }
  }

  static String get navtiveAdUnit {
    if (Platform.isAndroid) {
      return 'ca-app-pub-6969271444702752/1254713631';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-6969271444702752/3262494526';
    } else {
      throw new UnsupportedError('Unsupported');
    }
  }

  static String get fullScreenAdUnit {
    if (Platform.isAndroid) {
      return 'ca-app-pub-6969271444702752/1757841160';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-6969271444702752/2140984544';
    } else {
      throw new UnsupportedError('Unsupported');
    }
  }
}
