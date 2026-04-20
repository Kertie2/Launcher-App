import 'dart:async';
import 'package:flutter/material.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:external_app_launcher/external_app_launcher.dart';

class AppLockService {
  static Timer? _timer;
  static List<String> _allowedPackages = [];
  static bool _isActive = false;
  static bool _isAdmin = false;
  static bool _isDisabled = false;
  static bool _permissionCached = false; // Cache pour la permission
  static String myPackageName = "fr.timeo.launchercollege";

  static Function(String)? onAppBlocked;

  /// Démarre la surveillance
  static void start(List<String> allowed, {bool isAdmin = false}) async {
    if (_isDisabled) {
      _timer?.cancel();
      _isActive = false;
      return;
    }

    _allowedPackages = [
      myPackageName,
      "com.android.settings",
      "com.google.android.packageinstaller",

      ...allowed,
    ];
    _isAdmin = isAdmin;
    _isActive = true;

    _timer?.cancel();

    if (!_isAdmin) {
      // On vérifie la permission une seule fois au début pour éviter les logs inutiles
      _permissionCached = await UsageStats.checkUsagePermission() ?? false;

      _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        _checkCurrentApp();
      });
    }
  }

  static void stop() {
    _isActive = false;
    _timer?.cancel();
  }

  static void disableTotally() {
    _isDisabled = true;
    stop();
  }

  static bool get isDisabled => _isDisabled;

  static Future<void> _checkCurrentApp() async {
    if (!_isActive || _isAdmin || !_permissionCached) return;

    DateTime endDate = DateTime.now();
    DateTime startDate = endDate.subtract(const Duration(seconds: 1));

    List<EventUsageInfo> events = await UsageStats.queryEvents(
      startDate,
      endDate,
    );

    if (events.isEmpty) return;

    String? lastPackage;
    for (var event in events.reversed) {
      if (event.eventType == "1") {
        // MOVE_TO_FOREGROUND
        lastPackage = event.packageName;
        break;
      }
    }

    if (lastPackage != null &&
        lastPackage != myPackageName &&
        !_allowedPackages.contains(lastPackage)) {
      debugPrint("🚫 Blocage de : $lastPackage");

      await LaunchApp.openApp(
        androidPackageName: myPackageName,
        openStore: false,
      );

      if (onAppBlocked != null) {
        onAppBlocked!(lastPackage);
      }
    }
  }

  static Future<void> bringToForeground() async {
    await LaunchApp.openApp(
      androidPackageName: myPackageName,
      openStore: false,
    );
  }

  static Future<bool> checkAndRequestPermission(BuildContext context) async {
    bool hasPermission = await UsageStats.checkUsagePermission() ?? false;
    _permissionCached = hasPermission; // On met à jour le cache
    if (!hasPermission) {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Sécurité du Launcher"),
            content: const Text(
              "Pour que le mode kiosque fonctionne, vous devez autoriser 'Accès aux données d'utilisation' pour cette application.",
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await UsageStats.grantUsagePermission();
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text("Ouvrir les paramètres"),
              ),
            ],
          ),
        );
      }
      return false;
    }
    return true;
  }
}
