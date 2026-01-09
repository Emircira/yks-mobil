import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _exams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final data = await _api.getExamHistory();
    if (mounted) {
      setState(() {
        _exams = data;
        _isLoading = false;
      });
    }
  }

  void _deleteExam(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Silinsin mi?"),
        content: const Text("Bu deneme kalıcı olarak silinecek."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              await _api.deleteExam(id);
              _loadHistory();
            },
            child: const Text("SİL", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showExamDialog({Map<String, dynamic>? existingExam}) {
    final nameController = TextEditingController(
      text: existingExam?['exam_name'] ?? '',
    );

    // Ders Netleri (Varsa getir, yoksa boş)
    final turkceController = TextEditingController(
      text: existingExam?['tyt_turkce']?.toString() ?? '',
    );
    final sosyalController = TextEditingController(
      text: existingExam?['tyt_sosyal']?.toString() ?? '',
    );
    final matController = TextEditingController(
      text: existingExam?['tyt_mat']?.toString() ?? '',
    );
    final fenController = TextEditingController(
      text: existingExam?['tyt_fen']?.toString() ?? '',
    );
    final aytController = TextEditingController(
      text: existingExam?['ayt_net']?.toString() ?? '',
    );

    bool isEditing = existingExam != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isEditing ? "Denemeyi Düzenle" : "Yeni Deneme Ekle",
          style: GoogleFonts.bebasNeue(fontSize: 24),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Deneme Adı (Örn: 3D Yayınları)",
                  prefixIcon: Icon(Icons.edit_note),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                "TYT DETAYLARI",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 10),

              // İKİLİ SIRA: TÜRKÇE - SOSYAL
              Row(
                children: [
                  Expanded(child: _miniInput(turkceController, "Türkçe (40)")),
                  const SizedBox(width: 10),
                  Expanded(child: _miniInput(sosyalController, "Sosyal (20)")),
                ],
              ),
              const SizedBox(height: 10),
              // İKİLİ SIRA: MAT - FEN
              Row(
                children: [
                  Expanded(child: _miniInput(matController, "Mat (40)")),
                  const SizedBox(width: 10),
                  Expanded(child: _miniInput(fenController, "Fen (20)")),
                ],
              ),

              const Divider(height: 30),
              const Text(
                "AYT TOPLAM",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: aytController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "AYT Toplam Net (Max: 80)",
                  prefixIcon: Icon(Icons.school),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              double tr = double.tryParse(turkceController.text) ?? 0;
              double sos = double.tryParse(sosyalController.text) ?? 0;
              double mat = double.tryParse(matController.text) ?? 0;
              double fen = double.tryParse(fenController.text) ?? 0;
              double ayt = double.tryParse(aytController.text) ?? 0;

              // Basit Kontrol
              if (tr > 40 || sos > 20 || mat > 40 || fen > 20 || ayt > 80) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "⚠️ Hatalı Net Girişi! Soru sayılarını aştın.",
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              setState(() => _isLoading = true);

              if (isEditing) {
                await _api.updateExam(
                  existingExam['id'],
                  nameController.text,
                  tr,
                  sos,
                  mat,
                  fen,
                  ayt,
                );
              } else {
                await _api.addExam(nameController.text, tr, sos, mat, fen, ayt);
              }
              _loadHistory();
            },
            child: const Text("Kaydet", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _miniInput(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "GELİŞİM RAPORU",
          style: GoogleFonts.bebasNeue(fontSize: 26, letterSpacing: 2),
        ),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _exams.isEmpty
              ? Center(
                  child: Text(
                    "Henüz deneme yok. Ekle!",
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _exams.length,
                  itemBuilder: (context, index) {
                    final reversedIndex = _exams.length - 1 - index;
                    final exam = _exams[reversedIndex];

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // BAŞLIK VE TARİH
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    exam['exam_name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.teal.shade200),
                                  ),
                                  child: Text(
                                    "TYT: ${exam['tyt_net']} | AYT: ${exam['ayt_net']}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            // DETAYLAR
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _statItem(
                                  "Türkçe",
                                  "${exam['tyt_turkce']}",
                                  Colors.orange,
                                ),
                                _statItem(
                                  "Sosyal",
                                  "${exam['tyt_sosyal']}",
                                  Colors.purple,
                                ),
                                _statItem(
                                    "Mat", "${exam['tyt_mat']}", Colors.blue),
                                _statItem(
                                  "Fen",
                                  "${exam['tyt_fen']}",
                                  Colors.green,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            //  ALT BUTONLAR (KOÇ YORUMU VE MENÜ)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // 🧠 KOÇ YORUMU BUTONU
                                TextButton.icon(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                        ),
                                        title: Row(
                                          children: const [
                                            Icon(
                                              Icons.psychology,
                                              color: Colors.deepPurple,
                                            ),
                                            SizedBox(width: 10),
                                            Text("AI Koç Yorumu"),
                                          ],
                                        ),
                                        content: Text(
                                          exam['ai_comment'] ??
                                              "Bu deneme için analiz bulunamadı.",
                                          style:
                                              GoogleFonts.poppins(fontSize: 15),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text("Tamam"),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.analytics_outlined,
                                    size: 20,
                                    color: Colors.deepPurple,
                                  ),
                                  label: const Text(
                                    "Koç Yorumu",
                                    style: TextStyle(
                                      color: Colors.deepPurple,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.deepPurple.shade50,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),

                                // DÜZENLEME MENÜSÜ
                                PopupMenuButton<String>(
                                  child: const Icon(
                                    Icons.more_vert,
                                    color: Colors.grey,
                                  ),
                                  onSelected: (val) => val == 'edit'
                                      ? _showExamDialog(existingExam: exam)
                                      : _deleteExam(exam['id']),
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text("Düzenle"),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        "Sil",
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExamDialog(),
        label: const Text("Yeni Deneme", style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.teal,
      ),
    );
  }

  Widget _statItem(String label, String val, Color color) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
