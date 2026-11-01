---

# System Design: ThoughtTrace AI

---

## 1. Requirements

### 1.1 Functional Requirements

| # | Requirement |
|---|---|
| F1 | Users register, log in, manage profile |
| F2 | Browse and filter a curated problem catalog |
| F3 | Write and submit Java code in a browser-based editor |
| F4 | Execute submissions in a secure sandbox; return compilation, runtime, and test results |
| F5 | On failure, generate an LLM-powered structured diagnosis with evidence |
| F6 | Offer progressive coaching: hint → debug → explain → solution |
| F7 | Visualize algorithm execution step-by-step (arrays, pointers, windows) |
| F8 | Track per-skill proficiency with independent vs. assisted solve distinction |
| F9 | Recommend a personalized daily problem with rationale |
| F10 | Display learning analytics: skill map, streaks, error patterns, progress trends |

### 1.2 Non-Functional Requirements

| Dimension | Target |
|---|---|
| Submission → test results | < 5s (p95) |
| Submission → diagnosis | < 12s (p95) |
| Dashboard load | < 2s |
| Concurrent users | ~1,000 (MVP) |
| Code execution security | Full sandbox isolation — untrusted code must not access host, network, or other users' data |
| Availability | 99.5% (MVP) |
| AI degradation | Test results always shown; diagnosis is best-effort |
| Data durability | Submissions never lost, even if diagnosis fails |

### 1.3 Constraints

- Solo developer, 8-week MVP timeline
- Budget: minimal — no GPU infra, no Kubernetes
- Initial problem set: 10–30 curated Java problems
- Single language (Java) for MVP

---

## 2. High-Level Design

### 2.1 Component Diagram

```
┌────────────────────────────────────────────────────────────┐
│                        CLIENT                              │
│                                                            │
│  React SPA (Vite + TypeScript + Tailwind)                  │
│  ┌──────────┐ ┌──────────┐ ┌────────┐ ┌───────────────┐   │
│  │ Monaco   │ │Algorithm │ │Skill   │ │ Recommendation│   │
│  │ Editor   │ │Visualizer│ │Dash    │ │ Card          │   │
│  └────┬─────┘ └──────────┘ └────────┘ └───────────────┘   │
└───────┼────────────────────────────────────────────────────┘
        │ HTTPS (REST + JSON)
        │ JWT Bearer token
┌───────▼────────────────────────────────────────────────────┐
│                   SPRING BOOT MONOLITH                     │
│                                                            │
│  ┌──────────────────── API Gateway Layer ──────────────┐   │
│  │  Rate Limiter · CORS · JWT Filter · Exception Handler│  │
│  └──────────────────────────┬─────────────────────────┘   │
│                             │                              │
│  ┌──────┐ ┌──────────┐ ┌───▼───────┐ ┌──────────────┐    │
│  │Auth  │ │Problem   │ │Submission │ │Analytics     │    │
│  │Module│ │Module    │ │Module     │ │Module        │    │
│  └──┬───┘ └──┬───────┘ └───┬───────┘ └──────┬───────┘    │
│     │        │             │                 │            │
│     │        │    ┌────────▼─────────┐       │            │
│     │        │    │  Execution       │       │            │
│     │        │    │  Orchestrator    │       │            │
│     │        │    └──┬───────────┬───┘       │            │
│     │        │       │           │           │            │
│     │        │  ┌────▼────┐ ┌───▼────────┐  │            │
│     │        │  │Judge0   │ │Diagnosis   │  │            │
│     │        │  │Client   │ │Service     │  │            │
│     │        │  └────┬────┘ │(Spring AI) │  │            │
│     │        │       │      └───┬────────┘  │            │
│     │        │       │          │           │            │
│     │     ┌──▼───────▼──────────▼───────────▼──┐         │
│     │     │        Skill Profile Service        │         │
│     │     └──────────────┬─────────────────────┘         │
│     │                    │                                │
│     │     ┌──────────────▼─────────────────────┐         │
│     │     │     Recommendation Engine           │         │
│     │     └────────────────────────────────────┘         │
│     │                                                     │
│  ┌──▼─────────────────────────────────────────────────┐   │
│  │              Spring Data JPA / Hibernate            │   │
│  └──────────────────────┬─────────────────────────────┘   │
└─────────────────────────┼─────────────────────────────────┘
          │               │                    │
┌─────────▼───┐  ┌───────▼────────┐  ┌────────▼──────────┐
│  Judge0 CE  │  │  PostgreSQL    │  │   Claude API      │
│  (Docker)   │  │                │  │   (Anthropic)     │
│             │  │  users         │  │                    │
│  Sandboxed  │  │  problems      │  │  Structured       │
│  Java       │  │  submissions   │  │  diagnosis        │
│  execution  │  │  diagnoses     │  │  via Spring AI    │
│             │  │  skill_profiles│  │                    │
└─────────────┘  └────────────────┘  └───────────────────┘
```

