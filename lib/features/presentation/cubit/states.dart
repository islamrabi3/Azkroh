import 'package:azkroh_app/features/domain/entity/azan_entity.dart';

abstract class Appstates {}

class AppInitState extends Appstates {}

class AppLoadingState extends Appstates {}

class AppSuccessState extends Appstates {}

class AppErrorState extends Appstates {}

class AzkarCountState extends Appstates {}

class QuranDataFromApiState extends Appstates {}

class QuranGettingDataError extends Appstates {}

class GetPrayersTimeState extends Appstates {
  final AzanEntity azanEntity;

  GetPrayersTimeState({required this.azanEntity});
}

class GetPrayerTimeErrorState extends Appstates {}

class GetPrayerTimeLoadingState extends Appstates {}

class SetChannelState extends Appstates {}

class RadioStateStream extends Appstates {}

class PrayersState extends Appstates {}

class ToggleFavoriteButtonAddState extends Appstates {
  final bool isFavorite;

  ToggleFavoriteButtonAddState(this.isFavorite);
}

class QuranFavoruiteBtnState extends Appstates {
  final bool isFavorite;

  QuranFavoruiteBtnState(this.isFavorite);
}

class GetAyahEntityFromHiveBox extends Appstates {}

class ShareTextState extends Appstates {}

class UrlLauncherState extends Appstates {}

// class ToggleFavoriteButtonRemoveState extends Appstates {}
