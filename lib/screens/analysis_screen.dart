import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  String _uni = "...";
  String _bolum = "...";
  double _mevcutNet = 0;
  double _hedefNet = 100;
  int _yuzde = 0;

  @override
  void initState() {
    super.initState();
    _verileriCek();
  }

  // YKS Geri Sayım Hesaplayıcı (21 Haziran 2026 Varsayıldı)
  int _gunleriHesapla() {
    DateTime yksTarihi = DateTime(2026, 6, 21);
    int gunFarki = yksTarihi.difference(DateTime.now()).inDays;
    return gunFarki > 0 ? gunFarki : 0;
  }

  Future<void> _verileriCek() async {
    //  istatistik endpoint'inden verileri çekiyoruz
    final data = await _api.getStats();

    if (mounted) {
      setState(() {
        _uni = data['hedef_uni'] ?? "Üniversite";
        _bolum = data['hedef_bolum'] ?? "Bölüm";
        _mevcutNet = (data['mevcut_tyt'] ?? 0).toDouble();
        _hedefNet = (data['hedef_tyt'] ?? 100).toDouble();
        _yuzde = data['basari_orani'] ?? 0;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double ilerleme = (_mevcutNet / _hedefNet).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "HEDEF ANALİZİ",
          style: GoogleFonts.bebasNeue(
            fontSize: 26,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.teal,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : RefreshIndicator(
              onRefresh: _verileriCek,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    //  YKS GERİ SAYIM SAYACI
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.amber.shade700,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            color: Colors.amber.shade800,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              Text(
                                "YKS'YE ${_gunleriHesapla()} GÜN KALDI",
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 22,
                                  color: Colors.amber.shade900,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                "Vakit Daralıyor, Odaklan!",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // HEDEF KARTI
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.teal.shade700, Colors.teal.shade400],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.teal.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            "HEDEFİN",
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _uni,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            _bolum,
                            style: GoogleFonts.poppins(
                              color: Colors.amberAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // NET KARŞILAŞTIRMA
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNetCircle(
                          "MEVCUT",
                          _mevcutNet.toStringAsFixed(1),
                          Colors.orange,
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                        _buildNetCircle(
                          "HEDEF",
                          _hedefNet.toStringAsFixed(1),
                          Colors.green,
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // İLERLEME ÇUBUĞU
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Başarı Oranı",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              "%$_yuzde",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: ilerleme,
                            minHeight: 15,
                            backgroundColor: Colors.grey[300],
                            color: _yuzde < 50 ? Colors.orange : Colors.green,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _yuzde < 100
                              ? "Hedefine ulaşmak için ${(_hedefNet - _mevcutNet).toStringAsFixed(1)} net daha yapmalısın!"
                              : "Tebrikler! Hedef netine ulaştın! 🚀",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // MOTİVASYON KARTI
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lightbulb,
                            color: Colors.amber,
                            size: 30,
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Text(
                              _yuzde < 50
                                  ? "Henüz yolun başındayız. Temel konulara odaklanarak netlerini hızla artırabilirsin."
                                  : "Harika gidiyorsun! Deneme sıklığını artırarak hatalarını minimize et.",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[800],
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
    );
  }

  Widget _buildNetCircle(String title, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
            color: color.withOpacity(0.1),
          ),
          child: Text(
            value,
            style: GoogleFonts.bebasNeue(fontSize: 28, color: color),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
