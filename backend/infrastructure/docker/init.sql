-- FillFormAI PostgreSQL Init Script
-- Enables required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- For fuzzy text search
CREATE EXTENSION IF NOT EXISTS "unaccent"; -- For accent-insensitive search
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- Full-text search configuration for Indian languages
-- (Production: add Hindi/Tamil specific configurations)

COMMENT ON DATABASE fillformai IS 'FillFormAI - India AI Career Operating System';
