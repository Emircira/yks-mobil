import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'verify_page.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _uniController = TextEditingController();
  final _bolumController = TextEditingController();
  final _netController = TextEditingController();
  final _hedefNetController = TextEditingController();

  bool _isLoading = false;
  final ApiService _api = ApiService();

  void _kayitOl() async {
    // Basit doğrulama: Alanlar boş mu?
    if (_usernameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lütfen zorunlu alanları doldurun."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    String? hata = await _api.register(
      _usernameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _uniController.text.trim(),
      _bolumController.text.trim(),
      double.tryParse(_netController.text) ?? 0,
      double.tryParse(_hedefNetController.text) ?? 0,
    );

    setState(() => _isLoading = false);

    if (hata == null) {
      if (mounted) {
        // --- DEĞİŞİKLİK BURADA ---
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Kod gönderildi! Lütfen mailini kontrol et."),
            backgroundColor: Colors.green,
          ),
        );

        // Giriş sayfasına dönmek yerine, DOĞRULAMA sayfasına yönlendiriyoruz:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyPage(
              email: _emailController.text.trim(), // E-postayı aktarıyoruz
            ),
          ),
        );
        // -------------------------
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(hata), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("KAYIT OL"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.person_add, size: 60, color: Colors.deepPurple),
            const SizedBox(height: 20),
            _buildTextField(_usernameController, "Kullanıcı Adı", Icons.person),
            _buildTextField(_emailController, "E-Posta", Icons.email),
            _buildTextField(
              _passwordController,
              "Şifre",
              Icons.lock,
              isObscure: true,
            ),
            const Divider(),
            const Text(
              "HEDEF BİLGİLERİN",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            _buildTextField(
              _uniController,
              "Hedef Üniversite (Örn: ODTÜ)",
              Icons.school,
            ),
            _buildTextField(
              _bolumController,
              "Hedef Bölüm (Örn: Bilgisayar)",
              Icons.book,
            ),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    _netController,
                    "Şu anki Netin",
                    Icons.show_chart,
                    isNumber: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    _hedefNetController,
                    "Hedef Netin",
                    Icons.flag,
                    isNumber: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _kayitOl,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("KAYDI TAMAMLA"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isObscure = false,
    bool isNumber = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.deepPurple),
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
