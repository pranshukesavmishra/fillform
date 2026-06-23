# FillFormAI — India's AI Career Operating System

> _"Every Indian student, regardless of geography, income, or connections, gets the same career advantage as a student at IIT with a well-connected professor."_

---

## What Is This?

FillFormAI is not a form-filling app. It is a complete AI-powered career ecosystem for Indian students, solving:

- ❌ Students missing opportunities they don't know exist
- ❌ Discovering forms too late  
- ❌ Repeatedly filling the same information
- ❌ Making costly mistakes on applications
- ❌ Not knowing which opportunities they can realistically win
- ❌ Missing deadlines
- ❌ Lacking career guidance

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter Web (web-first, high-graphics) → Android/iOS |
| **Backend** | FastAPI (Python) — 9 microservices |
| **Primary DB** | PostgreSQL 16 |
| **Cache** | Redis 7 |
| **Document Store** | MongoDB 7 |
| **File Storage** | AWS S3 / MinIO (dev) |
| **Event Bus** | Apache Kafka |
| **AI / LLM** | Claude (Anthropic) + OpenAI fallback |
| **Gateway** | Nginx |
| **Monitoring** | Prometheus + Grafana |

## Microservices

```
port 8001  auth-service          JWT, OTP, Google OAuth, Aadhaar
port 8002  profile-service       Career DNA, document management
port 8003  opportunity-service   Discovery, search, eligibility
port 8004  application-service   Form fill, submission, tracking
port 8005  document-service      OCR, extraction, verification
port 8006  agent-service         Marketplace, sessions, KYC
port 8007  notification-service  Push, WhatsApp, SMS, Email
port 8008  ai-service            Career Twin, Form Intelligence, ML
port 8009  payment-service       Razorpay, escrow, payouts
```

## Quick Start

```bash
# Clone and setup
cp .env.example .env
# Edit .env with your API keys

# Start everything
make dev

# Services available at:
# API Gateway:  http://localhost:8000
# Frontend:     http://localhost:8080
# Grafana:      http://localhost:3001  (admin/admin123)
# MinIO:        http://localhost:9001  (minioadmin/minioadmin)
```

## Project Structure

```
fillformai/
├── backend/
│   ├── services/
│   │   ├── auth_service/          # JWT, OTP, OAuth
│   │   ├── profile_service/       # Career DNA
│   │   ├── opportunity_service/   # Discovery engine
│   │   ├── application_service/   # Application lifecycle
│   │   ├── document_service/      # OCR + verification
│   │   ├── agent_service/         # Marketplace
│   │   ├── notification_service/  # Multi-channel alerts
│   │   ├── ai_service/            # All AI modules
│   │   └── payment_service/       # Transactions
│   ├── shared/
│   │   ├── database.py            # DB connections
│   │   ├── middleware/auth.py     # JWT middleware
│   │   ├── models/base.py         # SQLAlchemy base
│   │   ├── config/settings.py     # Pydantic settings
│   │   └── utils/events.py        # Kafka events
│   └── infrastructure/
│       └── docker/                # Nginx, Dockerfile, init.sql
├── frontend/
│   └── lib/
│       ├── core/
│       │   ├── theme/             # Design system
│       │   └── router/            # GoRouter navigation
│       ├── features/
│       │   ├── auth/              # Splash, Onboarding, Login
│       │   ├── dashboard/         # Main dashboard + widgets
│       │   ├── opportunities/     # Discovery + detail
│       │   ├── applications/      # AI-powered form fill
│       │   ├── career_twin/       # AI chat interface
│       │   ├── agents/            # Marketplace
│       │   ├── profile/           # Career DNA editor
│       │   └── documents/         # Document vault
│       └── shared/
│           └── widgets/           # GlassCard, MainShell, etc.
├── ai/
│   ├── form_intelligence/         # Form field mapping engine
│   ├── eligibility_engine/        # Rule-based + ML matching
│   ├── career_twin/               # Claude-powered agent
│   └── skill_analyzer/            # Gap analysis + roadmaps
├── docs/
│   ├── DATABASE_SCHEMA.md
│   └── TEAM_ROADMAP.md
├── docker-compose.yml
├── Makefile
└── .env.example
```

## Design System

The frontend uses a premium dark theme designed for the web-first launch:

- **Colors:** Deep Indigo primary + Amber Gold accent on near-black backgrounds
- **Cards:** Glassmorphism with BackdropFilter blur
- **Typography:** Google Fonts Inter (variable weight)
- **Animations:** flutter_animate with staggered entrance animations
- **Responsive:** Adapts from 360px mobile → ultra-wide desktop
- **Accessibility:** High contrast ratios, semantic labels

## AI Modules

| Module | Purpose | Model |
|--------|---------|-------|
| Career Twin | Personal career advisor chatbot | Claude claude-sonnet-4-6 |
| Form Intelligence Engine | Auto-fill + validation | Claude haiku (classification) + claude-sonnet-4-6 (complex) |
| Eligibility Engine | Rule-based + LLM fallback | Rule engine + Claude haiku |
| Success Predictor | ML probability estimation | Statistical model + proxy signals |
| Skill Gap Analyzer | Identifies career unlock opportunities | Claude claude-sonnet-4-6 |
| Roadmap Generator | Month-by-month career plans | Claude claude-sonnet-4-6 |
| SOP Builder | Personal statement generation | Claude claude-sonnet-4-6 |

## Team Docs

- 📊 [6-Month Roadmap](docs/TEAM_ROADMAP.md)
- 🗄️ [Database Schema](docs/DATABASE_SCHEMA.md)
- 🔑 [Environment Variables](.env.example)
