import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class TutorScreen extends StatefulWidget {
  const TutorScreen({super.key});

  @override
  State<TutorScreen> createState() => _TutorScreenState();
}

class _TutorScreenState extends State<TutorScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, String>> _messages = [
    {
      "sender": "ai",
      "text":
          "Merhaba! Ben YKS Asistanın. Hedefine giden yolda seviyeni belirlemek veya strateji değiştirmek istersen aşağıdaki butonları kullanabilirsin! 👇",
    },
  ];

  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _gecmisiYukle();
  }

  void _gecmisiYukle() async {
    final history = await _api.getChatHistory();
    if (history.isNotEmpty) {
      List<Map<String, String>> loadedMessages = [];
      for (var item in history) {
        loadedMessages.add({
          "sender": "user",
          "text": item['user_question'].toString(),
        });
        loadedMessages.add({
          "sender": "ai",
          "text": item['ai_response'].toString(),
        });
      }
      if (mounted) {
        setState(() => _messages = loadedMessages);
        _scrollToBottom();
      }
    }
  }

  void _sendMessage({String? customMessage}) async {
    String userText = customMessage ?? _controller.text.trim();
    if (userText.isEmpty) return;

    setState(() {
      _messages.add({"sender": "user", "text": userText});
      _isTyping = true;
      if (customMessage == null) _controller.clear();
    });

    _scrollToBottom();

    String aiResponse = await _api.askAiTutor(userText);

    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add({"sender": "ai", "text": aiResponse});
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Aksiyon Baloncukları Tasarımı
  Widget _buildActionChip(
    String label,
    String message,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: color),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        onPressed: () => _sendMessage(customMessage: message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "AI HOCAM",
          style: GoogleFonts.bebasNeue(
            fontSize: 26,
            letterSpacing: 1,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.indigoAccent,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == "user";
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.indigoAccent : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(15),
                        topRight: const Radius.circular(15),
                        bottomLeft:
                            isUser ? const Radius.circular(15) : Radius.zero,
                        bottomRight:
                            isUser ? Radius.zero : const Radius.circular(15),
                      ),
                    ),
                    child: Text(
                      msg['text']!,
                      style: GoogleFonts.poppins(
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isTyping)
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Hoca yazıyor...",
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),

          //Hızlı Eylem Baloncukları (Keyboard üstü)
          Container(
            height: 50,
            color: Colors.transparent,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildActionChip(
                  "🚀 Vites Yükselt",
                  "Hocam, seviyemi yükseltelim. Artık daha zor konulara geçmek istiyorum.",
                  Icons.trending_up,
                  Colors.orange,
                ),
                _buildActionChip(
                  "👶 Sıfırdan Başla",
                  "Hocam temelim zayıf, her şeye en baştan, en temelden başlamak istiyorum.",
                  Icons.baby_changing_station,
                  Colors.blue,
                ),
                _buildActionChip(
                  "🔥 Motivasyon",
                  "Hocam moralim bozuk, beni biraz gaza getir!",
                  Icons.local_fire_department,
                  Colors.red,
                ),
                _buildActionChip(
                  "🎯 Hedef Analizi",
                  "Son durumuma göre hedefime ne kadar yakınım? Yorumlar mısın?",
                  Icons.analytics,
                  Colors.teal,
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: "Sorunu yaz...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: Colors.indigoAccent,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () => _sendMessage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
