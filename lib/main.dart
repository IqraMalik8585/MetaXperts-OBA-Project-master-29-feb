import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:background_locator_2/background_locator.dart';
import 'package:background_locator_2/callback_dispatcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity/connectivity.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' as gp;
import 'package:get/get.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:order_booking_shop/Tracker/trac.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'API/DatabaseOutputs.dart';
import 'API/Globals.dart';
import 'Databases/DBHelper.dart';
import 'Views/splash_screen.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:location00/location00.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // AndroidAlarmManager.initialize();
  //
  // // Initialize the FlutterBackground plugin
  // await FlutterBackground.initialize();
  //
  // // Enable background execution
  // await FlutterBackground.enableBackgroundExecution();

  // Initialize the service
  // await initializeServiceBackGroundData();
  await initializeServiceLocation();

  // Ensure Firebase is initialized before running the app
  await Firebase.initializeApp();

  await BackgroundLocator.initialize();

  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    ),
  );
}



void callbackDispatcher(){
  Workmanager().executeTask((task, inputData) async {
    print("WorkManager MMM ");
    return Future.value(true);
  });
}

Future<void> initializeServiceLocation() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground',
    'MY FOREGROUND SERVICE',
    description: 'This channel is used for important notifications.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  if (Platform.isIOS || Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        iOS: DarwinInitializationSettings(),
        android: AndroidInitializationSettings('ic_bg_service_small'),
      ),
    );
  }

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'AWESOME SERVICE',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
  );
}

// Future<void> initializeServiceBackGroundData() async {
//   final service1 = FlutterBackgroundService();
//
//   await service1.configure(
//     androidConfiguration: AndroidConfiguration(
//       onStart: onStart1,
//       autoStart: true,
//       isForegroundMode: false, // Change this to false
//     ),
//     iosConfiguration: IosConfiguration(
//       autoStart: true,
//       onForeground: onStart1,
//     ),
//   );
// }

@pragma('vm:entry-point')
void onStart1(ServiceInstance service1) async {
  DartPluginRegistrant.ensureInitialized();

  Timer.periodic(const Duration(minutes: 10), (timer) async {
    if (service1 is AndroidServiceInstance) {
      if (await service1.isForegroundService()) {
        backgroundTask();
      }
    }
    final deviceInfo = DeviceInfoPlugin();
    String? device1;

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      device1 = androidInfo.model;
    }

    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      device1 = iosInfo.model;
    }

    service1.invoke(
      'update',
      {
        "current_date": DateTime.now().toIso8601String(),
        "device": device1,
      },
    );
  }
  );
}


@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setString("hello", "world");

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  LocationService locationService = LocationService();
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
      backgroundTask();
      //ls.listenLocation();
    });
  }

  service.on('stopService').listen((event) async {
    locationService.stopListening();
    locationService.deleteDocument();
    Workmanager().cancelAll();
    await postFile();
    service.stopSelf();
    //stopListeningLocation();
    FlutterLocalNotificationsPlugin().cancelAll();
  });

  Timer.periodic(const Duration(minutes: 10), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        backgroundTask();
      }
    }
    final deviceInfo = DeviceInfoPlugin();
    String? device1;

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      device1 = androidInfo.model;
    }

    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      device1 = iosInfo.model;
    }

    service.invoke(
      'update',
      {
        "current_date": DateTime.now().toIso8601String(),
        "device": device1,
      },
    );
  }
  );

  Workmanager().registerPeriodicTask("1", "simpleTask", frequency: Duration(minutes: 15));

  if(isClockedIn == false){
    startTimer();
    locationService.listenLocation();
  }

  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {

        flutterLocalNotificationsPlugin.show(
          888,
          'COOL SERVICE',
          'Awesome',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'my_foreground',
              'MY FOREGROUND SERVICE',
              icon: 'ic_bg_service_small',
              ongoing: true,
              priority: Priority.high,
            ),
          ),
        );

        flutterLocalNotificationsPlugin.show(
          889,
          'Location',
          'Longitude ${locationService.longi} , Latitute ${locationService.lat}',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'my_foreground',
              'MY FOREGROUND SERVICE',
              icon: 'ic_bg_service_small',
              ongoing: true,
            ),
          ),
        );

        service.setForegroundNotificationInfo(
          title: "ClockIn",
          content: "Timer ${_formatDuration(secondsPassed.toString())}",
        );
      }
    }



    final deviceInfo = DeviceInfoPlugin();
    String? device;

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      device = androidInfo.model;
    }

    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      device = iosInfo.model;
    }

    service.invoke(
      'update',
      {
        "current_date": DateTime.now().toIso8601String(),
        "device": device,
      },
    );
  });
}


String _formatDuration(String secondsString) {
  int seconds = int.parse(secondsString);
  Duration duration = Duration(seconds: seconds);
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  String hours = twoDigits(duration.inHours);
  String minutes = twoDigits(duration.inMinutes.remainder(60));
  String secondsFormatted = twoDigits(duration.inSeconds.remainder(60));
  return '$hours:$minutes:$secondsFormatted';
}


backgroundTask() async {

  try {
    bool isConnected = await InternetConnectionChecker().hasConnection;
    DatabaseOutputs outputs = DatabaseOutputs();
    if (isConnected) {
      print('Internet connection is available. Initiating background data synchronization.');
      await synchronizeData();
      await outputs.checkFirstRun();

  print('Background data synchronization completed.');
    } else {
      print('No internet connection available. Skipping background data synchronization.');
    }
  } catch (e) {
    print('Error in backgroundTask: $e');
  }
}
Future<void> synchronizeData() async {
  print('Synchronizing data in the background.');
  await postAttendanceTable();
  await postAttendanceOutTable();
  await postShopTable();
  await postShopVisitData();
  await postStockCheckItems();
  await postMasterTable();
  await postOrderDetails();
  await postReturnFormTable();
  await postReturnFormDetails();
  await postRecoveryFormTable();
}

Future<void> postShopVisitData() async {
  DBHelper dbHelper = DBHelper();
  await dbHelper.postShopVisitData();
}

Future<void> postStockCheckItems() async {
  DBHelper dbHelper = DBHelper();
  await dbHelper.postStockCheckItems();
}

Future<void> postAttendanceOutTable() async {
  DBHelper dbHelper = DBHelper();
  await dbHelper.postAttendanceOutTable();
}

Future<void> postAttendanceTable() async {
  DBHelper dbHelper = DBHelper();
  await dbHelper.postAttendanceTable();
}

Future<void> postMasterTable() async {
  DBHelper dbHelper = DBHelper();
  await dbHelper.postMasterTable();
}

Future<void> postOrderDetails() async {
  DBHelper dbHelper = DBHelper();
  await dbHelper.postOrderDetails();
}

Future<void> postShopTable() async {
  DBHelper dbHelper = DBHelper();
  await dbHelper.postShopTable();
}

Future<void> postReturnFormTable() async {
  print('Attempting to post Return data');
  DBHelper dbHelper = DBHelper();
  await dbHelper.postReturnFormTable();
  print('Return data posted successfully');
}

Future<void> postReturnFormDetails() async {
  DBHelper dbHelper = DBHelper();
  await dbHelper.postReturnFormDetails();
}

Future<void> postRecoveryFormTable() async {
  DBHelper dbHelper = DBHelper();
  await dbHelper.postRecoveryFormTable();
}






