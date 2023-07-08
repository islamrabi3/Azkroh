import 'package:azkroh_app/features/domain/entity/azan_entity.dart';

abstract class AzanBaseRepo {
  Future<AzanEntity> getAzanData(double lati, double longi);
}