### 2.2 Core Data Flow

**Happy path — failed submission:**

```
1.  User writes Java code, clicks Submit
2.  POST /api/submissions { problemId, sourceCode, language }
3.  Backend creates Submission record (status: PENDING)
4.  Returns 202 { submissionId }
5.  Frontend starts polling GET /api/submissions/{id}
6.
7.  ── Async in backend ──────────────────────────────────
8.  │ Fetch test cases for this problem
9.  │ For each test case:
10. │   POST Judge0 /submissions { source_code, stdin, expected_output, ... }
11. │   Poll Judge0 until terminal status
12. │   Parse stdout, stderr, time, memory
13. │   Save TestResult row
14. │
15. │ If all passed → status = ACCEPTED, update skill profile, done
16. │
17. │ If any failed → status = WRONG_ANSWER (or COMPILE_ERROR, etc.)
18. │   Assemble evidence payload:
19. │     { code, problem, compiler_output, failing_tests, error_type }
20. │   POST Claude API (via Spring AI ChatClient)
21. │   Parse structured JSON response
22. │   Save Diagnosis row
23. │   Update skill profile (record failure + error pattern)
24. │   Recalculate recommendation if needed
25. ── End async ──────────────────────────────────────────
26.
27. Frontend poll receives terminal status
28. Renders: test results + diagnosis panel + visualizer
```

**Happy path — accepted submission:**

```
Same flow through step 15. No diagnosis needed.
Skill profile updated: increment independent_solves (or assisted_solves).
If this was today's recommended problem, mark was_solved = true.
```

---

## 3. Deep Dive

### 3.1 Submission Pipeline (the critical path)

This is the system's most important flow. It touches every backend module and both external services.

```
                    POST /api/submissions
                           │
                    ┌──────▼──────┐
                    │  Validate   │ (problem exists, code non-empty, rate limit OK)
                    │  Persist    │ (status=PENDING, save source_code)
                    │  Return 202 │
                    └──────┬──────┘
                           │ @Async (Spring thread pool)
                    ┌──────▼──────┐
                    │  Load test  │
                    │  cases      │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  Execute    │ (Judge0 — batch submit, poll)
                    │  via Judge0 │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  Parse &    │ (per-test pass/fail, stdout, stderr, time)
                    │  save       │
                    │  TestResults│
                    └──────┬──────┘
                           │
                  ┌────────▼────────┐
                  │ All passed?      │
                  └──┬───────────┬──┘
                    YES          NO
                     │            │
              ┌──────▼──┐  ┌─────▼──────┐
              │status =  │  │ status =   │
              │ACCEPTED  │  │ WRONG_ANS  │
              └──────┬───┘  │ /COMPILE_  │
                     │      │ ERR/etc    │
                     │      └─────┬──────┘
                     │            │
                     │     ┌──────▼──────┐
                     │     │  Build      │
                     │     │  evidence   │
                     │     │  payload    │
                     │     └──────┬──────┘
                     │            │
                     │     ┌──────▼──────┐
                     │     │  Call       │
                     │     │  Claude API │ (timeout: 15s, retry: 1x)
                     │     └──────┬──────┘
                     │            │
                     │     ┌──────▼──────┐
                     │     │  Validate & │
                     │     │  save       │
                     │     │  Diagnosis  │
                     │     └──────┬──────┘
                     │            │
              ┌──────▼────────────▼──────┐
              │  Update skill profile    │
              │  Update recommendation   │
              └──────────────────────────┘
```

