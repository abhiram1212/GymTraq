-- GymTraq full schema — current state (run once against a fresh database).
-- For the shared exercise catalog, run seed_exercises.sql afterwards.

CREATE TABLE users (
    user_id     SERIAL PRIMARY KEY,
    email       TEXT NOT NULL UNIQUE,
    password    TEXT NOT NULL,          -- bcrypt hash, never plain text
    weight      NUMERIC,
    height      NUMERIC,
    age         INTEGER,
    sex         TEXT,
    profile_pic TEXT,                   -- base64 JPEG avatar
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE exercises (
    exercise_id   SERIAL PRIMARY KEY,
    exercise_name TEXT NOT NULL,
    muscle_group  TEXT,
    -- NULL = shared seed catalog visible to everyone; otherwise owned by one user
    user_id       INTEGER REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE sessions (
    session_id SERIAL PRIMARY KEY,
    date       DATE NOT NULL,
    notes      TEXT,
    name       TEXT,
    user_id    INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE entries (
    entry_id    SERIAL PRIMARY KEY,
    set_number  INTEGER NOT NULL,
    reps        INTEGER NOT NULL,
    weight      NUMERIC NOT NULL,
    session_id  INTEGER NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
    exercise_id INTEGER NOT NULL REFERENCES exercises(exercise_id)
);

CREATE TABLE ai_chat_messages (
    message_id SERIAL PRIMARY KEY,
    message    TEXT NOT NULL,
    role       TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
    user_id    INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE
);

-- Password-reset OTP codes (bcrypt-hashed, expiring, attempt-limited)
CREATE TABLE password_reset_codes (
    id         SERIAL PRIMARY KEY,
    user_id    INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    code_hash  TEXT NOT NULL,
    attempts   INTEGER NOT NULL DEFAULT 0,
    used       BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Helpful indexes for the app's common lookups
CREATE INDEX idx_sessions_user      ON sessions(user_id);
CREATE INDEX idx_entries_session    ON entries(session_id);
CREATE INDEX idx_entries_exercise   ON entries(exercise_id);
CREATE INDEX idx_chat_user          ON ai_chat_messages(user_id);
CREATE INDEX idx_reset_user         ON password_reset_codes(user_id);
