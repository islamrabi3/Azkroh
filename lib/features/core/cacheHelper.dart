

import 'package:shared_preferences/shared_preferences.dart';

class CacheHelper {
  static SharedPreferences? sharedPreferences ;

  static Future<SharedPreferences> init()async{
    sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences!;
  }
}