#### Key design decisions in this pipeline:

**Async execution:** The submission is persisted synchronously (no data loss), then processing is kicked off asynchronously. The frontend polls. This keeps the API responsive and handles slow Judge0 or Claude responses gracefully.

```java
@Service
public class SubmissionService {

    @Async("submissionExecutor")
    @Transactional
    public void processSubmission(UUID submissionId) {
        Submission sub = submissionRepo.findById(submissionId).orElseThrow();
        try {
            List<TestCase> cases = testCaseRepo.findByProblemId(sub.getProblemId());
            List<TestResult> results = executionService.execute(sub, cases);
            testResultRepo.saveAll(results);

            if (results.stream().allMatch(TestResult::isPassed)) {
                sub.setStatus(SubmissionStatus.ACCEPTED);
            } else {
                sub.setStatus(classifyFailure(results));
                Diagnosis dx = diagnosisService.diagnose(sub, results, cases);
                diagnosisRepo.save(dx);
            }
            submissionRepo.save(sub);
            skillProfileService.update(sub);
        } catch (Exception e) {
            sub.setStatus(SubmissionStatus.INTERNAL_ERROR);
            submissionRepo.save(sub);
            log.error("Submission processing failed", e);
        }
    }
}
```

**Thread pool config:**

```yaml
spring:
  task:
    execution:
      pool:
        core-size: 4
        max-size: 8
        queue-capacity: 50
      thread-name-prefix: "submission-"
```

At MVP scale (~1000 users, not all submitting simultaneously), 4–8 threads processing submissions is sufficient. Each thread spends most time waiting on Judge0 and Claude I/O, so this handles ~20-40 concurrent submissions.

---

### 3.2 Judge0 Integration

```
┌────────────────┐          ┌──────────────┐
│ ExecutionService│─────────▶│  Judge0 CE   │
│                │  HTTP     │              │
│ submit(code,   │  POST     │  Compiles    │
│   tests[])     │──────────▶│  Executes    │
│                │           │  Returns     │
│ poll(tokens[]) │  GET      │  stdout/err  │
│                │◀──────────│  time/mem    │
└────────────────┘           └──────────────┘
```

**Interface:**

```java
public interface CodeExecutor {
    List<ExecutionResult> execute(String sourceCode, String language,
                                  List<TestCase> testCases,
                                  ExecutionConfig config);
}
```

**Judge0 batch flow:**

```java
@Service
public class Judge0Executor implements CodeExecutor {

    public List<ExecutionResult> execute(...) {
        // 1. Batch submit — one Judge0 submission per test case
        List<String> tokens = judge0Client.batchSubmit(
            sourceCode, languageId, testCases, config
        );

        // 2. Poll until all terminal (max 30s, 500ms interval)
        List<Judge0Response> responses = judge0Client.pollUntilDone(
            tokens, Duration.ofSeconds(30), Duration.ofMillis(500)
        );

        // 3. Map to domain model
        return responses.stream()
            .map(this::toExecutionResult)
            .toList();
    }
}
```

**Judge0 status mapping:**

| Judge0 Status ID | Meaning | Maps To |
|---|---|---|
| 1-2 | In Queue / Processing | Keep polling |
| 3 | Accepted | Compare stdout to expected |
| 4 | Wrong Answer | WRONG_ANSWER |
| 5 | Time Limit Exceeded | TIME_LIMIT |
| 6 | Compilation Error | COMPILE_ERROR |
| 7-12 | Runtime errors | RUNTIME_ERROR |
| 13 | Internal Error | Retry once, then INTERNAL_ERROR |

---

### 3.3 Diagnosis Service

**Prompt assembly:**

