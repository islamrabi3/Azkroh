import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/constance/constance.dart';
import 'package:azkroh_app/features/core/methods/methods.dart';

import 'package:azkroh_app/features/presentation/cubit/cubit.dart';
import 'package:azkroh_app/features/presentation/cubit/states.dart';
import 'package:azkroh_app/features/presentation/screens/all_screen/favorites_screen.dart';
import 'package:azkroh_app/features/presentation/screens/azkar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_svg/flutter_svg.dart';

import 'dart:ui' as UI;

import '../../core/methods/get_location.dart';

UI.TextDirection direction = UI.TextDirection.rtl;

List<Map<String, dynamic>> azkarCategoires = [
  {
    'title': 'المصحف',
    'svg_img': 'assets/images/quran-rehal-svgrepo-com.svg',
    'color': Colors.blueGrey
  },
  {
    'title': 'السبحة',
    'svg_img': 'assets/images/necklace-svgrepo-com.svg',
    'color': Colors.blueGrey
  },
  {
    'title': 'مواقيت الصلاة',
    'svg_img': 'assets/images/mosque-svgrepo-com.svg',
    'color': const Color.fromARGB(255, 61, 75, 38)
  },
  {
    'title': 'الاذاعة',
    'svg_img': 'assets/images/radio-svgrepo-com.svg',
  },
  {
    'title': 'القبلة',
    'svg_img': 'assets/images/kaaba-svgrepo-com.svg',
    'color': Colors.lightGreen
  },
  {
    'title': 'التقويم الهجري',
    'svg_img': 'assets/images/date-svgrepo-com.svg',
    'color': Colors.blueGrey
  }
];

class HomePageScreen extends StatefulWidget {
  const HomePageScreen({super.key});

  @override
  State<HomePageScreen> createState() => _HomePageScreenState();
}

class _HomePageScreenState extends State<HomePageScreen> {
  // int randomIndex = Random().nextInt(youTubeLinksList.length);
  // final YoutubePlayerController _controller = YoutubePlayerController(
  //   initialVideoId: youTubeLinksList[Random().nextInt(youTubeLinksList.length)],
  //   flags: const YoutubePlayerFlags(
  //     autoPlay: false,
  //     mute: false,
  //     showLiveFullscreenButton: true,
  //     loop: true,
  //   ),
  // );

