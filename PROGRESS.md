# ThoughtTrace AI — Build Progress

Last updated: 2026-11-01

Build plan source: `Instructions.txt` (6 phases, 42 tasks). This file tracks where we actually are.

---

## Where we are

**Phase 1 — Foundation: Tasks 1–3 of 9 done.** Backend compiles. Postgres runs. Judge0 does not yet.

| Phase 1 task | Status |
|---|---|
| 1. Spring Boot project + Maven | ✅ Done |
| 2. Docker Compose: PostgreSQL + Judge0 CE | ⚠️ Postgres up & verified · Judge0 blocked |
| 3. JPA entities (User, Problem, TestCase, Submission, TestResult) | ✅ Done |
| 4. Auth repositories / services / controllers (register, login, me) | ⬜ Next |
| 5. JWT filter + Spring Security config | ⬜ |
| 6. Problem CRUD + seed 5 problems with test cases | ⬜ |
| 7. Judge0 integration (ExecutionService) | ⬜ |
| 8. Submission pipeline (`POST /api/submissions`) | ⬜ |
| 9. End-to-end test: register → login → submit → pass/fail | ⬜ |

Phases 2–6 (AI diagnosis, frontend, visualizer, skill profile, polish) not started.

---

## What has been built

### Repository

Git repo initialized on `main`. One commit so far:

- `8e41ea4` — *Scaffold ThoughtTrace AI backend and dev infrastructure* (20 files)

**Uncommitted** (Task 3 work, compiles clean, not yet committed):

```
M  backend/src/main/java/com/thoughttrace/ThoughtTraceApplication.java
M  backend/src/main/resources/db/migration/V1__initial_schema.sql
?? backend/src/main/java/com/thoughttrace/auth/
?? backend/src/main/java/com/thoughttrace/common/
?? backend/src/main/java/com/thoughttrace/problem/
?? backend/src/main/java/com/thoughttrace/submission/
```

### Task 1 — Backend scaffold

- `backend/` generated from Spring Initializr with the Maven wrapper, so **no local Maven install is needed** — use `./mvnw` (bash) or `.\mvnw.cmd` (PowerShell).
- Dependencies: web (MVC), data-jpa, security, validation, postgresql, flyway, actuator, lombok, `spring-ai-starter-model-anthropic`, jjwt 0.12.6 (api/impl/jackson).
- All 10 module packages created: `auth`, `problem`, `submission`, `execution`, `diagnosis`, `skill`, `recommendation`, `analytics`, `visualization`, `common`.
- `ThoughtTraceApplication` with `@EnableAsync` (for async diagnosis in Phase 2) and `@ConfigurationPropertiesScan`.
- `application.yml` — datasource, JPA (`ddl-auto: validate`), Flyway, Spring AI Anthropic, and a `thoughttrace.*` block for JWT / Judge0 / CORS / diagnosis. Every value is env-overridable.
- `application-test.yml` — `create-drop` + Flyway off, for tests without a real DB.

### Task 2 — Infrastructure + schema

- `docker-compose.yml` — `postgres` (app DB) plus the full Judge0 CE stack: `judge0-db`, `judge0-redis`, `judge0-server`, `judge0-workers` (both privileged).
- `judge0.conf` — Judge0 server/worker environment (DB, Redis, execution limits, `ENABLE_NETWORK=false`).
- `.env.example`, `.gitignore`, `README.md`.
- `V1__initial_schema.sql` — **all 12 tables**: `users`, `problems`, `skills`, `problem_skills`, `test_cases`, `submissions`, `test_results`, `diagnoses`, `user_skill_profiles`, `daily_recommendations`, `learning_sessions`, `user_feedback`. Enums as `CHECK` constraints, JSONB for `evidence` and `recent_error_patterns`, and the documented indexes including the partial index on in-flight submission statuses.

Schema-first on purpose: Flyway owns the schema and Hibernate runs `ddl-auto: validate`, so a drifted entity fails at startup instead of silently rewriting tables.

### Task 3 — Entities, repositories, config

| File | Notes |
|---|---|
| `auth/User.java` | `@PrePersist`/`@PreUpdate` maintain `created_at`/`updated_at` |
| `problem/Problem.java`, `problem/Difficulty.java` | |
| `problem/TestCase.java` | `hidden` / `sample` flags — hidden cases never reach the client |
| `submission/Submission.java` | defaults applied in `@PrePersist` (language `java`, status `PENDING`, assist `NONE`) |
| `submission/SubmissionStatus.java` | + `isTerminal()` / `isFailure()` helpers; includes `INTERNAL_ERROR` |
| `submission/AssistLevel.java` | only `NONE` counts as an independent solve |
| `submission/TestResult.java` | |
| `auth/UserRepository`, `problem/ProblemRepository`, `problem/TestCaseRepository`, `submission/SubmissionRepository`, `submission/TestResultRepository` | Spring Data JPA |
| `common/config/JwtProperties`, `Judge0Properties`, `CorsProperties` | records bound via `@ConfigurationPropertiesScan` |

