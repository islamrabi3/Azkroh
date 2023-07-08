

import '../cacheHelper.dart';
import '../doaa_model.dart';

List<DoaaModel> fromSharedList =CacheHelper.sharedPreferences!.getString('list_store')!=null ? DoaaModel.decode(CacheHelper.sharedPreferences!.getString('list_store')!):[];
var newList = fromSharedList.where((element) => element.isFavorite!);