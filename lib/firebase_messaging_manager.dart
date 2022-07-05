import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart' as fb_core;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_messaging_manager/model/notification_callback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'model/notification.dart' as notification_model;

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class FirebaseMessagingManager {
  FirebaseMessagingManager._privateConstructor();

  static final FirebaseMessagingManager _instance = FirebaseMessagingManager._privateConstructor();

  static FirebaseMessagingManager get instance => _instance;
  String channelName = "";
  String channelId = "";
  String channelDesc = "";
  bool isAppOpen = false;

  NotificationCallback? notificationCallback;

  Future<void> init(
      {NotificationCallback? notificationCallback, String? channelId, String? channelName, String? channelDesc}) async {
    try {
      await fb_core.Firebase.initializeApp();
      isAppOpen = true;
      this.channelId = channelId ?? "";
      this.channelName = channelName ?? "";
      this.channelDesc = channelDesc ?? "";
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      this.notificationCallback = notificationCallback;
      NotificationSettings settings =
          await FirebaseMessaging.instance.requestPermission(announcement: true, carPlay: true, criticalAlert: true);
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('User granted provisional permission');
      } else {
        debugPrint('User declined or has not accepted permission');
      }
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      getToken();
      //initNotifications();
      FirebaseMessaging.onMessage.listen((message) {
        notificationMessageHandler(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage? message) async {
        if (message != null) {
          _onLaunchNotification(message);
        }
      });

      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) async {
        if (message != null) {
          _onLaunchNotification(message);
        }
      });
    } catch (error) {
      debugPrint("Firebase Initialisation Error : $error");
    }
  }

  Future<String?> getToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      debugPrint("Token: $token");
      return token;
    } catch (error) {
      debugPrint(error.toString());
      return "N/A";
    }
  }

  _onLaunchNotification(RemoteMessage? message) async {
    debugPrint("Message: ${jsonEncode(message?.data)}");
    openNotificationDetailScreen(message?.data ?? {}, notificationCallback);
  }

  notificationMessageHandler(RemoteMessage message) async {
    debugPrint(
        "Message: ${jsonEncode(message.data)} or ${message.notification?.title} and ${message.notification?.body}");
    notification_model.Notification? notification =
        notification_model.Notification.fromJson((message.notification?.toMap()) ?? {});
    showNotificationWithDefaultSound(notification.id, notification.title, notification.body, notification);
  }

  Future showNotificationWithDefaultSound(
      String? id, String? title, String? body, notification_model.Notification? notification) async {
    debugPrint("Title : $title Body : $body");
    AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId, // id
      channelName, // title
      description: channelDesc, // description
      importance: Importance.high,
    );
    if (Platform.isAndroid || !isAppOpen) {
      var iOSPlatformChannelSpecifics = const IOSNotificationDetails();
      flutterLocalNotificationsPlugin
          .show(
              int.parse(id ?? "0"),
              title,
              body,
              NotificationDetails(
                  iOS: iOSPlatformChannelSpecifics,
                  android: AndroidNotificationDetails(channel.id, channel.name,
                      subText: body, channelDescription: channel.description, icon: 'app_icon')),
              payload: jsonEncode(notification))
          .catchError((error) {
        print("Error: $error");
      });
    }
  }

  sendPushNotification(
      {required String? deviceToken,
      required String message,
      required String title,
      required String serverKey,
      Map<String, dynamic>? data}) async {
    if (deviceToken != null) {
      var url = Uri.parse('https://fcm.googleapis.com/fcm/send');
      Map<String, dynamic> body = {};
      Map<String, dynamic> notification = {};
      notification['title'] = title;
      notification['body'] = message;
      notification['mutable_content'] = false;
      notification['click_action'] = 'FLUTTER_NOTIFICATION_CLICK';
      body['notification'] = notification;
      body['data'] = data ?? {};
      body['to'] = deviceToken;
      Map<String, String> headers = {};
      headers['Authorization'] = 'key=$serverKey';
      headers['Content-Type'] = 'application/json';
      var response = await http.post(url, body: jsonEncode(body), headers: headers);
      debugPrint('sendPushNotification Response status: ${response.statusCode}');
      debugPrint('sendPushNotification Response body: ${response.body}');
    }
  }
}

void openNotificationDetailScreen(Map<String, dynamic> data, NotificationCallback? notificationCallback) {
  if (notificationCallback?.onNotificationClick != null) {
    notificationCallback?.onNotificationClick!(data: data);
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await fb_core.Firebase.initializeApp();
  debugPrint("Remote Message in Background");
  FirebaseMessagingManager.instance.sendPushNotification(
      deviceToken:
          "cLAd2lcQR0Wap6bPV0E9kl:APA91bHi6cVfHh8pCOLQjSp1N9k_DlW45Qd08-_EN8TlWyUAEgjncDHQYCDmGfQegN5j6azPum6WQAqoTMVt8kGigpR75vJZWosZ57IaFk1IKiVkHOoz_I5GRaarl6mEUBTFvDbJdfX7¬",
      message: "Good Bye",
      title: "Tata",
      serverKey:
          "AAAAukFHqdk:APA91bGPLAD7wUTZNPMcbyqe187m1vktOd0roIDwWR6_3Dn-YY7owzmddjF2glPXC4dj9GLlt4QSxsrZ3jrlsYJuaJVyBO3aZ4vtt0OjZnmx97KemAAmwINt3h-pNl5oof1DablHTjZz");
}
