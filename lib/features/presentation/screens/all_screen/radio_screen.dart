import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/presentation/cubit/cubit.dart';
import 'package:azkroh_app/features/presentation/cubit/states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:radio_player/radio_player.dart';

class RadioScreen extends StatefulWidget {
  const RadioScreen({Key? key}) : super(key: key);

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  RadioPlayer radioPlayer = RadioPlayer();
  bool isPlaying = false;
  List<String>? metadata;

  Future<void> initRadioPlayer() async {
    await radioPlayer.setChannel(
      title: 'اذاعة القرءان الكريم',
      url:
          'http://n07.radiojar.com/8s5u5tpdtwzuv?rj-ttl=5&rj-tok=AAABhXglQt4AOpim4iZjKalTLg',
      imagePath: 'assets/images/R.jpg',
    );

    radioPlayer.stateStream.listen((value) {
      setState(() {
        isPlaying = value;
      });
    });
  }

  @override
  void initState() {
    initRadioPlayer();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppCubit, Appstates>(
      builder: (context, state) {
        var cubit = context.read<AppCubit>();
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: const Text('إذاعة القرءان الكريم'),
            ),
            body: Center(
                child: FutureBuilder(
              future: radioPlayer.getArtworkImage(),
              builder: (context, snapshot) {
                Image? artWork;
                if (snapshot.hasData) {
                  artWork = snapshot.data;
                } else {
                  artWork = Image.asset(
                    'assets/images/R.jpg',
                    fit: BoxFit.fill,
                  );
                }
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 180,
                      width: 180,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10.0),
                        child: artWork,
                      ),
                    ),
                    const Text(
                      'إذاعة القرءان الكريم ',
                      style: AppStyle.regularTextStyle,
                    )
                  ],
                );
              },
            )),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                isPlaying ? radioPlayer.pause() : radioPlayer.play();
              },
              tooltip: 'Control button',
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
          ),
        );
      },
      listener: (context, state) {},
    );
  }
}
