-- FillFormAI PostgreSQL Init Script
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "unaccent";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

COMMENT ON DATABASE fillformai IS 'FillFormAI - India AI Career Operating System';

-- ── Users ──────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone                   VARCHAR(15) UNIQUE NOT NULL,
    email                   VARCHAR(255) UNIQUE,
    full_name               VARCHAR(255),
    dob                     DATE,
    gender                  VARCHAR(20),
    state                   VARCHAR(100),
    district                VARCHAR(100),
    pincode                 VARCHAR(10),
    category                VARCHAR(20),    -- general|obc|sc|st|ews
    religion                VARCHAR(50),
    disability_type         VARCHAR(100),
    is_minority             BOOLEAN DEFAULT FALSE,
    education_level         VARCHAR(50),    -- 10th|12th|diploma|ug|pg|phd
    institution_name        VARCHAR(255),
    board_or_university     VARCHAR(255),
    marks_10th_percent      NUMERIC(5,2),
    marks_12th_percent      NUMERIC(5,2),
    stream                  VARCHAR(50),    -- science|arts|commerce
    course_name             VARCHAR(255),
    current_year_of_study   SMALLINT,
    passing_year            SMALLINT,
    father_name             VARCHAR(255),
    father_occupation       VARCHAR(255),
    mother_name             VARCHAR(255),
    mother_occupation       VARCHAR(255),
    family_income_annual    INTEGER,
    number_of_siblings      SMALLINT,
    is_bpl                  BOOLEAN DEFAULT FALSE,
    ration_card_type        VARCHAR(20),
    career_goal             TEXT,
    skills                  TEXT[],
    languages_known         TEXT[] DEFAULT ARRAY['Hindi'],
    fcm_token               VARCHAR(500),
    whatsapp_opted_in       BOOLEAN DEFAULT TRUE,
    preferred_language      VARCHAR(10) DEFAULT 'hi',
    profile_photo_url       VARCHAR(500),
    role                    VARCHAR(20) DEFAULT 'student',  -- student|admin|agent
    is_active               BOOLEAN DEFAULT TRUE,
    last_login_at           TIMESTAMPTZ,
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    updated_at              TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
CREATE INDEX IF NOT EXISTS idx_users_state_district ON users(state, district);
CREATE INDEX IF NOT EXISTS idx_users_category ON users(category);

-- ── OTP ───────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS otp_records (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone       VARCHAR(15) NOT NULL,
    otp_hash    VARCHAR(255) NOT NULL,
    expires_at  TIMESTAMPTZ NOT NULL,
    used        BOOLEAN DEFAULT FALSE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_otp_phone ON otp_records(phone);

-- ── Sessions ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    refresh_token   VARCHAR(500) UNIQUE NOT NULL,
    expires_at      TIMESTAMPTZ NOT NULL,
    device_info     JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON user_sessions(refresh_token);

-- ── Opportunities ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS opportunities (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title               VARCHAR(500) NOT NULL,
    category            VARCHAR(50) NOT NULL,    -- scholarship|government_job|internship|loan|skill_program
    description         TEXT,
    eligibility_criteria JSONB DEFAULT '{}',
    amount              INTEGER,                 -- INR
    deadline            DATE,
    issuing_authority   VARCHAR(255),
    portal_url          VARCHAR(500),
    state               VARCHAR(100),            -- null = national
    level               VARCHAR(20),             -- national|state|district
    source_url          VARCHAR(500),
    last_verified_at    TIMESTAMPTZ,
    is_active           BOOLEAN DEFAULT TRUE,
    max_applications    INTEGER,
    tags                TEXT[],
    eligibility_summary TEXT[],
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Extra columns used by opportunity_service's richer ORM model (eligibility
-- engine, scraper pipeline, AI scoring). Kept alongside the original simple
-- columns (amount, is_active, eligibility_criteria) which application_service
-- and other services query directly with raw SQL — the scraper writes both.
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS short_description VARCHAR(1000);
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS full_description TEXT;
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS subcategory VARCHAR(100);
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS application_url VARCHAR(500);
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS open_date DATE;
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS result_date DATE;
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS amount_min NUMERIC(12,2);
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS amount_max NUMERIC(12,2);
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS currency VARCHAR(3) DEFAULT 'INR';
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active';
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS verification_confidence NUMERIC(4,3) DEFAULT 0;
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS eligibility_rules JSONB DEFAULT '{}';
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS documents_required JSONB DEFAULT '[]';
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS difficulty_score NUMERIC(4,3) DEFAULT 0.5;
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS competition_score NUMERIC(4,3) DEFAULT 0.5;
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS total_applicants INTEGER DEFAULT 0;
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS total_seats INTEGER;
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS platform_applicants INTEGER DEFAULT 0;
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS platform_success_count INTEGER DEFAULT 0;
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS source VARCHAR(100);
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS last_scraped_at VARCHAR(50);
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS form_schema JSONB DEFAULT '{}';
ALTER TABLE opportunities ADD COLUMN IF NOT EXISTS raw_content TEXT;

-- opportunity_service's ORM model treats tags/eligibility_summary as JSONB
-- (to match eligibility_rules/documents_required); convert from the
-- original TEXT[] columns.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'opportunities' AND column_name = 'tags' AND data_type = 'ARRAY'
    ) THEN
        ALTER TABLE opportunities ALTER COLUMN tags TYPE JSONB USING to_jsonb(tags);
        ALTER TABLE opportunities ALTER COLUMN tags SET DEFAULT '[]';
    END IF;
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'opportunities' AND column_name = 'eligibility_summary' AND data_type = 'ARRAY'
    ) THEN
        ALTER TABLE opportunities ALTER COLUMN eligibility_summary TYPE JSONB USING to_jsonb(eligibility_summary);
        ALTER TABLE opportunities ALTER COLUMN eligibility_summary SET DEFAULT '[]';
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_opp_category ON opportunities(category);
CREATE INDEX IF NOT EXISTS idx_opp_state ON opportunities(state);
CREATE INDEX IF NOT EXISTS idx_opp_deadline ON opportunities(deadline);
CREATE INDEX IF NOT EXISTS idx_opp_active ON opportunities(is_active);
CREATE INDEX IF NOT EXISTS idx_opp_status ON opportunities(status);
CREATE INDEX IF NOT EXISTS idx_opp_source ON opportunities(source);
CREATE INDEX IF NOT EXISTS idx_opp_title_fts ON opportunities USING GIN (to_tsvector('english', title));

