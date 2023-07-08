import 'package:azkroh_app/features/domain/entity/azan_entity.dart';
import 'package:azkroh_app/features/domain/repo/azan_base_repo.dart';

class GetAzanDetailsUseCase {
  final AzanBaseRepo azanBaseRepo;

  GetAzanDetailsUseCase({required this.azanBaseRepo});

  Future<AzanEntity> call(lati, longi) async {
    return await azanBaseRepo.getAzanData(lati, longi);
  }
}