```java
@Service
public class DiagnosisService {

    private final ChatClient chatClient;
    private final PromptTemplate diagnosisPrompt;

    public Diagnosis diagnose(Submission sub, List<TestResult> results,
                               List<TestCase> cases) {

        TestResult firstFailing = results.stream()
            .filter(r -> !r.isPassed()).findFirst().orElseThrow();
        TestCase failingCase = findCase(cases, firstFailing);

        String prompt = diagnosisPrompt.render(Map.of(
            "title",           sub.getProblem().getTitle(),
            "description",     sub.getProblem().getDescription(),
            "difficulty",      sub.getProblem().getDifficulty(),
            "topics",          sub.getProblem().getSkillNames(),
            "source_code",     sub.getSourceCode(),
            "status",          sub.getStatus(),
            "compiler_error",  firstFailing.getErrorOutput(),
            "input",           failingCase.getInput(),
            "expected_output", failingCase.getExpectedOutput(),
            "actual_output",   firstFailing.getActualOutput()
        ));

        // Call Claude API with structured output
        DiagnosisResponse response = chatClient.prompt()
            .user(prompt)
            .call()
            .entity(DiagnosisResponse.class);  // Spring AI JSON binding

        return toDiagnosis(sub.getId(), response);
    }
}
```

**Structured output DTO:**

```java
public record DiagnosisResponse(
    String errorCategory,
    String errorSubcategory,
    String explanation,
    String counterexampleInput,
    String counterexampleExpected,
    String counterexampleActual,
    List<Integer> relevantCodeLines,
    String suggestion,
    double confidence
) {}
```

**Failure handling:**

| Failure | Action |
|---|---|
| Claude API timeout (15s) | Retry once. If still fails, save submission without diagnosis. |
| Malformed JSON response | Log, retry once with stricter prompt suffix. |
| Confidence < 0.4 | Store diagnosis but flag as low-confidence in UI. |
| Rate limit (429) | Exponential backoff, max 2 retries. |

The diagnosis is **never required** for the submission to complete. The user always sees test results. Diagnosis is additive.

---

### 3.4 Skill Profile Service

**Proficiency calculation:**

```java
@Service
public class SkillProfileService {

    public void update(Submission submission) {
        List<Skill> skills = submission.getProblem().getSkills();
        for (Skill skill : skills) {
            UserSkillProfile profile = getOrCreate(submission.getUserId(), skill.getId());

            profile.setTotalAttempts(profile.getTotalAttempts() + 1);

            if (submission.getStatus() == ACCEPTED) {
                if (submission.getAssistLevel() == NONE || submission.getAssistLevel() == HINT) {
                    profile.setIndependentSolves(profile.getIndependentSolves() + 1);
                } else {
                    profile.setAssistedSolves(profile.getAssistedSolves() + 1);
                }
            }

            // Update error patterns from diagnosis
            if (submission.getDiagnosis() != null) {
                appendErrorPattern(profile, submission.getDiagnosis());
            }

            profile.setProficiencyScore(calculateProficiency(profile));
            profile.setLastPracticedAt(Instant.now());
            skillProfileRepo.save(profile);
        }
    }

    private double calculateProficiency(UserSkillProfile p) {
        if (p.getTotalAttempts() == 0) return 0.0;
        double weighted = (p.getIndependentSolves() * 1.0)
                        + (p.getAssistedSolves() * 0.3);
        return Math.min(100.0, (weighted / p.getTotalAttempts()) * 100.0);
    }
}
```

**Error pattern tracking (JSONB):**

```json
[
  { "pattern": "off_by_one", "count": 3, "lastSeen": "2026-10-28" },
  { "pattern": "wrong_window_shrink", "count": 2, "lastSeen": "2026-10-30" }
]
```

Capped at 20 most recent patterns per skill. Old patterns decay naturally as they drop off.

---

### 3.5 Recommendation Engine

