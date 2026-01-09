import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();

  List<dynamic> _todos = [];
  String _kocUnvan = "Yükleniyor...";
  String _kocMesaj = "Analiz yapılıyor...";
  bool _isLoading = true;

  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    _sayfayiYukle();
  }

  void _sayfayiYukle() async {
    setState(() => _isLoading = true);
    try {
      final gelenGorevler = await _api.getTodos();
      final userData = await _api.getUserData();
      final analiz = await _api.askAiCoach(
        userData['rank'] ?? "10000",
        userData['uni'] ?? "Üniversite",
      );

      if (mounted) {
        setState(() {
          _todos = gelenGorevler;
          _kocUnvan = analiz['unvan'] ?? "YKS KOÇU";
          _kocMesaj = analiz['mesaj'] ?? "Hedefine odaklan!";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _kocUnvan = "HATA";
          _kocMesaj = "Bağlantı sorunu veya sunucu meşgul.";
        });
      }
    }
  }

  Future<void> _aiPlanOlustur() async {
    setState(() => _isLoading = true);

    final hataMesaji = await _api.createDailyPlan();

    if (mounted) {
      if (hataMesaji == null) {
        _sayfayiYukle();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Yapay zeka yeni planını hazırladı! 🚀"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hataMesaji),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _listeyiTemizle() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Temizlik Zamanı"),
        content: const Text(
          "Sadece tamamladığın (üstünü çizdiğin) görevler silinecek. Yapmadıkların listede kalacak. Onaylıyor musun?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);

              bool basarili = await _api.clearTodos();

              if (mounted) {
                if (basarili) {
                  _sayfayiYukle();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("🧹 Tamamlanan görevler temizlendi!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Hata oluştu. Sunucuyu kontrol et."),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              "TEMİZLE",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _gorevTamamla(int id, bool suankiDurum) async {
    setState(() {
      final index = _todos.indexWhere((gorev) => gorev['id'] == id);
      if (index != -1) _todos[index]['is_completed'] = !suankiDurum;
    });
    await _api.toggleTodo(id);
  }

  void _cikisYap() async {
    await _api.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _anaMenuyeDon() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: _anaMenuyeDon,
        ),
        title: Text(
          "PLANLARIM",
          style: GoogleFonts.bebasNeue(
            letterSpacing: 2,
            fontSize: 28,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _listeyiTemizle,
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            tooltip: "Tamamlananları Temizle",
          ),
          IconButton(
            onPressed: _cikisYap,
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.shade700,
                  Colors.deepPurple.shade400,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _kocUnvan.toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _kocMesaj,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _todos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_add,
                              size: 50,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Listen boş. Yapay zeka plan oluştursun!",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _todos.length,
                        itemBuilder: (context, index) {
                          final gorev = _todos[index];
                          final yapildi = gorev['is_completed'] ?? false;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            color:
                                yapildi ? Colors.grey.shade200 : Colors.white,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: ListTile(
                                leading: Checkbox(
                                  value: yapildi,
                                  activeColor: Colors.green,
                                  onChanged: (val) =>
                                      _gorevTamamla(gorev['id'], yapildi),
                                ),
                                title: Text(
                                  gorev['content']
                                      .toString()
                                      .replaceAll("**", ""),
                                  style: TextStyle(
                                    decoration: yapildi
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color:
                                        yapildi ? Colors.grey : Colors.black87,
                                    fontWeight: yapildi
                                        ? FontWeight.normal
                                        : FontWeight.w500,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                  softWrap: true,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _aiPlanOlustur,
        backgroundColor:
            (_todos.isNotEmpty && _todos.any((t) => t['is_completed'] == false))
                ? Colors.grey
                : Colors.deepPurple,
        icon: const Icon(Icons.auto_awesome, color: Colors.white),
        label: Text(
          _isLoading ? "Bekleniyor..." : "AI Planı Oluştur",
          style: const TextStyle(color: Colors.white),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 0) {
            _anaMenuyeDon();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "Ana Menü",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "Planım"),
        ],
      ),
    );
  }
}
