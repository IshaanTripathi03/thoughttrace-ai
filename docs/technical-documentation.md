# ThoughtTrace AI — Technical Documentation

**Version:** 1.0  
**Date:** November 1, 2026  
**Status:** Pre-Development

---

## 1. Project Overview

**ThoughtTrace AI** is an AI-powered adaptive coding education platform that diagnoses *why* a learner's solution fails, visualizes algorithm execution, and uses that diagnosis to recommend what to practice next.

**Tagline:** *Understand the Why Behind Every Wrong Answer*

**Core Loop:** Diagnose → Understand → Practice → Evaluate → Adapt

**Target Users:** Students and early-career developers preparing for coding interviews and competitive programming. Initial language support: Java.

**What makes it different:** Most platforms tell you *that* you're wrong. ThoughtTrace tells you *why* and adapts your next problem accordingly.

---

## 2. System Architecture

```
┌─────────────────────────────────────────────────────┐
│                     FRONTEND                         │
│  React + TypeScript + Vite + Tailwind + shadcn/ui   │
│  Monaco Editor │ SVG Visualizer │ Dashboard          │
└────────────────────────┬────────────────────────────┘
                         │ REST API (JSON)
┌────────────────────────▼────────────────────────────┐
│                  SPRING BOOT BACKEND                 │
│                                                      │
│  ┌──────────┐ ┌───────────┐ ┌────────────────────┐  │
│  │ Auth &   │ │Submission │ │  Recommendation    │  │
│  │ Users    │ │ Service   │ │  Engine            │  │
│  └──────────┘ └─────┬─────┘ └────────────────────┘  │
│                     │                                │
│  ┌──────────────────▼──────────┐ ┌───────────────┐  │
│  │ Code Execution Orchestrator │ │ Skill Profile │  │
│  └──────────────┬──────────────┘ │ Service       │  │
│                 │                 └───────────────┘  │
│  ┌──────────────▼──────────────┐                     │
│  │   AI Diagnosis Service      │                     │
│  │   (Claude API via Spring AI)│                     │
│  └─────────────────────────────┘                     │
└────────────────────────┬────────────────────────────┘
          │                              │
┌─────────▼──────────┐     ┌─────────────▼───────────┐
│    Judge0 API       │     │      PostgreSQL          │
│  (Code Execution)   │     │   (All app data)         │
└─────────────────────┘     └─────────────────────────┘
```

### Data Flow

1. User submits code → Backend receives submission
2. Backend sends code to Judge0 → gets compilation result, stdout, stderr, execution time
3. Backend compares output against stored test cases
4. On failure: Backend assembles evidence payload (code, error, test results, problem metadata) → sends to Claude API
5. Claude API returns structured diagnosis JSON
6. Backend stores diagnosis, updates skill profile, recalculates recommendation
7. Frontend renders diagnosis, visualization, and updated dashboard

---

## 3. Tech Stack

| Layer | Technology | Rationale |
|---|---|---|
| **Frontend** | React 18, TypeScript, Vite | Fast dev experience, strong typing |
| **UI** | Tailwind CSS, shadcn/ui | Consistent, accessible components |
| **Code Editor** | Monaco Editor | VSCode-quality editing in browser |
| **Visualizations** | SVG + Framer Motion | Animatable, lightweight, 2D-first |
| **Backend** | Java 17+, Spring Boot 3 | Robust, well-supported, matches target language |
| **LLM Integration** | Spring AI (Claude API) | Clean abstraction over LLM calls |
| **Database** | PostgreSQL 15+ | Relational, JSON support, proven |
| **ORM** | Spring Data JPA / Hibernate | Standard for Spring ecosystem |
| **Code Execution** | Judge0 CE (self-hosted or cloud) | Handles sandboxing, timeouts, multi-language |
| **Auth** | Spring Security + JWT | Stateless, standard |
| **Build** | Maven (backend), npm (frontend) | Standard tooling |
| **Testing** | JUnit 5, Vitest, React Testing Library | Backend + frontend coverage |
| **Containerization** | Docker, Docker Compose | Local dev parity |

---

## 4. Database Schema

### 4.1 Entity Relationship Summary

