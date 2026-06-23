# FillFormAI — Complete PostgreSQL Database Schema

## Core Tables

### users
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | gen_random_uuid() |
| phone | VARCHAR(15) | UNIQUE, indexed |
| email | VARCHAR(255) | UNIQUE, nullable |
| full_name | VARCHAR(255) | NOT NULL |
| hashed_password | VARCHAR(255) | nullable (OAuth users) |
| role | ENUM | student\|agent\|admin\|institution |
| auth_provider | ENUM | email\|google\|phone\|digilocker |
| is_active | BOOLEAN | DEFAULT true |
| is_verified | BOOLEAN | DEFAULT false |
| is_aadhaar_verified | BOOLEAN | DEFAULT false |
| aadhaar_last4 | VARCHAR(4) | encrypted |
| google_id | VARCHAR(255) | UNIQUE, nullable |
| last_login_at | TIMESTAMPTZ | |
| login_count | INTEGER | DEFAULT 0 |
| preferred_language | VARCHAR(10) | DEFAULT 'en' |
| fcm_token | TEXT | push notifications |
| whatsapp_opted_in | BOOLEAN | DEFAULT false |
| metadata_ | JSONB | extensible |
| created_at | TIMESTAMPTZ | server_default now() |
| updated_at | TIMESTAMPTZ | auto-updated |

### career_dna
Stores the complete structured career profile for each student.
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | UUID FK→users | UNIQUE |
| full_name | VARCHAR(255) | from Aadhaar |
| date_of_birth | DATE | |
| gender | VARCHAR(10) | |
| category | VARCHAR(20) | SC\|ST\|OBC\|OBC-NCL\|EWS\|General |
| education_level | VARCHAR(50) | 10th\|10+2\|Graduate\|etc |
| stream | VARCHAR(100) | Science\|Commerce\|Arts\|etc |
| board | VARCHAR(100) | CBSE\|ICSE\|UP Board\|etc |
| institution_name | VARCHAR(255) | |
| marks_10th_percent | FLOAT | |
| marks_12th_percent | FLOAT | |
| cgpa | FLOAT | for college students |
| passing_year | INTEGER | |
| state | VARCHAR(50) | |
| district | VARCHAR(100) | |
| address | JSONB | {line1, city, pincode} |
| family_income_annual | BIGINT | in INR |
| father_name | VARCHAR(255) | |
| mother_name | VARCHAR(255) | |
| bank_details | JSONB | encrypted {account, ifsc, bank_name} |
| skills | JSONB | array of skill strings |
| career_goals | JSONB | array of goal strings |
| age | INTEGER | computed |
| is_first_gen_student | BOOLEAN | |
| is_disability | BOOLEAN | |
| disability_type | VARCHAR(100) | |
| completeness_score | FLOAT | 0-1, computed |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

### documents
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | UUID FK→users | indexed |
| document_type | VARCHAR(100) | aadhaar\|10th_marksheet\|etc |
| file_name | VARCHAR(255) | |
| s3_key | TEXT | encrypted path |
| file_size_bytes | INTEGER | |
| mime_type | VARCHAR(100) | |
| verification_status | ENUM | unverified\|ai_verified\|digilocker\|agent_verified |
| verification_confidence | FLOAT | 0-1 |
| extracted_data | JSONB | AI-extracted structured data |
| expires_at | DATE | for dated documents |
| is_expired | BOOLEAN | computed |
| created_at | TIMESTAMPTZ | |

### opportunities
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| title | VARCHAR(500) | full-text indexed |
| short_description | VARCHAR(1000) | |
| full_description | TEXT | |
| category | ENUM | scholarship\|government_job\|etc |
| subcategory | VARCHAR(100) | |
| issuing_authority | VARCHAR(255) | |
| portal_url | TEXT | |
| application_url | TEXT | |
| open_date | DATE | |
| deadline | DATE | indexed |
| result_date | DATE | |
| amount_min | FLOAT | |
| amount_max | FLOAT | |
| currency | VARCHAR(3) | DEFAULT 'INR' |
| status | ENUM | active\|upcoming\|closed\|draft |
| is_verified | BOOLEAN | human-verified |
| verification_confidence | FLOAT | AI confidence |
| eligibility_rules | JSONB | structured rules |
| documents_required | JSONB | array |
| difficulty_score | FLOAT | 0-1 |
| competition_score | FLOAT | 0-1 |
| total_applicants | INTEGER | nationwide |
| total_seats | INTEGER | |
| platform_applicants | INTEGER | via FillFormAI |
| platform_success_count | INTEGER | outcomes |
| tags | JSONB | array |
| source | VARCHAR(100) | scraped\|manual\|api |
| form_schema | JSONB | extracted form fields |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

