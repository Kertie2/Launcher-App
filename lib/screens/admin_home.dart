import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'dart:ui';
import '../services/api_service.dart';
import '../services/app_lock_service.dart';
import 'login_screen.dart';
import 'dart:convert';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:http/http.dart' as http;
import '../services/device_service.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class AdminHome extends StatefulWidget {
  final String userName;
  const AdminHome({super.key, required this.userName});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> with TickerProviderStateMixin {
  List<dynamic> allowedApps = [];
  bool isLoading = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  static const Color _bleu = Color(0xFF003189);
  static const Color _bleuFonce = Color(0xFF001F5C);
  static const Color _fond = Color(0xFFF0F4FF);
  static const Color _blanc = Colors.white;

  @override
  void initState() {
    super.initState();
    AppLockService.start([], isAdmin: true);
    _fetchApps();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _fetchApps() async {
    setState(() => isLoading = true);
    try {
      final apps = await ApiService.getAllowedApps();
      setState(() {
        allowedApps = apps;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showSnack("Erreur lors de la récupération des apps", Colors.red);
    }
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

  Future<void> _logout() async {
    final deviceId = await DeviceService.getDeviceId() ?? 'NON-CONFIGURE';
    await ApiService.logoutDevice(deviceId);
    if (!mounted) return;
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

  void _showDeviceIdDialog() async {
    final currentId = await DeviceService.getDeviceId();
    final controller = TextEditingController(text: currentId ?? '');

    showDialog(
      context: context,
      builder: (context) => _buildDialog(
        title: "Identifiant tablette",
        icon: Icons.tablet_android_rounded,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _fond,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 15,
                    color: _bleu.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Actuel : ${currentId ?? 'Non configuré'}",
                    style: TextStyle(
                      fontSize: 13,
                      color: _bleuFonce.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildDialogField(
              "Nouvel identifiant",
              controller,
              "ex: LENOVO-TAB-01",
            ),
          ],
        ),
        actions: [
          _buildDialogBtn("Annuler", false, () => Navigator.pop(context)),
          _buildDialogBtn("Enregistrer", true, () async {
            final newId = controller.text.trim();
            if (newId.isEmpty) return;
            await DeviceService.setDeviceId(newId);
            Navigator.pop(context);
            _showSnack("✅ Identifiant configuré : $newId", Colors.green);
          }),
        ],
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _bleu,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Application>> _getInstalledApps() async {
    List<Application> apps = await DeviceApps.getInstalledApplications(
      includeAppIcons: true,
      includeSystemApps: true,
      onlyAppsWithLaunchIntent: true,
    );
    apps.sort(
      (a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()),
    );
    return apps;
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
            _buildQuickActions(),
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
              // Logos
              Row(
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

              const Spacer(),

              // Titre centré
              Column(
                children: [
                  const Text(
                    "Espace Administration",
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

              // User + logout
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
                              widget.userName.isNotEmpty
                                  ? widget.userName[0].toUpperCase()
                                  : "A",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _logout(),
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

  Widget _buildQuickActions() {
    return Container(
      color: _blanc,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Row(
        children: [
          _buildActionChip(
            Icons.add_rounded,
            "Ajouter une app",
            _bleu,
            () => _showAddAppDialog(),
          ),
          const SizedBox(width: 12),
          _buildActionChip(
            Icons.store_rounded,
            "Play Store",
            const Color(0xFF34A853),
            () => LaunchApp.openApp(
              androidPackageName: 'com.android.vending',
              openStore: false,
            ),
          ),
          const SizedBox(width: 12),
          _buildActionChip(
            Icons.language_rounded,
            "Chrome",
            const Color(0xFF4285F4),
            () => LaunchApp.openApp(
              androidPackageName: 'com.android.chrome',
              openStore: false,
            ),
          ),
          const SizedBox(width: 12),
          _buildActionChip(
            Icons.tablet_android_rounded,
            "ID Tablette",
            const Color(0xFF6C63FF),
            () => _showDeviceIdDialog(),
          ),
          const Spacer(),
          // Refresh
          GestureDetector(
            onTap: _fetchApps,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _fond,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _bleu.withOpacity(0.15)),
              ),
              child: Icon(Icons.refresh_rounded, color: _bleu, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppGrid() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF003189)),
      );
    }

    if (allowedApps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apps_rounded, size: 64, color: _bleu.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              "Aucune application autorisée",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _bleuFonce.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Ajoutez des applications via le bouton ci-dessus",
              style: TextStyle(
                fontSize: 13,
                color: _bleuFonce.withOpacity(0.3),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchApps,
      color: _bleu,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Applications autorisées",
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
                  crossAxisCount: 6,
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
      ),
    );
  }

  Widget _buildAppCard(Map<String, dynamic> app) {
    String name = app['appName'] ?? "App";
    String packageName = app['packageName'] ?? "";
    final imgUrl = "${ApiService.currentBaseUrl}/uploads/$packageName.png";

    return FutureBuilder<bool>(
      future: DeviceApps.isAppInstalled(packageName),
      builder: (context, snapshot) {
        final isInstalled = snapshot.data ?? false;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Container(
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
          child: Stack(
            children: [
              // Contenu principal
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icône
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        imgUrl,
                        height: 56,
                        width: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_bleu, const Color(0xFF4A7FE5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : "?",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 8),

                    // Bouton Ouvrir ou Installer
                    if (isLoading)
                      SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _bleu,
                        ),
                      )
                    else if (isInstalled)
                      GestureDetector(
                        onTap: () => DeviceApps.openApp(packageName),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34A853).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF34A853).withOpacity(0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                size: 14,
                                color: Color(0xFF34A853),
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Ouvrir",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF34A853),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () => _installApp(packageName, name),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _bleu.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _bleu.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.download_rounded,
                                size: 14,
                                color: _bleu,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Installer",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _bleu,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Bouton supprimer
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => _buildDialog(
                        title: "Supprimer l'application",
                        icon: Icons.delete_outline_rounded,
                        content: Text(
                          "Voulez-vous supprimer \"$name\" de la liste des applications autorisées ?",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4A5568),
                            height: 1.5,
                          ),
                        ),
                        actions: [
                          _buildDialogBtn(
                            "Annuler",
                            false,
                            () => Navigator.pop(context, false),
                          ),
                          _buildDialogBtn(
                            "Supprimer",
                            true,
                            () => Navigator.pop(context, true),
                            danger: true,
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      final deleted = await ApiService.deleteApp(app['id']);
                      if (deleted) _fetchApps();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Télécharge et installe l'APK
  Future<void> _installApp(String packageName, String appName) async {
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

      // Rafraîchit la grille après installation
      await Future.delayed(const Duration(seconds: 2));
      setState(() {});
    } catch (e) {
      _showSnack("❌ Erreur : $e", Colors.red);
    }
  }

  // --- DIALOG HELPERS ---
  Widget _buildDialog({
    required String title,
    required IconData icon,
    required Widget content,
    required List<Widget> actions,
  }) {
    return Dialog(
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
                  child: Icon(icon, color: _bleu, size: 22),
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'DepartementFont',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A1628),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            content,
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4A5568),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF7F9FF),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogBtn(
    String label,
    bool primary,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: danger
              ? Colors.red
              : primary
              ? _bleu
              : const Color(0xFFF0F4FF),
          foregroundColor: primary || danger
              ? Colors.white
              : const Color(0xFF4A5568),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }

  // --- LOGIQUE POP-UP AJOUTER APP ---
  void _showAddAppDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildDialog(
        title: "Ajouter une application",
        icon: Icons.add_rounded,
        content: SizedBox(
          width: 500,
          height: 400,
          child: FutureBuilder<List<Application>>(
            future: _getInstalledApps(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: _bleu));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("Aucune application trouvée."));
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final app = snapshot.data![index];
                  Widget icon = Icon(
                    Icons.android_rounded,
                    color: Colors.green.shade400,
                    size: 40,
                  );
                  if (app is ApplicationWithIcon) {
                    icon = ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        app.icon,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    );
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    leading: icon,
                    title: Text(
                      app.appName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      app.packageName,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    trailing: GestureDetector(
                      onTap: () async {
                        _showLoadingDialog(
                          "Envoi de l'application au serveur...",
                        );
                        String iconBase64 = "";
                        if (app is ApplicationWithIcon) {
                          iconBase64 = base64Encode(app.icon);
                        }
                        bool success = await ApiService.addApp(
                          app.appName,
                          app.packageName,
                          iconBase64,
                          app.apkFilePath,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          if (success) {
                            Navigator.pop(context);
                            _fetchApps();
                            _showSnack(
                              "✅ ${app.appName} ajoutée",
                              Colors.green,
                            );
                          } else {
                            _showSnack("❌ Échec de l'ajout", Colors.red);
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _bleu.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.add_rounded, color: _bleu, size: 20),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          _buildDialogBtn("Fermer", false, () => Navigator.pop(context)),
        ],
      ),
    );
  }
}
