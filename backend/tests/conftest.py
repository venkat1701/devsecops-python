import os

# Never let the tests touch the real PostgreSQL database.
os.environ["DATABASE_URL"] = "sqlite://"

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app import models  # noqa: F401  registers models on Base.metadata
from app.db import Base, get_db
from app.main import app

# In-memory SQLite shared across threads so TestClient sees the same database.
engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
TestingSessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

@pytest.fixture()
def client():
    """Fresh schema per test so tests are independent of each other."""
    Base.metadata.create_all(bind=engine)
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()
    Base.metadata.drop_all(bind=engine)

@pytest.fixture()
def make_task(client):
    def _make(**overrides):
        payload = {"title": "Deploy application", "priority": "HIGH", "assignee": "Student", **overrides}
        response = client.post("/api/tasks", json=payload)
        assert response.status_code == 201, response.text
        return response.json()
    return _make