```
users 1──N submissions N──1 problems
users 1──N user_skill_profiles N──1 skills
submissions 1──N test_results
submissions 1──1 diagnoses
problems N──M skills (via problem_skills)
users 1──N daily_recommendations N──1 problems
users 1──N learning_sessions
submissions 1──N user_feedback
```

### 4.2 Table Definitions

#### `users`
| Column | Type | Constraints |
|---|---|---|
| id | UUID | PK |
| email | VARCHAR(255) | UNIQUE, NOT NULL |
| password_hash | VARCHAR(255) | NOT NULL |
| display_name | VARCHAR(100) | NOT NULL |
| created_at | TIMESTAMP | NOT NULL, DEFAULT NOW() |
| updated_at | TIMESTAMP | NOT NULL |
| last_login_at | TIMESTAMP | |
| streak_count | INT | DEFAULT 0 |
| streak_last_date | DATE | |

#### `problems`
| Column | Type | Constraints |
|---|---|---|
| id | UUID | PK |
| title | VARCHAR(255) | NOT NULL |
| slug | VARCHAR(255) | UNIQUE, NOT NULL |
| description | TEXT | NOT NULL |
| difficulty | ENUM('EASY','MEDIUM','HARD') | NOT NULL |
| starter_code | TEXT | |
| solution_code | TEXT | NOT NULL |
| solution_explanation | TEXT | |
| time_limit_ms | INT | DEFAULT 2000 |
| memory_limit_kb | INT | DEFAULT 262144 |
| created_at | TIMESTAMP | NOT NULL |
| is_active | BOOLEAN | DEFAULT TRUE |

#### `skills`
| Column | Type | Constraints |
|---|---|---|
| id | UUID | PK |
| name | VARCHAR(100) | UNIQUE, NOT NULL |
| category | VARCHAR(50) | NOT NULL |
| description | TEXT | |
| display_order | INT | |

#### `problem_skills` (junction)
| Column | Type | Constraints |
|---|---|---|
| problem_id | UUID | FK → problems, PK |
| skill_id | UUID | FK → skills, PK |
| is_primary | BOOLEAN | DEFAULT FALSE |

#### `test_cases`
| Column | Type | Constraints |
|---|---|---|
| id | UUID | PK |
| problem_id | UUID | FK → problems, NOT NULL |
| input | TEXT | NOT NULL |
| expected_output | TEXT | NOT NULL |
| is_hidden | BOOLEAN | DEFAULT FALSE |
| is_sample | BOOLEAN | DEFAULT FALSE |
| order_index | INT | |

#### `submissions`
| Column | Type | Constraints |
|---|---|---|
| id | UUID | PK |
| user_id | UUID | FK → users, NOT NULL |
| problem_id | UUID | FK → problems, NOT NULL |
| source_code | TEXT | NOT NULL |
| language | VARCHAR(20) | DEFAULT 'java' |
| status | ENUM('PENDING','COMPILING','RUNNING','ACCEPTED','WRONG_ANSWER','COMPILE_ERROR','RUNTIME_ERROR','TIME_LIMIT','MEMORY_LIMIT') | NOT NULL |
| submitted_at | TIMESTAMP | NOT NULL |
| execution_time_ms | INT | |
| memory_used_kb | INT | |
| was_assisted | BOOLEAN | DEFAULT FALSE |
| assist_level | ENUM('NONE','HINT','DEBUG','EXPLAIN','SOLUTION') | DEFAULT 'NONE' |

**Index:** `(user_id, problem_id, submitted_at DESC)`

#### `test_results`
| Column | Type | Constraints |
|---|---|---|
| id | UUID | PK |
| submission_id | UUID | FK → submissions, NOT NULL |
| test_case_id | UUID | FK → test_cases, NOT NULL |
| actual_output | TEXT | |
| passed | BOOLEAN | NOT NULL |
| execution_time_ms | INT | |
| error_output | TEXT | |