```java
@Service
public class RecommendationEngine {

    public DailyRecommendation recommend(UUID userId) {
        List<UserSkillProfile> profiles = skillProfileRepo
            .findByUserIdOrderByProficiencyAsc(userId);

        // Step 1: Find weakest skills with enough evidence
        List<UserSkillProfile> candidates = profiles.stream()
            .filter(p -> p.getTotalAttempts() >= 2)
            .filter(p -> p.getProficiencyScore() < 80.0)
            .toList();

        if (candidates.isEmpty()) {
            // All skills strong or untested — pick least-practiced
            candidates = profiles.stream()
                .sorted(comparing(UserSkillProfile::getTotalAttempts))
                .limit(3)
                .toList();
        }

        // Step 2: Prefer stale skills (not practiced in 3+ days)
        UserSkillProfile target = candidates.stream()
            .filter(p -> p.getLastPracticedAt() == null ||
                p.getLastPracticedAt().isBefore(Instant.now().minus(3, DAYS)))
            .findFirst()
            .orElse(candidates.get(0));

        // Step 3: Pick difficulty
        Difficulty diff = target.getProficiencyScore() < 30 ? EASY
                        : target.getProficiencyScore() < 70 ? MEDIUM
                        : HARD;

        // Step 4: Find unsolved problem in this skill at this difficulty
        Problem problem = problemRepo.findUnsolved(
            userId, target.getSkillId(), diff
        );

        // Step 5: Generate rationale
        String rationale = buildRationale(target, problem);

        return new DailyRecommendation(userId, problem.getId(),
            LocalDate.now(), rationale, target.getSkillId());
    }
}
```

**Rationale template:**

```
"Your {skill} proficiency is {score}% — you've had difficulty with
{topErrorPattern} in recent attempts. This {difficulty} problem
focuses on {problemSkill} and will help reinforce {concept}."
```

---

### 3.6 Algorithm Visualizer (Frontend)

**Architecture:**

```
┌─────────────────────────────────────────────────┐
│                VisualizerContainer               │
│                                                  │
│  ┌───────────────┐    ┌────────────────────────┐ │
│  │ PlaybackBar   │    │   StateInspector       │ │
│  │ ◀ ▶ ⏸ ⏹ ⚡   │    │   variables: {         │ │
│  │ step: 4/12    │    │     left: 0            │ │
│  └───────┬───────┘    │     right: 3           │ │
│          │            │     maxLen: 2           │ │
│  ┌───────▼──────────┐ │   }                    │ │
│  │ SVG Canvas       │ └────────────────────────┘ │
│  │                  │                            │
│  │  ┌─┬─┬─┬─┬─┬─┐  │ ┌────────────────────────┐ │
│  │  │a│b│c│a│d│e│  │ │  CodeHighlighter       │ │
│  │  └─┴─┴─┴─┴─┴─┘  │ │                        │ │
│  │   ▲       ▲      │ │  line 5: ►             │ │
│  │   L       R      │ │  line 6:               │ │
│  │  [window]        │ │  line 7:               │ │
│  └──────────────────┘ └────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

**State snapshot model:**

```typescript
interface ExecutionSnapshot {
  step: number;
  line: number;                    // current source line
  variables: Record<string, any>;  // { left: 0, right: 3, maxLen: 2 }
  dataStructures: {
    type: 'array' | 'set' | 'map' | 'stack' | 'queue';
    name: string;
    values: any[];
    highlights: {                  // which indices to highlight
      index: number;
      color: 'pointer-left' | 'pointer-right' | 'window' | 'current';
      label?: string;
    }[];
  }[];
  annotation?: string;            // "Window shrinks: removing 'a'"
}

type ExecutionTrace = ExecutionSnapshot[];
```

**How traces are generated (MVP):**

For the initial 10 problems, traces are generated server-side by a **custom Java trace recorder** per problem type — not by instrumenting arbitrary code. Each problem has a `TraceGenerator` that runs the reference solution and records snapshots:

```java
public interface TraceGenerator {
    List<ExecutionSnapshot> generate(String input);
}

