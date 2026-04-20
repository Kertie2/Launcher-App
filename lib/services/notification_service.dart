import 'package:flutter/material.dart';
import 'api_service.dart';
import 'device_service.dart';

class NotificationService {
  static VoidCallback? onForceOpen;
  static Function(String message)? onNotificationReceived;

  static Future<void> init() async {
    // Pas de package externe nécessaire
  }

  static Future<void> checkPending() async {
    final deviceId = await DeviceService.getDeviceId();
    if (deviceId == null) return;

    final notifications = await ApiService.getPendingNotifications(deviceId);

    for (final notif in notifications) {
      final int id = notif['id'];
      final String message = notif['message'] ?? '';

      await ApiService.markNotificationRead(id);

      if (message == '__FORCE_OPEN__') {
        if (onForceOpen != null) onForceOpen!();
      } else {
        if (onNotificationReceived != null) {
          onNotificationReceived!(message);
        }
        // Si app en arrière-plan on ne fait rien —
        // le kiosque ramènera l'élève sur le launcher de toute façon
      }
    }
  }
}