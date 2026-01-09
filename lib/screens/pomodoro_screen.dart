import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  // AYARLAR (Dakika cinsinden)
  static const int workTime = 25;
  static const int breakTime = 5;

  int _remainingSeconds = workTime * 60;
  bool _isWorkTime = true;
  bool _isRunning = false;
  Timer? _timer;

  // Çember animasyonu için
  double get _progress {
    int total = _isWorkTime ? workTime * 60 : breakTime * 60;
    return _remainingSeconds / total;
  }

  void _startTimer() {
    if (_timer != null) _timer!.cancel();
    setState(() => _isRunning = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
          _isRunning = false;
          _showCompletionDialog();
        }
      });
    });
  }

  void _pauseTimer() {
    if (_timer != null) _timer!.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    if (_timer != null) _timer!.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _isWorkTime ? workTime * 60 : breakTime * 60;
    });
  }

  void _switchMode() {
    _resetTimer();
    setState(() {
      _isWorkTime = !_isWorkTime;
      _remainingSeconds = _isWorkTime ? workTime * 60 : breakTime * 60;
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(_isWorkTime ? "Mola Zamanı! ☕" : "Hadi İşe Dön! 📚"),
        content: Text(
          _isWorkTime
              ? "Harika bir çalışma seansıydı. Şimdi 5 dakika dinlen."
              : "Mola bitti. Yeni bir 25 dakikalık odaklanmaya hazır mısın?",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _switchMode(); // Modu otomatik değiştir
            },
            child: const Text("TAMAM"),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    if (_timer != null) _timer!.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Renk Teması
    Color mainColor = _isWorkTime ? Colors.deepPurple : Colors.green;
    Color bgColor =
        _isWorkTime ? Colors.deepPurple.shade50 : Colors.green.shade50;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "ODAKLANMA MODU",
          style: GoogleFonts.bebasNeue(fontSize: 26, letterSpacing: 2),
        ),
        centerTitle: true,
        backgroundColor: mainColor,
        elevation: 0,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // DURUM METNİ
          Text(
            _isWorkTime ? "ÇALIŞMA VAKTİ" : "MOLA VAKTİ",
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: mainColor,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 40),

          // SAYAÇ DAİRESİ
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 250,
                height: 250,
                child: CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 20,
                  backgroundColor: Colors.grey.shade300,
                  color: mainColor,
                ),
              ),
              Text(
                _formatTime(_remainingSeconds),
                style: GoogleFonts.bebasNeue(
                  fontSize: 80,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 50),

          // KONTROL BUTONLARI
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // BAŞLAT / DURDUR BUTONU
              ElevatedButton(
                onPressed: _isRunning ? _pauseTimer : _startTimer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  _isRunning ? "DURAKLAT" : "BAŞLAT",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // SIFIRLA BUTONU
              IconButton(
                onPressed: _resetTimer,
                icon: const Icon(Icons.refresh),
                iconSize: 40,
                color: Colors.grey[700],
                tooltip: "Sıfırla",
              ),
            ],
          ),
          const SizedBox(height: 20),

          // MOD DEĞİŞTİRME BUTONU
          TextButton(
            onPressed: _switchMode,
            child: Text(
              _isWorkTime ? "Mola Moduna Geç" : "Çalışma Moduna Geç",
              style: TextStyle(color: mainColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