// Example: sliding window trace
public class SlidingWindowTraceGenerator implements TraceGenerator {
    public List<ExecutionSnapshot> generate(String input) {
        List<ExecutionSnapshot> trace = new ArrayList<>();
        // Run algorithm step by step, snapshot at each iteration
        // Record: line, variables, array state, pointer positions
        return trace;
    }
}
```

This avoids the complexity of general-purpose code instrumentation. The visualizer shows how the **correct algorithm** executes on the **failing input** — helping the learner understand the expected behavior.

**Frontend playback:**

```typescript
const usePlayback = (trace: ExecutionTrace) => {
  const [step, setStep] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [speed, setSpeed] = useState(1); // 0.5x, 1x, 2x

  useEffect(() => {
    if (!playing) return;
    const interval = setInterval(() => {
      setStep(s => {
        if (s >= trace.length - 1) { setPlaying(false); return s; }
        return s + 1;
      });
    }, 1000 / speed);
    return () => clearInterval(interval);
  }, [playing, speed]);

  return {
    snapshot: trace[step],
    step, total: trace.length,
    play: () => setPlaying(true),
    pause: () => setPlaying(false),
    stepForward: () => setStep(s => Math.min(s + 1, trace.length - 1)),
    stepBackward: () => setStep(s => Math.max(s - 1, 0)),
    reset: () => { setStep(0); setPlaying(false); },
    setSpeed,
  };
};
```

---

### 3.7 API Contract Summary

**Auth:**

```
POST   /api/auth/register       { email, password, displayName } → 201 { userId, token }
POST   /api/auth/login           { email, password }              → 200 { token, refreshToken }
POST   /api/auth/refresh         { refreshToken }                 → 200 { token }
GET    /api/auth/me                                               → 200 { user }
```

**Problems:**

```
GET    /api/problems             ?difficulty=MEDIUM&skill=sliding-window&status=unsolved
                                                                  → 200 { problems[], total }
GET    /api/problems/{id}                                         → 200 { problem, sampleTests[] }
```

**Submissions:**

```
POST   /api/submissions          { problemId, sourceCode }        → 202 { submissionId }
GET    /api/submissions/{id}     (poll until terminal)            → 200 { submission, testResults[], diagnosis? }
GET    /api/submissions          ?problemId=X&page=0&size=20      → 200 { submissions[], total }
```

**Coaching:**

```
POST   /api/coaching/hint        { submissionId }                 → 200 { hint, level }
POST   /api/coaching/explain     { submissionId }                 → 200 { explanation }
POST   /api/coaching/solution    { problemId }                    → 200 { solution, walkthrough }
```

**Skills & Profile:**

```
GET    /api/skills/profile                                        → 200 { skills[] with proficiency }
GET    /api/skills/error-patterns                                 → 200 { patterns[] }
```

**Recommendations:**

```
GET    /api/recommendations/today                                 → 200 { problem, rationale, targetSkill }
GET    /api/recommendations/history  ?page=0&size=30              → 200 { recommendations[] }
```

**Analytics:**

```
GET    /api/analytics/overview                                    → 200 { totalSolved, streak,
                                                                          independentRate, topWeakness,
                                                                          recentProgress }
GET    /api/analytics/progress   ?days=30                         → 200 { dailyStats[] }
```

**Feedback:**

```
POST   /api/feedback             { diagnosisId?, recommendationId?,
                                   type, comment }                → 201
```

---

### 3.8 Data Model (Entity Relationships)

```
users
  │
  ├──< submissions >── problems ──< test_cases
  │        │                │
  │        ├──< test_results (per submission × test_case)
  │        │
  │        └──1 diagnosis
  │
  ├──< user_skill_profiles >── skills >──< problem_skills
  │
  ├──< daily_recommendations >── problems
  │
  ├──< learning_sessions
  │
  └──< user_feedback
```

**Key indexes:**

```sql
-- Hot query: user's submissions for a problem
CREATE INDEX idx_submissions_user_problem
  ON submissions(user_id, problem_id, submitted_at DESC);

-- Polling: recent pending submissions
CREATE INDEX idx_submissions_status
  ON submissions(status) WHERE status IN ('PENDING','COMPILING','RUNNING');

-- Recommendation: unsolved problems by skill and difficulty
CREATE INDEX idx_problem_skills_difficulty
  ON problems(difficulty)
  INCLUDE (id, title);

-- Skill profile lookup
CREATE UNIQUE INDEX idx_user_skill
  ON user_skill_profiles(user_id, skill_id);

-- Daily recommendation uniqueness
CREATE UNIQUE INDEX idx_daily_rec
  ON daily_recommendations(user_id, recommended_date);