### applications
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | UUID FK→users | indexed |
| opportunity_id | UUID FK→opportunities | indexed |
| status | ENUM | draft\|in_progress\|submitted\|accepted\|rejected\|pending |
| ai_fill_percent | FLOAT | how much AI filled |
| completeness_score | FLOAT | |
| success_probability | FLOAT | at time of submission |
| submitted_at | TIMESTAMPTZ | |
| outcome | VARCHAR(50) | accepted\|rejected\|waitlisted |
| outcome_date | DATE | |
| amount_received | BIGINT | if scholarship won |
| agent_session_id | UUID FK→agent_sessions | nullable |
| form_data | JSONB | encrypted filled values |
| validation_result | JSONB | pre-submission check result |
| error_log | JSONB | any errors encountered |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

### agents
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | UUID FK→users | |
| display_name | VARCHAR(255) | |
| bio | TEXT | |
| city | VARCHAR(100) | |
| state | VARCHAR(50) | |
| languages | JSONB | array |
| specializations | JSONB | array |
| kyc_status | ENUM | pending\|verified\|rejected |
| aadhaar_verified | BOOLEAN | |
| pan_verified | BOOLEAN | |
| badge_tier | ENUM | bronze\|silver\|gold\|platinum |
| trust_score | FLOAT | 0-100 |
| avg_rating | FLOAT | |
| total_sessions | INTEGER | |
| total_earnings_inr | BIGINT | |
| is_available | BOOLEAN | |
| hourly_rate_inr | INTEGER | |
| response_time_minutes | INTEGER | avg |
| created_at | TIMESTAMPTZ | |

### agent_sessions
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| agent_id | UUID FK→agents | |
| student_id | UUID FK→users | |
| opportunity_id | UUID FK→opportunities | nullable |
| status | ENUM | requested\|accepted\|in_progress\|completed\|cancelled\|disputed |
| session_type | VARCHAR(50) | form_fill\|counseling\|document_prep |
| scheduled_at | TIMESTAMPTZ | |
| started_at | TIMESTAMPTZ | |
| ended_at | TIMESTAMPTZ | |
| duration_minutes | INTEGER | |
| total_fee_inr | INTEGER | |
| platform_fee_inr | INTEGER | 20% |
| agent_earnings_inr | INTEGER | |
| student_rating | INTEGER | 1-5 |
| student_review | TEXT | |
| agent_notes | TEXT | |
| recording_url | TEXT | encrypted, 30-day retention |
| payment_id | UUID FK→payments | |
| created_at | TIMESTAMPTZ | |

### notifications
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | UUID FK→users | indexed |
| type | VARCHAR(100) | opportunity_alert\|deadline\|etc |
| channel | ENUM | push\|whatsapp\|sms\|email\|in_app |
| title | VARCHAR(255) | |
| body | TEXT | |
| data | JSONB | deep link data |
| status | ENUM | pending\|sent\|delivered\|read\|failed |
| sent_at | TIMESTAMPTZ | |
| read_at | TIMESTAMPTZ | |
| opportunity_id | UUID | nullable |
| created_at | TIMESTAMPTZ | |

### trust_scores
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | UUID FK→users | UNIQUE |
| total_score | FLOAT | 0-100 |
| identity_score | FLOAT | Aadhaar, email, phone |
| document_score | FLOAT | document completeness |
| activity_score | FLOAT | engagement |
| outcome_score | FLOAT | application success |
| community_score | FLOAT | referrals, reports |
| tier | ENUM | new\|bronze\|silver\|gold\|platinum |
| last_computed_at | TIMESTAMPTZ | |

### payments
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | UUID FK→users | |
| amount_inr | INTEGER | in paise |
| currency | VARCHAR(3) | INR |
| type | ENUM | agent_session\|subscription\|premium |
| status | ENUM | pending\|authorized\|captured\|failed\|refunded |
| razorpay_order_id | VARCHAR(100) | |
| razorpay_payment_id | VARCHAR(100) | |
| metadata | JSONB | |
| created_at | TIMESTAMPTZ | |

### audit_logs (IMMUTABLE — append only)
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | UUID | actor |
| action | VARCHAR(100) | |
| entity_type | VARCHAR(50) | |
| entity_id | UUID | |
| old_value | JSONB | |
| new_value | JSONB | |
| ip_address | INET | |
| user_agent | TEXT | |
| service | VARCHAR(50) | which microservice |
| created_at | TIMESTAMPTZ | |

## Indexes
```sql
-- Full-text search on opportunities
CREATE INDEX idx_opportunities_fts ON opportunities USING gin(to_tsvector('english', title || ' ' || coalesce(short_description, '')));

-- JSONB eligibility rules (for eligibility filtering)
CREATE INDEX idx_opp_eligibility_states ON opportunities USING gin((eligibility_rules->'states_allowed'));
CREATE INDEX idx_opp_eligibility_categories ON opportunities USING gin((eligibility_rules->'categories'));

-- Trigram search for agent names
CREATE INDEX idx_agents_name_trgm ON agents USING gin(display_name gin_trgm_ops);

-- Composite indexes
CREATE INDEX idx_applications_user_status ON applications(user_id, status);
CREATE INDEX idx_notifications_user_unread ON notifications(user_id, status) WHERE status = 'pending';
CREATE INDEX idx_opportunities_active_deadline ON opportunities(deadline) WHERE status = 'active';
```
