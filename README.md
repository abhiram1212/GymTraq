# GymTraq

A personal iOS gym tracking app with an AI coaching feature. Built with SwiftUI on the frontend and Node.js + PostgreSQL on the backend.

---

## Tech Stack

| Layer    | Technology                        |
|----------|-----------------------------------|
| iOS App  | SwiftUI, `@Observable`, iOS 26    |
| Backend  | Node.js, Express                  |
| Database | PostgreSQL (raw SQL, no ORM)      |
| Auth     | JWT (jsonwebtoken) + bcrypt       |
| AI       | Claude API (Anthropic)            |

---

## Features

### Workouts
- Log workout sessions with a custom name (defaults to time-of-day, e.g. "Monday Morning")
- Add exercises to a session via a two-level picker: muscle group → exercise
- Track sets with reps and weight per exercise
- Auto-increment set numbers; renumbers remaining sets when one is deleted
- Edit session name, date, and notes after logging
- Swipe to delete a session (with confirmation dialog)
- Per-exercise context menu: Move Up / Move Down / Replace Exercise / Delete Exercise

### Exercises
- Exercise library sorted by muscle group (Chest, Back, Legs, Shoulders, Biceps, Triceps, Core)
- Muscle group assigned explicitly on creation, or inferred by keyword if not set
- Search bar with flat list fallback
- Add custom exercises with optional muscle group

### Session Detail
- Stats: Variations (unique exercises) + Total Sets
- Session card shows exercise summary: "3x Bench Press, 2x Pec Fly"
- Notes visible inline when present

### AI Coach
- Chat interface powered by the Claude API
- Full conversation history persisted per user

### Auth
- Sign up / Sign in with email + password
- Forgot Password (reset by email — no OTP, direct reset)
- JWT stored in UserDefaults; auto-login on relaunch

### Profile
- View and edit weight, height, age, sex
- Change password
- Sign out

---

## Project Structure

```
GymTraq/
├── gymtraq-backend/
│   ├── app.js
│   ├── db.js
│   ├── middleware/
│   │   └── auth.js
│   ├── routes/
│   │   ├── users.js
│   │   ├── exercises.js
│   │   ├── sessions.js
│   │   ├── entries.js
│   │   └── aiChat.js
│   └── controllers/
│       ├── usersController.js
│       ├── exercisesController.js
│       ├── sessionsController.js
│       ├── entriesController.js
│       └── aiChatController.js
│
└── GymTraq/ (Xcode project)
    └── GymTraq/
        ├── Models/
        │   └── Models.swift
        ├── Services/
        │   └── APIService.swift
        ├── ViewModels/
        │   ├── AuthViewModel.swift
        │   ├── SessionsViewModel.swift
        │   ├── ExercisesViewModel.swift
        │   ├── ChatViewModel.swift
        │   └── ProfileViewModel.swift
        └── Views/
            ├── Auth/         AuthView.swift
            ├── Main/         HomeView.swift
            ├── Sessions/     SessionsView.swift, SessionDetailView.swift
            ├── Exercises/    ExercisesView.swift
            ├── Chat/         ChatView.swift
            ├── Profile/      ProfileView.swift
            └── Components/   GlassCard.swift, AnimatedBackground.swift
```

---

## Database Schema

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
    exercise_name TEXT NOT NULL,
    muscle_group  TEXT
);

CREATE TABLE sessions (
    session_id SERIAL PRIMARY KEY,
    date       DATE NOT NULL,
    name       TEXT,
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

## API Routes

### Public
| Method | Path                      | Description              |
|--------|---------------------------|--------------------------|
| POST   | /users                    | Sign up                  |
| POST   | /users/login              | Login, returns JWT       |
| POST   | /users/forgot-password    | Reset password by email  |

### Protected (requires `Authorization: Bearer <token>`)
| Method | Path                          | Description                        |
|--------|-------------------------------|------------------------------------|
| GET    | /users/:id                    | Get profile                        |
| PUT    | /users/:id                    | Update profile                     |
| PUT    | /users/:id/password           | Change password                    |
| DELETE | /users/:id                    | Delete account                     |
| GET    | /exercises                    | List all exercises                 |
| POST   | /exercises                    | Create exercise                    |
| GET    | /sessions                     | List sessions for logged-in user   |
| POST   | /sessions                     | Create session                     |
| PUT    | /sessions/:id                 | Update session                     |
| DELETE | /sessions/:id                 | Delete session                     |
| GET    | /entries?session_id=X         | Get entries for a session          |
| GET    | /entries                      | Get all entries for user           |
| POST   | /entries                      | Create entry                       |
| PUT    | /entries/:id                  | Update entry                       |
| DELETE | /entries/:id                  | Delete entry                       |
| DELETE | /entries/by-exercise          | Delete all sets for an exercise in a session |
| PUT    | /entries/replace              | Replace an exercise across all sets in a session |
| GET    | /ai-chat                      | Get chat history                   |
| POST   | /ai-chat                      | Send message                       |

---

## Running Locally

### Backend
```bash
cd gymtraq-backend
npm install
# create a .env file:
# DATABASE_URL=postgres://...
# JWT_SECRET=your_secret
# ANTHROPIC_API_KEY=sk-ant-...
npm run dev
```

### iOS App
Open `GymTraq/GymTraq.xcodeproj` in Xcode. The backend URL is set to `http://localhost:3000` in `APIService.swift`. Requires iOS 26 SDK for `.glassEffect`.

---

## Status

Frontend and backend are functionally complete. Not yet deployed. Next steps:
- Deploy backend (Railway / Render / Fly.io)
- TestFlight distribution
- Email OTP for forgot password (currently resets by email match only)
