import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import 'dart:async';

class AdminDevicesScreen extends StatefulWidget {
    const AdminDevicesScreen({super.key});

    @override
    State<AdminDevicesScreen> createState() => _AdminDevicesScreenState();
}

class _AdminDevicesScreenState extends State<AdminDevicesScreen> {
    List<dynamic> devices = [];
    bool isLoading = true;
    Timer? _refreshTimer;

    static const Color _bleu = Color(0xFF003189);
    static const Color _bleuFonce = Color(0xFF001F5C);
    static const Color _fond = Color(0xFFF0F4FF);

    @override
    void initState() {
        super.initState();
        _loadDevices();
        _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadDevices());
    }

    @override
    void dispose() {
        _refreshTimer?.cancel();
        super.dispose();
    }

    Future<void> _loadDevices() async {
        final data = await ApiService.getDevices();
        if (mounted) setState(() { devices = data; isLoading = false; });
    }

    void _showSnack(String msg, Color color) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
            backgroundColor: color,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
        ));
    }

    void _showSendNotifDialog({String? targetDeviceId}) {
        final controller = TextEditingController();
        showDialog(
            context: context,
            builder: (context) => Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Row(children: [
                                Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                        color: _bleu.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.campaign_rounded, color: _bleu, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                    child: Text(
                                        targetDeviceId != null
                                            ? "Notifier : $targetDeviceId"
                                            : "Notifier toutes les tablettes",
                                        style: const TextStyle(
                                            fontFamily: 'DepartementFont',
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0A1628),
                                        ),
                                    ),
                                ),
                            ]),
                            const SizedBox(height: 20),
                            TextField(
                                controller: controller,
                                autofocus: true,
                                maxLines: 3,
                                decoration: InputDecoration(
                                    hintText: "Ex: Rendez vos tablettes maintenant",
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
                            ),
                            const SizedBox(height: 20),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                    ElevatedButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: _fond,
                                            foregroundColor: const Color(0xFF4A5568),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: const Text("Annuler"),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton(
                                        onPressed: () async {
                                            final msg = controller.text.trim();
                                            if (msg.isEmpty) return;
                                            await ApiService.sendNotification(
                                                message: msg,
                                                deviceId: targetDeviceId,
                                            );
                                            Navigator.pop(context);
                                            _showSnack("📢 Notification envoyée !", Colors.green);
                                        },
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: _bleu,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: const Text("Envoyer", style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                ],
                            ),
                        ],
                    ),
                ),
            ),
        );
    }

    @override
    Widget build(BuildContext context) {
        final connectedDevices = devices.where((d) => d['adb_status'] == 'Connected').toList();

        return Scaffold(
            backgroundColor: _fond,
            appBar: AppBar(
                backgroundColor: const Color(0xFF001040),
                foregroundColor: Colors.white,
                title: const Text(
                    "Gestion des tablettes",
                    style: TextStyle(fontFamily: 'DepartementFont', fontWeight: FontWeight.bold),
                ),
                actions: [
                    // Bouton notif globale
                    Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TextButton.icon(
                            onPressed: connectedDevices.isEmpty
                                ? null
                                : () => _showSendNotifDialog(),
                            icon: const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
                            label: Text(
                                "Notifier toutes (${connectedDevices.length})",
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                        ),
                    ),
                    IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: _loadDevices,
                    ),
                ],
            ),
            body: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF003189)))
                : devices.isEmpty
                    ? Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                Icon(Icons.tablet_android_rounded, size: 64, color: _bleu.withOpacity(0.2)),
                                const SizedBox(height: 16),
                                Text("Aucune tablette enregistrée",
                                    style: TextStyle(fontSize: 18, color: _bleuFonce.withOpacity(0.4))),
                            ],
                        ),
                    )
                    : RefreshIndicator(
                        onRefresh: _loadDevices,
                        color: _bleu,
                        child: ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: devices.length,
                            itemBuilder: (context, index) {
                                final device = devices[index];
                                return _buildDeviceCard(device);
                            },
                        ),
                    ),
        );
    }

    Widget _buildDeviceCard(Map<String, dynamic> device) {
        final String deviceId = device['device_id'] ?? '—';
        final String? user = device['assigned_user'];
        final bool isConnected = device['adb_status'] == 'Connected';
        final bool isBlacklisted = device['blacklisted'] == 1;

        return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border(
                    left: BorderSide(
                        width: 4,
                        color: isBlacklisted
                            ? Colors.red
                            : isConnected
                                ? const Color(0xFF10B981)
                                : Colors.grey.shade300,
                    ),
                ),
                boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                    ),
                ],
            ),
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Row(
                            children: [
                                Icon(
                                    Icons.tablet_android_rounded,
                                    color: isConnected ? const Color(0xFF10B981) : Colors.grey,
                                    size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(
                                        deviceId,
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF111827),
                                        ),
                                    ),
                                ),
                                // Badge statut
                                Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: isBlacklisted
                                            ? Colors.red.withOpacity(0.1)
                                            : isConnected
                                                ? const Color(0xFF10B981).withOpacity(0.1)
                                                : Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                        isBlacklisted ? "Bloquée" : isConnected ? "Connectée" : "Hors ligne",
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isBlacklisted
                                                ? Colors.red
                                                : isConnected
                                                    ? const Color(0xFF10B981)
                                                    : Colors.grey,
                                        ),
                                    ),
                                ),
                            ],
                        ),
                        if (user != null) ...[
                            const SizedBox(height: 8),
                            Row(
                                children: [
                                    Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey.shade400),
                                    const SizedBox(width: 6),
                                    Text(user, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                ],
                            ),
                        ],
                        if (isConnected) ...[
                            const SizedBox(height: 14),
                            Row(
                                children: [
                                    // Envoyer notif
                                    Expanded(
                                        child: GestureDetector(
                                            onTap: () => _showSendNotifDialog(targetDeviceId: deviceId),
                                            child: Container(
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                decoration: BoxDecoration(
                                                    color: const Color(0xFF003189).withOpacity(0.08),
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(color: const Color(0xFF003189).withOpacity(0.2)),
                                                ),
                                                child: const Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                        Icon(Icons.campaign_rounded, size: 16, color: Color(0xFF003189)),
                                                        SizedBox(width: 6),
                                                        Text("Notification", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF003189))),
                                                    ],
                                                ),
                                            ),
                                        ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Forcer ouverture launcher
                                    Expanded(
                                        child: GestureDetector(
                                            onTap: () async {
                                                await ApiService.forceOpenLauncher(deviceId);
                                                _showSnack("📱 Ouverture du launcher forcée", const Color(0xFF6C63FF));
                                            },
                                            child: Container(
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                decoration: BoxDecoration(
                                                    color: const Color(0xFF6C63FF).withOpacity(0.08),
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.2)),
                                                ),
                                                child: const Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                        Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFF6C63FF)),
                                                        SizedBox(width: 6),
                                                        Text("Forcer launcher", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6C63FF))),
                                                    ],
                                                ),
                                            ),
                                        ),
                                    ),
                                ],
                            ),
                        ],
                    ],
                ),
            ),
        );
    }
}