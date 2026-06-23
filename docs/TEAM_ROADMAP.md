# FillFormAI — 6-Person Team Roadmap (6 Months to Launch)

## Team Structure

| Person | Role | Stack | Responsibilities |
|--------|------|-------|-----------------|
| **P1** | Lead Backend | FastAPI, PostgreSQL, Redis | Auth, Profile, Opportunity services; DB schema; API design |
| **P2** | Backend / Integrations | FastAPI, Kafka, AWS | Application, Document, Payment, Notification services; S3; Twilio/WhatsApp |
| **P3** | Lead Frontend | Flutter Web | Dashboard, Auth, core UI system, routing, state management |
| **P4** | Frontend / UX | Flutter Web | Opportunity pages, Application flow, Agent marketplace UI, animations |
| **P5** | AI / ML Engineer | Python, LangChain, Claude API | Career Twin, Form Intelligence, Eligibility Engine, Skill Analyzer |
| **P6** | DevOps + Full-stack | Docker, K8s, Nginx, Flutter | Infrastructure, CI/CD, Monitoring, Agent service, shared utilities |

---

## Month 1: Foundation (Weeks 1-4)

### Sprint 1 (Week 1-2): Core Infrastructure
| Person | Tasks |
|--------|-------|
| P1 | PostgreSQL schema, Auth service (OTP + Google OAuth), JWT middleware |
| P2 | Docker Compose setup, Kafka topology, S3/MinIO config, Redis setup |
| P3 | Flutter project init, Design system (AppTheme, colors, typography), Router |
| P4 | Glassmorphism components, Splash + Onboarding screens |
| P5 | AI service scaffold, Claude API integration, Career Twin v0 |
| P6 | GitHub Actions CI, nginx gateway config, environment management |

### Sprint 2 (Week 3-4): Auth + Profile
| Person | Tasks |
|--------|-------|
| P1 | Profile service, Career DNA models, Profile CRUD APIs |
| P2 | Document upload service (S3), OCR pipeline (Tesseract) |
| P3 | Login screen (OTP flow, Google OAuth), Profile creation wizard |
| P4 | Document upload UI with drag-and-drop, progress indicators |
| P5 | Document extraction models (Aadhaar, marksheets) |
| P6 | Monitoring (Prometheus + Grafana), log aggregation |

**Month 1 Milestone:** User can sign up, create profile, upload 3 document types ✓

---

## Month 2: Opportunity Engine (Weeks 5-8)

### Sprint 3 (Week 5-6): Opportunity Database
| Person | Tasks |
|--------|-------|
| P1 | Opportunity service, search API (full-text), eligibility filter API |
| P2 | Opportunity scraper (50 UP/Bihar scholarships), data pipeline |
| P3 | Dashboard screen (all widgets), Main shell (side nav + bottom nav) |
| P4 | Opportunity list page (search, filters, cards), Detail page |
| P5 | AI Eligibility Engine v1 (rule-based + LLM fallback) |
| P6 | Opportunity scraper scheduler (Celery/APScheduler), data quality |

### Sprint 4 (Week 7-8): Matching & Discovery
| Person | Tasks |
|--------|-------|
| P1 | Opportunity-Student matching API, save/unsave endpoints |
| P2 | Notification service (push + SMS via Twilio) |
| P3 | Daily briefing card, Trust score UI, Deadline timeline |
| P4 | Opportunity filter UI refinement, saved opportunities screen |
| P5 | Success Probability Predictor v1 |
| P6 | WhatsApp notification pipeline (pending API approval) |

**Month 2 Milestone:** 1,000 real opportunities in DB, eligibility matching working, notifications sent ✓

---

## Month 3: Application Engine (Weeks 9-12)

### Sprint 5 (Week 9-10): Form Intelligence
| Person | Tasks |
|--------|-------|
| P1 | Application service (CRUD, status tracking), form schema extractor |
| P2 | Payment service (Razorpay integration), escrow logic |
| P3 | Application stepper UI, AI fill progress animation |
| P4 | Form field components with AI confidence badges |
| P5 | Form Intelligence Engine v1 (80 form fields mapped), validation engine |
| P6 | End-to-end testing framework, load testing (Locust) |

### Sprint 6 (Week 11-12): Error Prevention + Submission
| Person | Tasks |
|--------|-------|
| P1 | Pre-submission validation API, application history API |
| P2 | Application tracking (outcome recording pipeline) |
| P3 | Error prevention UI (modal dialogs, inline errors, confidence display) |
| P4 | Application history screen, status tracking UI |
| P5 | Error Prevention Engine (pattern-based + LLM), SOP Builder v1 |
| P6 | Form scraper for top 20 government portals |

