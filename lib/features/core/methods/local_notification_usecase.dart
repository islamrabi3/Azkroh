// import 'dart:math';

// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// class LocalNotificationHelper {
//  static FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();

//   // initiate Android and Ios specifics

//   // AndroidInitializationSettings initializationSettingsAndroid =
//   //     AndroidInitializationSettings('@mipmap/ic_launcher');
//   // IOSInitializationSettings initializationSettingsIOS = IOSInitializationSettings();
//  static InitializationSettings initializationSettings = InitializationSettings(
//       android: AndroidInitializationSettings('@mipmap/ic_launcher'),
//       iOS: IOSInitializationSettings());

//   // init setting method

//  static initSetting ()async{
//    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
//   }

// static List<String> notificationTexts = [
//    "Hey there! It's time to take a break and stretch your legs.",
//    "Don't forget to drink water today.",
//    "Time to check your emails and get back to work!",
//    "Have you taken a moment to breathe today? Do it now!",
//    "Take a deep breath and enjoy the present moment.",
//    "Good job! Keep up the hard work.",
//    "It's okay to take a break when you need one."
//  ];

// static String generateRandomText() {
//    final random = Random();
//    int index = random.nextInt(notificationTexts.length);
//    return notificationTexts[index];
//  }

//    // show periodic notification
//  static void scheduleNotification() async {
//    // await initSetting();
//    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
//        'repeatDailyAtTime channel id',
//        'Flutter local notification',
//        'Open the notification');
//    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
//    var platformChannelSpecifics = NotificationDetails(
//        android: androidPlatformChannelSpecifics, iOS: iOSPlatformChannelSpecifics);
//    await _flutterLocalNotificationsPlugin.periodicallyShow(
//        0,
//        'Notification Title',
//        generateRandomText(),
//        RepeatInterval.everyMinute,
//        platformChannelSpecifics);
//  }

// }
