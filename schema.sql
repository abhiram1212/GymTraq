CREATE TABLE users (
    user_id  SERIAL PRIMARY KEY,
    email    TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL,
    weight   NUMERIC,
    height   NUMERIC,
    age      INTEGER,
    sex      TEXT
);

CREATE TABLE exercises (
    exercise_id   SERIAL PRIMARY KEY,
    exercise_name TEXT NOT NULL
);

CREATE TABLE sessions (
    session_id SERIAL PRIMARY KEY,
    date       DATE NOT NULL,
    notes      TEXT,
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
