"""PostgreSQL connection (Neon), configured by DATABASE_URL in backend/.env."""
import logging
import os
from collections.abc import Iterator

from dotenv import load_dotenv
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

logger = logging.getLogger(__name__)

load_dotenv()


class Base(DeclarativeBase):
    pass


_session_factory: sessionmaker[Session] | None = None


def init_db() -> None:
    """Connect and create missing tables at startup. Without a database the API still runs."""
    global _session_factory
    url = os.getenv("DATABASE_URL")
    if not url:
        logger.warning("DATABASE_URL is not set; scan history is disabled.")
        return

    # Neon gives a plain postgresql:// URL; tell SQLAlchemy to use psycopg 3.
    url = url.replace("postgresql://", "postgresql+psycopg://", 1)
    # Neon closes idle connections, so check each one before use.
    engine = create_engine(url, pool_pre_ping=True, pool_recycle=300)
    try:
        Base.metadata.create_all(engine)
    except Exception as exc:
        logger.warning("Database unavailable; scan history is disabled: %s", exc)
        return

    _session_factory = sessionmaker(engine, expire_on_commit=False)
    logger.info("Database connected.")


def db_available() -> bool:
    return _session_factory is not None


def new_session() -> Session:
    if _session_factory is None:
        raise RuntimeError("Database is not initialised.")
    return _session_factory()


def get_session() -> Iterator[Session]:
    """FastAPI dependency: one session per request, 503 when there is no database."""
    if _session_factory is None:
        raise HTTPException(503, "Scan history is not available: the database is not configured.")
    with _session_factory() as session:
        yield session
