import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notification service for displaying notifications when app is in foreground
/// Uses flutter_local_notifications to show custom notifications
class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize local notifications
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
    log('Local notifications initialized');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    log('Local notification tapped with payload: $payload');

    if (payload == null || payload.isEmpty) return;

    // Parse payload format: "type:value|key:value"
    final Map<String, String> data = {};
    final parts = payload.split('|');
    for (final part in parts) {
      final keyValue = part.split(':');
      if (keyValue.length == 2) {
        data[keyValue[0]] = keyValue[1];
      }
    }

    final type = data['type'];
    final postingId = data['postingId'];
    final conversationId = data['conversationId'];
    final taskId = data['taskId'];

    log('Parsed notification tap - Type: $type');

    // Get navigator
    final navigator = WidgetsBinding.instance.rootElement
        ?.findAncestorStateOfType<NavigatorState>();

    if (navigator == null) {
      log('⚠️ Navigator not available, cannot navigate from notification');
      return;
    }

    // Navigate based on type
    switch (type) {
      case 'collector_assigned':
      case 'status_update':
        if (postingId != null) {
          navigator.pushNamed(
            '/household/track',
            arguments: {'postingId': postingId},
          );
          log('✅ Navigated to track screen');
        }
        break;

      case 'new_task':
        if (taskId != null) {
          navigator.pushNamed(
            '/collector/task-details',
            arguments: {'taskId': taskId},
          );
          log('✅ Navigated to collector task details');
        }
        break;

      case 'new_message':
        if (conversationId != null) {
          navigator.pushNamed(
            '/household/chat',
            arguments: {'conversationId': conversationId},
          );
          log('✅ Navigated to chat screen');
        }
        break;

      case 'new_posting':
        if (postingId != null) {
          navigator.pushNamed(
            '/junkshop/assigned-pickups',
            arguments: {'postingId': postingId},
          );
          log('✅ Navigated to junkshop assigned pickups');
        }
        break;

      default:
        log('⚠️ Unknown notification type: $type');
    }
  }

  /// Show a notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final androidDetails = AndroidNotificationDetails(
      'ecokuha_channel', // Channel ID
      'EcoKuha Notifications', // Channel name
      channelDescription: 'Notifications for waste collection updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        body,
        htmlFormatBigText: false,
        contentTitle: title,
        summaryText: 'EcoKuha',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    log('Local notification shown: $title - $body');
  }

  /// Show notification for collector assignment
  Future<void> showCollectorAssignedNotification({
    required String collectorName,
    required String postingId,
  }) async {
    await showNotification(
      title: 'Collector Assigned',
      body: '$collectorName has been assigned to your pickup',
      payload: 'type:collector_assigned|postingId:$postingId',
      id: postingId.hashCode,
    );
  }

  /// Show notification for status update
  Future<void> showStatusUpdateNotification({
    required String status,
    required String postingId,
  }) async {
    String message;
    switch (status) {
      case 'on_route':
        message = 'Your collector is on the way';
        break;
      case 'arrived':
        message = 'Your collector has arrived';
        break;
      case 'collecting':
        message = 'Collection is in progress';
        break;
      case 'completed':
        message = 'Collection completed successfully';
        break;
      default:
        message = 'Status updated to $status';
    }

    await showNotification(
      title: 'Pickup Status Update',
      body: message,
      payload: 'type:status_update|postingId:$postingId|status:$status',
      id: postingId.hashCode,
    );
  }

  /// Show notification for new task (collector)
  Future<void> showNewTaskNotification({
    required String householdName,
    required String taskId,
  }) async {
    await showNotification(
      title: 'New Pickup Task',
      body: 'You have been assigned a new pickup from $householdName',
      payload: 'type:new_task|taskId:$taskId',
      id: taskId.hashCode,
    );
  }

  /// Show notification for new message
  Future<void> showNewMessageNotification({
    required String senderName,
    required String messagePreview,
    required String conversationId,
  }) async {
    await showNotification(
      title: 'New Message from $senderName',
      body: messagePreview,
      payload: 'type:new_message|conversationId:$conversationId',
      id: conversationId.hashCode,
    );
  }

  /// Show notification for new posting (junkshop)
  Future<void> showNewPostingNotification({
    required String householdName,
    required String postingId,
  }) async {
    await showNotification(
      title: 'New Pickup Request',
      body: '$householdName has posted a new pickup request',
      payload: 'type:new_posting|postingId:$postingId',
      id: postingId.hashCode,
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
