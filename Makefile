.PHONY: dev build test migrate seed clean logs

# ── Development ──────────────────────────────────────────────────────────────
dev:
	docker compose up --build

dev-bg:
	docker compose up --build -d

# ── Individual services ───────────────────────────────────────────────────────
auth:
	docker compose up --build auth-service postgres redis

ai:
	docker compose up --build ai-service postgres redis

frontend:
	cd frontend && flutter run -d chrome --web-port 8080

# ── Database ──────────────────────────────────────────────────────────────────
migrate:
	docker compose exec auth-service alembic upgrade head
	docker compose exec profile-service alembic upgrade head
	docker compose exec opportunity-service alembic upgrade head

seed:
	docker compose exec opportunity-service python -m scripts.seed_opportunities

# ── Testing ───────────────────────────────────────────────────────────────────
test-backend:
	docker compose exec auth-service pytest -v --cov=.
test-frontend:
	cd frontend && flutter test

# ── Build ─────────────────────────────────────────────────────────────────────
build-web:
	cd frontend && flutter build web --release --web-renderer canvaskit

build-android:
	cd frontend && flutter build apk --release

build-ios:
	cd frontend && flutter build ios --release

# ── Utilities ─────────────────────────────────────────────────────────────────
logs:
	docker compose logs -f

clean:
	docker compose down -v
	rm -rf frontend/build

shell-db:
	docker compose exec postgres psql -U fillform -d fillformai

shell-redis:
	docker compose exec redis redis-cli
