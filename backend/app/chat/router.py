"""Chat history endpoints: save and reload chatbot conversations."""
import json
from datetime import datetime
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, Path, Query
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.chat.history import ChatMessage
from app.db import get_session

router = APIRouter(prefix="/api/v1/chat", tags=["chat"])

MAX_REPLY_BYTES = 256 * 1024  # an answer card is a few KB

# Created by the app (random hex / uuid); not guessable, so it also keeps
# one device's conversation separate from another's.
ConversationId = Annotated[str, Path(pattern=r"^[A-Za-z0-9-]{16,64}$")]


def _small_enough(reply: dict[str, Any]) -> dict[str, Any]:
    if len(json.dumps(reply)) > MAX_REPLY_BYTES:
        raise ValueError("reply is too large")
    return reply


class MessageIn(BaseModel):
    question: str = Field(min_length=1, max_length=2000)
    lang: str | None = Field(default=None, max_length=8)
    topic: str | None = Field(default=None, max_length=64)
    sick: bool = False
    reply: dict[str, Any] = Field(description='The answer as streamed: {"meta": ..., "done": ..., "text": ...}.')

    _check_reply = field_validator("reply")(_small_enough)


class ReplyIn(BaseModel):
    reply: dict[str, Any]

    _check_reply = field_validator("reply")(_small_enough)


class MessageOut(BaseModel):
    id: int
    created_at: datetime
    question: str
    lang: str | None
    topic: str | None
    sick: bool
    reply: dict[str, Any]


class SavedMessage(BaseModel):
    id: int


class Conversation(BaseModel):
    items: list[MessageOut] = Field(description="Oldest first.")


@router.get("/conversations/{conversation_id}/messages", response_model=Conversation)
def list_messages(
    conversation_id: ConversationId,
    session: Annotated[Session, Depends(get_session)],
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
):
    """The latest `limit` messages of a conversation, oldest first."""
    rows = session.scalars(
        select(ChatMessage)
        .where(ChatMessage.conversation_id == conversation_id)
        .order_by(ChatMessage.id.desc())
        .limit(limit)
    ).all()
    return Conversation(items=[MessageOut.model_validate(r, from_attributes=True) for r in reversed(rows)])


@router.post("/conversations/{conversation_id}/messages", response_model=SavedMessage, status_code=201)
def save_message(
    conversation_id: ConversationId, message: MessageIn, session: Annotated[Session, Depends(get_session)]
):
    row = ChatMessage(conversation_id=conversation_id, **message.model_dump())
    session.add(row)
    session.commit()
    return SavedMessage(id=row.id)


@router.put("/conversations/{conversation_id}/messages/{message_id}", status_code=204)
def update_reply(
    conversation_id: ConversationId,
    message_id: int,
    body: ReplyIn,
    session: Annotated[Session, Depends(get_session)],
):
    """Replace a saved answer, e.g. after the slower AI-model answer was added to it."""
    row = session.get(ChatMessage, message_id)
    if row is None or row.conversation_id != conversation_id:
        raise HTTPException(404, "Message not found.")
    row.reply = body.reply
    session.commit()


@router.delete("/conversations/{conversation_id}", status_code=204)
def delete_conversation(conversation_id: ConversationId, session: Annotated[Session, Depends(get_session)]):
    session.execute(delete(ChatMessage).where(ChatMessage.conversation_id == conversation_id))
    session.commit()