#### `diagnoses`
| Column | Type | Constraints |
|---|---|---|
| id | UUID | PK |
| submission_id | UUID | FK → submissions, UNIQUE, NOT NULL |
| error_category | VARCHAR(50) | |
| error_subcategory | VARCHAR(50) | |
| explanation | TEXT | NOT NULL |
| evidence | JSONB | NOT NULL |
| counterexample_input | TEXT | |
| counterexample_expected | TEXT | |
| counterexample_actual | TEXT | |
| suggestion | TEXT | |
| confidence | DECIMAL(3,2) | |
| model_used | VARCHAR(50) | |
| created_at | TIMESTAMP | NOT NULL |

**`evidence` JSONB structure:**
```json
{
  "failing_test_index": 2,
  "compiler_error": null,
  "runtime_error": null,
  "relevant_code_lines": [12, 13, 14],
  "identified_pattern": "incorrect_window_shrink_condition",
  "execution_trace_summary": "..."
}
```

#### `user_skill_profiles`
| Column | Type | Constraints |
|---|---|---|
| id | UUID | PK |
| user_id | UUID | FK → users, NOT NULL |
| skill_id | UUID | FK → skills, NOT NULL |
| proficiency_score | DECIMAL(4,2) | DEFAULT 0.0 |
| total_attempts | INT | DEFAULT 0 |
| independent_solves | INT | DEFAULT 0 |
| assisted_solves | INT | DEFAULT 0 |
| recent_error_patterns | JSONB | DEFAULT '[]' |
| last_practiced_at | TIMESTAMP | |
| updated_at | TIMESTAMP | NOT NULL |

**Unique:** `(user_id, skill_id)`

#### `daily_recommendations`
| Column | Type | Constraints |
|---|---|---|
| id | UUID | PK |
| user_id | UUID | FK → users, NOT NULL |
| problem_id | UUID | FK → problems, NOT NULL |
| recommended_date | DATE | NOT NULL |
| rationale | TEXT | NOT NULL |
| target_skill_id | UUID | FK → skills |
| was_attempted | BOOLEAN | DEFAULT FALSE |
| was_solved | BOOLEAN | DEFAULT FALSE |
| was_independent | BOOLEAN | |
| created_at | TIMESTAMP | NOT NULL |

**Unique:** `(user_id, recommended_date)`

#### `learning_sessions`
| Column | Type | Constraints |
|---|---|---|
| id | UUID | PK |
| user_id | UUID | FK → users, NOT NULL |
| problem_id | UUID | FK → problems |
| started_at | TIMESTAMP | NOT NULL |
| ended_at | TIMESTAMP | |
| hints_used | INT | DEFAULT 0 |
| submissions_count | INT | DEFAULT 0 |
| outcome | ENUM('SOLVED_INDEPENDENT','SOLVED_ASSISTED','GAVE_UP','IN_PROGRESS') | |

#### `user_feedback`
| Column | Type | Constraints |
|---|---|---|
| id | UUID | PK |
| user_id | UUID | FK → users, NOT NULL |
| submission_id | UUID | FK → submissions |
| diagnosis_id | UUID | FK → diagnoses |
| recommendation_id | UUID | FK → daily_recommendations |
| feedback_type | ENUM('HELPFUL','UNHELPFUL','INCORRECT','OTHER') | NOT NULL |
| comment | TEXT | |
| created_at | TIMESTAMP | NOT NULL |

---

## 5. Core Modules

### Module 1: AI Debugging Coach

**Purpose:** Diagnose *why* code failed, not just *that* it failed.

**Flow:**
1. Submission fails test cases
2. System assembles evidence: source code, compiler output, test results, problem metadata
3. Evidence sent to Claude API with a structured prompt
4. Returns: error category, explanation, counterexample, suggestion
5. Displayed alongside the code editor

**Coaching Modes (progressive rollout):**

| Mode | MVP | Behavior |
|---|---|---|
| Debug | ✅ | Locate the bug with evidence |
| Hint | Phase 2 | Small nudge without revealing answer |
| Explain | Phase 2 | Teach the underlying concept |
| Interview | Phase 3 | Socratic questioning |
| Solution | Phase 2 | Full solution with walkthrough |

**Key Constraint:** Every diagnosis must cite execution evidence. The AI prompt includes explicit instructions not to fabricate test results.

### Module 2: Interactive Algorithm Playground

