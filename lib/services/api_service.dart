import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';

class ApiService {
  final String baseUrl = "http://10.0.2.2:8000";
  final Dio _dio = Dio();
  final _storage = const FlutterSecureStorage();

  ApiService() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
  }

  // --- TOKEN VE YETKİLENDİRME ---
  Future<Options> _getAuthOptions() async {
    String? token = await _storage.read(key: 'jwt_token');
    return Options(
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json; charset=UTF-8",
        "Accept": "application/json; charset=UTF-8",
      },
    );
  }

  // ==========================================================
  // 1. OTURUM VE KULLANICI İŞLEMLERİ
  // ==========================================================

  Future<String?> login(String username, String password) async {
    try {
      final response = await _dio.post(
        '/token',
        data: {'username': username, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      if (response.statusCode == 200) {
        await _storage.write(
          key: 'jwt_token',
          value: response.data['access_token'],
        );
        await _storage.write(key: 'username', value: username);
        return null; // Başarılı
      }
      return "Giriş başarısız.";
    } on DioException catch (e) {
      return "Hata: ${e.response?.data['detail'] ?? "Sunucuya ulaşılamadı"}";
    }
  }

  Future<String?> register(
    String username,
    String email,
    String password,
    String uni,
    String bolum,
    double net,
    double hedefNet,
  ) async {
    try {
      await _dio.post(
        '/register',
        data: {
          "username": username,
          "email": email,
          "password": password,
          "targets": {
            "dream_university": uni,
            "dream_department": bolum,
            "current_tyt_net": net,
            "target_tyt_net": hedefNet,
          },
        },
      );
      return null;
    } on DioException catch (e) {
      return e.response?.data['detail'] ?? "Kayıt hatası.";
    }
  }

  Future<bool> deleteAccount() async {
    try {
      final options = await _getAuthOptions();
      await _dio.delete('/hesap-sil', options: options);
      await logout();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async => await _storage.deleteAll();

  Future<bool> isLoggedIn() async {
    String? token = await _storage.read(key: 'jwt_token');
    return token != null;
  }

  // ==========================================================
  // 2. HAFIZA VE YEREL VERİLER
  // ==========================================================

  Future<void> saveUserGoal(
    String siralama,
    String universite,
    String unvan,
  ) async {
    await _storage.write(key: 'user_rank', value: siralama);
    await _storage.write(key: 'user_uni', value: universite);
    await _storage.write(key: 'user_title', value: unvan);
  }

  Future<Map<String, String>> getUserData() async {
    String name = await _storage.read(key: 'username') ?? "Öğrenci";
    String unvan = await _storage.read(key: 'user_title') ?? "Çaylak";
    String rank = await _storage.read(key: 'user_rank') ?? "-";
    String uni = await _storage.read(key: 'user_uni') ?? "Üniversite";
    return {"name": name, "title": unvan, "rank": rank, "uni": uni};
  }

  // ==========================================================
  // 3. YAPAY ZEKA VE PLANLAMA
  // ==========================================================

  Future<Map<String, dynamic>> askAiCoach(
    String siralama,
    String universite,
  ) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post(
        '/ai-koc-analiz',
        data: {'siralama': siralama, 'universite': universite},
        options: options,
      );
      return response.data;
    } catch (e) {
      return {"unvan": "HATA", "mesaj": "Bağlantı kurulamadı."};
    }
  }

  Future<String> askAiTutor(String text) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post(
        '/ai-soru-sor',
        data: {'soru_metni': text},
        options: options,
      );
      return response.data['cevap'];
    } catch (e) {
      return "Hocam şu an meşgul, lütfen biraz sonra tekrar sormayı dene.";
    }
  }

  // Başarılıysa null döner, engellenirse hata mesajı döner.
  Future<String?> createDailyPlan() async {
    try {
      final options = await _getAuthOptions();
      await _dio.post('/plan-olustur', options: options);
      return null; // 200 OK -> Başarılı
    } on DioException catch (e) {
      // Eğer 406 hatası gelirse (Backend'deki engel), mesajı döndür.
      if (e.response?.statusCode == 406) {
        return e.response?.data['detail'] ?? "Önce görevleri tamamla.";
      }
      return "Bir hata oluştu.";
    }
  }

  // ÇÖP KUTUSU İÇİN SİLME FONKSİYONU
  Future<bool> clearTodos() async {
    try {
      final options = await _getAuthOptions();
      await _dio.delete('/gorevleri-temizle', options: options);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==========================================================
  // 4. İSTATİSTİK VE LİSTELEME
  // ==========================================================

  Future<Map<String, dynamic>> getStats() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/istatistikler', options: options);
      return response.data;
    } catch (e) {
      return {};
    }
  }

  Future<List<dynamic>> getChatHistory() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/chat-gecmisi', options: options);
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getTodos() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/gorevler', options: options);
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<bool> toggleTodo(int id) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put('/gorev-yap/$id', options: options);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> createChallenge() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post('/challenge-olustur', options: options);
      return response.data;
    } catch (e) {
      return {
        "baslik": "HATA",
        "aciklama": "Bağlantı kurulamadı.",
        "sure_dk": 0,
        "xp_degeri": 0,
      };
    }
  }

  Future<List<dynamic>> getExamHistory() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/deneme-gecmisi', options: options);
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<bool> deleteExam(int id) async {
    try {
      final options = await _getAuthOptions();
      await _dio.delete('/deneme-sil/$id', options: options);
      return true;
    } catch (e) {
      return false;
    }
  }

  // DENEME GÜNCELLE
  Future<bool> updateExam(
    int id,
    String name,
    double turkce,
    double sosyal,
    double mat,
    double fen,
    double ayt,
  ) async {
    try {
      final options = await _getAuthOptions();
      await _dio.put(
        '/deneme-guncelle/$id',
        data: {
          "exam_name": name,
          "tyt_turkce": turkce,
          "tyt_sosyal": sosyal,
          "tyt_mat": mat,
          "tyt_fen": fen,
          "ayt_net": ayt,
        },
        options: options,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addExam(
    String name,
    double turkce,
    double sosyal,
    double mat,
    double fen,
    double ayt,
  ) async {
    try {
      final options = await _getAuthOptions();
      await _dio.post(
        '/deneme-ekle',
        data: {
          "exam_name": name,
          "tyt_turkce": turkce,
          "tyt_sosyal": sosyal,
          "tyt_mat": mat,
          "tyt_fen": fen,
          "ayt_net": ayt,
        },
        options: options,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String> solvePhotoQuestion(File imageFile) async {
    try {
      final options = await _getAuthOptions();
      String fileName = imageFile.path.split('/').last;

      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '/soru-coz',
        data: formData,
        options: options,
      );
      return response.data['cevap'];
    } catch (e) {
      return "Görsel yüklenirken bir hata oluştu.";
    }
  }

  // Profildeki rütbe ve xp bilgisini çekmek için
  Future<Map<String, dynamic>> getProfileData() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get('/profil', options: options);
      return response.data;
    } catch (e) {
      return {
        "kullanici_adi": "Öğrenci",
        "rutbe": "Çaylak",
        "xp": 0,
        "ilerleme": 0.0,
      };
    }
  }
}
