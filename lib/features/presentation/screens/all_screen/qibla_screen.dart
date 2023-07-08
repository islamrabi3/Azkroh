import 'package:flutter/material.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';

import '../../../core/widgets/qibal_compass.dart';

class QibalScreen extends StatefulWidget {
  const QibalScreen({super.key});

  @override
  State<QibalScreen> createState() => _QibalScreenState();
}

class _QibalScreenState extends State<QibalScreen> {
final _deviceSupport = FlutterQiblah.androidDeviceSensorSupport();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('القبلة'),),
        body: FutureBuilder(
          future:_deviceSupport ,
          builder: (context, snapshot) {
            if(snapshot.connectionState == ConnectionState.waiting){
              return const Center(child: CircularProgressIndicator(),);
            }
            if(snapshot.hasError){
              return Center(child: Text(snapshot.error.toString()),);
            }
            if(snapshot.hasData){
              return const QiblaCompass();
            }else{
              return Container();
            }
          },
        ),
      ),
    );
  }
}
