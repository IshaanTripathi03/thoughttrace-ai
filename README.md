# ThoughtTrace AI

AI-powered adaptive coding education platform.

**Core loop:** submit Java code → execute in a sandbox → AI diagnoses *why* it failed → track skill weaknesses → recommend the next problem.

## Stack

| Layer | Choice |
|---|---|
| Frontend | React + TypeScript + Vite + Tailwind + shadcn/ui + Monaco + Framer Motion |
| Backend | Java 21 + Spring Boot 4.1 + Spring AI + Spring Security + Spring Data JPA |
| Database | PostgreSQL 15 (Flyway migrations) |
| Code execution | Judge0 CE (self-hosted, Docker) |
| AI | Claude API via Spring AI |
| Auth | JWT (stateless) |

> The design docs specify Spring Boot 3. Spring Initializr no longer publishes Boot 3 starters, so the
> backend is on Boot 4.1.2 / Spring AI 2.0.2 — same architecture, current baseline.

## Layout

```
thoughttrace-ai/
├── backend/                 # Spring Boot modular monolith
│   └── src/main/java/com/thoughttrace/
│       ├── auth/            # JWT auth, user management
│       ├── problem/         # Problem CRUD, test cases
│       ├── submission/      # Code submission, status tracking
│       ├── execution/       # Judge0 client, result parsing
│       ├── diagnosis/       # Claude API, prompt building
│       ├── skill/           # Skill profiles, proficiency calc
│       ├── recommendation/  # Daily problem selection
│       ├── analytics/       # Dashboard aggregations
│       ├── visualization/   # Execution trace generation
│       └── common/          # Shared DTOs, exceptions, config
├── frontend/                # React SPA (Phase 3)
├── docker-compose.yml       # PostgreSQL + Judge0 CE
└── judge0.conf              # Judge0 server/worker config
```

Each module exposes a service interface. No cross-module repository access.

## Local development

Prerequisites: Docker Desktop (running), JDK 21+, Node 20+.

```bash
cp .env.example .env     # fill in secrets
docker compose up -d     # PostgreSQL + Judge0
cd backend && ./mvnw spring-boot:run
```

- Backend: http://localhost:8080 (health: `/actuator/health`)
- Judge0: http://localhost:2358
- PostgreSQL: `localhost:5432`

Judge0 needs `privileged: true` and, on Linux hosts, cgroup v1. On Docker Desktop for
Windows/macOS it runs under the WSL2/LinuxKit VM; if the workers fail to start, check
`docker compose logs judge0-workers`.

## Environment variables

| Variable | Description |
|---|---|
| `DB_URL` / `DB_USER` / `DB_PASSWORD` | App PostgreSQL connection |
| `JUDGE0_URL` | Judge0 base URL (default `http://localhost:2358`) |
| `JWT_SECRET` | Base64-encoded 256-bit JWT signing secret |
| `JWT_EXPIRATION_MINUTES` | Access token lifetime |
| `CORS_ORIGINS` | Allowed frontend origins |
| `ANTHROPIC_API_KEY` | Claude API key (Phase 2) |

## Key design rules

- Submission source code is saved to the DB **before** any external call — no data loss.
- Diagnosis is async and best-effort; test results always render even if the AI call fails.
- Judge0 executes all user code. Nothing runs in the Spring Boot process.
- The AI prompt always carries real execution evidence — the model never invents test results.
- Proficiency = `(independent_solves * 1.0 + assisted_solves * 0.3) / total_attempts * 100`.
- Recommendation order: weakest skill → stale preference → difficulty bracket → exclude mastered.

## Build status

- [x] Phase 1.1 — Backend scaffold (Maven, Spring Boot, module packages, config)
- [x] Phase 1.2 — Docker Compose (PostgreSQL + Judge0 CE) + `V1__initial_schema.sql`
- [ ] Phase 1.3 — JPA entities
- [ ] Phase 1.4 — Auth (register / login / me)
- [ ] Phase 1.5 — JWT filter + Security config
- [ ] Phase 1.6 — Problem CRUD + seed 5 problems
- [ ] Phase 1.7 — Judge0 integration
- [ ] Phase 1.8 — Submission pipeline
- [ ] Phase 2 — AI diagnosis
- [ ] Phase 3 — Frontend core
- [ ] Phase 4 — Visualizer
- [ ] Phase 5 — Skill profile & recommendations
- [ ] Phase 6 — Polish & deploy
