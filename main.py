import os
import io
import sys
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.header import Header 
import random
import json
from datetime import datetime, timedelta, date 
from typing import Optional
from io import BytesIO
import asyncio
import traceback
import time 
import hashlib # ✅ GÜVENLİK İÇİN EKLENDİ

# Konsol çıktı ayarı
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from contextlib import asynccontextmanager
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from fastapi import FastAPI, Depends, HTTPException, status, UploadFile, File, Request, Form
from fastapi.responses import JSONResponse
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel 
from sqlalchemy.orm import Session
from passlib.context import CryptContext
from jose import JWTError, jwt
from dotenv import load_dotenv
from PIL import Image 
import google.generativeai as genai 

# Importlar (Düzeltilmiş hali)
import models as models, schemas as schemas
from database import SessionLocal, engine, Base

load_dotenv()

# --- AYARLAR ---
SECRET_KEY = os.getenv("SECRET_KEY")
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7 
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")
MAIL_USERNAME = os.getenv("MAIL_USERNAME")
MAIL_PASSWORD = os.getenv("MAIL_PASSWORD")

MODEL_NAME = "gemini-2.0-flash"

# --- AI BAŞLATMA ---
if GOOGLE_API_KEY:
    try:
        genai.configure(api_key=GOOGLE_API_KEY)
        print(f"✅ Google AI Bağlantısı Başarılı ({MODEL_NAME})")
    except Exception as e:
        print(f"🚨 API Başlatma Hatası: {e}")

Base.metadata.create_all(bind=engine)

# --- YARDIMCI FONKSİYONLAR ---

def calculate_level(xp):
    if xp < 150: return "Çaylak", xp/150
    if xp < 500: return "Çırak", (xp-150)/350
    if xp < 1500: return "Kalfa", (xp-500)/1000
    if xp < 3000: return "Usta", (xp-1500)/1500
    return "YKS LORDU", 1.0

# ✅ GÜVENLİK FONKSİYONU: Şifre Normalizasyonu
# Bcrypt'in 72 byte limitini aşmamak için şifreyi önce SHA-256 ile hashler.
def normalize_password(password: str) -> str:
    return hashlib.sha256(password.encode("utf-8")).hexdigest()

# --- Pydantic MODELLERİ ---
class VerifyRequest(BaseModel):
    email: str
    code: str

class ResendCodeRequest(BaseModel):
    email: str

class AiGoalRequest(BaseModel):
    siralama: str
    universite: str

class SoruIstegi(BaseModel):
    soru_metni: str

scheduler = AsyncIOScheduler()

#  MAIL FONKSİYONU 
def send_email_func(to_email, subject, body):
    if not MAIL_USERNAME or not MAIL_PASSWORD:
        print("❌ MAIL AYARLARI EKSİK! .env dosyasını kontrol et.")
        return False 

    try:
        msg = MIMEMultipart()
        msg['From'] = f"YKS Asistan <{MAIL_USERNAME}>"
        msg['To'] = to_email
        msg['Subject'] = Header(subject, 'utf-8') 
        msg.attach(MIMEText(body, 'plain', 'utf-8')) 
        
        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.ehlo()
        server.starttls() 
        server.login(MAIL_USERNAME, MAIL_PASSWORD)
        server.sendmail(MAIL_USERNAME, to_email, msg.as_string())
        server.quit()
        print(f"✅ Mail başarıyla gönderildi: {to_email}")
        return True

    except smtplib.SMTPAuthenticationError:
        print("🚨 GİRİŞ HATASI: Kullanıcı adı veya Uygulama Şifresi yanlış! .env dosyasını kontrol et.")
        return False
    except Exception as e:
        print(f"🚨 BEKLENMEYEN MAIL HATASI: {str(e)}")
        return False

@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    if scheduler.running:
        scheduler.shutdown()

app = FastAPI(lifespan=lifespan)

# --- VERİTABANI BAĞLANTISI ---
def get_db():
    db = SessionLocal()
    try: yield db
    finally: db.close()

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None: raise HTTPException(status_code=401)
    except JWTError: raise HTTPException(status_code=401)
    
    user = db.query(models.User).filter(models.User.username == username).first()
    if user is None: raise HTTPException(status_code=401)
    return user

# ==========================================
#  ENDPOINTLER
# ==========================================

