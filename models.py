from sqlalchemy import Boolean, Column, ForeignKey, Integer, String, Float, DateTime, Date, Text
from sqlalchemy.orm import relationship
from database import Base
from datetime import datetime

# 1. KULLANICI TABLOSU
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    email = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    is_active = Column(Boolean, default=False)
    verification_code = Column(String, nullable=True)
    xp = Column(Integer, default=0)
    
    # 🔥 YENİ EKLENEN STREAK SÜTUNLARI
    streak = Column(Integer, default=0)
    last_active_date = Column(Date, nullable=True)

    target = relationship("UserTarget", back_populates="user", uselist=False)
    todos = relationship("Todo", back_populates="user")
    exam_results = relationship("ExamResult", back_populates="user")
    chat_history = relationship("ChatMessage", back_populates="user")

# 2. HEDEF TABLOSU
class UserTarget(Base):
    __tablename__ = "user_targets"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    ranking = Column(String, nullable=True)
    dream_university = Column(String, nullable=True)
    dream_department = Column(String, nullable=True)
    current_tyt_net = Column(Float, default=0.0)
    target_tyt_net = Column(Float, default=0.0)

    user = relationship("User", back_populates="target")

# 3. GÖREVLER TABLOSU
class Todo(Base):
    __tablename__ = "todos"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    content = Column(String)
    is_completed = Column(Boolean, default=False)

    user = relationship("User", back_populates="todos")

# 4. DENEME SONUÇLARI
class ExamResult(Base):
    __tablename__ = "exam_results"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    exam_name = Column(String)
    
    tyt_turkce = Column(Float)
    tyt_sosyal = Column(Float)
    tyt_mat = Column(Float)
    tyt_fen = Column(Float)
    
    tyt_net = Column(Float)
    ayt_net = Column(Float)
    
    ai_comment = Column(String, nullable=True)
    date = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="exam_results")

# 5. CHAT GEÇMİŞİ
class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    user_question = Column(String)
    ai_response = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="chat_history")