`INTERNAL_ERROR` is an addition to the documented status enum — it distinguishes "Judge0 or the orchestrator broke" from "the learner's code is wrong", which matters because the AI diagnosis must not fire on infrastructure failures.

---

## Verified vs. not verified

**Verified:**
- `./mvnw compile` succeeds (Java 21 target on a JDK 26 host).
- `docker compose config` validates.
- Postgres container runs and accepts connections — `PostgreSQL 15.19` on `localhost:5432`, database/user/password all `thoughttrace`.

**Not verified yet:**
- The Flyway migration has **never been applied** — the backend has not been booted against the database.
- Judge0 has never answered a request.
- No tests written beyond the generated `contextLoads`.

---

## Known issues / blockers

1. **Judge0 images did not finish pulling.** The ~1.5 GB pull died with `unexpected EOF`, and the Docker engine then started returning `500 Internal Server Error` on every API call. Needs a Docker Desktop restart, then `docker compose up -d`.
2. **Judge0 on Windows is a risk.** Judge0 1.13.1 wants cgroup v1; under Docker Desktop/WSL2 the workers often fail to start. If `docker compose logs judge0-workers` shows cgroup errors, the fallbacks are: pin the Judge0 1.13.0 + `cgroup v1` WSL config, or run Judge0 on a small Linux VM and point `JUDGE0_URL` at it.
3. **Spring Boot 4.1.2, not 3.x.** Spring Initializr rejects Boot 3 (`compatibility range is >=4.0.0`). Spring AI is 2.0.2. Architecture is unchanged, but any Boot 3 snippet from the design docs may need adjusting.
4. **`mvnw` is flaky under Git Bash** on this machine (cygwin `fork: Resource temporarily unavailable` under load). Prefer `.\mvnw.cmd` from PowerShell.
5. **`ANTHROPIC_API_KEY` is not set.** Not needed until Phase 2.

---

## What to do next

### Immediate — unblock and verify the foundation

1. Restart Docker Desktop, then from the project root:
   ```bash
   docker compose up -d
   ```
2. Confirm the Judge0 workers survived:
   ```bash
   docker compose logs --tail=50 judge0-workers
   ```
3. Boot the backend so Flyway applies `V1` and Hibernate validates the entities against it:
   ```bash
   cd backend && ./mvnw spring-boot:run
   ```
   Then check `http://localhost:8080/actuator/health` and confirm the 12 tables plus `flyway_schema_history` exist.
4. Commit the Task 3 work.

### Then — Phase 1, Task 4 onward

- **Task 4** — `AuthService` (BCrypt registration, login), DTOs with Bean Validation, `AuthController`: `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/me`.
- **Task 5** — `JwtService` (sign/verify with jjwt), `JwtAuthenticationFilter`, `SecurityConfig` (stateless sessions, CORS from `CorsProperties`, public auth + actuator routes, everything else authenticated).
- **Task 6** — `V2__seed_skills_and_problems.sql` or a `DataSeeder`: skill categories plus the 5 curated problems with test cases — Two Sum, Valid Parentheses, Maximum Subarray, Sliding Window Maximum, Longest Substring Without Repeating Characters. Each needs description, starter code, solution code, and sample + hidden test cases.
- **Task 7** — `Judge0Client` (`RestClient`): `POST /submissions?base64_encoded=false&wait=false`, poll `GET /submissions/{token}`, map Judge0 status ids → `SubmissionStatus`, honour `pollTimeoutMs`.
- **Task 8** — `SubmissionService`: save source code **first**, then execute each test case, persist `TestResult` rows, derive the final status. `POST /api/submissions`, `GET /api/submissions/{id}`.
- **Task 9** — End-to-end check with a real Java solution and a deliberately broken one.

### Design rules to keep honouring

- Source code is saved to the DB before any external call.
- Diagnosis is async and best-effort; test results render even when the AI call fails.
- Judge0 executes all user code — nothing runs in the Spring Boot process.
- The AI prompt always carries real execution evidence; the model never invents test results.
- Proficiency = `(independent_solves * 1.0 + assisted_solves * 0.3) / total_attempts * 100`.
- Recommendation order: weakest skill → stale preference → difficulty bracket → exclude mastered.
- Modules talk through service interfaces; no cross-module repository access.
