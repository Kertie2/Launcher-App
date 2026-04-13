import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../services/api_service.dart';
import '../services/app_lock_service.dart';
import 'package:device_apps/device_apps.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import '../services/device_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

class _StudentHomeState extends State<StudentHome>
    with TickerProviderStateMixin {
  List<dynamic> allowedApps = [];
  Map<String, bool> installedStatus = {};
  Map<String, bool> installingStatus = {};
  Timer? _updateTimer;
  Timer? _secretTapResetTimer;
  final TextEditingController _disableCodeController = TextEditingController();
  int _secretTapCount = 0;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  static const Color _bleu = Color(0xFF003189);
  static const Color _bleuFonce = Color(0xFF001F5C);
  static const Color _fond = Color(0xFFF0F4FF);
  static const Color _blanc = Colors.white;

  Future<void> _logout() async {
    final deviceId = await DeviceService.getDeviceId() ?? 'NON-CONFIGURE';
    await ApiService.logoutDevice(deviceId);
    if (!mounted) return;
    AppLockService.start([]);
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadApps();
    _checkLauncherUpdate();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    AppLockService.onAppBlocked = (packageName) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("⚠️ Cette application n'est pas autorisée."),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(20),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    };

    _updateTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadApps(),
    );
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _secretTapResetTimer?.cancel();
    _disableCodeController.dispose();
    _fadeController.dispose();
    AppLockService.onAppBlocked = null;
    super.dispose();
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
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
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = 'v${packageInfo.version}';
      if (currentVersion != latestVersion) {
        _downloadAndInstallLauncher(latest['downloadUrl'], latestVersion);
      }
    } catch (e) {
      debugPrint("❌ Erreur vérification MAJ : $e");
    }
  }

  Future<void> _downloadAndInstallLauncher(String url, String version) async {
    if (!mounted) return;
    _showSnack(
      "🔄 Mise à jour $version disponible, téléchargement...",
      Colors.blue,
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
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _bleu.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.lock_open_rounded,
                      color: _bleu,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    "Code de désactivation",
                    style: TextStyle(
                      fontFamily: 'DepartementFont',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A1628),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _disableCodeController,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "Entrez le code",
                  filled: true,
                  fillColor: _fond,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _bleu.withOpacity(0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _bleu, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _bleu.withOpacity(0.15)),
                  ),
                ),
                onSubmitted: (_) => _validateDisableCode(dialogContext),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _fond,
                      foregroundColor: const Color(0xFF4A5568),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Annuler"),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => _validateDisableCode(dialogContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _bleu,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Valider"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _validateDisableCode(BuildContext dialogContext) {
    if (_disableCodeController.text == "2109") {
      AppLockService.disableTotally();
      Navigator.of(dialogContext).pop();
      if (!mounted) return;
      _showSnack("Verrouillage des applications désactivé.", Colors.green);
      return;
    }
    Navigator.of(dialogContext).pop();
    if (!mounted) return;
    _showSnack("Code incorrect.", Colors.red);
  }

  Future<void> _checkPermissions() async {
    await Permission.requestInstallPackages.request();
    if (mounted) await AppLockService.checkAndRequestPermission(context);
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
    }

    final heartbeat = await ApiService.sendHeartbeat(
      deviceId,
      installedAppsList,
    );

    if (heartbeat['blacklisted'] == true) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.block_rounded,
                      color: Colors.red,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Tablette bloquée",
                    style: TextStyle(
                      fontFamily: 'DepartementFont',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A1628),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Cette tablette a été bloquée par un administrateur.\n\nRaison : ${heartbeat['reason'] ?? 'Non précisée'}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4A5568),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _logout(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      "OK",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
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

  // Télécharge et installe à la demande (au tap)
  Future<void> _downloadAndInstallOnTap(
    String packageName,
    String appName,
  ) async {
    if (installingStatus[packageName] == true) return;

    setState(() => installingStatus[packageName] = true);
    AppLockService.stop();

    _showSnack("⏳ Téléchargement de $appName...", _bleu);

    try {
      final directory = await getApplicationSupportDirectory();
      final savePath = '${directory.path}/$packageName.apk';

      final urls = [
        "${ApiService.currentBaseUrl}/uploads/apks/$packageName.apk",
        "${ApiService.currentFallbackUrl}/uploads/apks/$packageName.apk",
      ];

      bool downloaded = false;
      for (final url in urls) {
        try {
          await Dio().download(
            url,
            savePath,
            options: Options(receiveTimeout: const Duration(minutes: 3)),
          );
          downloaded = true;
          break;
        } catch (_) {}
      }

      if (!downloaded) {
        _showSnack("❌ Impossible de télécharger $appName", Colors.red);
        return;
      }

      await OpenFilex.open(
        savePath,
        type: "application/vnd.android.package-archive",
      );

      // Poll pour détecter l'installation
      int attempts = 0;
      while (attempts < 24) {
        await Future.delayed(const Duration(seconds: 5));
        bool isInstalled = await DeviceApps.isAppInstalled(packageName);
        if (isInstalled) {
          if (mounted) setState(() => installedStatus[packageName] = true);
          _showSnack("✅ $appName installée !", Colors.green);
          break;
        }
        attempts++;
      }
    } catch (e) {
      debugPrint("❌ Erreur installation $appName: $e");
    } finally {
      if (mounted) setState(() => installingStatus[packageName] = false);
      AppLockService.start(
        allowedApps.map((app) => app['packageName'] as String).toList(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fond,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildAppGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF001040), Color(0xFF003189)],
        ),
        boxShadow: [
          BoxShadow(
            color: _bleuFonce.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          child: Row(
            children: [
              // Logos avec tap secret
              GestureDetector(
                onTap: _handleSecretLogoTap,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset('assets/logo_aude.png', height: 42),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      color: Colors.white24,
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset('assets/logo_college.png', height: 42),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Titre
              Column(
                children: [
                  const Text(
                    "Espace Élève",
                    style: TextStyle(
                      fontFamily: 'DepartementFont',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "Collège Saint-Exupéry de Bram",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Infos élève + logout
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              widget.displayName.isNotEmpty
                                  ? widget.displayName[0].toUpperCase()
                                  : "E",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              widget.classe,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _logout,
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppGrid() {
    if (allowedApps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apps_rounded, size: 64, color: _bleu.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              "Aucune application disponible",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _bleuFonce.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Vos applications",
                style: TextStyle(
                  fontFamily: 'DepartementFont',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _bleuFonce,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _bleu.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${allowedApps.length}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _bleu,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 0.85,
              ),
              itemCount: allowedApps.length,
              itemBuilder: (context, index) {
                final app = allowedApps[index];
                return _buildAppCard(app);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppCard(Map<String, dynamic> app) {
    final String packageName = app['packageName'] ?? '';
    final String name = app['appName'] ?? 'App';
    final bool isInstalled = installedStatus[packageName] ?? false;
    final bool isInstalling = installingStatus[packageName] ?? false;
    final imgUrl = "${ApiService.currentBaseUrl}/uploads/$packageName.png";

    return GestureDetector(
      onTap: () async {
        if (isInstalling) return;
        if (isInstalled) {
          DeviceApps.openApp(packageName);
        } else {
          await _downloadAndInstallOnTap(packageName, name);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _blanc,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icône
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      imgUrl,
                      height: 64,
                      width: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 64,
                        width: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_bleu, const Color(0xFF4A7FE5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : "?",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Overlay si en cours d'installation
                  if (isInstalling)
                    Container(
                      height: 64,
                      width: 64,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Nom
              Text(
                name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 6),

              // Badge statut
              if (isInstalling)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _bleu.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "Installation...",
                    style: TextStyle(
                      fontSize: 9,
                      color: _bleu,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else if (!isInstalled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.download_rounded,
                        size: 10,
                        color: Colors.orange,
                      ),
                      SizedBox(width: 3),
                      Text(
                        "Appuyer pour installer",
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
