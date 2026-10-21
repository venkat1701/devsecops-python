def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "UP"}

def test_api_health_alias_for_ingress(client):
    assert client.get("/api/health").json() == {"status": "UP"}

def test_ready_checks_database(client):
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "READY"}

def test_root(client):
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["service"] == "TaskBoard API"

def test_create_task(client):
    response = client.post("/api/tasks", json={"title": "Deploy application", "priority": "HIGH", "assignee": "Student"})
    assert response.status_code == 201
    body = response.json()
    assert body["id"] > 0
    assert body["title"] == "Deploy application"
    assert body["status"] == "TODO"
    assert body["created_at"]

def test_create_task_rejects_empty_title(client):
    assert client.post("/api/tasks", json={"title": ""}).status_code == 422

def test_create_task_rejects_unknown_priority(client):
    assert client.post("/api/tasks", json={"title": "x", "priority": "URGENT"}).status_code == 422

def test_list_tasks_newest_first(client, make_task):
    make_task(title="first")
    make_task(title="second")
    titles = [t["title"] for t in client.get("/api/tasks").json()]
    assert titles == ["second", "first"]

def test_get_task(client, make_task):
    task = make_task(title="Write Terraform")
    response = client.get(f"/api/tasks/{task['id']}")
    assert response.status_code == 200
    assert response.json()["title"] == "Write Terraform"

def test_get_missing_task_returns_404(client):
    assert client.get("/api/tasks/9999").status_code == 404

def test_update_task_partial(client, make_task):
    task = make_task(title="Configure ingress")
    response = client.put(f"/api/tasks/{task['id']}", json={"status": "IN_PROGRESS"})
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "IN_PROGRESS"
    assert body["title"] == "Configure ingress"

def test_update_missing_task_returns_404(client):
    assert client.put("/api/tasks/9999", json={"status": "DONE"}).status_code == 404

def test_delete_task(client, make_task):
    task = make_task()
    assert client.delete(f"/api/tasks/{task['id']}").status_code == 204
    assert client.get(f"/api/tasks/{task['id']}").status_code == 404

def test_delete_missing_task_returns_404(client):
    assert client.delete("/api/tasks/9999").status_code == 404

def test_stats_counts_by_status(client, make_task):
    make_task(status="TODO")
    make_task(status="TODO")
    make_task(status="IN_PROGRESS")
    make_task(status="DONE")
    assert client.get("/api/tasks/stats").json() == {"total": 4, "todo": 2, "inProgress": 1, "done": 1}

def test_metrics_exposes_prometheus_format(client, make_task):
    make_task()
    client.get("/api/tasks")
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "http_requests_total" in response.text
    assert 'taskboard_task_events_total{event="created"}' in response.text
