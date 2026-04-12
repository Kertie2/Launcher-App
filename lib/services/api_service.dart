import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static const String baseUrl = "http://10.111.27.253:3000";
  static const String baseUrlFallback = "http://192.168.1.55:3000";

  static String? _token;

  static String? _activeBaseUrl;

  // Getters pour utiliser l'IP qui fonctionne partout dans l'app
  static String get currentBaseUrl => _activeBaseUrl ?? baseUrl;
  static String get currentFallbackUrl =>
      (_activeBaseUrl == null || _activeBaseUrl == baseUrl)
      ? baseUrlFallback
      : baseUrl;

  static Map<String, String> get _authHeaders => {
    "Content-Type": "application/json",
    if (_token != null) "Authorization": "Bearer $_token",
  };

  static Future<Map<String, dynamic>> getLatestLauncherVersion() async {
    final response = await _tryRequest(
      (base) => http.get(
        Uri.parse('$base/api/launcher/latest'),
        headers: _authHeaders,
      ),
    );
    if (response == null) return {};
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> sendHeartbeat(
    String deviceId,
    List<Map<String, String>> installedApps,
  ) async {
    final response = await _tryRequest(
      (base) => http.post(
        Uri.parse('$base/api/devices/heartbeat'),
        headers: _authHeaders,
        body: jsonEncode({
          'deviceId': deviceId,
          'installedApps': installedApps,
        }),
      ),
    );
    if (response == null) return {'success': false};
    return jsonDecode(response.body);
  }

  static Future<void> logoutDevice(String deviceId) async {
    await _tryRequest(
      (base) => http.post(
        Uri.parse('$base/api/devices/logout'),
        headers: _authHeaders,
        body: jsonEncode({'deviceId': deviceId}),
      ),
    );
  }

  // Vérifie si la tablette est blacklistée
  static Future<bool> isDeviceBlacklisted(String deviceId) async {
    final response = await _tryRequest(
      (base) => http.get(
        Uri.parse('$base/api/devices/$deviceId/status'),
        headers: _authHeaders,
      ),
    );
    if (response == null) return false;
    final data = jsonDecode(response.body);
    return data['blacklisted'] == true;
  }

  static Future<http.Response?> _tryRequest(
    Future<http.Response> Function(String base) requestFn, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_activeBaseUrl != null) {
      try {
        return await requestFn(_activeBaseUrl!).timeout(timeout);
      } catch (_) {
        _activeBaseUrl = null; // Reset if the preferred URL fails
      }
    }

    // Try with the primary URL
    try {
      final response = await requestFn(baseUrl).timeout(timeout);
      _activeBaseUrl = baseUrl;
      return response;
    } catch (_) {
      // If it fails, try the fallback
      try {
        final response = await requestFn(baseUrlFallback).timeout(timeout);
        _activeBaseUrl = baseUrlFallback;
        return response;
      } catch (_) {
        return null; // Both failed
      }
    }
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
    String deviceId,
  ) async {
    final response = await _tryRequest((base) {
      return http.post(
        Uri.parse("$base/api/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "password": password,
          "deviceId": deviceId,
        }),
      );
    });
    if (response == null)
      return {"success": false, "message": "Serveur injoignable"};

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['token'];
      return data;
    }
    return {"success": false, "message": "Erreur identifiants"};
  }

  static Future<List<dynamic>> getAllowedApps() async {
    final response = await _tryRequest(
      (base) => http.get(Uri.parse('$base/api/apps'), headers: _authHeaders),
    );
    return (response != null && response.statusCode == 200)
        ? jsonDecode(response.body)
        : [];
  }

  static Future<bool> addApp(
    String name,
    String package,
    String iconBase64,
    String apkPath,
  ) async {
    try {
      debugPrint("📤 [addApp] Début envoi : $name ($package)");
      debugPrint("📤 [addApp] APK path : $apkPath");
      debugPrint("📤 [addApp] Token présent : ${_token != null}");
      debugPrint("📤 [addApp] URL cible : $currentBaseUrl/api/apps");

      final response = await _tryRequest((base) async {
        debugPrint("📤 [addApp] Tentative sur : $base");
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$base/api/apps'),
        );
        request.fields['appName'] = name;
        request.fields['package'] = package;
        request.fields['iconBase64'] = iconBase64;

        if (_token != null) {
          request.headers['Authorization'] = 'Bearer $_token';
        } else {
          debugPrint("❌ [addApp] Pas de token !");
        }

        debugPrint("📤 [addApp] Ajout du fichier APK...");
        request.files.add(
          await http.MultipartFile.fromPath(
            'apk',
            apkPath,
            contentType: MediaType(
              'application',
              'vnd.android.package-archive',
            ),
          ),
        );

        debugPrint("📤 [addApp] Envoi de la requête...");
        var streamed = await request.send();
        final resp = await http.Response.fromStream(streamed);
        debugPrint("📤 [addApp] Réponse reçue : ${resp.statusCode}");
        debugPrint("📤 [addApp] Body : ${resp.body}");
        return resp;
      }, timeout: const Duration(minutes: 2));

      final success =
          response != null &&
          response.statusCode >= 200 &&
          response.statusCode < 300;
      debugPrint(
        "📤 [addApp] Résultat final : ${success ? '✅ Succès' : '❌ Échec'}",
      );
      return success;
    } catch (e) {
      debugPrint("❌ [addApp] Exception : $e");
      return false;
    }
  }

  static Future<bool> deleteApp(int id) async {
    final response = await _tryRequest(
      (base) =>
          http.delete(Uri.parse('$base/api/apps/$id'), headers: _authHeaders),
    );
    return response != null &&
        response.statusCode >= 200 &&
        response.statusCode < 300;
  }
}
