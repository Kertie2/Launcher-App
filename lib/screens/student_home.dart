import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../services/api_service.dart';
import '../services/app_lock_service.dart';
import 'package:device_apps/device_apps.dart'; // Pour vérifier et ouvrir les apps installées
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart'; // Import de la nouvelle version
import '../services/device_service.dart';
import 'package:package_info_plus/package_info_plus.dart'; // MAJ launcher

class StudentHome extends StatefulWidget {
  final String displayName;
  final String classe;

  const StudentHome({
    super.key,
    required this.displayName,
    required this.classe,
  });

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  List<dynamic> allowedApps = [];
  Map<String, bool> installedStatus = {}; // Stocke si le package est installé
  Timer? _updateTimer;
  Timer? _secretTapResetTimer;
  final TextEditingController _disableCodeController = TextEditingController();
  bool _isInstalling = false; // Évite de lancer 10 installs en même temps
  int _secretTapCount = 0;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadApps();
    _checkLauncherUpdate();

    AppLockService.onAppBlocked = (packageName) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "⚠️ Cette application n'est pas autorisée sur cette tablette.",
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    };

    // Heartbeat toutes les 30 secondes
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadApps();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel(); // Arrête le timer quand on quitte la page
    _secretTapResetTimer?.cancel();
    _disableCodeController.dispose();
    AppLockService.onAppBlocked = null;
    super.dispose();
  }

  void _handleSecretLogoTap() {
    _secretTapResetTimer?.cancel();
    _secretTapCount++;

    if (_secretTapCount >= 5) {
      _secretTapCount = 0;
      _showDisableAppLockDialog();
      return;
    }

    _secretTapResetTimer = Timer(const Duration(seconds: 4), () {
      _secretTapCount = 0;
    });
  }

  Future<void> _checkLauncherUpdate() async {
    try {
      final latest = await ApiService.getLatestLauncherVersion();
      if (latest.isEmpty) return;

      final latestVersion = latest['version'] as String?;
      if (latestVersion == null) return;

      // Récupère la version actuelle de l'app
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = 'v${packageInfo.version}';

      debugPrint("📱 Version actuelle : $currentVersion");
      debugPrint("🆕 Dernière version : $latestVersion");

      if (currentVersion != latestVersion) {
        _downloadAndInstallLauncher(latest['downloadUrl'], latestVersion);
      }
    } catch (e) {
      debugPrint("❌ Erreur vérification MAJ : $e");
    }
  }

  Future<void> _downloadAndInstallLauncher(String url, String version) async {
    if (!mounted) return;

    // Affiche une notification discrète
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("🔄 Mise à jour $version disponible, téléchargement..."),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.blue,
      ),
    );

    try {
      final directory = await getApplicationSupportDirectory();
      final savePath = '${directory.path}/launcher-update.apk';

      await Dio().download(
        url,
        savePath,
        options: Options(receiveTimeout: const Duration(minutes: 5)),
      );

      if (!mounted) return;

      // Désactive le kiosque pour l'installation
      AppLockService.stop();

      await OpenFilex.open(
        savePath,
        type: "application/vnd.android.package-archive",
      );
    } catch (e) {
      debugPrint("❌ Erreur MAJ launcher : $e");
      AppLockService.start(
        allowedApps.map((app) => app['packageName'] as String).toList(),
      );
    }
  }

  Future<void> _showDisableAppLockDialog() async {
    _disableCodeController.clear();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Code de désactivation"),
        content: TextField(
          controller: _disableCodeController,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Code",
            hintText: "Entrez le code",
          ),
          onSubmitted: (_) => _validateDisableCode(dialogContext),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => _validateDisableCode(dialogContext),
            child: const Text("Valider"),
          ),
        ],
      ),
    );
  }

  void _validateDisableCode(BuildContext dialogContext) {
    if (_disableCodeController.text == "2109") {
      AppLockService.disableTotally();
      Navigator.of(dialogContext).pop();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Le verrouillage des applications est désactivé."),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    Navigator.of(dialogContext).pop();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Code incorrect."),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _checkPermissions() async {
    await Permission.requestInstallPackages.request();
    if (mounted) {
      await AppLockService.checkAndRequestPermission(context);
    }
  }

  void _loadApps() async {
    final apps = await ApiService.getAllowedApps();
    final deviceId = await DeviceService.getDeviceId() ?? 'NON-CONFIGURE';
    Map<String, bool> status = {};
    List<String> pkgNames = [];
    List<Map<String, String>> installedAppsList = [];

    for (var app in apps) {
      String pkg = app['packageName'] ?? '';
      if (pkg.isEmpty) continue;
      pkgNames.add(pkg);

      bool isInstalled = await DeviceApps.isAppInstalled(pkg);
      status[pkg] = isInstalled;

      if (isInstalled) {
        installedAppsList.add({
          'packageName': pkg,
          'appName': app['appName'] ?? '',
        });
      }

      if (!isInstalled && !_isInstalling) {
        _downloadAndInstall(pkg, app['appName'] ?? 'App');
      }
    }

    // Envoie le heartbeat avec les apps installées
    final heartbeat = await ApiService.sendHeartbeat(
      deviceId,
      installedAppsList,
    );

    // Si la tablette est blacklistée, on déconnecte
    if (heartbeat['blacklisted'] == true) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Tablette bloquée"),
            content: Text(
              "Cette tablette a été bloquée par un administrateur.\n\nRaison : ${heartbeat['reason'] ?? 'Non précisée'}",
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                ),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
      return;
    }

    AppLockService.start(pkgNames);

    if (mounted) {
      setState(() {
        allowedApps = apps;
        installedStatus = status;
      });
    }
  }

  Future<void> _downloadAndInstall(String packageName, String appName) async {
    if (_isInstalling) return;
    _isInstalling = true;

    // Désactive le kiosque pendant l'installation
    AppLockService.stop();

    try {
      final directory = await getApplicationSupportDirectory();
      final String savePath = "${directory.path}/$packageName.apk";

      final urls = [
        "${ApiService.currentBaseUrl}/uploads/apks/$packageName.apk",
        "${ApiService.currentFallbackUrl}/uploads/apks/$packageName.apk",
      ];

      bool downloaded = false;

      for (final url in urls) {
        try {
          debugPrint("📥 Tentative téléchargement : $url");
          await Dio().download(
            url,
            savePath,
            options: Options(
              sendTimeout: const Duration(seconds: 2),
              receiveTimeout: const Duration(seconds: 5),
            ),
          );
          downloaded = true;
          debugPrint("✅ Téléchargement réussi depuis $url");
          break;
        } catch (e) {
          debugPrint("⚠️ Échec téléchargement depuis $url : $e");
        }
      }

      if (!downloaded) {
        debugPrint("❌ Impossible de télécharger $appName");
        return;
      }

      final result = await OpenFilex.open(
        savePath,
        type: "application/vnd.android.package-archive",
      );

      debugPrint("Résultat de l'ouverture : ${result.message}");

      // Attend que l'utilisateur finisse l'installation
      // On poll jusqu'à ce que l'app soit installée (max 2 minutes)
      int attempts = 0;
      while (attempts < 24) {
        await Future.delayed(const Duration(seconds: 5));
        bool isInstalled = await DeviceApps.isAppInstalled(packageName);
        if (isInstalled) {
          debugPrint("✅ $appName installée !");
          break;
        }
        attempts++;
      }
    } catch (e) {
      debugPrint("❌ Erreur installation $appName: $e");
    } finally {
      _isInstalling = false;
      // Réactive le kiosque avec la liste des apps autorisées
      AppLockService.start(
        allowedApps.map((app) => app['packageName'] as String).toList(),
      );
      debugPrint("🔒 Kiosque réactivé");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 2),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: SafeArea(
            child: Row(
              children: [
                GestureDetector(
                  onTap: _handleSecretLogoTap,
                  child: Image.asset('assets/logo_aude.png', height: 60),
                ),
                const SizedBox(width: 15),
                GestureDetector(
                  onTap: _handleSecretLogoTap,
                  child: Image.asset('assets/logo_college.png', height: 60),
                ),
                const Spacer(),
                const Text(
                  "Espace Élève",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Bienvenue ${widget.displayName}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.classe,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(width: 15),
                IconButton(
                  icon: const Icon(
                    Icons.exit_to_app,
                    size: 40,
                    color: Colors.red,
                  ),
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Vos applications :",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            // On vérifie si la liste contient des apps
            Expanded(
              child: allowedApps.isEmpty
                  ? const Center(child: Text("Aucune application autorisée."))
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5, // 5 icônes par ligne
                            mainAxisSpacing: 30,
                            crossAxisSpacing: 20,
                            childAspectRatio: 0.8,
                          ),
                      itemCount: allowedApps.length,
                      itemBuilder: (context, index) {
                        final app = allowedApps[index];
                        return _buildAppIcon(
                          app['packageName'] ?? '',
                          app['appName'] ?? 'App',
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppIcon(String packageName, String label) {
    bool isInstalled = installedStatus[packageName] ?? true;

    // Utilisation de l'IP active mémorisée
    final urls = [
      "${ApiService.currentBaseUrl}/uploads/$packageName.png",
      "${ApiService.currentFallbackUrl}/uploads/$packageName.png",
    ];

    return GestureDetector(
      onTap: () {
        if (isInstalled) {
          DeviceApps.openApp(packageName);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 100,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                urls[0],
                height: 100,
                width: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Image.network(
                    urls[1],
                    height: 100,
                    width: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            label.isNotEmpty ? label[0].toUpperCase() : "?",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 35,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 100,
            child: Text(
              isInstalled ? label : "Installation...",
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isInstalled ? Colors.black : Colors.orange,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