@app.post("/register")
def register_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    # 1. Kullanıcı Kontrolü
    existing = db.query(models.User).filter((models.User.email == user.email) | (models.User.username == user.username)).first()
    if existing: raise HTTPException(status_code=400, detail="Kullanıcı zaten var.")
    
    # ✅ GÜVENLİ HASHLEME (SHA-256 -> BCRYPT)
    normalized_pw = normalize_password(user.password)
    hashed_pw = pwd_context.hash(normalized_pw)

    code = str(random.randint(100000, 999999))
    
    db_user = models.User(username=user.username, email=user.email, hashed_password=hashed_pw, is_active=False, verification_code=code)
    db.add(db_user)
    
    if user.targets:
        db.add(models.UserTarget(
            user_id=db_user.id, 
            dream_university=user.targets.dream_university, 
            dream_department=user.targets.dream_department, 
            current_tyt_net=user.targets.current_tyt_net, 
            target_tyt_net=user.targets.target_tyt_net
        ))
    
    db.commit()
    db.refresh(db_user)
    
    # Mail Gönderimi (Hata Toleranslı)
    try:
        mail_durumu = send_email_func(user.email, "Doğrulama Kodu", f"Kodun: {code}")
        if not mail_durumu:
            print("⚠️ Uyarı: Kullanıcı oluştu ama mail gidemedi.")
    except Exception as e:
        print(f"Mail kritik hata: {e}")

    return {"durum": "basarili", "mesaj": "Kayıt alındı. Kod mail adresine gönderildi."}

@app.post("/verify")
def verify_email(req: VerifyRequest, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == req.email).first()
    if not user: raise HTTPException(status_code=404)
    if user.verification_code == req.code:
        user.is_active = True
        user.verification_code = None
        db.commit()
        return {"durum": "basarili", "mesaj": "Doğrulandı."}
    raise HTTPException(status_code=400, detail="Hatalı kod.")

@app.post("/token")
def login(form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.username == form.username).first()
    if not user:
        raise HTTPException(status_code=401, detail="Hatalı giriş.")
    
    # ✅ GİRİŞTE DE AYNI NORMALİZASYON
    normalized_input = normalize_password(form.password)
    
    if not pwd_context.verify(normalized_input, user.hashed_password):
        raise HTTPException(status_code=401, detail="Hatalı giriş.")
        
    if not user.is_active: raise HTTPException(status_code=403, detail="Onaylanmamış hesap.")
    return {"access_token": create_access_token({"sub": user.username}), "token_type": "bearer"}