**Month 3 Milestone:** End-to-end application flow working for 5 test scholarships ✓

---

## Month 4: Agent Marketplace (Weeks 13-16)

### Sprint 7 (Week 13-14): Agent Onboarding
| Person | Tasks |
|--------|-------|
| P1 | Agent service (profile, KYC, badge system, rating), session management |
| P2 | Agent payment split (Razorpay route), earnings dashboard API |
| P3 | Agent list screen, agent profile page |
| P4 | Session booking UI, video call integration (Agora) |
| P5 | Skill Gap Analyzer v1 |
| P6 | Agent KYC pipeline (DigiLocker integration), fraud detection rules |

### Sprint 8 (Week 15-16): Trust System
| Person | Tasks |
|--------|-------|
| P1 | Trust Score service (computation, storage, display) |
| P2 | Session recording storage (S3, 30-day retention) |
| P3 | Trust score widget, Application Confidence Score UI |
| P4 | Agent session UI (pre/during/post session flow) |
| P5 | Trust Engine (anomaly detection for fraud) |
| P6 | Dispute resolution workflow, audit log system |

**Month 4 Milestone:** 50 agent beta testers onboarded, 100 test sessions completed ✓

---

## Month 5: AI Career Twin + Polish (Weeks 17-20)

### Sprint 9 (Week 17-18): Career Twin
| Person | Tasks |
|--------|-------|
| P1 | Conversation history API, Career goals API, Roadmap CRUD |
| P2 | Roadmap PDF generation, Email delivery (SendGrid) |
| P3 | Career Twin chat screen (streaming responses, action buttons) |
| P4 | Goal setting UI, Career roadmap visualization |
| P5 | Career Twin v2 (streaming, multi-turn memory, vernacular), Roadmap Generator |
| P6 | LLM cost tracking, inference optimization, caching strategies |

### Sprint 10 (Week 19-20): Vernacular + Performance
| Person | Tasks |
|--------|-------|
| P1 | Language preferences API, i18n support |
| P2 | WhatsApp bot integration (career twin over WhatsApp) |
| P3 | Hindi UI support (RTL considerations, font), performance optimization |
| P4 | Animations polish, loading states, error states, empty states |
| P5 | Hindi Career Twin fine-tuning, UP/Bihar scholarship domain knowledge |
| P6 | CDN setup (CloudFront), image optimization, bundle size reduction |

**Month 5 Milestone:** Career Twin working in Hindi + English, NPS >50 from beta users ✓

---

## Month 6: Launch (Weeks 21-24)

### Sprint 11 (Week 21-22): Beta & Fixes
- Beta launch with 500 students in 3 UP districts
- Daily NPS surveys, bug bash
- Performance testing (1,000 concurrent users)
- Security audit

### Sprint 12 (Week 23-24): Production Launch
- Public launch announcement
- App Store submission (Android first)
- Press & PR
- Agent recruitment drive
- Government partnership outreach begins

---

## Key Technical Decisions

### Why Flutter Web First?
- Single codebase → mobile app in weeks, not months
- Canvas rendering = pixel-perfect custom UI impossible in HTML/CSS
- Dart is type-safe, reduces bugs at scale
- Trade-off: slightly larger initial bundle (mitigated with canvaskit + lazy loading)

### Why FastAPI Microservices?
- Python: best AI/ML library ecosystem
- Async-first: handles 10K+ concurrent requests per instance
- Each service deployable independently → zero-downtime deployments
- Trade-off: more complex than monolith — justified at 100K+ users

### Why Claude for Career Twin?
- Best instruction-following for complex, multi-step career reasoning
- Strong Hindi/Indic language understanding
- Tool-use capability for structured outputs
- Cost: ~₹0.15/conversation, offset by premium subscription

### Why Kafka?
- Decouples services completely (notification doesn't block application)
- Replay capability for recovery
- Foundation for analytics pipeline
- Trade-off: operational complexity — use managed MSK in production

---

## Cost Estimates (Monthly, at MVP scale — 10K MAU)

| Category | Monthly Cost |
|----------|-------------|
| AWS (2 EC2 + RDS + S3) | ₹40,000 |
| Anthropic API (AI features) | ₹15,000 |
| Twilio OTP/SMS | ₹8,000 |
| WhatsApp API | ₹5,000 |
| Razorpay (payment processing) | ₹3,000 |
| Monitoring (DataDog/Grafana) | ₹5,000 |
| **Total** | **~₹76,000/month** |

At 1K agent sessions/month × ₹200 avg × 20% = ₹40,000 revenue
At 500 Pro subscribers × ₹99 = ₹49,500 revenue
**Total Revenue: ₹89,500 → approaching break-even at MVP scale**
