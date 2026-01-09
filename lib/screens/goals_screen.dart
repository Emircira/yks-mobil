import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});
  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  final TextEditingController _siralamaController = TextEditingController();
  final TextEditingController _universiteController = TextEditingController();
  bool _isAnalyzing = false;
  final ApiService _api = ApiService();

  void _analizEt() async {
    if (_siralamaController.text.isEmpty) return;
    setState(() => _isAnalyzing = true);

    final sonuc = await _api.askAiCoach(
      _siralamaController.text,
      _universiteController.text,
    );
    await _api.saveUserGoal(
      _siralamaController.text,
      _universiteController.text,
      sonuc['unvan'],
    );

    setState(() => _isAnalyzing = false);
    _dialogGoster(sonuc['unvan'], sonuc['mesaj']);
  }

  void _dialogGoster(String unvan, String mesaj) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.deepPurple.shade900,
        title: Text(
          unvan,
          style: GoogleFonts.bebasNeue(color: Colors.amber, fontSize: 28),
        ),
        content: Text(mesaj, style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            ),
            child: const Text(
              "GÖREVİ BAŞLAT 🚀",
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: _isAnalyzing
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "HEDEFİNİ BELİRLE",
                    style: GoogleFonts.bebasNeue(
                      fontSize: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _siralamaController,
                    decoration: const InputDecoration(
                      labelText: "Hedef Sıralama",
                      labelStyle: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _universiteController,
                    decoration: const InputDecoration(
                      labelText: "Üniversite",
                      labelStyle: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _analizEt,
                    child: const Text("ANALİZ ET & BAŞLA ✨"),
                  ),
                ],
              ),
            ),
    );
  }
}
