import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones(); // Saat dilimlerini yükle

    // Android Ayarları
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS Ayarları (İzin isteme dahil)
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // 🔥 HER GÜN SABAH 08:00'DE BİLDİRİM KUR
  Future<void> scheduleDailyNotification() async {
    // Önce Android 13+ için izin isteyelim
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0, // Bildirim ID
      'Günaydın Şampiyon! ☀️', // Başlık
      'Rakiplerin 2 test çözdü bile. Hedefin seni bekliyor, kalk ve masanın başına geç! 🚀', // İçerik
      _nextInstanceOfEightAM(), // Saat hesaplama fonksiyonu
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_motivation_channel', // Kanal ID
          'Günlük Motivasyon', // Kanal Adı
          channelDescription: 'Her sabah motivasyon bildirimi',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          DateTimeComponents.time, // Her gün aynı saatte tekrarla
    );
  }

  // Saati Hesapla (Sabah 08:00)
  tz.TZDateTime _nextInstanceOfEightAM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    // Hedef: Bugün 08:00
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 0);

    // Eğer saat 08:00'i geçtiyse, yarına kur
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // Test İçin: 5 Saniye Sonraya Kur
  Future<void> scheduleTestNotification() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      1,
      'Test Bildirimi 🔔',
      'Bildirim sistemi sorunsuz çalışıyor!',
      tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
      const NotificationDetails(
        android: AndroidNotificationDetails('test_channel', 'Test Kanalı'),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
