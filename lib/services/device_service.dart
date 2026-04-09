import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  static const String _deviceIdKey = 'device_id';

  // Récupère l'ID, retourne null si pas encore configuré
  static Future<String?> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceIdKey);
  }

  // Sauvegarde l'ID
  static Future<void> setDeviceId(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceIdKey, deviceId);
  }

  // Vérifie si l'ID est configuré
  static Future<bool> isConfigured() async {
    final id = await getDeviceId();
    return id != null && id.isNotEmpty;
  }
}