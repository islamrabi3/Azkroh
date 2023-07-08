import 'package:azkroh_app/features/domain/entity/quran_entity.dart';
import 'package:azkroh_app/features/domain/repo/quran_base_repo.dart';

class GetQuranDataUseCase {
  final QuranBaseRepo quranBaseRepo;

  GetQuranDataUseCase({required this.quranBaseRepo});

  Future<QuranEntity> call() async {
    return await quranBaseRepo.getQuranDataFromApi();
  }
}
