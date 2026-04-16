# GymTraq - Claude Code Context

## Project Overview
GymTraq is an iOS gym tracking app with an AI coaching feature.

## Tech Stack
- **Backend:** Node.js + Express
- **Database:** PostgreSQL
- **Frontend:** SwiftUI (iOS) - Claude Code handles all frontend code
- **AI:** Claude API

---

## Dependencies
- `express` - web framework
- `pg` - PostgreSQL database client (use raw SQL, no ORM)
- `jsonwebtoken` - JWT generation and verification
- `bcrypt` - password hashing
- `dotenv` - environment variables
- `nodemon` - dev server auto-reload (devDependency)

---

## Project Structure
gymtraq-backend/
├── routes/
│   ├── users.js
│   ├── exercises.js
│   ├── sessions.js
│   ├── entries.js
│   └── aiChat.js
├── controllers/
│   ├── usersController.js
│   ├── exercisesController.js
│   ├── sessionsController.js
│   ├── entriesController.js
│   └── aiChatController.js
├── middleware/
│   └── auth.js
└── app.js

---

## Backend Base URL
http://localhost:3000

---

## Authentication (iOS)
- Store JWT token in device Keychain after login
- On app launch, check Keychain for existing token -- if found, skip login screen
- All requests must include header: `Authorization: Bearer <token>`

---

## iOS App Screens

### 1. Splash Screen
- App logo centered
- Auto-navigates to Login or Home based on stored token

### 2. Auth Screens
- **Login Screen** -- email + password fields, login button, link to signup
- **Signup Screen** -- email + password fields, signup button, link to login

### 3. Home Screen (tab 1)
- Top: greeting with user's email and profile icon (top right)
- Last workout summary card (date + exercises)
- "Log Workout" prominent button -> navigates to Log Workout screen
- Recent sessions list below

### 4. Log Workout Screen
- Create new session (date auto-filled to today, optional notes field)
- Add exercises to the session
- For each exercise: add sets with reps and weight
- Save session button

### 5. Exercises Screen (tab 2)
- List of all exercises
- Search bar to filter
- "Add Exercise" button -> modal with exercise name field

### 6. AI Coach Screen (tab 3)
- Chat interface (bubbles -- user on right, AI on left)
- Message input at bottom with send button
- Full conversation history loaded on open

### 7. Profile Screen (slide in from profile icon top right)
- Shows email, weight, height, age, sex
- Edit button to update details
- Sign out button (clears token, returns to login)

### Navigation
- Bottom tab bar: Home, Exercises, AI Coach
- Profile accessible via icon in top right of Home screen

---

## UI Style
- Dark mode first
- Clean, minimal aesthetic
- Accent color: electric blue (#007AFF)
- Rounded cards for workout summaries
- SF Symbols for icons

## Architecture Patterns
- Routes only define the URL and HTTP method, then hand off to controllers
- Controllers contain all business logic and database queries
- Auth middleware verifies JWT on all protected routes
- Database queries use raw SQL via the `pg` client -- no ORM

---

## Authentication
- Signup and login routes are public (no auth required)
- All other routes are protected by JWT middleware
- Passwords must always be hashed with bcrypt before storing -- never store plain text
- JWT is generated on login and contains the user_id
- Middleware extracts user_id from JWT on every protected request

---

## REST API Routes

### Users (public)
- `POST /users` -- sign up (no auth)
- `POST /users/login` -- login, returns JWT (no auth)

### Users (protected)
- `GET /users/:id` -- get own profile
- `PUT /users/:id` -- update profile
- `DELETE /users/:id` -- delete account

### Exercises (protected)
- `POST /exercises` -- create exercise
- `GET /exercises` -- get all exercises

### Sessions (protected)
- `POST /sessions` -- create session
- `GET /sessions` -- get all sessions for logged-in user
- `PUT /sessions/:id` -- update session
- `DELETE /sessions/:id` -- delete session

### Entries (protected)
- `POST /entries` -- create entry
- `GET /entries` -- get entries
- `PUT /entries/:id` -- update entry
- `DELETE /entries/:id` -- delete entry

### AI Chat (protected)
- `POST /ai-chat` -- send message
- `GET /ai-chat` -- get chat history
- `DELETE /ai-chat/:id` -- delete message

---

## Database Schema

### users
- user_id (PRIMARY KEY, SERIAL)
- email (TEXT, NOT NULL, UNIQUE)
- password (TEXT, NOT NULL) -- always hashed, never plain text
- weight (NUMERIC)
- height (NUMERIC)
- age (INTEGER)
- sex (TEXT)

### exercises
- exercise_id (PRIMARY KEY, SERIAL)
- exercise_name (TEXT, NOT NULL)

### sessions
- session_id (PRIMARY KEY, SERIAL)
- date (DATE, NOT NULL)
- notes (TEXT)
- user_id (FOREIGN KEY -> users, CASCADE DELETE)

### entries
- entry_id (PRIMARY KEY, SERIAL)
- set_number (INTEGER, NOT NULL)
- reps (INTEGER, NOT NULL)
- weight (NUMERIC, NOT NULL)
- session_id (FOREIGN KEY -> sessions, CASCADE DELETE)
- exercise_id (FOREIGN KEY -> exercises)

### ai_chat_messages
- message_id (PRIMARY KEY, SERIAL)
- message (TEXT, NOT NULL)
- role (TEXT, NOT NULL) -- "user" or "assistant"
- user_id (FOREIGN KEY -> users, CASCADE DELETE)

---

## Relationships
- User -> Sessions (one to many)
- Session -> Entries (one to many)
- Exercise -> Entries (one to many)
- User -> AI Chat Messages (one to many)

## Cascading Deletes
- User deleted -> Sessions deleted -> Entries deleted
- User deleted -> AI Chat Messages deleted

---

## Coding Conventions
- Use SERIAL for all auto-incrementing primary keys
- Always add NOT NULL where data is required
- Store passwords as hashed strings (never plain text)
- Use snake_case for all table and column names
- Use raw SQL with pg -- no ORM

---

## Status

**Paused on 2026-04-16.** Resuming later.

## Next Steps (in order)
1. ~~Database schema~~ ✅
2. ~~Backend API~~ ✅
3. ~~AI coaching integration~~ ✅
4. ~~SwiftUI frontend~~ ✅ (core screens complete — see Pending Work below)
5. Deploy

## Pending Work (resume here)
- Test all recent changes end-to-end on device/simulator
- iOS 26 `.glassEffect` — verify it compiles (requires Xcode 26 beta + iOS 26 SDK; fallback to `.ultraThinMaterial` if not available)
- Session detail: confirm notes save correctly after edit propagates back to SessionsView via `onUpdate` callback
- Set renumbering after delete: verify DB updates fire correctly
- Exercise picker in sessions: two-level (muscle group → exercise list → reps/weight form)
- Forgot password: no email verification — resets by email match only (intentional for now, improve later with email OTP)
- Deploy backend (Railway / Render / Fly.io recommended)
- TestFlight distribution

## Pending DB Migrations (run before resuming)
```sql
-- Add session name
ALTER TABLE sessions ADD COLUMN name TEXT;

-- Add muscle group to exercises
ALTER TABLE exercises ADD COLUMN muscle_group TEXT;
```

---

## Completed: Database Schema (schema.sql)

```sql
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
```

---

## Developer Background
- Has backend experience from a previous project (DocMind)
- Familiar with SQL queries, REST endpoints, and system prompts
- SwiftUI frontend will be handled entirely by Claude Code