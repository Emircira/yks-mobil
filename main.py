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
from typing import Optional, Dict
from io import BytesIO
import asyncio
import traceback
import time 
import hashlib 

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

# Importlar
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
    # ÇAYLAK: 0 - 1.000 XP (Alışma Evresi)
    if xp < 1000: 
        return "Çaylak", xp / 1000
    
    # ÇIRAK: 1.000 - 5.000 XP (Temel Atma - Yaklaşık 1-2 Ay)
    if xp < 5000: 
        return "Çırak", (xp - 1000) / 4000
    
    # KALFA: 5.000 - 15.000 XP (Gelişme Dönemi - Yıl Ortası)
    if xp < 15000: 
        return "Kalfa", (xp - 5000) / 10000
    
    # USTA: 15.000 - 30.000 XP (Ustalaşma - Son Düzlük)
    if xp < 30000: 
        return "Usta", (xp - 15000) / 15000
        
    # YKS LORDU: 30.000+ XP (Artık Sınava Hazırsın)
    return "YKS LORDU", 1.0

def normalize_password(password: str) -> str:
    return hashlib.sha256(password.encode("utf-8")).hexdigest()

# --- Pydantic MODELLERİ ---
# (schemas.py olmadığı için bazı modelleri burada tanımlıyoruz)
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

# 👇 YENİ DENEME İSTEK MODELİ (Konu Analizli)
class DenemeEkleRequest(BaseModel):
    exam_name: str
    tyt_turkce: float
    tyt_sosyal: float
    tyt_mat: float
    tyt_fen: float
    ayt_net: float
    # Örn: {"Fonksiyonlar": 2, "Paragraf": 3}
    yanlis_konular: Dict[str, int] = {} 

scheduler = AsyncIOScheduler()

#  MAIL FONKSİYONU 
def send_email_func(to_email, subject, body):
    if not MAIL_USERNAME or not MAIL_PASSWORD:
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
        return True
    except Exception as e:
        print(f"Mail Hata: {str(e)}")
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
    existing = db.query(models.User).filter((models.User.email == user.email) | (models.User.username == user.username)).first()
    if existing: raise HTTPException(status_code=400, detail="Kullanıcı zaten var.")
    
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
    
    send_email_func(user.email, "Doğrulama Kodu", f"Kodun: {code}")
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
    if not user: raise HTTPException(status_code=401, detail="Hatalı giriş.")
    
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
        if target.dream_department: bilgi = target.dream_department
        elif target.ranking: bilgi = f"Hedef: {target.ranking}"
            
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
        if todo.is_completed: user.xp += 10 
        else: user.xp -= 10 
        db.commit()
    return {"mesaj": "Ok", "yeni_xp": user.xp}

