
import 'dart:async';

import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';

import 'location_error_widget.dart';

class QiblaCompass extends StatefulWidget {
  const QiblaCompass({Key? key}) : super(key: key);

  @override
  State<QiblaCompass> createState() => _QiblaCompassState();
}

class _QiblaCompassState extends State<QiblaCompass> {

  final locationStreamController = StreamController<LocationStatus>.broadcast();

  get stream => locationStreamController.stream;
  Future<void> checkLocationStatus () async{
    final locationStatus =  await FlutterQiblah.checkLocationStatus();
    if(locationStatus.enabled && locationStatus.status == LocationPermission.denied){
      await FlutterQiblah.requestPermissions();
      final s = await FlutterQiblah.checkLocationStatus();
      locationStreamController.add(s);
    }else {
      locationStreamController.add(locationStatus);
    }
  }

  @override
  void initState() {
    checkLocationStatus();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    locationStreamController.close();
    FlutterQiblah().dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8.0),
      child: StreamBuilder(
        stream: stream,
        builder: (context, AsyncSnapshot<LocationStatus> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (snapshot.data!.enabled == true) {
            switch (snapshot.data!.status) {
              case LocationPermission.always:
              case LocationPermission.whileInUse:
                return QiblahCompassWidget();

              case LocationPermission.denied:
                return LocationErrorWidget(
                  error: "Location service permission denied",
                  callback: checkLocationStatus,
                );
              case LocationPermission.deniedForever:
                return LocationErrorWidget(
                  error: "Location service Denied Forever !",
                  callback: checkLocationStatus,
                );
              default:
                return Container();
            }
          } else {
            return LocationErrorWidget(
              error: "Please enable Location service",
              callback: checkLocationStatus,
            );
          }
        },
      ),
    );
  }

}

class QiblahCompassWidget extends StatelessWidget {
  final _compassSvg = SvgPicture.asset('assets/images/compass.svg');
  final _needleSvg = SvgPicture.asset(
    'assets/images/needle.svg',
    fit: BoxFit.contain,
    height: 300,
    alignment: Alignment.center,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FlutterQiblah.qiblahStream,
      builder: (_, AsyncSnapshot<QiblahDirection> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
        {
          return const Center(child: CircularProgressIndicator(),);
        }

        final qiblahDirection = snapshot.data!;

        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Transform.rotate(
              angle: (qiblahDirection.direction * (pi / 180) * -1),
              child: _compassSvg,
            ),
            Transform.rotate(
              angle: (qiblahDirection.qiblah * (pi / 180) * -1),
              alignment: Alignment.center,
              child: _needleSvg,
            ),
            Positioned(
              bottom: 8,
              child: Text("${qiblahDirection.offset.toStringAsFixed(3)}°"),
            )
          ],
        );
      },
    );
  }
}
