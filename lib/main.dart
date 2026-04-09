// lib/main.dart

import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const CollegeMDM());
}

class CollegeMDM extends StatelessWidget {
  const CollegeMDM({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MDM Saint-Exupéry',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Définit la police d'écriture par défaut
        fontFamily: 'DepartementFont',
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