**Purpose:** Step-by-step visual execution of algorithms.

**MVP Scope (2D SVG):**
- Array/string operations with index highlighting
- Two-pointer movement
- Sliding window expansion/contraction
- Variable state panel

**Phase 2 additions:**
- Stack/queue push-pop visualization
- Recursion call-stack tree
- Sorting step visualization

**Phase 3+ additions:**
- Tree traversal (BFS/DFS)
- Graph traversal with path highlighting
- 3D visualizations via React Three Fiber (selective)

**Controls:** Play, pause, step forward, step backward, reset, speed slider.

**Implementation:** Execution states are recorded as an array of snapshots. The visualizer replays snapshots with animated transitions between states.

### Module 3: Adaptive Daily Recommendation

**Purpose:** Pick the best next problem based on demonstrated weaknesses.

**Algorithm (rule-based, MVP):**
```
1. Get user's skill profiles ordered by proficiency ASC
2. Filter to skills with >= 2 attempts (enough evidence)
3. Among weakest skills, prefer those not practiced in 3+ days
4. Select a problem at appropriate difficulty:
   - proficiency < 30%  → EASY
   - proficiency 30-70% → MEDIUM
   - proficiency > 70%  → HARD
5. Exclude already-solved problems (independent solves)
6. Generate rationale string explaining the selection
```

**Rationale example:** *"You've struggled with sliding window problems — your last 3 attempts had incorrect window-shrink conditions. This fixed-window problem builds that foundation."*

### Module 4: Learner Skill Profile

**Initial skill categories (15):**
Arrays & Strings, Hashing, Two Pointers, Sliding Window, Binary Search, Linked Lists, Stacks & Queues, Recursion & Backtracking, Trees & BSTs, Graphs, Greedy, Dynamic Programming, Heaps & Priority Queues, Sorting, Graph Algorithms

**Error pattern categories tracked:**
Off-by-one, wrong boundary, wrong condition, incorrect state update, missing edge case, invalid invariant, wrong complexity, duplicate handling error

**Scoring model (MVP):**
```
proficiency = (independent_solves * 1.0 + assisted_solves * 0.3) / total_attempts * 100
```
Weighted toward independent solves. Recalculated after each submission.

### Module 5: Learning Analytics Dashboard

**Components:**
- Today's recommended problem with rationale
- Skill radar/bar chart (topic vs. proficiency)
- Submission history (calendar heatmap)
- Error pattern frequency breakdown
- Independent vs. assisted solve ratio
- Streak counter
- Topics improving vs. declining (trend arrows)

---

## 6. API Reference

### Authentication

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/auth/register` | Create account |
| POST | `/api/auth/login` | Get JWT token |
| POST | `/api/auth/refresh` | Refresh token |
| GET | `/api/auth/me` | Current user profile |

### Problems

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/problems` | List problems (filterable by difficulty, skill, status) |
| GET | `/api/problems/{id}` | Problem detail with sample test cases |
| GET | `/api/problems/{id}/starter` | Starter code template |

### Submissions

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/submissions` | Submit code for evaluation |
| GET | `/api/submissions/{id}` | Submission detail with test results |
| GET | `/api/submissions?problemId={id}` | User's submissions for a problem |
| GET | `/api/submissions/history` | Paginated submission history |

**POST `/api/submissions` Request:**
```json
{
  "problemId": "uuid",
  "sourceCode": "public class Solution { ... }",
  "language": "java"
}
```

**Response:**
```json
{
  "id": "uuid",
  "status": "WRONG_ANSWER",
  "executionTimeMs": 45,
  "testResults": [
    { "testCaseId": "uuid", "passed": true, "executionTimeMs": 12 },
    { "testCaseId": "uuid", "passed": false, "actualOutput": "3", "expectedOutput": "4" }
  ],
  "diagnosis": { ... }
}
```

### Diagnoses

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/diagnoses/{submissionId}` | Get diagnosis for a submission |
| POST | `/api/diagnoses/{id}/feedback` | Submit feedback on diagnosis |

