import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

class NotificationService {


//싱글톤 패턴 으로 생성한 인스턴스는 전역으로 사용되는 객체이기때문에 데이터를 공유하면서 사용할 수있음
//단점으로는 코드 작성이 복잡해진다 자식객체를 가질수없고 내부구조를 변경할 수 없음 

  // 싱글톤 패턴 구현
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin(); //초기화 


  // 알림 초기화
  Future<void> initialize() async {
    print('알림 초기화 시작');
    
    //안드로이드 설정 
    const androidInitialize = AndroidInitializationSettings('@mipmap/ic_launcher');

    //ios 설정 

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    //초기화 설정 

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) async {
        print('알림 클릭됨: ${details.payload}');
      },
    );
    
    print('알림 초기화 완료');
  }

  // 알림 표시
  Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'geofence_channel',
      'Geofence Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
    );
    
    print('알림 전송 완료: $title - $body');
  }
} 