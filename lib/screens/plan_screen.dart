import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../services/api_service.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _todos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _mevcutGorevleriGetir();
  }

  Future<void> _mevcutGorevleriGetir() async {
    setState(() => _isLoading = true);
    final list = await _api.getTodos();
    if (mounted) {
      setState(() {
        _todos = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _gorevDurumunuDegistir(int id) async {
    bool success = await _api.toggleTodo(id);
    if (success) {
      setState(() {
        final index = _todos.indexWhere((t) => t['id'] == id);
        if (index != -1) {
          _todos[index]['is_completed'] = !_todos[index]['is_completed'];
        }
      });
    }
  }

  // 🔥 YENİ PLAN OLUŞTURMA (SIKI KONTROLLÜ)
  Future<void> _yeniPlanOlustur() async {
    setState(() => _isLoading = true);

    // Backend'den ya null (başarılı) ya da hata mesajı (string) döner
    String? hataMesaji = await _api.createDailyPlan();

    if (mounted) {
      setState(() => _isLoading = false);

      if (hataMesaji == null) {
        // BAŞARILI
        _mevcutGorevleriGetir();
        _ozelMesajGoster("Yeni planın hazır! Saldır! 🚀", Colors.green);
      } else {
        // ENGELLENDİ (Görevler bitmemiş)
        _ozelMesajGoster(hataMesaji, Colors.redAccent);
      }
    }
  }

  // 🔥 LİSTEYİ TEMİZLEME BUTONU
  void _listeyiTemizle() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Listeyi Sıfırla?"),
        content: const Text(
          "Bütün görevlerin silinecek. Tertemiz bir sayfa açılacak.",
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
                  _mevcutGorevleriGetir(); // Listeyi yenile
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("🗑️ Liste tertemiz oldu!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "⚠️ Hata: Sunucuya bağlanılamadı. Terminali kontrol et!",
                      ),
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

  void _ozelMesajGoster(String mesaj, Color renk) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              renk == Colors.green ? Icons.check_circle : Icons.lock,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mesaj,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: renk,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tamamlanmış görev sayısı
    int tamamlanan = _todos.where((t) => t['is_completed'] == true).length;
    double oran = _todos.isEmpty ? 0 : tamamlanan / _todos.length;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "ÇALIŞMA PLANIM",
          style: GoogleFonts.bebasNeue(
            fontSize: 26,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        actions: [
          // ÇÖP KUTUSU İKONU (Sıfırlamak için)
          IconButton(
            onPressed: _listeyiTemizle,
            icon: const Icon(Icons.delete_sweep, color: Colors.white70),
            tooltip: "Listeyi Temizle",
          ),
        ],
      ),
      body: Column(
        children: [
          // İLERLEME ÇUBUĞU
          if (_todos.isNotEmpty)
            LinearProgressIndicator(
              value: oran,
              backgroundColor: Colors.deepPurple.shade100,
              color: Colors.greenAccent.shade400,
              minHeight: 6,
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
                              Icons.checklist,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Listen boş. AI sana plan yapsın!",
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _todos.length,
                        itemBuilder: (context, index) {
                          final item = _todos[index];
                          bool isDone = item['is_completed'] ?? false;

                          return FadeInUp(
                            duration: const Duration(milliseconds: 300),
                            child: Card(
                              color:
                                  isDone ? Colors.grey.shade200 : Colors.white,
                              elevation: isDone ? 0 : 2,
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: isDone
                                    ? BorderSide.none
                                    : BorderSide(
                                        color:
                                            Colors.deepPurple.withOpacity(0.1),
                                      ),
                              ),
                              child: ListTile(
                                leading: GestureDetector(
                                  onTap: () =>
                                      _gorevDurumunuDegistir(item['id']),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDone
                                          ? Colors.green
                                          : Colors.transparent,
                                      border: Border.all(
                                        color:
                                            isDone ? Colors.green : Colors.grey,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      size: 16,
                                      color: isDone
                                          ? Colors.white
                                          : Colors.transparent,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  item['content']
                                      .toString()
                                      .replaceAll("**", ""),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color:
                                        isDone ? Colors.grey : Colors.black87,
                                    fontWeight: isDone
                                        ? FontWeight.normal
                                        : FontWeight.w500,
                                  ),
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
        onPressed: _isLoading ? null : _yeniPlanOlustur,
        backgroundColor: _todos.every((t) => t['is_completed'] == true) ||
                _todos.isEmpty
            ? Colors.deepPurple
            : Colors
                .grey, // Görevler bitmediyse buton gri görünsün (Görsel ipucu)
        icon: const Icon(Icons.auto_awesome, color: Colors.white),
        label: Text(
          "AI Planı Oluştur",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
