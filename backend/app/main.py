from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import Counter
from prometheus_fastapi_instrumentator import Instrumentator
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .config import settings
from .db import get_db
from .models import Task
from .schemas import StatsOut, TaskCreate, TaskOut, TaskUpdate

# Schema is owned by Alembic (run before Uvicorn in the container); tests build their own schema.
app = FastAPI(title=settings.app_name, version=settings.app_version)
app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins, allow_methods=["*"], allow_headers=["*"])
Instrumentator(excluded_handlers=["/metrics"]).instrument(app).expose(app, endpoint="/metrics", include_in_schema=False)

# Business metric alongside the default HTTP request/latency metrics.
TASK_EVENTS = Counter("taskboard_task_events_total", "Task lifecycle events", ["event"])

@app.get("/")
def root():
    return {"service": settings.app_name, "version": settings.app_version, "docs": "/docs"}

@app.get("/health")
@app.get("/api/health", include_in_schema=False)
def health():
    return {"status": "UP"}

@app.get("/ready")
def ready(db: Session = Depends(get_db)):
    try:
        db.execute(select(func.count(Task.id)))
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Database not ready") from exc
    return {"status": "READY"}

@app.get("/api/tasks", response_model=list[TaskOut])
def list_tasks(db: Session = Depends(get_db)):
    return list(db.scalars(select(Task).order_by(Task.id.desc())))

@app.get("/api/tasks/stats", response_model=StatsOut)
def stats(db: Session = Depends(get_db)):
    rows = db.execute(select(Task.status, func.count(Task.id)).group_by(Task.status)).all()
    counts = {status: count for status, count in rows}
    return StatsOut(total=sum(counts.values()), todo=counts.get("TODO", 0), inProgress=counts.get("IN_PROGRESS", 0), done=counts.get("DONE", 0))

@app.get("/api/tasks/{task_id}", response_model=TaskOut)
def get_task(task_id: int, db: Session = Depends(get_db)):
    task = db.get(Task, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    return task

@app.post("/api/tasks", response_model=TaskOut, status_code=status.HTTP_201_CREATED)
def create_task(payload: TaskCreate, db: Session = Depends(get_db)):
    task = Task(**payload.model_dump())
    db.add(task)
    db.commit()
    db.refresh(task)
    TASK_EVENTS.labels(event="created").inc()
    return task

@app.put("/api/tasks/{task_id}", response_model=TaskOut)
def update_task(task_id: int, payload: TaskUpdate, db: Session = Depends(get_db)):
    task = db.get(Task, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(task, key, value)
    db.commit()
    db.refresh(task)
    TASK_EVENTS.labels(event="updated").inc()
    return task

@app.delete("/api/tasks/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_task(task_id: int, db: Session = Depends(get_db)):
    task = db.get(Task, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    db.delete(task)
    db.commit()
    TASK_EVENTS.labels(event="deleted").inc()