### AI Coaching

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/coaching/hint` | Get a progressive hint |
| POST | `/api/coaching/explain` | Get concept explanation |
| POST | `/api/coaching/solution` | Get full solution walkthrough |

### Skill Profile

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/skills/profile` | User's full skill profile |
| GET | `/api/skills/profile/{skillId}` | Detail for one skill |
| GET | `/api/skills/error-patterns` | User's recurring error patterns |

### Recommendations

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/recommendations/today` | Today's recommended problem |
| GET | `/api/recommendations/history` | Past recommendations with outcomes |

### Dashboard / Analytics

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/analytics/overview` | Dashboard summary data |
| GET | `/api/analytics/progress?range=30d` | Progress over time |
| GET | `/api/analytics/streaks` | Streak data |

---

## 7. AI Integration

### Diagnosis Prompt Design

The AI receives a **structured evidence payload**, not raw code alone:

```
You are an AI debugging coach for a coding education platform.

PROBLEM:
Title: {title}
Description: {description}
Difficulty: {difficulty}
Topics: {topics}

STUDENT'S CODE:
{source_code}

EXECUTION RESULTS:
- Status: {status}
- Compiler error: {compiler_error or "None"}
- Failing test case #{index}:
  Input: {input}
  Expected: {expected_output}
  Actual: {actual_output}
- Error output: {stderr}

INSTRUCTIONS:
1. Identify the root cause of failure based on the code and test results.
2. Classify the error (off-by-one, wrong condition, missing edge case, etc.).
3. Provide a counterexample input if possible.
4. Explain WHY the code fails on that input — trace through the logic.
5. Give a suggestion that guides without revealing the full solution.
6. Do NOT fabricate test results. Only reference data provided above.
7. Rate your confidence (0.0–1.0).

Respond in JSON:
{
  "errorCategory": "...",
  "errorSubcategory": "...",
  "explanation": "...",
  "counterexampleInput": "...",
  "counterexampleExpected": "...",
  "counterexampleActual": "...",
  "relevantCodeLines": [12, 13],
  "suggestion": "...",
  "confidence": 0.85
}
```

### Guardrails
- AI never sees hidden test case inputs (only the failing output comparison)
- Response validated against JSON schema before storing
- Fallback: if AI call fails, user still sees raw test results
- Confidence < 0.5 triggers a "low confidence" disclaimer in the UI

---

## 8. Code Execution Service

### Judge0 Integration

**Flow:**
```
Backend → POST Judge0 /submissions (batch)
       → Poll GET /submissions/{token} until status is final
       → Parse stdout, stderr, exit code, time, memory
       → Compare stdout against expected output per test case
       → Return structured TestResult[]
```

**Configuration:**
```yaml
judge0:
  base-url: http://judge0:2358
  language-id: 62  # Java (OpenJDK 13)
  cpu-time-limit: 2      # seconds
  memory-limit: 262144   # KB (256MB)
  max-processes: 30
  enable-network: false
  callback-url: null     # polling mode
```

**Security measures:**
- Judge0 runs in its own Docker network, no access to app DB
- Network disabled inside execution containers
- Filesystem read-only except `/tmp`
- Process count limited
- Submissions queued — max concurrent executions capped

**Self-hosted Judge0 deployment:**
```yaml
# docker-compose.yml (excerpt)
judge0:
  image: judge0/judge0-ce:latest
  ports:
    - "2358:2358"
  depends_on:
    - judge0-db
    - judge0-redis
  environment:
    - RAILS_MAX_THREADS=4
    - CPU_TIME_LIMIT=2
    - MEMORY_LIMIT=262144
```

---

## 9. Frontend Architecture

### Pages

| Route | Page | Description |
|---|---|---|
| `/` | Landing | Hero, features, CTA |
| `/login`, `/register` | Auth | JWT-based auth forms |
| `/dashboard` | Dashboard | Skill map, streak, recommendation, history |
| `/problems` | Problem List | Filterable/sortable problem catalog |
| `/problems/:id` | Problem Workspace | Editor + problem + test results + diagnosis + visualizer |
| `/profile` | Profile | Settings, skill detail, error pattern breakdown |

### Problem Workspace Layout

