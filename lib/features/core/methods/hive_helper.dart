import 'package:azkroh_app/features/core/doaa_model.dart';
import 'package:azkroh_app/features/domain/entity/quran_entity.dart';
import 'package:hive/hive.dart';

class HiveHelper {
  static void registerHiveMethod() {
    Hive.registerAdapter(DoaaModelAdapter());
    Hive.registerAdapter(QuranEntityAdapter());
    Hive.registerAdapter(QuranDataEntityAdapter());
    Hive.registerAdapter(SuraEntityAdapter());
    Hive.registerAdapter(AyahEntityAdapter());
  }
}
