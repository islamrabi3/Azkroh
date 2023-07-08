import 'package:azkroh_app/features/domain/entity/quran_entity.dart';

abstract class QuranBaseRepo {
  Future<QuranEntity> getQuranDataFromApi();
}
