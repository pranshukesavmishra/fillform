# FillFormAI — Launch Guide

## Prerequisites
- Docker Desktop (Mac/Windows) or Docker Engine + Compose plugin (Linux)
- Git

## 1. Clone & configure

```bash
git clone https://github.com/pranshukesavmishra/fillform
cd fillform
git checkout claude/youthful-shannon-ciwcbw

cp .env.example .env
# Edit .env — fill in ANTHROPIC_API_KEY at minimum
```

## 2. Launch everything

```bash
docker compose up --build
```

This starts:
| Service | URL |
|---------|-----|
| Flutter Web App | http://localhost:8080 |
| API Gateway | http://localhost:8000 |
| Auth Service | http://localhost:8001 |
| Profile Service | http://localhost:8002 |
| Opportunity Service | http://localhost:8003 |
| Application Service | http://localhost:8004 |
| Document Service | http://localhost:8005 |
| Agent Service | http://localhost:8006 |
| Notification Service | http://localhost:8007 |
| AI Service | http://localhost:8008 |
| Payment Service | http://localhost:8009 |
| MinIO (S3) Console | http://localhost:9001 (admin/minioadmin) |
| Grafana | http://localhost:3001 (admin/admin123) |

## 3. Verify all services are healthy

```bash
curl http://localhost:8000/health
curl http://localhost:8001/health
curl http://localhost:8002/health
# ... etc
```

## 4. Required secrets (minimum to run)

Edit your `.env`:
```
ANTHROPIC_API_KEY=sk-ant-...    # Required for AI features
SECRET_KEY=<64+ random chars>   # Required for JWT auth
```

Optional (features degrade gracefully without these):
```
TWILIO_ACCOUNT_SID=...          # For SMS OTP
WHATSAPP_BUSINESS_TOKEN=...     # For WhatsApp alerts
RAZORPAY_KEY_ID=...             # For payments
FCM_SERVER_KEY=...              # For push notifications
```

## 5. First login

Since Twilio SMS is optional, in development the OTP is printed to the **auth-service logs**:
```bash
docker compose logs auth-service | grep "OTP"
```

Send OTP to any phone number → check logs → enter OTP → you're in.

## 6. Flutter Web (dev hot-reload)

```bash
cd frontend
flutter pub get
flutter run -d chrome --web-port 8080 \
  --dart-define=API_BASE_URL=http://localhost:8000
```

## 7. Common commands

```bash
# Stop everything
docker compose down

# Stop and wipe data (fresh start)
docker compose down -v

# Rebuild just one service
docker compose up --build ai-service

# View logs for a service
docker compose logs -f ai-service

# Open psql
docker compose exec postgres psql -U fillform -d fillformai

# Open Redis CLI
docker compose exec redis redis-cli
```

## 8. Database schema

The full schema is auto-created from `backend/infrastructure/docker/init.sql` when PostgreSQL starts for the first time. Sample opportunities and agents are seeded automatically.

## Architecture

```
Flutter Web (port 8080)
    │
    ▼
NGINX Gateway (port 8000)
    │
    ├── /api/v1/auth/          → auth-service:8001
    ├── /api/v1/profile/       → profile-service:8002
    ├── /api/v1/opportunities/ → opportunity-service:8003
    ├── /api/v1/applications/  → application-service:8004
    ├── /api/v1/documents/     → document-service:8005
    ├── /api/v1/agents/        → agent-service:8006
    ├── /api/v1/notifications/ → notification-service:8007
    ├── /api/v1/ai/            → ai-service:8008
    └── /api/v1/payments/      → payment-service:8009

Infrastructure:
  PostgreSQL 16 (port 5432)
  Redis 7       (port 6379)
  MongoDB 7     (port 27017)
  Apache Kafka  (port 9092)
  MinIO S3      (port 9000)
```