@app.delete("/gorevleri-temizle")
def clear_todos(db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    count = db.query(models.Todo).filter(models.Todo.user_id == user.id, models.Todo.is_completed == True).delete()
    db.commit()
    return {"mesaj": f"{count} tamamlanmış görev temizlendi!"}

# main.py içindeki create_ai_plan fonksiyonunu sil ve bunu yapıştır:

@app.post("/plan-olustur")
def create_ai_plan(db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    # 1. Yarım kalan iş kontrolü
    unfinished_count = db.query(models.Todo).filter(models.Todo.user_id == user.id, models.Todo.is_completed == False).count()
    if unfinished_count > 0:
        raise HTTPException(status_code=406, detail=f"🚫 Önce elindeki {unfinished_count} görevi bitir! Yarım iş bırakma.")

    try:
        # 2. SEVİYE ve XP HESAPLA
        rutbe, _ = calculate_level(user.xp)
        target = user.target
        hedef_siralamasi = target.ranking if target and target.ranking else "İlk 20.000"
        
        # 3. TYT/AYT DENGE STRATEJİSİ
        odak_konusu = ""
        if rutbe == "Çaylak":
            odak_konusu = "DURUM: %100 TYT KONU. Temel Matematik, Paragraf ve Dil Bilgisi konuları ver."
        elif rutbe == "Çırak":
            odak_konusu = "DURUM: %70 TYT - %30 AYT. TYT konuları ağırlıklı ama araya Türkçe Branş Denemesi ekle."
        elif rutbe == "Kalfa":
            odak_konusu = "DURUM: %40 TYT (DENEME) - %60 AYT (KONU). AYT ağırlıklı git ama mutlaka 'TYT Genel Deneme' veya 'Matematik Branş Denemesi' ekle."
        else: 
            odak_konusu = "DURUM: %100 SINAV MODU. Seri TYT ve AYT Denemeleri ver. Zor kaynaklara yönlendir."

        # Geçmiş bitenleri hatırlat
        son_bitenler = db.query(models.Todo).filter(models.Todo.user_id == user.id, models.Todo.is_completed == True).order_by(models.Todo.id.desc()).limit(10).all()
        biten_txt = ", ".join([t.content for t in son_bitenler]) if son_bitenler else "Yok"

        # 4. GÜÇLENDİRİLMİŞ PROMPT (EMİR KİPİ + SOHBET YASAK)
        prompt = f"""
        ROL: Disiplinli YKS Koçu.
        ÖĞRENCİ: {rutbe} seviyesinde. Hedef: {hedef_siralamasi}.
        
        GEÇMİŞTE YAPILANLAR: {biten_txt}.
        STRATEJİ: {odak_konusu}
        
        KURALLAR:
        1. ASLA "Öğrenci yapsın", "izlesin" gibi 3. şahıs dili kullanma.
        2. DOĞRUDAN EMİR VER: "Çöz", "İzle", "Bitir", "Tekrarla".
        3. ASLA sohbet etme, giriş cümlesi yazma (Örn: 'Harika program hazırladım' DEME). Sadece 4 maddeyi alt alta yaz.
        4. Müfredat sırasına uy.
        
        GÖREV:
        Bugün için 4 adet nokta atışı görev yaz.
        
        FORMAT ÖRNEĞİ:
        - [Matematik]: Üslü Sayılar - [Mert Hoca'dan konu videosunu izle ve 3 test bitir.]
        - [Türkçe]: Paragraf - [Süre tutarak 20 paragraf sorusu çöz.]
        """

        if not GOOGLE_API_KEY: return {"mesaj": "Bağlantı Yok", "gorevler": []}

        model = genai.GenerativeModel(MODEL_NAME)
        response = model.generate_content(prompt)
        raw_text = response.text.strip()
        
        # Temizleme
        clean_tasks = []
        for line in raw_text.split("\n"):
            line = line.strip()
            # Kısa veya boş satırları atla
            if len(line) < 10: continue
            # Yıldızları ve tireleri temizle
            cleaned_line = line.replace("* ", "").strip()
            if cleaned_line.startswith("- "): 
                cleaned_line = cleaned_line[2:]
            
            clean_tasks.append(cleaned_line)

        # İlk 4 görevi al ve kaydet
        final_tasks = clean_tasks[:4]
        for task in final_tasks:
            db.add(models.Todo(content=task, user_id=user.id))
        
        db.commit()
        return {"mesaj": "Yeni görevlerin hazır komutan!", "gorevler": final_tasks}

    except Exception as e:
        print(f"Plan Hata: {e}")
        raise HTTPException(status_code=500, detail="Plan oluşturulamadı.")

@app.post("/ai-soru-sor")
def ask_tutor(req: SoruIstegi, db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    try:
        if not GOOGLE_API_KEY: return {"cevap": "Bağlantı yok."}
        target = user.target
        
        system_instruction = f"""
        Sen YKS Koçusun.
        ÖĞRENCİ: {user.username}, Hedef: {target.ranking if target else 'Belirsiz'}.
        GÖREV EKLEME: Eğer ders önerirsen cümlenin sonuna "GOREV_EKLE: <Kısa Görev>" yaz.
        """
        full_prompt = f"{system_instruction}\n\nSoru: {req.soru_metni}"
        
        model = genai.GenerativeModel(MODEL_NAME)
        response = model.generate_content(full_prompt)
        final_answer = response.text
        
        ai_reply_to_show = final_answer
        if "GOREV_EKLE:" in final_answer:
            parts = final_answer.split("GOREV_EKLE:")
            ai_reply_to_show = parts[0].strip()
            raw_task = parts[1].strip()
            try:
                db.add(models.Todo(user_id=user.id, content=f"🤖 Hoca: {raw_task}"))
                db.commit()
            except: db.rollback()

        db.add(models.ChatMessage(user_id=user.id, user_question=req.soru_metni, ai_response=ai_reply_to_show))
        db.commit()
        return {"cevap": ai_reply_to_show}
    except Exception as e:
        return {"cevap": f"Hata: {str(e)}"}

@app.post("/ai-koc-analiz")
def ai_analyze(req: AiGoalRequest, user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        if not user.target:
            db.add(models.Target(user_id=user.id, ranking=req.siralama, dream_university=req.universite))
            db.commit()
            db.refresh(user)
        else:
            user.target.ranking = req.siralama
            user.target.dream_university = req.universite
            db.commit()
            
        mevcut_net = user.target.current_tyt_net if user.target else 0
        seviye = "BAŞLANGIÇ" if mevcut_net < 30 else "ORTA" if mevcut_net < 60 else "İYİ"
        
        prompt = f"""
        Rol: YKS Koçu. Öğrenci Hedefi: {req.siralama}. Net: {mevcut_net}. Seviye: {seviye}.
        Görev: Durum analizi yap.
        Format (JSON): {{ "unvan": "...", "mesaj": "..." }}
        """
        
        if not GOOGLE_API_KEY: return {"unvan": "OFFLINE", "mesaj": "Kaydedildi."}
        
        model = genai.GenerativeModel(MODEL_NAME)
        response = model.generate_content(prompt)
        text = response.text.replace("```json", "").replace("```", "").strip()
        return json.loads(text)
    except Exception:
        return {"unvan": "KAYDEDİLDİ", "mesaj": "Hedef alındı."}

@app.post("/soru-coz")
async def solve_question(file: UploadFile = File(...), user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        if not GOOGLE_API_KEY: return {"cevap": "AI Yok"}
        contents = await file.read()
        image = Image.open(io.BytesIO(contents))
        model = genai.GenerativeModel(MODEL_NAME)
        response = model.generate_content(["Bu soruyu çöz:", image])
        user.xp += 15
        db.commit()
        return {"cevap": response.text}
    except:
        return {"cevap": "Hata oluştu."}

@app.post("/challenge-olustur")
def create_challenge(db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    try:
        rutbe, _ = calculate_level(user.xp)
        son_gorevler = db.query(models.Todo).filter(models.Todo.user_id == user.id).order_by(models.Todo.id.desc()).limit(3).all()
        konu_baglam = ", ".join([t.content for t in son_gorevler]) if son_gorevler else "Genel YKS"
        
        prompt = f"""
        Rol: Oyun Yapımcısı. Seviye: {rutbe}. Konu: {konu_baglam}.
        Görev: Zorlu bir challenge metni yaz.
        Format (JSON): {{ "baslik": "...", "aciklama": "...", "sure_dk": 45, "xp_degeri": 100 }}
        Kural: Metin sonunda 'GÖREVİN: ... çözmek' yazmalı.
        """
        if not GOOGLE_API_KEY: raise Exception("API Yok")
        
        model = genai.GenerativeModel(MODEL_NAME)
        response = model.generate_content(prompt)
        text = response.text.replace("```json", "").replace("```", "").strip()
        return json.loads(text)
    except:
        return {"baslik": "Hata Avı", "aciklama": "Sistem hata verdi, sen 20 soru çöz.", "sure_dk": 30, "xp_degeri": 50}

# 👇 GÜNCELLENMİŞ DENEME EKLEME (KONU ANALİZLİ)
@app.post("/deneme-ekle")
def add_exam(req: DenemeEkleRequest, db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    toplam_tyt = req.tyt_turkce + req.tyt_sosyal + req.tyt_mat + req.tyt_fen
    user.xp += 50
    
    # 1. AI YORUMU (YANLIŞ KONULARA GÖRE)
    ai_tavsiyesi = "Analiz oluşturulamadı."
    if GOOGLE_API_KEY and req.yanlis_konular:
        try:
            hatalar = ", ".join([f"{k} ({v} yanlış)" for k,v in req.yanlis_konular.items()])
            prompt = f"""
            Rol: Sert YKS Koçu. 
            Öğrenci Denemesi: {req.exam_name}. Net: {toplam_tyt}.
            🚨 EN ÇOK YANLIŞ YAPILAN KONULAR: {hatalar}.
            
            GÖREV: Sadece bu yanlış konulara odaklanan, nokta atışı bir eleştiri ve tavsiye ver.
            Kısa ve net ol (Maks 2 cümle).
            """
            model = genai.GenerativeModel(MODEL_NAME)
            response = model.generate_content(prompt)
            ai_tavsiyesi = response.text.strip()
        except Exception as e:
            print(f"Analiz Hatası: {e}")
    elif GOOGLE_API_KEY:
        # Konu girilmediyse genel yorum
        try:
            prompt = f"Rol: Sert Koç. Net: {toplam_tyt}. Genel bir tavsiye ver."
            model = genai.GenerativeModel(MODEL_NAME)
            response = model.generate_content(prompt)
            ai_tavsiyesi = response.text.strip()
        except: pass

    # 2. VERİTABANINA KAYIT
    yeni_deneme = models.ExamResult(
        user_id=user.id,
        exam_name=req.exam_name,
        tyt_turkce=req.tyt_turkce,
        tyt_sosyal=req.tyt_sosyal,
        tyt_mat=req.tyt_mat,
        tyt_fen=req.tyt_fen,
        tyt_net=toplam_tyt,
        ayt_net=req.ayt_net,
        topic_mistakes=req.yanlis_konular, # 👇 YANLIŞLAR KAYDEDİLDİ
        ai_comment=ai_tavsiyesi,
        date=datetime.now()
    )
    db.add(yeni_deneme)
    if user.target: user.target.current_tyt_net = toplam_tyt
    db.commit()
    
    return {"mesaj": "Kaydedildi!", "analiz": ai_tavsiyesi}

@app.get("/deneme-gecmisi")
def get_exams(user: models.User = Depends(get_current_user)):
    return user.exam_results

@app.get("/chat-gecmisi", response_model=list[schemas.ChatMessageBase])
def get_chat_history(user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(models.ChatMessage).filter(models.ChatMessage.user_id == user.id).order_by(models.ChatMessage.created_at.asc()).limit(50).all()

@app.get("/istatistikler")
def get_stats(user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    target = user.target
    son_deneme = db.query(models.ExamResult).filter(models.ExamResult.user_id == user.id).order_by(models.ExamResult.date.desc()).first()
    mevcut_tyt = son_deneme.tyt_net if son_deneme else (target.current_tyt_net if target else 0)
    return {
        "mevcut_tyt": mevcut_tyt,
        "hedef_bolum": target.dream_department if target else "Belirsiz",
        "basari_orani": int((mevcut_tyt / (target.target_tyt_net or 120)) * 100) if target else 0
    }

@app.delete("/deneme-sil/{exam_id}")
def delete_exam(exam_id: int, db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    db.query(models.ExamResult).filter(models.ExamResult.id == exam_id, models.ExamResult.user_id == user.id).delete()
    db.commit()
    return {"mesaj": "Silindi"}
from sqlalchemy import text

from sqlalchemy import text

@app.get("/tabloyu-duzelt")
def fix_table_schema(db: Session = Depends(get_db)):
    """
    BU FONKSİYON SADECE TEK SEFERLİK KULLANIM İÇİNDİR.
    Eski 'exam_results' tablosunu siler ve yenisini (yeni sütunlarla) oluşturur.
    DİKKAT: Eski deneme kayıtların silinir!
    """
    try:
        # 1. Eski tabloyu zorla sil
        db.execute(text("DROP TABLE IF EXISTS exam_results CASCADE;"))
        db.commit()
        
        # 2. Modellerdeki yeni yapıya göre tabloyu tekrar oluştur
        models.Base.metadata.create_all(bind=engine)
        
        return {"durum": "BAŞARILI", "mesaj": "ExamResult tablosu silindi ve 'topic_mistakes' sütunuyla yeniden oluşturuldu. Artık deneme ekleyebilirsin!"}
    except Exception as e:
        return {"durum": "HATA", "hata": str(e)}