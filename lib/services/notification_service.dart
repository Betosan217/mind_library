import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static final _notificationTapStream = NotificationTapStream();

  static NotificationTapStream get notificationTapStream =>
      _notificationTapStream;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('America/Guatemala'));
      } catch (e) {
        final String timeZoneName = DateTime.now().timeZoneName;
        try {
          tz.setLocalLocation(tz.getLocation(timeZoneName));
        } catch (e) {
          tz.setLocalLocation(tz.UTC);
          debugPrint('Usando UTC como timezone');
        }
      }

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse:
            _onBackgroundNotificationTapped,
      );

      await _createNotificationChannel();

      _initialized = true;
      debugPrint('NotificationService inicializado correctamente');
    } catch (e, stackTrace) {
      debugPrint('Error al inicializar NotificationService: $e');
      debugPrint('Stack: $stackTrace');
    }
  }

  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'task_reminders',
      'Recordatorios de Tareas',
      description: 'Notificaciones para recordar tareas pendientes',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    debugPrint('Canal de notificaciones creado');
  }

  Future<bool> requestPermissions() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImplementation = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        final granted = await androidImplementation
            ?.requestNotificationsPermission();

        final alarmPermission = await androidImplementation
            ?.requestExactAlarmsPermission();

        debugPrint('Permiso notificaciones: $granted');
        debugPrint('Permiso alarmas exactas: $alarmPermission');

        return granted ?? false;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosImplementation = _notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();

        final granted = await iosImplementation?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      return true;
    } catch (e) {
      debugPrint('Error al pedir permisos: $e');
      return false;
    }
  }

  Future<void> scheduleTaskNotification({
    required String taskId,
    required String taskTitle,
    required DateTime scheduledDate,
    String? taskGroupName,
  }) async {
    try {
      if (!_initialized) {
        debugPrint('Inicializando NotificationService...');
        await initialize();
      }

      final now = DateTime.now();
      if (scheduledDate.isBefore(now)) {
        debugPrint('La fecha de recordatorio es en el pasado: $scheduledDate');
        return;
      }

      final int notificationId = taskId.hashCode.abs();

      debugPrint('Programando notificación:');
      debugPrint('   ID: $notificationId');
      debugPrint('   Fecha: $scheduledDate');

      tz.Location location;
      try {
        location = tz.local;
      } catch (e) {
        debugPrint('Error con tz.local, usando UTC');
        location = tz.UTC;
      }

      final tz.TZDateTime scheduledTZDate = tz.TZDateTime.from(
        scheduledDate,
        location,
      );

      debugPrint('   TZDateTime: $scheduledTZDate');

      const androidDetails = AndroidNotificationDetails(
        'task_reminders',
        'Recordatorios de Tareas',
        channelDescription: 'Notificaciones para recordar tareas pendientes',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        showWhen: true,
        ongoing: false,
        autoCancel: true,
        styleInformation: BigTextStyleInformation(''),
        visibility: NotificationVisibility.public,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        notificationId,
        'Recordatorio: $taskTitle',
        taskGroupName != null
            ? '> $taskGroupName'
            : 'Es hora de completar tu tarea',
        scheduledTZDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: taskId,
      );

      final difference = scheduledDate.difference(now);
      debugPrint(' Notificación programada exitosamente:');
      debugPrint('   Tarea: $taskTitle');
      debugPrint('   ID: $notificationId');
      debugPrint('   Fecha: $scheduledDate');
      debugPrint('   En: ${difference.inMinutes} minutos');
    } catch (e, stackTrace) {
      debugPrint('ERROR al programar notificación:');
      debugPrint('   Error: $e');
      debugPrint('   Stack: $stackTrace');
    }
  }

  Future<void> cancelTaskNotification(String taskId) async {
    try {
      final int notificationId = taskId.hashCode.abs();
      await _notifications.cancel(notificationId);
      debugPrint('Notificación cancelada: $taskId (ID: $notificationId)');
    } catch (e) {
      debugPrint('Error al cancelar notificación: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      debugPrint('Todas las notificaciones canceladas');
    } catch (e) {
      debugPrint('Error al cancelar todas las notificaciones: $e');
    }
  }

  Future<void> printPendingNotifications() async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      debugPrint('Notificaciones pendientes: ${pending.length}');
      for (var notification in pending) {
        debugPrint(
          '   - ID: ${notification.id}, Título: ${notification.title}',
        );
      }
    } catch (e) {
      debugPrint('Error al obtener notificaciones pendientes: $e');
    }
  }

  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async {
    try {
      return await _notifications.getNotificationAppLaunchDetails();
    } catch (e) {
      debugPrint('Error al obtener launch details: $e');
      return null;
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    final String? taskId = response.payload;

    if (taskId != null) {
      _notificationTapStream.addTaskId(taskId);
    }
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    final String? taskId = response.payload;

    if (taskId != null) {
      _notificationTapStream.addTaskId(taskId);
    }
  }

  Future<void> showImmediateNotification({
    required String title,
    required String body,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      const androidDetails = AndroidNotificationDetails(
        'task_reminders',
        'Recordatorios de Tareas',
        channelDescription: 'Notificaciones para recordar tareas pendientes',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        DateTime.now().millisecond,
        title,
        body,
        notificationDetails,
      );

      debugPrint('✅ Notificación inmediata mostrada');
    } catch (e) {
      debugPrint('❌ Error al mostrar notificación: $e');
    }
  }
}

// =====================================================
// 🆕 STREAM PARA MANEJAR TAPS EN NOTIFICACIONES
// =====================================================
class NotificationTapStream {
  final _controller = StreamController<String>.broadcast();
  Stream<String> get stream => _controller.stream;

  void addTaskId(String taskId) {
    if (!_controller.isClosed) {
      _controller.add(taskId);
    }
  }

  void dispose() {
    _controller.close();
  }
}
