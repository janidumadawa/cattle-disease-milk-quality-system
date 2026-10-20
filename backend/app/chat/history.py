"""Chatbot conversation history, kept in the database.

Each row is one question and the chatbot's full answer (card, topic,
suggestions ...), so the app can show the conversation again after a restart
and the chatbot can keep answering follow-ups ("how do I treat it?").
A conversation is identified by an id the app creates once per device.
"""
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    conversation_id: Mapped[str] = mapped_column(String(64), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    question: Mapped[str] = mapped_column(Text)
    lang: Mapped[str | None] = mapped_column(String(8))
    # The answer's topic ("Mastitis") and whether it described a sick cow: the
    # chatbot uses these from earlier turns to answer follow-up questions.
    topic: Mapped[str | None] = mapped_column(String(64))
    sick: Mapped[bool] = mapped_column(Boolean, default=False)
    # The chatbot's answer as the app received it: {"meta": ..., "done": ..., "text": ...}.
    reply: Mapped[dict] = mapped_column(JSONB)