-- ── Bookmarks ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS opportunity_bookmarks (
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    opportunity_id  UUID REFERENCES opportunities(id) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, opportunity_id)
);

-- opportunity_service's ORM model uses dedicated view/save tables (distinct
-- from the simpler opportunity_bookmarks table above used elsewhere).
CREATE TABLE IF NOT EXISTS opportunity_views (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    opportunity_id  UUID NOT NULL,
    user_id         UUID NOT NULL,
    source          VARCHAR(50),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_opp_views_opp ON opportunity_views(opportunity_id);
CREATE INDEX IF NOT EXISTS idx_opp_views_user ON opportunity_views(user_id);

CREATE TABLE IF NOT EXISTS opportunity_saves (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    opportunity_id  UUID NOT NULL,
    user_id         UUID NOT NULL,
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_opp_saves_opp ON opportunity_saves(opportunity_id);
CREATE INDEX IF NOT EXISTS idx_opp_saves_user ON opportunity_saves(user_id);

-- ── Applications ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS applications (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID REFERENCES users(id) ON DELETE CASCADE,
    opportunity_id      UUID REFERENCES opportunities(id),
    status              VARCHAR(30) DEFAULT 'submitted',
    form_data           JSONB DEFAULT '{}',
    registration_number VARCHAR(100),
    notes               TEXT,
    rejection_reason    TEXT,
    submitted_at        TIMESTAMPTZ DEFAULT NOW(),
    outcome_date        DATE,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_apps_user ON applications(user_id);
CREATE INDEX IF NOT EXISTS idx_apps_status ON applications(status);
CREATE INDEX IF NOT EXISTS idx_apps_opp ON applications(opportunity_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_apps_user_opp ON applications(user_id, opportunity_id)
    WHERE status NOT IN ('withdrawn');

-- ── Documents ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS documents (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    document_type   VARCHAR(100) NOT NULL,
    file_name       VARCHAR(500),
    s3_key          VARCHAR(1000),
    expires_at      DATE,
    is_verified     BOOLEAN DEFAULT FALSE,
    is_expired      BOOLEAN DEFAULT FALSE,
    uploaded_at     TIMESTAMPTZ DEFAULT NOW(),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_docs_user ON documents(user_id);
CREATE INDEX IF NOT EXISTS idx_docs_expiry ON documents(expires_at) WHERE is_expired = FALSE;

-- ── Application Documents ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS application_documents (
    application_id  UUID REFERENCES applications(id) ON DELETE CASCADE,
    document_id     UUID REFERENCES documents(id) ON DELETE CASCADE,
    attached_at     TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (application_id, document_id)
);

-- ── Notifications ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
    type        VARCHAR(50) NOT NULL,
    channel     VARCHAR(20) NOT NULL,   -- push|whatsapp|sms|in_app
    title       VARCHAR(255),
    body        TEXT,
    data        JSONB DEFAULT '{}',
    status      VARCHAR(20) DEFAULT 'pending',
    sent_at     TIMESTAMPTZ,
    read_at     TIMESTAMPTZ,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notif_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notif_status ON notifications(status);
CREATE INDEX IF NOT EXISTS idx_notif_data ON notifications USING GIN (data);

-- ── Agents ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS agents (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                 UUID REFERENCES users(id),
    full_name               VARCHAR(255) NOT NULL,
    bio                     TEXT,
    profile_photo_url       VARCHAR(500),
    phone                   VARCHAR(15),
    specializations         TEXT[],
    languages               TEXT[] DEFAULT ARRAY['Hindi'],
    districts_covered       TEXT[],
    fee_per_session         INTEGER DEFAULT 99,
    average_rating          NUMERIC(3,2),
    total_reviews           INTEGER DEFAULT 0,
    total_sessions          INTEGER DEFAULT 0,
    is_verified             BOOLEAN DEFAULT FALSE,
    is_active               BOOLEAN DEFAULT TRUE,
    is_online               BOOLEAN DEFAULT FALSE,
    response_time_minutes   INTEGER DEFAULT 60,
    available_session_types TEXT[] DEFAULT ARRAY['phone_call', 'video_call'],
    created_at              TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_agents_verified ON agents(is_verified, is_active);
CREATE INDEX IF NOT EXISTS idx_agents_rating ON agents(average_rating DESC);

-- ── Agent Sessions ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS agent_sessions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id          UUID REFERENCES users(id),
    agent_id            UUID REFERENCES agents(id),
    session_type        VARCHAR(30),
    scheduled_at        TIMESTAMPTZ,
    duration_minutes    INTEGER DEFAULT 30,
    issue_description   TEXT,
    documents_needed    JSONB DEFAULT '[]',
    preferred_language  VARCHAR(10) DEFAULT 'hi',
    fee_amount          INTEGER DEFAULT 0,
    payment_status      VARCHAR(20) DEFAULT 'pending',
    status              VARCHAR(20) DEFAULT 'pending',
    meeting_link        VARCHAR(500),
    notes               TEXT,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_agent_sessions_student ON agent_sessions(student_id);
CREATE INDEX IF NOT EXISTS idx_agent_sessions_agent ON agent_sessions(agent_id);

-- ── Agent Reviews ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS agent_reviews (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id  UUID REFERENCES agent_sessions(id),
    agent_id    UUID REFERENCES agents(id),
    student_id  UUID REFERENCES users(id),
    rating      SMALLINT CHECK (rating BETWEEN 1 AND 5),
    review      TEXT,
    tags        JSONB DEFAULT '[]',
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ── Payment Orders ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payment_orders (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID REFERENCES users(id),
    razorpay_order_id   VARCHAR(100) UNIQUE,
    razorpay_payment_id VARCHAR(100),
    amount_paise        INTEGER NOT NULL,
    currency            VARCHAR(5) DEFAULT 'INR',
    purpose             VARCHAR(50),
    reference_id        VARCHAR(255),
    status              VARCHAR(20) DEFAULT 'created',
    paid_at             TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payments_user ON payment_orders(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payment_orders(status);

-- ── Subscriptions ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS subscriptions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES users(id) UNIQUE,
    plan        VARCHAR(50) NOT NULL,
    started_at  TIMESTAMPTZ DEFAULT NOW(),
    expires_at  DATE,
    status      VARCHAR(20) DEFAULT 'active'
);

-- ── Seed Sample Opportunities ─────────────────────────────────────────────────
INSERT INTO opportunities (title, category, description, amount, deadline, issuing_authority, state, level, portal_url, eligibility_summary, is_active)
VALUES
(
    'National Scholarship Portal - Post Matric Scholarship (SC)',
    'scholarship',
    'Post-matric scholarship for SC students pursuing studies after class 10. Covers tuition fees and maintenance allowance.',
    25000,
    '2025-10-31',
    'Ministry of Social Justice & Empowerment',
    NULL,
    'national',
    'https://scholarships.gov.in',
    to_jsonb(ARRAY['SC category', 'Post-matric (11th onwards)', 'Family income < ₹2.5 lakh/year', 'Not availing other scholarship']),
    TRUE
),
(
    'UP Scholarship (Dashmottar) - Post Matric',
    'scholarship',
    'Post-matric scholarship for students in Uttar Pradesh belonging to OBC/SC/ST/General (minority) categories.',
    15000,
    '2025-11-15',
    'UP Scholarship & Fee Reimbursement Online System',
    'Uttar Pradesh',
    'state',
    'https://scholarship.up.gov.in',
    to_jsonb(ARRAY['UP domicile required', 'Post-matric students', 'OBC/SC/ST/Minority', 'Income limit varies by category']),
    TRUE
),
(
    'Prime Minister''s Scholarship Scheme (PMSS) - WARB',
    'scholarship',
    'Scholarship for wards of ex-servicemen/coast guard personnel. ₹2500/month for boys, ₹3000/month for girls.',
    36000,
    '2025-09-30',
    'Kendriya Sainik Board',
    NULL,
    'national',
    'https://ksb.gov.in/pm-scholarship',
    to_jsonb(ARRAY['Ward of ex-serviceman/coast guard', 'Minimum 60% in qualifying exam', 'Age: 18-25 years', 'First professional degree']),
    TRUE
),
(
    'Begum Hazrat Mahal National Scholarship (Minority Girls)',
    'scholarship',
    'Scholarship for meritorious girls from minority communities studying in class 9-12.',
    10000,
    '2025-10-15',
    'Maulana Azad Education Foundation',
    NULL,
    'national',
    'https://scholarships.gov.in',
    to_jsonb(ARRAY['Girl student', 'Muslim/Christian/Sikh/Buddhist/Jain/Parsi minority', 'Class 9-12', 'Min 50% in previous class', 'Income < ₹2 lakh/year']),
    TRUE
),
(
    'SSC Combined Graduate Level (CGL) Examination 2025',
    'government_job',
    'Annual recruitment by SSC for various Group B & C posts including Inspector, Auditor, Accountant, etc. across central govt ministries.',
    NULL,
    '2025-08-31',
    'Staff Selection Commission',
    NULL,
    'national',
    'https://ssc.nic.in',
    to_jsonb(ARRAY['Graduate in any discipline', 'Age: 18-32 years (relaxation for reserved categories)', 'Indian citizen', 'Physical standards for some posts']),
    TRUE
),
(
    'PM YASASVI Scholarship for OBC/EBC/DNT Students',
    'scholarship',
    'Top Class Education Scheme for OBC, EBC and DNT students in class 9 & 11.',
    75000,
    '2025-09-30',
    'Ministry of Social Justice & Empowerment',
    NULL,
    'national',
    'https://yet.nta.ac.in',
    to_jsonb(ARRAY['OBC/EBC/DNT category', 'Class 9 or 11 students', 'Family income < ₹2.5 lakh/year', 'Must appear in YASASVI exam']),
    TRUE
),
(
    'Mukhyamantri Abhyudaya Yojana - UP Free Coaching',
    'skill_program',
    'Free coaching for competitive exams (IAS, IPS, PCS, NDA, CDS, SSC, JEE, NEET) for UP youth.',
    0,
    NULL,
    'UP Government',
    'Uttar Pradesh',
    'state',
    'https://abhyuday.up.gov.in',
    to_jsonb(ARRAY['UP domicile', 'Age: 16-40 years (varies by exam)', 'Preparing for competitive exams', 'Family income < ₹5 lakh/year preferred']),
    TRUE
),
(
    'AICTE Pragati Scholarship for Technical Education (Girls)',
    'scholarship',
    'Scholarship for girl students pursuing technical education (Diploma/Degree in AICTE approved institutions).',
    50000,
    '2025-10-31',
    'AICTE',
    NULL,
    'national',
    'https://scholarships.gov.in',
    to_jsonb(ARRAY['Girl student', 'Diploma or Degree in AICTE approved institution', 'Family income < ₹8 lakh/year', 'One scholarship per family']),
    TRUE
)
ON CONFLICT DO NOTHING;

-- Seed a sample verified agent
INSERT INTO agents (full_name, bio, phone, specializations, languages, districts_covered, fee_per_session, is_verified, is_active, is_online, response_time_minutes, available_session_types)
VALUES
(
    'Rajesh Kumar Gupta',
    'Former bank employee with 10 years of experience helping students with NSP, UP Scholarship, and PFMS issues. Helped 500+ students get scholarships.',
    '+919876543210',
    ARRAY['nsp', 'up_scholarship', 'pfms', 'document_renewal'],
    ARRAY['Hindi', 'English'],
    ARRAY['Lucknow', 'Unnao', 'Kanpur'],
    99,
    TRUE, TRUE, TRUE, 30,
    ARRAY['phone_call', 'video_call', 'in_person']
),
(
    'Priya Sharma',
    'Social worker specializing in government scheme awareness. Fluent in Hindi and helps with income/caste/domicile certificate renewal.',
    '+919765432109',
    ARRAY['document_renewal', 'college_admission', 'aadhaar'],
    ARRAY['Hindi'],
    ARRAY['Varanasi', 'Allahabad', 'Mirzapur'],
    79,
    TRUE, TRUE, FALSE, 60,
    ARRAY['phone_call', 'video_call']
)
ON CONFLICT DO NOTHING;