```
┌──────────────────────────────────────────────────┐
│  Problem Title                    [Hint] [Submit]│
├──────────────────────┬───────────────────────────┤
│                      │                           │
│  Problem Description │   Monaco Code Editor      │
│  (scrollable)        │                           │
│                      │                           │
│  Sample I/O          │                           │
│                      │                           │
├──────────────────────┼───────────────────────────┤
│                      │                           │
│  Algorithm           │   Test Results            │
│  Visualizer          │   + AI Diagnosis Panel    │
│  (SVG + controls)    │                           │
│                      │                           │
└──────────────────────┴───────────────────────────┘
```

### State Management
- **React Query (TanStack Query)** for server state (submissions, problems, profile)
- **Zustand** for local UI state (editor content, visualizer playback state, panel layout)
- No Redux — the app is API-driven, not heavily client-stateful

### Key Components
- `<CodeEditor />` — Monaco wrapper with problem-specific language config
- `<DiagnosisPanel />` — renders structured diagnosis with collapsible sections
- `<AlgorithmVisualizer />` — SVG-based step-through with Framer Motion transitions
- `<SkillRadar />` — radar or bar chart of topic proficiencies
- `<StreakCalendar />` — GitHub-style heatmap of activity
- `<RecommendationCard />` — today's problem with rationale

---

## 10. Development Phases

### Phase 1 — Foundation (Weeks 1–2)

**Backend:**
- Spring Boot project scaffold (Maven, project structure)
- JPA entities: `User`, `Problem`, `TestCase`, `Submission`, `TestResult`
- Repositories + Services + REST Controllers for auth, problems, submissions
- Judge0 integration service (submit, poll, parse)
- Spring Security + JWT auth
- Seed data: 5 curated problems with test cases

**Frontend:**
- Vite + React + TypeScript scaffold
- Tailwind + shadcn/ui setup
- Auth pages (login/register)
- Problem list page
- Problem workspace with Monaco Editor
- Submit → see pass/fail results

**✅ Deliverable:** User signs up, picks a problem, submits Java code, sees test results.

### Phase 2 — AI Diagnosis (Weeks 3–4)

**Backend:**
- Spring AI integration with Claude API
- Diagnosis prompt builder service
- `Diagnosis` entity + API
- Feedback endpoint
- Error category enum

**Frontend:**
- Diagnosis panel component
- Evidence display (failing input, relevant lines, explanation)
- Feedback buttons (helpful/unhelpful)
- Submission history page

**✅ Deliverable:** Failed submissions get structured, evidence-backed explanations.

### Phase 3 — Visualizer (Weeks 5–6)

**Backend:**
- Execution trace recorder (state snapshots per step)
- Trace API endpoint

**Frontend:**
- SVG-based `AlgorithmVisualizer` component
- Array visualization with index/pointer highlighting
- Two-pointer and sliding-window animation
- Playback controls (play, pause, step, speed)
- Code line synchronization

**✅ Deliverable:** Step-through visual execution for array/window problems.

### Phase 4 — Skill Profile & Recommendations (Weeks 7–8)

**Backend:**
- `Skill`, `UserSkillProfile` entities
- Proficiency calculation service
- Error-pattern tracking
- Rule-based recommendation engine
- `DailyRecommendation` entity + API
- `LearningSession` tracking

**Frontend:**
- Dashboard page with skill chart, streak, recommendation
- Skill detail drill-down
- Error pattern breakdown
- Recommendation card with rationale

**✅ Deliverable:** Full learning loop — diagnose → track → recommend → repeat.

### Phase 5 — Polish & Expand (Weeks 9+)

- Expand problem set to 20–30
- Add hint + explain + solution coaching modes
- Stack, queue, recursion visualizations
- Spaced repetition in recommendation logic
- Performance optimizations
- Responsive mobile layout
- E2E tests

---

## 11. Non-Functional Requirements

### Security
- All user code treated as untrusted; executed only in Judge0 sandbox
- JWT tokens with short expiry + refresh token rotation
- Bcrypt password hashing
- Rate limiting on submission and AI endpoints (e.g., 10 submissions/min, 20 AI calls/hour)
- No hidden test case inputs exposed to frontend
- API keys stored in environment variables, never in code

