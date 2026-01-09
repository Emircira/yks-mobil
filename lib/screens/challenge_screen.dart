import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  final ApiService _api = ApiService();

  // Durum Değişkenleri
  bool _isLoading = false;
  Map<String, dynamic>? _activeChallenge; //
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isTimerRunning = false;

  // 1. YENİ CHALLENGE İSTE (Backend'e bağlanır)
  Future<void> _getChallenge() async {
    setState(() => _isLoading = true);

    final challenge = await _api.createChallenge();

    setState(() {
      _activeChallenge = challenge;
      _isLoading = false;

      _remainingSeconds = (challenge['sure_dk'] ?? 30) * 60;
    });
  }

  // 2. MEYDAN OKUMAYI BAŞLAT
  void _startChallenge() {
    setState(() => _isTimerRunning = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _stopChallenge(basarili: false); // Süre bitti, kaybettin
      }
    });
  }

  // 3. BİTİR veya PES ET
  void _stopChallenge({required bool basarili}) {
    _timer?.cancel();
    setState(() {
      _isTimerRunning = false;
      _activeChallenge = null; // Ekranı sıfırla
    });

    // Sonuç Mesajı
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(basarili ? "TEBRİKLER! 🏆" : "SÜRE BİTTİ ⏳"),
        content: Text(
          basarili
              ? "Bu zorlu görevi başarıyla tamamladın! Harikasın."
              : "Üzülme, bir dahaki sefere daha hızlı olacaksın!",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tamam"),
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade900, // Oyun modu için koyu tema
      appBar: AppBar(
        title: Text(
          "MEYDAN OKUMA",
          style: GoogleFonts.bebasNeue(
            fontSize: 26,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // DURUM1: (AKTİF MOD)
              if (_isTimerRunning) ...[
                const Icon(Icons.timer, size: 80, color: Colors.amberAccent),
                const SizedBox(height: 20),
                Text(
                  "KALAN SÜRE",
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  _formatTime(_remainingSeconds),
                  style: GoogleFonts.bebasNeue(
                    fontSize: 80,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () => _stopChallenge(basarili: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle, size: 30),
                  label: const Text(
                    "GÖREVİ BİTİRDİM!",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ]
              // DURUM 2:
              else if (_activeChallenge != null) ...[
                // GÖREV KARTI
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _activeChallenge!['baslik'] ?? "GÖREV",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.bebasNeue(
                          fontSize: 32,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const Divider(thickness: 2),
                      const SizedBox(height: 15),
                      Text(
                        _activeChallenge!['aciklama'] ?? "Açıklama yok.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.access_time_filled,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "${_activeChallenge!['sure_dk']} Dakika",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 20),
                          const Icon(Icons.star, color: Colors.amber),
                          const SizedBox(width: 8),
                          Text(
                            "${_activeChallenge!['xp_degeri']} XP",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton(
                      onPressed: () => setState(() => _activeChallenge = null),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 15,
                        ),
                      ),
                      child: const Text("REDDET"),
                    ),
                    ElevatedButton(
                      onPressed: _startChallenge,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                      ),
                      child: const Text(
                        "KABUL ET 🔥",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ]
              // DURUM 3: Hiçbir Şey Yoksa
              else ...[
                _isLoading
                    ? const CircularProgressIndicator(color: Colors.amber)
                    : GestureDetector(
                        onTap: _getChallenge,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.deepPurple.shade700,
                            border: Border.all(color: Colors.amber, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.bolt,
                                size: 60,
                                color: Colors.amber,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "BANA MEYDAN\nOKU",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 24,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                const SizedBox(height: 30),
                Text(
                  "Hazır olduğunda butona bas.\nYapay zeka seni zorlayacak bir görev seçecek!",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.white54),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
