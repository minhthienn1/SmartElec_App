import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import '../main.dart';
import 'api_service.dart';
import '../models/chat_message.dart' as chat_msg;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Xử lý thông báo khi app ở background/terminated
  debugPrint("📩 Nhận thông báo Background: ${message.messageId}");
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response.payload);
      },
    );

    // Tạo Notification Channel đặc biệt cho Đơn hàng mới (Android)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'job_alerts', // id
      'Cảnh báo đơn hàng', // name
      description: 'Kênh thông báo cho các đơn sửa chữa mới',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('emergency_alarm'),
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _initFCM();
  }

  static Future<void> _initFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    String? token = await messaging.getToken();
    debugPrint('🔑 FCM Token: $token');
    if (token != null) {
      ApiService.updateFcmToken(token);
    }

    // 1. Khi App đang mở (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 Foreground Message: ${message.data}');
      
      if (message.notification != null) {
        String type = message.data['type'] ?? 'default';
        
        if (type == 'NEW_JOB') {
          showJobAlertNotification(
            message.notification!.title ?? "Có đơn mới!",
            message.notification!.body ?? "Bạn có một yêu cầu sửa chữa gần đây.",
            message.data['jobId']?.toString() ?? '',
          );
        } else {
          showNewMessageNotification(
            message.notification!.title ?? "Thông báo",
            message.notification!.body ?? "",
            payload: _convertDataToString(message.data),
          );
        }
      }
    });

    // 2. Khi người dùng bấm vào thông báo từ Background (App vẫn đang sống)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🖱️ Notification Opened App: ${message.data}');
      _handleDeepLink(message.data);
    });

    // 3. Khi App bị Terminated (App đã chết) và được mở lên từ thông báo
    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('💀 App opened from Terminated state: ${initialMessage.data}');
      // Lưu lại data để các màn hình chính tự check sau khi Login xong
      pendingData = initialMessage.data;
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  static Map<String, dynamic>? pendingData;

  static void _handleNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    // Parse payload "key:value,key:value" thành Map
    Map<String, dynamic> data = {};
    try {
      final parts = payload.split(',');
      for (var part in parts) {
        final kv = part.split(':');
        if (kv.length == 2) {
          data[kv[0].trim()] = kv[1].trim();
        }
      }
      _handleDeepLink(data);
    } catch (e) {
      debugPrint('❌ Error parsing notification payload: $e');
    }
  }

  static void _handleDeepLink(Map<String, dynamic> data) {
    String? type = data['type'];
    if (type == 'NEW_JOB' && data['jobId'] != null) {
      navigatorKey.currentState?.pushNamed('/job_detail', arguments: data['jobId'].toString());
    } else if (type == 'JOB_ACCEPTED' && data['sessionId'] != null) {
      navigatorKey.currentState?.pushNamed('/chat_detail', arguments: {
        'sessionId': int.parse(data['sessionId'].toString()),
        'receiver': chat_msg.User(
          id: int.tryParse(data['receiverId']?.toString() ?? '') ?? 0,
          fullName: data['receiverName']?.toString() ?? 'Khách hàng',
          role: 'USER',
          avatarUrl: data['receiverAvatar']?.toString(),
        ),
      });
    }
  }

  // Hàm để các màn hình chính gọi sau khi đã khởi động xong
  static void checkPendingNotification() {
    if (pendingData != null) {
      _handleDeepLink(pendingData!);
      pendingData = null; // Xử lý xong thì xóa đi
    }
  }

  static String _convertDataToString(Map<String, dynamic> data) {
    // Helper to store data in payload string
    return data.entries.map((e) => "${e.key}:${e.value}").join(",");
  }

  // Thông báo đặc biệt cho đơn hàng (có chuông to)
  static Future<void> showJobAlertNotification(String title, String body, String jobId) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'job_alerts',
      'Cảnh báo đơn hàng',
      channelDescription: 'Kênh thông báo cho các đơn sửa chữa mới',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('emergency_alarm'),
      playSound: true,
    );

    await _notificationsPlugin.show(
      id: 999, // ID cố định hoặc random cho job alert
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: 'type:NEW_JOB,jobId:$jobId',
    );
  }

  static Future<void> showNewMessageNotification(String title, String body, {String? payload}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'chat_messages_v2',
      'Tin nhắn mới',
      channelDescription: 'Thông báo khi có tin nhắn mới',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _notificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  static Future<void> scheduleDeviceMaintenance(dynamic device) async {
    // Giữ nguyên code cũ
  }
}