  // AdmobBannerSize? _admobBannerSize;
 @override
  void initState() {
    super.initState();
    LocationHelper.getLocationMethod();
  }
  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;
    return BlocConsumer<AppCubit, Appstates>(
      builder: (context, state) {
        AppCubit cubit = context.read<AppCubit>();

        // condition:cubit.azanEntityData != null

        return Directionality(
          textDirection: direction,
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                            image: DecorationImage(
                                image: AssetImage(
                                  'assets/images/evening.jpg',
                                ),
                                opacity: .9,
                                fit: BoxFit.cover)),
                        child: Container(
                          margin: const EdgeInsets.only(top: 400),
                          decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(25),
                                topRight: Radius.circular(25),
                              )),
                          child: Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // headersComponent('دعاء اليوم '),
                                // // we need to put random verse from API instead.
                                // defaultZekrHeaderContainer(
                                //     text: 'رب زدني علما',
                                //     height: height,
                                //     width: width),
                                // const Divider(thickness: 2.0),
                                headersComponent('الأذكار '),
                                customHorizontalListView(
                                    ctx: context,
                                    width: width,
                                    azkarMapList: cubit.azkarMap),
                                const Divider(
                                  thickness: 3.0,
                                ),
                                GridView.count(
                                  crossAxisCount: 2,
                                  shrinkWrap: true,
                                  crossAxisSpacing: 2.0,
                                  mainAxisSpacing: 2.0,
                                  childAspectRatio: 1 / .6,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: List.generate(
                                    6,
                                    (index) => InkWell(
                                      onTap: () {
                                        navigateTo(
                                            context, cubit.screens[index]);
                                      },
                                      child: SizedBox(
                                        height: 200.0,
                                        width: 200.0,
                                        child: Column(
                                          children: [
                                            Text(
                                              '${azkarCategoires[index]['title']}',
                                              style: AppStyle.regularTextStyle,
                                            ),
                                            SizedBox(
                                              height: 50.0,
                                              width: 50.0,
                                              child: SvgPicture.asset(
                                                '${azkarCategoires[index]['svg_img']}',
                                                color: azkarCategoires[index]
                                                    ['color'],
                                                cacheColorFilter: true,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                          top: 250.0,
                          right: 150.0,
                          child: Text(
                            'أذكر الله',
                            style: AppStyle.regularTextStyle
                                .copyWith(fontSize: 35.0, shadows: [
                              const Shadow(
                                  color: Colors.white,
                                  blurRadius: 5,
                                  offset: Offset(1, 1)),
                              const Shadow(
                                  color: Colors.blueGrey,
                                  blurRadius: 5,
                                  offset: Offset(1, 1)),
                            ]),
                          )),
                      Positioned(
                          top: 100,
                          right: 30,
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.black38,
                                radius: 25,
                                child: IconButton(
                                    onPressed: () {
                                      cubit.shareMethod(
                                          'https://play.google.com/store/apps/details?id=com.islamsalemco.azkroh');
                                    },
                                    icon: const Icon(
                                      Icons.ios_share_rounded,
                                      size: 30.0,
                                      color: Colors.white,
                                    )),
                              ),
                              const SizedBox(
                                width: 5.0,
                              ),
                              CircleAvatar(
                                backgroundColor: Colors.black38,
                                radius: 25,
                                child: IconButton(
                                    onPressed: () {
                                      cubit.launchTo();
                                    },
                                    icon: const Icon(
                                      Icons.mail_outline,
                                      size: 30.0,
                                      color: Colors.white,
                                    )),
                              ),
                            ],
                          ))
                    ],
                  ),
                ],
              ),
            ),
            // floatingActionButton: FloatingActionButton(
            //   onPressed: () {
            //     navigateTo(
            //         context,
            //         FavoritesScreen(
            //           fromSharedList: fromSharedList,
            //         ));
            //   },
            //   child: const Icon(Icons.favorite_border, color: Colors.white,),
            // ),
          ),
        );
      },
      listener: (context, state) {},
    );
  }

  Widget customHorizontalListView(
      {BuildContext? ctx,
      double? width,
      List<Map<String, dynamic>>? azkarMapList}) {
    return SizedBox(
      width: double.infinity,
      height: 100.0,
      child: ListView.builder(
        itemBuilder: (ctx, index) {
          return InkWell(
            onTap: () => navigateTo(
                context,
                AzkarScreen(
                  pageTitle: azkarMapList[index]['title'],
                  listOfDoaaModel: azkarMapList[index]['zekr_contetnt'],
                )),
            child: Container(
              margin: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                  image: DecorationImage(
                      opacity: .5,
                      fit: BoxFit.cover,
                      image: AssetImage(
                        azkarMapList[index]['image'],
                      )),
                  borderRadius: const BorderRadius.all(Radius.circular(12.0)),
                  color: Colors.black),
              width: width! * .8,
              child: Center(
                child: Text(
                  azkarMapList[index]['title'],
                  style: textstyleComponent().copyWith(color: Colors.white),
                ),
              ),
            ),
          );
        },
        itemCount: azkarMapList!.length,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        shrinkWrap: true,
      ),
    );
  }

  Widget defaultZekrHeaderContainer(
      {double? height, double? width, required String text, bool? isDoaa}) {
    return Center(
      child: Container(
        height: height! * .08,
        width: width! * .8,
        decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(12.0)),
            color: Colors.white54),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              fontSize: 20.0,
            ),
            // textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Text headersComponent(
    String title,
  ) =>
      Text(
        title,
        style: textstyleComponent(),
      );

  TextStyle textstyleComponent() {
    return const TextStyle(
        fontFamily: 'Amiri',
        color: Colors.black,
        fontWeight: FontWeight.bold,
        fontSize: 25.0);
  }
}
