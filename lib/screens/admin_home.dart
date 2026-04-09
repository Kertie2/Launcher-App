import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import '../services/api_service.dart';
import '../services/app_lock_service.dart';
import 'login_screen.dart';
import 'dart:convert';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:http/http.dart' as http;
import '../services/device_service.dart';

class AdminHome extends StatefulWidget {
  final String userName;
  const AdminHome({super.key, required this.userName});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  List<dynamic> allowedApps = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // L'admin peut aller partout, on désactive le verrouillage
    AppLockService.start([], isAdmin: true);
    _fetchApps();
  }

  void _showDeviceIdDialog() async {
    final currentId = await DeviceService.getDeviceId();
    final controller = TextEditingController(text: currentId ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Configurer l'identifiant tablette"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "ID actuel : ${currentId ?? 'Non configuré'}",
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "Nouvel identifiant",
                hintText: "ex: 10",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newId = controller.text.trim();
              if (newId.isEmpty) return;
              await DeviceService.setDeviceId(newId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("✅ Identifiant configuré : $newId"),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false, // Empêche de fermer en cliquant à côté
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  // Récupération des apps depuis le serveur
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erreur lors de la récupération des apps"),
        ),
      );
    }
  }

  Future<List<Application>> _getInstalledApps() async {
    // includeSystemApps: false permet d'éliminer la majorité des services Android
    // onlyAppsWithLaunchIntent: true permet de ne garder que les apps avec une icône/interface
    List<Application> apps = await DeviceApps.getInstalledApplications(
      includeAppIcons: true,
      includeSystemApps: true,
      onlyAppsWithLaunchIntent: true,
    );

    // Tri alphabétique pour que ce soit plus simple pour l'admin
    apps.sort(
      (a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()),
    );

    return apps;
  }

  void _playStore() async {
    await LaunchApp.openApp(
      androidPackageName: 'com.android.vending',
      openStore: false, // On ne veut pas ouvrir le Play Store si ça rate
    );
  }

  void _chrome() async {
    await LaunchApp.openApp(
      androidPackageName: 'com.android.chrome',
      openStore: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAdminAppBar(context),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchApps,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildActionButton(
                          Icons.store,
                          "Accéder au Play Store",
                          () => _playStore(),
                        ),
                        const SizedBox(width: 20),
                        _buildActionButton(
                          Icons.language,
                          "Accéder a Chrome",
                          () => _chrome(),
                        ),
                        const SizedBox(width: 20),
                        _buildActionButton(
                          Icons.add,
                          "Ajouter une application",
                          () => _showAddAppDialog(),
                        ),
                        const SizedBox(width: 20),
                        _buildActionButton(
                          Icons.tablet_android,
                          "Configurer l'ID tablette",
                          () => _showDeviceIdDialog(),
                        ), // <- nouveau
                      ],
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      "Applications autorisées :",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      children: allowedApps
                          .map((app) => _buildAppItem(app))
                          .toList(),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  // --- WIDGETS DE COMPOSANTS ---

  PreferredSizeWidget _buildAdminAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(100),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300, width: 2),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SafeArea(
          child: Row(
            children: [
              Image.asset('assets/logo_aude.png', height: 60),
              const SizedBox(width: 15),
              Image.asset('assets/logo_college.png', height: 60),
              const Spacer(),
              const Text(
                "Espace de Gestion",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                "Admin: ${widget.userName}",
                style: const TextStyle(fontSize: 16, color: Colors.blueGrey),
              ),
              const SizedBox(width: 15),
              IconButton(
                icon: const Icon(Icons.exit_to_app, size: 40),
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.black),
      label: Text(
        label,
        style: const TextStyle(color: Colors.black, fontSize: 16),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade300,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _buildAppItem(Map<String, dynamic> app) {
    String name = app['appName'] ?? "App";
    String packageName = app['packageName'] ?? "";

    // Fonction pour récupérer l'image avec fallback
    Future<String> _getImageUrl() async {
      final urls = [
        "${ApiService.currentBaseUrl}/uploads/$packageName.png",
        "${ApiService.currentFallbackUrl}/uploads/$packageName.png",
      ];

      for (var url in urls) {
        try {
          final response = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 2));
          if (response.statusCode == 200) {
            return url; // URL valide trouvée
          }
        } catch (_) {
          // Ignore et passe au suivant
        }
      }
      return ""; // Aucun URL valide, on utilisera le fallback texte
    }

    return FutureBuilder<String>(
      future: _getImageUrl(),
      builder: (context, snapshot) {
        String imageUrl = snapshot.data ?? "";

        return Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildFallback(name),
                        )
                      : _buildFallback(name),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    onTap: () async {
                      bool deleted = await ApiService.deleteApp(app['id']);
                      if (deleted) _fetchApps();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        );
      },
    );
  }

  // Fallback si l'image n'existe pas
  Widget _buildFallback(String name) {
    return Container(
      height: 100,
      width: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.blueGrey.shade700,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "?",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // --- LOGIQUE POP-UP AJOUTER APP ---
  void _showAddAppDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Installer une application sur le launcher"),
        content: SizedBox(
          width: 500, // Un peu plus large pour voir les noms de packages
          height: 400,
          child: FutureBuilder<List<Application>>(
            future: _getInstalledApps(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text("Aucune application tierce trouvée."),
                );
              }

              final installedApps = snapshot.data!;

              return ListView.builder(
                shrinkWrap: true,
                itemCount: installedApps.length,
                itemBuilder: (context, index) {
                  final app = installedApps[index];

                  // On vérifie si on peut afficher l'icône réelle de l'app
                  Widget leader = const Icon(
                    Icons.android,
                    color: Colors.green,
                  );
                  if (app is ApplicationWithIcon) {
                    leader = Image.memory(app.icon, width: 40);
                  }

                  return ListTile(
                    leading: leader,
                    title: Text(app.appName),
                    subtitle: Text(
                      app.packageName,
                      style: const TextStyle(fontSize: 10),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.blue),
                      onPressed: () async {
                        _showLoadingDialog(
                          "Veuillez patienter pendant que l'app est envoyée au serveur...",
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
                          Navigator.pop(
                            context,
                          ); // Ferme le dialogue de chargement
                          if (success) {
                            Navigator.pop(
                              context,
                            ); // Ferme le dialogue de sélection
                            _fetchApps();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Échec de l'ajout")),
                            );
                          }
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }
}