```

---

## 4. Scale & Reliability

### 4.1 Load Estimation (MVP)

| Metric | Estimate |
|---|---|
| Registered users | ~1,000 |
| Daily active users | ~200 |
| Submissions per day | ~1,000 (5 per active user) |
| Judge0 executions per day | ~5,000 (5 test cases avg × 1,000 submissions) |
| Claude API calls per day | ~400 (40% of submissions fail) |
| Peak concurrent submissions | ~20 |

This is comfortably handled by a single Spring Boot instance with 4-8 async threads and a single Judge0 worker.

### 4.2 Bottleneck Analysis

| Component | Bottleneck | Mitigation |
|---|---|---|
| Judge0 | Worker queue saturation at ~50 concurrent | Cap async threads; queue submissions; user sees "processing" |
| Claude API | 3-8s latency per call, rate limits | Async; cache diagnosis per submission (never re-diagnose same submission); show test results while diagnosis loads |
| PostgreSQL | Not a bottleneck at this scale | Indexes on hot paths; connection pool size 10-20 |
| Frontend | Monaco editor load (~2MB) | Lazy load; code-split editor from landing page |

### 4.3 Failure Modes & Recovery

```
┌──────────────────┐    ┌────────────────────┐    ┌───────────────────┐
│  Judge0 down     │    │  Claude API down   │    │  PostgreSQL down  │
│                  │    │                    │    │                   │
│  Submission      │    │  Submission        │    │  Entire app       │
│  saved but       │    │  completes with    │    │  returns 503      │
│  returns         │    │  test results      │    │                   │
│  INTERNAL_ERROR  │    │  only, no          │    │  Submissions in   │
│                  │    │  diagnosis          │    │  flight are lost  │
│  User sees       │    │                    │    │  (acceptable at   │
│  "execution      │    │  User sees         │    │  MVP scale)       │
│  service busy,   │    │  "Diagnosis         │    │                   │
│  try again"      │    │  unavailable"       │    │  Mitigation:      │
│                  │    │  with test panel    │    │  managed DB with  │
│  Auto-retry: 1x  │    │                    │    │  daily backups    │
└──────────────────┘    │  No retry needed   │    └───────────────────┘
                        │  (user can request │
                        │  diagnosis later)  │
                        └────────────────────┘
```

**Invariant:** A submission's source code is persisted to PostgreSQL **before** any external call. The user's work is never lost.

### 4.4 Rate Limiting

| Endpoint | Limit | Scope |
|---|---|---|
| POST /api/submissions | 10 / minute | Per user |
| POST /api/coaching/* | 20 / hour | Per user |
| POST /api/auth/login | 5 / minute | Per IP |
| All endpoints | 100 / minute | Per user (global) |

Implemented with Spring's `RateLimiter` (in-memory bucket for MVP; Redis-backed later).

---

## 5. Trade-off Summary

| Decision | Chose | Over | Why |
|---|---|---|---|
| Monolith | Spring Boot modular monolith | Microservices | 8-week solo dev. Clean module boundaries allow later extraction. |
| Execution | Judge0 CE (external) | Custom sandbox | Security-hardened sandbox is a project in itself. Judge0 is battle-tested. |
| AI | Claude API (hosted) | Self-hosted model | Frontier reasoning quality needed for code diagnosis. No GPU budget. |
| Diagnosis trigger | Async after submission | Streaming/SSE | Simpler. Polling is adequate for 5-12s operations. Upgrade to SSE if UX demands. |
| Recommendations | Rule-based | ML/collaborative filtering | 10-30 problems don't need ML. Rules are explainable (product requirement). |
| Visualizer | Pre-built traces per problem | General code instrumentation | Instrumentation is a research problem. Curated traces are reliable and buildable. |
| State management | TanStack Query + Zustand | Redux | API-driven app; server state dominates. No need for Redux complexity. |
| Auth | JWT (stateless) | Sessions | Simple; no Redis needed for sessions. |
| Deployment | Single VM + managed DB | Kubernetes | Solo dev. No orchestration needed at MVP scale. |

### What to revisit at 10x scale (~10,000 users)

- Add Redis for rate limiting, caching, and session management
- Move Judge0 to a dedicated VM cluster with multiple workers
- Consider SSE/WebSocket for real-time submission status instead of polling
- Extract diagnosis service if AI calls need independent scaling or queuing
- Add CDN for static assets and problem content
- Consider pgvector for semantic search over problems and educational content
- Evaluate ML-based recommendation engine once problem catalog exceeds 100