// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart'; // Import du service
import '../services/app_lock_service.dart';
import 'student_home.dart';
import 'admin_home.dart';
import '../services/device_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Au login, aucune app n'est autorisée
    AppLockService.start([]);
    _checkLockPermission();
  }

  Future<void> _checkLockPermission() async {
    await AppLockService.checkAndRequestPermission(context);
  }

  void _launchLoginProcess() async {
    final deviceId = await DeviceService.getDeviceId() ?? "NON-CONFIGURE";

    // Avertissement si pas configuré, mais on bloque pas l'admin
    if (deviceId == "NON-CONFIGURE") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "⚠️ Tablette non configurée. Connectez-vous en admin pour l'identifier.",
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final response = await ApiService.login(
      _userController.text.trim(),
      _passwordController.text,
      deviceId,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (response['success'] == true) {
      String role = response['role'];
      String displayName = response['displayName'];
      String details = response['details'] ?? "";

      // Si pas configuré et que c'est un élève, on bloque
      if (deviceId == "NON-CONFIGURE" && role != 'ADMIN') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "❌ Cette tablette doit être configurée par un administrateur avant utilisation.",
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      if (role == 'ADMIN') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminHome(userName: displayName),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                StudentHome(displayName: displayName, classe: details),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/login_background.png',
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 100),
                    Container(
                      width: 500,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Connectez vous avec votre compte",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const Divider(
                            thickness: 1,
                            indent: 50,
                            endIndent: 50,
                          ),
                          const SizedBox(height: 30),
                          _buildInputField(
                            "Identifiant",
                            _userController,
                            false,
                          ),
                          const SizedBox(height: 20),
                          _buildInputField(
                            "Mot de passe",
                            _passwordController,
                            true,
                          ),
                          const SizedBox(height: 40),
                          ElevatedButton(
                            onPressed: _showWarningDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 50,
                                vertical: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              "Se connecter",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWarningDialog() {
    if (_userController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Champs vides !")));
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Avertissement de sécurité"),
        content: const Text(
          "En vous connectant, vous acceptez que toutes les actions effectuées sur cette tablette soient enregistrées et rattachées à votre compte personnel.\n\nSouhaitez-vous continuer ?",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _launchLoginProcess();
            },
            child: const Text("Continuer"),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    bool isPassword,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
