import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
// --- SAYFA İMPORTLARI ---
import 'home_screen.dart';
import 'goals_screen.dart';
import 'analysis_screen.dart';
import 'progress_screen.dart';
import 'challenge_screen.dart';
import 'tutor_screen.dart';
import 'vision_screen.dart';
import 'login_screen.dart';
import 'pomodoro_screen.dart'; // ✅ Pomodoro eklendi

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService();

  // Kullanıcı Verileri
  String _name = "Yükleniyor...";
  String _title = "Çaylak"; // Rütbe
  int _xp = 0; // Puan
  double _progress = 0.0; // Seviye Çubuğu (0.0 - 1.0 arası)
  int _streak = 1; // 🔥 ZİNCİR (GÜN) SAYACI

  @override
  void initState() {
    super.initState();
    _bilgileriGetir();
  }

  // Verileri Backend'den Çeken Fonksiyon
  void _bilgileriGetir() async {
    // 1. BİLDİRİM SİSTEMİNİ BAŞLAT
    // Sabah 8 alarmı
    NotificationService().init().then((_) {
      NotificationService().scheduleDailyNotification();
    });

    // 🔥 2. VERİLERİ ÇEK
    try {
      var data = await _api.getProfileData();

      if (mounted) {
        setState(() {
          _name = data['kullanici_adi'] ?? "Öğrenci";
          _title = data['rutbe'] ?? "Çaylak";
          _xp = data['xp'] ?? 0;
          _progress = (data['ilerleme'] ?? 0.0).toDouble();
          _streak = data['streak'] ?? 1; //  Backend'den gelen ateş verisi!
        });
      }
    } catch (e) {
      print("Veri hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "YKS ASİSTAN",
          style: GoogleFonts.bebasNeue(
            fontSize: 26,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        actions: [
          // --- MENÜ ---
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              if (value == 'logout') {
                await _api.logout();
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'logout', child: Text("Çıkış Yap")),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. KİMLİK KARTI (XP, RÜTBE VE ATEŞ)
            FadeInDown(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.deepPurple, Colors.indigoAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // SOL TARAF (AVATAR + İSİM)
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.deepPurple.shade100,
                                child: Text(
                                  _name.isNotEmpty
                                      ? _name[0].toUpperCase()
                                      : "?",
                                  style: GoogleFonts.bebasNeue(
                                      fontSize: 28, color: Colors.deepPurple),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _name.length > 10
                                      ? "${_name.substring(0, 8)}..."
                                      : _name,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _title, // Rütbe (Çaylak vb.)
                                  style: GoogleFonts.bebasNeue(
                                    color: Colors.amberAccent,
                                    fontSize: 18,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // SAĞ TARAF ( ATEŞ SAYAÇ)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.orange.shade800,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.orange.withOpacity(0.5),
                                    blurRadius: 8)
                              ]),
                          child: Row(
                            children: [
                              const Icon(Icons.local_fire_department,
                                  color: Colors.yellow, size: 22),
                              const SizedBox(width: 4),
                              Text(
                                "$_streak Gün",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 15),

                    // XP İLERLEME ÇUBUĞU
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("XP: $_xp",
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                            Text("${(_progress * 100).toInt()}%",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _progress,
                            minHeight: 6,
                            backgroundColor: Colors.black26,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              "KONTROL PANELİ",
              style: GoogleFonts.bebasNeue(
                fontSize: 24,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 10),

            // 2. BUTONLAR MENÜSÜ (IZGARA)
            Expanded(
              child: GridView.count(
                crossAxisCount: 2, // Yan yana 2 buton
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  _buildMenuCard(context, "PLANLARIM", Icons.checklist_rtl,
                      Colors.blueAccent, const HomeScreen()),
                  _buildMenuCard(context, "HEDEFİM", Icons.flag,
                      Colors.orangeAccent, const GoalScreen()),
                  _buildMenuCard(context, "ANALİZ", Icons.insights, Colors.teal,
                      const AnalysisScreen()),
                  _buildMenuCard(context, "GELİŞİM", Icons.trending_up,
                      Colors.purpleAccent, const ProgressScreen()),
                  _buildMenuCard(context, "CHALLENGE", Icons.emoji_events,
                      Colors.redAccent, const ChallengeScreen()),
                  _buildMenuCard(context, "AI HOCAM", Icons.chat_bubble_outline,
                      Colors.indigo, const TutorScreen()),
                  _buildMenuCard(context, "SORU ÇÖZ", Icons.camera_enhance,
                      Colors.pinkAccent, const VisionScreen()),
                  _buildMenuCard(context, "POMODORO", Icons.timer,
                      Colors.deepOrange, const PomodoroScreen()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // BUTON TASARIMI YARDIMCISI
  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget page,
  ) {
    return FadeInUp(
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        ).then((_) => _bilgileriGetir()),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: color),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                style: GoogleFonts.bebasNeue(
                  fontSize: 20,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
