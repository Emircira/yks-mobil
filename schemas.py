from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from models import User

# --- ORTAK PARÇALAR ---
class TodoBase(BaseModel):
    content: str
    is_completed: bool = False

#  DETAYLI DENEME YAPISI
class ExamResultBase(BaseModel):
    exam_name: str
 
    tyt_turkce: float = 0.0
    tyt_sosyal: float = 0.0
    tyt_mat: float = 0.0
    tyt_fen: float = 0.0
    # AYT 
    ayt_net: Optional[float] = 0.0

# --- KULLANICI OLUŞTURMA (Register) ---
class UserTargetCreate(BaseModel):
    dream_university: str
    dream_department: str
    current_tyt_net: float
    target_tyt_net: float

class UserCreate(BaseModel):
    username: str
    email: str
    password: str
    targets: UserTargetCreate

# --- YAPILACAKLAR (TODO) İŞLEMLERİ ---
class TodoCreate(TodoBase):
    pass

class TodoResponse(TodoBase):
    id: int
    created_at: datetime
    class Config:
        from_attributes = True

# --- DENEME SONUCU İŞLEMLERİ ---
class ExamResultCreate(ExamResultBase):
    pass

class ExamResultResponse(ExamResultBase):
    id: int
    tyt_net: float 
    ai_comment: Optional[str] = None
    date: datetime
    class Config:
        from_attributes = True

# --- YAPAY ZEKA SORUSU ---
class SoruModeli(BaseModel):
    soru: str

class SoruIstegi(BaseModel):
    soru_metni: str

# --- SOHBET GEÇMİŞİ ---
class ChatMessageBase(BaseModel):
    user_question: str
    ai_response: str
    created_at: datetime
    class Config:
        from_attributes = True