### Performance
- Submission → result: < 5s for typical problems
- AI diagnosis: < 10s (async with loading state)
- Dashboard load: < 2s
- Frontend bundle: < 500KB gzipped
- Database queries indexed on hot paths (user+problem lookups, skill profiles)

### Reliability
- Failed AI calls degrade gracefully (show test results without diagnosis)
- Judge0 queue overflow → user sees "execution service busy" with retry
- All submissions persisted before execution (no data loss on crash)
- Idempotent submission processing

### Maintainability
- Backend: layered architecture (Controller → Service → Repository)
- AI prompts stored as templates, not hardcoded in Java
- Judge0 integration behind an interface (swappable executor)
- Feature flags for coaching modes
- Structured logging (JSON) with correlation IDs

---

## 12. Deployment Guide

### Local Development

```yaml
# docker-compose.yml
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: thoughttrace
      POSTGRES_USER: tt_user
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

  judge0-db:
    image: postgres:15
    environment:
      POSTGRES_DB: judge0
      POSTGRES_USER: judge0
      POSTGRES_PASSWORD: ${JUDGE0_DB_PASSWORD}

  judge0-redis:
    image: redis:7

  judge0:
    image: judge0/judge0-ce:latest
    depends_on:
      - judge0-db
      - judge0-redis
    ports:
      - "2358:2358"
    environment:
      - DATABASE_URL=postgres://judge0:${JUDGE0_DB_PASSWORD}@judge0-db:5432/judge0
      - REDIS_URL=redis://judge0-redis:6379

  backend:
    build: ./backend
    ports:
      - "8080:8080"
    depends_on:
      - postgres
      - judge0
    environment:
      - SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/thoughttrace
      - SPRING_DATASOURCE_USERNAME=tt_user
      - SPRING_DATASOURCE_PASSWORD=${DB_PASSWORD}
      - JUDGE0_BASE_URL=http://judge0:2358
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}

  frontend:
    build: ./frontend
    ports:
      - "5173:5173"

volumes:
  pgdata:
```

### Environment Variables

| Variable | Description |
|---|---|
| `DB_PASSWORD` | PostgreSQL password |
| `ANTHROPIC_API_KEY` | Claude API key |
| `JUDGE0_BASE_URL` | Judge0 service URL |
| `JWT_SECRET` | JWT signing secret (min 256-bit) |
| `JWT_EXPIRY_MS` | Token expiry (default: 900000 = 15min) |
| `CORS_ORIGINS` | Allowed frontend origins |

### Production Deployment

- **Frontend:** Vercel or Cloudflare Pages (static build)
- **Backend:** Railway, Render, or AWS ECS (containerized Spring Boot)
- **Database:** Managed PostgreSQL (Supabase, Neon, or AWS RDS)
- **Judge0:** Self-hosted on a dedicated VM with Docker (needs privileged containers)
- **Monitoring:** Application logs → stdout (captured by platform), Sentry for error tracking
- **CI/CD:** GitHub Actions → build → test → deploy

---

## 13. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| AI produces incorrect diagnosis | Ground all prompts in execution evidence; show confidence score; allow user feedback |
| Skill profile mislabels weakness | Require 2+ attempts before scoring; distinguish confidence from proficiency |
| Recommendations feel repetitive | Include novelty factor, spaced repetition, and user feedback loop |
| Learner code compromises server | Judge0 sandboxes execution; no code runs in Spring Boot process |
| Judge0 becomes bottleneck | Queue submissions; cap concurrent executions; show loading states |
| 3D visualizations delay MVP | Deferred to Phase 3+; MVP uses 2D SVG only |
| API cost from LLM calls | Cache diagnoses per submission; rate-limit AI calls per user |
| Learner becomes AI-dependent | Track independent vs. assisted solves; progressive hint escalation |

### Future Enhancements (Post-MVP)
- Multi-language support (Python, C++, JavaScript)
- Interview simulation mode with timed sessions
- 3D graph/tree visualizations (React Three Fiber)
- Spaced repetition scheduler
- Weekly learning plans
- AI-generated problem variants
- Instructor dashboard
- Collaborative debugging sessions
- Mobile app

