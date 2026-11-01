-- ThoughtTrace AI -- initial schema.
-- Mirrors the data model in Documentation.txt section 4.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ---------- users ----------
CREATE TABLE users (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email            VARCHAR(255) NOT NULL UNIQUE,
    password_hash    VARCHAR(255) NOT NULL,
    display_name     VARCHAR(100) NOT NULL,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    last_login_at    TIMESTAMPTZ,
    streak_count     INT          NOT NULL DEFAULT 0,
    streak_last_date DATE
);

-- ---------- problems ----------
CREATE TABLE problems (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title                VARCHAR(255) NOT NULL,
    slug                 VARCHAR(255) NOT NULL UNIQUE,
    description          TEXT         NOT NULL,
    difficulty           VARCHAR(10)  NOT NULL CHECK (difficulty IN ('EASY','MEDIUM','HARD')),
    starter_code         TEXT,
    solution_code        TEXT         NOT NULL,
    solution_explanation TEXT,
    time_limit_ms        INT          NOT NULL DEFAULT 2000,
    memory_limit_kb      INT          NOT NULL DEFAULT 262144,
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    is_active            BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_problems_difficulty ON problems (difficulty) WHERE is_active;

-- ---------- skills ----------
CREATE TABLE skills (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name          VARCHAR(100) NOT NULL UNIQUE,
    category      VARCHAR(50)  NOT NULL,
    description   TEXT,
    display_order INT
);

-- ---------- problem_skills ----------
CREATE TABLE problem_skills (
    problem_id UUID    NOT NULL REFERENCES problems (id) ON DELETE CASCADE,
    skill_id   UUID    NOT NULL REFERENCES skills (id) ON DELETE CASCADE,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (problem_id, skill_id)
);

CREATE INDEX idx_problem_skills_skill ON problem_skills (skill_id);

-- ---------- test_cases ----------
CREATE TABLE test_cases (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    problem_id      UUID    NOT NULL REFERENCES problems (id) ON DELETE CASCADE,
    input           TEXT    NOT NULL,
    expected_output TEXT    NOT NULL,
    is_hidden       BOOLEAN NOT NULL DEFAULT FALSE,
    is_sample       BOOLEAN NOT NULL DEFAULT FALSE,
    order_index     INT     NOT NULL DEFAULT 0
);

CREATE INDEX idx_test_cases_problem ON test_cases (problem_id, order_index);

-- ---------- submissions ----------
CREATE TABLE submissions (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    problem_id        UUID        NOT NULL REFERENCES problems (id),
    source_code       TEXT        NOT NULL,
    language          VARCHAR(20) NOT NULL DEFAULT 'java',
    status            VARCHAR(20) NOT NULL CHECK (status IN (
                          'PENDING','COMPILING','RUNNING','ACCEPTED','WRONG_ANSWER',
                          'COMPILE_ERROR','RUNTIME_ERROR','TIME_LIMIT','MEMORY_LIMIT','INTERNAL_ERROR')),
    submitted_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    execution_time_ms INT,
    memory_used_kb    INT,
    was_assisted      BOOLEAN     NOT NULL DEFAULT FALSE,
    assist_level      VARCHAR(10) NOT NULL DEFAULT 'NONE'
                          CHECK (assist_level IN ('NONE','HINT','DEBUG','EXPLAIN','SOLUTION'))
);

CREATE INDEX idx_submissions_user_problem ON submissions (user_id, problem_id, submitted_at DESC);

-- ---------- test_results ----------
CREATE TABLE test_results (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_id     UUID    NOT NULL REFERENCES submissions (id) ON DELETE CASCADE,
    test_case_id      UUID    NOT NULL REFERENCES test_cases (id),
    actual_output     TEXT,
    passed            BOOLEAN NOT NULL,
    execution_time_ms INT,
    error_output      TEXT
);

CREATE INDEX idx_test_results_submission ON test_results (submission_id);

-- ---------- diagnoses ----------
CREATE TABLE diagnoses (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_id           UUID        NOT NULL UNIQUE REFERENCES submissions (id) ON DELETE CASCADE,
    error_category          VARCHAR(50),
    error_subcategory       VARCHAR(50),
    explanation             TEXT        NOT NULL,
    evidence                JSONB       NOT NULL DEFAULT '{}'::jsonb,
    counterexample_input    TEXT,
    counterexample_expected TEXT,
    counterexample_actual   TEXT,
    suggestion              TEXT,
    confidence              NUMERIC(3,2),
    model_used              VARCHAR(50),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------- user_skill_profiles ----------
CREATE TABLE user_skill_profiles (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id               UUID         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    skill_id              UUID         NOT NULL REFERENCES skills (id) ON DELETE CASCADE,
    proficiency_score     NUMERIC(5,2) NOT NULL DEFAULT 0.0,
    total_attempts        INT          NOT NULL DEFAULT 0,
    independent_solves    INT          NOT NULL DEFAULT 0,
    assisted_solves       INT          NOT NULL DEFAULT 0,
    recent_error_patterns JSONB        NOT NULL DEFAULT '[]'::jsonb,
    last_practiced_at     TIMESTAMPTZ,
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, skill_id)
);

-- ---------- daily_recommendations ----------
CREATE TABLE daily_recommendations (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    problem_id       UUID        NOT NULL REFERENCES problems (id),
    recommended_date DATE        NOT NULL,
    rationale        TEXT        NOT NULL,
    target_skill_id  UUID        REFERENCES skills (id),
    was_attempted    BOOLEAN     NOT NULL DEFAULT FALSE,
    was_solved       BOOLEAN     NOT NULL DEFAULT FALSE,
    was_independent  BOOLEAN,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, recommended_date)
);

-- ---------- learning_sessions ----------
CREATE TABLE learning_sessions (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    problem_id        UUID        REFERENCES problems (id),
    started_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at          TIMESTAMPTZ,
    hints_used        INT         NOT NULL DEFAULT 0,
    submissions_count INT         NOT NULL DEFAULT 0,
    outcome           VARCHAR(20) CHECK (outcome IN (
                          'SOLVED_INDEPENDENT','SOLVED_ASSISTED','GAVE_UP','IN_PROGRESS'))
);

CREATE INDEX idx_learning_sessions_user ON learning_sessions (user_id, started_at DESC);

-- ---------- user_feedback ----------
CREATE TABLE user_feedback (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    submission_id     UUID        REFERENCES submissions (id) ON DELETE CASCADE,
    diagnosis_id      UUID        REFERENCES diagnoses (id) ON DELETE CASCADE,
    recommendation_id UUID        REFERENCES daily_recommendations (id) ON DELETE CASCADE,
    feedback_type     VARCHAR(20) NOT NULL CHECK (feedback_type IN ('HELPFUL','UNHELPFUL','INCORRECT','OTHER')),
    comment           TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