@app.delete("/hesap-sil")
def delete_account(user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        db.query(models.Todo).filter(models.Todo.user_id == user.id).delete()
        db.query(models.ExamResult).filter(models.ExamResult.user_id == user.id).delete()
        db.query(models.UserTarget).filter(models.UserTarget.user_id == user.id).delete()
        db.query(models.ChatMessage).filter(models.ChatMessage.user_id == user.id).delete()
        
        db.delete(user)
        db.commit()
        return {"mesaj": "Hesap silindi."}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/profil")
def get_profile(user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    bugun = date.today()
    dun = bugun - timedelta(days=1)
    
    if user.last_active_date != bugun:
        if user.last_active_date == dun:
            user.streak += 1 
        else:
            user.streak = 1 
        
        user.last_active_date = bugun
        db.commit()
    
    rutbe, ilerleme = calculate_level(user.xp)
    
    target = user.target
    bilgi = "Belirsiz"
    if target:
        ranking = getattr(target, 'ranking', None)
        dept = getattr(target, 'dream_department', None)
        if dept: bilgi = dept
        elif ranking: bilgi = f"Hedef: {ranking}"
            
    return {
        "kullanici_adi": user.username,
        "hedef_bolum": bilgi,
        "xp": user.xp,
        "rutbe": rutbe,
        "ilerleme": ilerleme,
        "streak": user.streak
    }

@app.get("/gorevler")
def get_todos(user: models.User = Depends(get_current_user)):
    return user.todos

@app.put("/gorev-yap/{todo_id}")
def toggle_todo(todo_id: int, db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    todo = db.query(models.Todo).filter(models.Todo.id == todo_id, models.Todo.user_id == user.id).first()
    if todo:
        todo.is_completed = not todo.is_completed
        if todo.is_completed:
            user.xp += 10 
        else:
            user.xp -= 10 
        db.commit()
    return {"mesaj": "Ok", "yeni_xp": user.xp}

@app.delete("/gorevleri-temizle")
def clear_todos(db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    count = db.query(models.Todo).filter(
        models.Todo.user_id == user.id, 
        models.Todo.is_completed == True
    ).delete()
    db.commit()
    return {"mesaj": f"{count} tamamlanmış görev temizlendi!"}





@app.post("/ai-soru-sor")
def ask_tutor(req: SoruIstegi, db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    try:
        if not GOOGLE_API_KEY: return {"cevap": "Bağlantı yok."}

        target = user.target
        profil_ozeti = f"""
        İsim: {user.username}
        Hedef: {target.ranking if target else 'İlk 10.000'}
        """

        
        system_instruction = f"""
        Sen YKS Koçusun. Bilgiler: {profil_ozeti}.
        
        TARZIN:
        1. Öğrenciyi soru yağmuruna tutma. Sadece sorusuna odaklan.
        2. Kısa, net ve çözüm odaklı ol.
        3. Motivasyon ver ama boş yapma.
        
        ÖNEMLİ - GÖREV SİSTEMİ:
        Eğer cevabında öğrenciye "Şunu çalış, bunu çöz" dersen, cümlenin EN SONUNA şu kodu ekle:
        GOREV_EKLE: <Buraya Yapılacak İşi 3-4 Kelimeyle Yaz>
        
        Örnek Cevap:
        "Türevde zorlanman normal, bol soru çözmelisin.
        GOREV_EKLE: Türev Çözümlü Video İzle"
        """
        
        full_prompt = f"{system_instruction}\n\nÖğrenci Sorusu: {req.soru_metni}"
        
        model = genai.GenerativeModel(MODEL_NAME)
        response = model.generate_content(full_prompt)
        final_answer = response.text

        
        ai_reply_to_show = final_answer
        
        
        if "GOREV_EKLE:" in final_answer:
            parts = final_answer.split("GOREV_EKLE:")
            ai_reply_to_show = parts[0].strip() # Kullanıcıya sadece sohbeti göster
            
            raw_task = parts[1].strip()
            clean_task = raw_task.replace("*", "").replace("-", "").replace(".", "").strip()
            
            # Veritabanına (Planlarım Listesine) Ekle
            try:
                
                new_todo = models.Todo(user_id=user.id, content=f"🤖 Hoca: {clean_task}")
                db.add(new_todo)
                db.commit()
            except:
                db.rollback()

        db.add(models.ChatMessage(user_id=user.id, user_question=req.soru_metni, ai_response=ai_reply_to_show))
        db.commit()

        return {"cevap": ai_reply_to_show}
    except Exception as e:
        print(f"AI Hata: {e}")
        return {"cevap": f"Hata: {str(e)}"}

@app.post("/ai-koc-analiz")
def ai_analyze(req: AiGoalRequest, user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    unfinished_count = db.query(models.Todo).filter(models.Todo.user_id == user.id, models.Todo.is_completed == False).count()
    
    # Hedefleri her türlü kaydedelim (Hata olsa bile veri kaybolmasın)
    try:
        if user.target:
            if hasattr(user.target, 'ranking'): user.target.ranking = req.siralama
            user.target.dream_university = req.universite
            db.commit()
    except: pass

    if unfinished_count > 0:
        return {
            "unvan": "ÖNCE GÖREVLER!",
            "mesaj": f"Masanda {unfinished_count} tane yarım kalmış iş var. Analiz istiyorsan önce onları bitir."
        }

    try:
        prompt = f"""
        Rol: Sert ve Disiplinli YKS Koçu. 
        Öğrenci Hedefi: Sıralama {req.siralama}, Üniversite {req.universite}.
        
        GÖREV: Bu hedefe ulaşmak için kısa, vurucu bir motivasyon/analiz yap.
        CEVAP FORMATI: Sadece aşağıdaki JSON formatında cevap ver. Markdown kullanma.
        
        {{
            "unvan": "KISA BİR LAKAP (Örn: SON SAVAŞÇI)",
            "mesaj": "Buraya en fazla 2 cümlelik sert bir tavsiye yaz."
        }}
        """
        if not GOOGLE_API_KEY: return {"unvan": "OFFLINE", "mesaj": "Bağlantı yok."}
        
        model = genai.GenerativeModel(MODEL_NAME)
        response = model.generate_content(prompt)
        
        # 👇 JSON TEMİZLEYİCİ
        text = response.text.strip()
        # Eğer yapay zeka ```json ... ``` gibi şeyler eklediyse temizle
        if "```" in text:
            text = text.replace("```json", "").replace("```", "").strip()
        
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            # Eğer hala JSON değilse manuel cevap dön, hata verme
            return {"unvan": "HEDEF ALINDI", "mesaj": "Hedefin sisteme işlendi. Şimdi çalışma zamanı!"}
            
    except Exception as e:
        print(f"Analiz Hatası: {e}")
        # Hata olsa bile 200 OK dönelim ki uygulama çökmesin
        return {"unvan": "HEDEF KAYDEDİLDİ", "mesaj": "Başarıyla kaydedildi."}

@app.post("/soru-coz")
async def solve_question(
    file: UploadFile = File(...), 
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db) 
):
    try:
        if not GOOGLE_API_KEY: return {"cevap": "AI Bağlantısı yok."}
        contents = await file.read()
        image = Image.open(io.BytesIO(contents))
        
        model = genai.GenerativeModel(MODEL_NAME)
        response = model.generate_content(["Bu soruyu çöz:", image])
        
        user.xp += 15
        db.commit() 
        
        return {"cevap": response.text}
    except Exception as e:
        print(f"Hata: {e}")
        return {"cevap": "Görseli okuyamadım."}

# main.py içindeki create_challenge fonksiyonunu sil ve bunu yapıştır:

@app.post("/challenge-olustur")
def create_challenge(db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    try:
      
        rutbe, _ = calculate_level(user.xp)
        
      
        modlar = [
            "SPEEDRUN (Hız Testi): Çok kısa sürede çok soru çözmeye odaklı.",
            "SURVIVOR (Dayanıklılık): Masadan kalkmadan uzun süre odaklanma.",
            "SNIPER (Nokta Atışı): Sadece en çok yanlış yapılan, zor bir konuya odaklanma.",
            "ERROR 404 (Hata Avı): Geçmiş denemelerdeki yanlışları tekrar çözme.",
            "BOSS FIGHT (Zor Soru): Sadece en zor kaynaklardan soru çözme."
        ]
        secilen_mod = random.choice(modlar)

        # 3. DİNAMİK PROMPT
        prompt = f"""
        ROL: Çılgın bir Oyun Yapımcısı ve YKS Koçu.
        OYUNCU SEVİYESİ: {rutbe} (Buna uygun zorluk ayarla).
        SEÇİLEN OYUN MODU: {secilen_mod}
        
        GÖREV: Bu moda uygun, heyecan verici bir YKS görevi (Challenge) oluştur.
        
        KURALLAR:
        1. Başlık çok havalı ve oyun terimi içersin.
        2. Açıklama gaza getirici olsun.
        3. Süre ve XP, oyuncu seviyesine ({rutbe}) uygun olsun (Usta ise zor, Çaylak ise kolay).
        4. "Paragraf çöz" gibi sıkıcı şeyler yazma, yaratıcı ol!
        
        CEVAP FORMATI (Sadece JSON):
        {{
            "baslik": "...",
            "aciklama": "...",
            "sure_dk": 45, 
            "xp_degeri": 150
        }}
        """

        if not GOOGLE_API_KEY: 
            return {"baslik": "Bağlantı Yok", "aciklama": "İnternetini kontrol et savaşçı!", "sure_dk": 0, "xp_degeri": 0}

        model = genai.GenerativeModel(MODEL_NAME)
        response = model.generate_content(prompt)
        text = response.text.replace("```json", "").replace("```", "").strip()
        
        return json.loads(text)

    except Exception as e:
        
        fallback_tasks = [
            {"baslik": "Zamanla Yarış", "aciklama": "20 dakikada 20 Mat sorusu yetiştirebilir misin?", "sure_dk": 20, "xp_degeri": 50},
            {"baslik": "Yanlışların İntikamı", "aciklama": "Son denemendeki fen yanlışlarını analiz et.", "sure_dk": 40, "xp_degeri": 80},
            {"baslik": "Sessizlik Yemini", "aciklama": "60 dakika telefon yasak, full odak biyoloji çalış.", "sure_dk": 60, "xp_degeri": 100}
        ]
        return random.choice(fallback_tasks)
@app.post("/deneme-ekle")
def add_exam(exam: schemas.ExamResultCreate, db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    toplam_tyt = exam.tyt_turkce + exam.tyt_sosyal + exam.tyt_mat + exam.tyt_fen
    user.xp += 50
    
    ai_tavsiyesi = "Analiz oluşturulamadı."
    if GOOGLE_API_KEY:
        try:
            prompt = f"Rol: Sert Koç. Sonuçlar: {exam.tyt_turkce} Türkçe, {exam.tyt_mat} Mat. 2 cümlelik eleştiri yap."
            model = genai.GenerativeModel(MODEL_NAME)
            response = model.generate_content(prompt)
            ai_tavsiyesi = response.text.strip()
        except: pass

    yeni_deneme = models.ExamResult(
        user_id=user.id,
        exam_name=exam.exam_name,
        tyt_turkce=exam.tyt_turkce,
        tyt_sosyal=exam.tyt_sosyal,
        tyt_mat=exam.tyt_mat,
        tyt_fen=exam.tyt_fen,
        tyt_net=toplam_tyt,
        ayt_net=exam.ayt_net,
        ai_comment=ai_tavsiyesi,
        date=datetime.now()
    )
    db.add(yeni_deneme)
    if user.target: user.target.current_tyt_net = toplam_tyt
    db.commit()
    return {"mesaj": "Kaydedildi ve Analiz Yapıldı!"}

@app.get("/deneme-gecmisi")
def get_exams(user: models.User = Depends(get_current_user)):
    return user.exam_results

@app.get("/chat-gecmisi", response_model=list[schemas.ChatMessageBase])
def get_chat_history(user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    messages = db.query(models.ChatMessage).filter(models.ChatMessage.user_id == user.id).order_by(models.ChatMessage.created_at.asc()).limit(50).all()
    return messages

@app.get("/istatistikler")
def get_stats(user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    target = user.target
    son_deneme = db.query(models.ExamResult).filter(models.ExamResult.user_id == user.id).order_by(models.ExamResult.date.desc()).first()
    mevcut_tyt = son_deneme.tyt_net if son_deneme else (target.current_tyt_net if target else 0)
    hedef_tyt = target.target_tyt_net if target else 120
    basari = int((mevcut_tyt / hedef_tyt) * 100) if hedef_tyt > 0 else 0
    return {
        "mevcut_tyt": mevcut_tyt,
        "mevcut_ayt": son_deneme.ayt_net if son_deneme else 0,
        "hedef_tyt": hedef_tyt,
        "hedef_bolum": target.dream_department if target else "Belirsiz",
        "hedef_uni": target.dream_university if target else "Belirsiz",
        "basari_orani": basari if basari <= 100 else 100
    }

@app.delete("/deneme-sil/{exam_id}")
def delete_exam(exam_id: int, db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    exam = db.query(models.ExamResult).filter(models.ExamResult.id == exam_id, models.ExamResult.user_id == user.id).first()
    if not exam: raise HTTPException(status_code=404, detail="Deneme bulunamadı")
    db.delete(exam)
    db.commit()
    return {"mesaj": "Deneme silindi"}

@app.put("/deneme-guncelle/{exam_id}")
def update_exam(exam_id: int, exam_data: schemas.ExamResultCreate, db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    exam = db.query(models.ExamResult).filter(models.ExamResult.id == exam_id, models.ExamResult.user_id == user.id).first()
    if not exam: raise HTTPException(status_code=404, detail="Deneme bulunamadı")
    
    toplam_tyt = exam_data.tyt_turkce + exam_data.tyt_sosyal + exam_data.tyt_mat + exam_data.tyt_fen
    exam.exam_name = exam_data.exam_name
    exam.tyt_turkce = exam_data.tyt_turkce
    exam.tyt_sosyal = exam_data.tyt_sosyal
    exam.tyt_mat = exam_data.tyt_mat
    exam.tyt_fen = exam_data.tyt_fen
    exam.tyt_net = toplam_tyt
    exam.ayt_net = exam_data.ayt_net
    
    last_exam = db.query(models.ExamResult).filter(models.ExamResult.user_id == user.id).order_by(models.ExamResult.date.desc()).first()
    if last_exam and last_exam.id == exam_id and user.target:
        user.target.current_tyt_net = toplam_tyt
        
    db.commit()
    return {"mesaj": "Deneme güncellendi"}