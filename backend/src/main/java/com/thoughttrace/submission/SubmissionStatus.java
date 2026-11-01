package com.thoughttrace.submission;

public enum SubmissionStatus {
    PENDING,
    COMPILING,
    RUNNING,
    ACCEPTED,
    WRONG_ANSWER,
    COMPILE_ERROR,
    RUNTIME_ERROR,
    TIME_LIMIT,
    MEMORY_LIMIT,
    /** Judge0 or the orchestrator failed; the submission itself is not the user's fault. */
    INTERNAL_ERROR;

    public boolean isTerminal() {
        return this != PENDING && this != COMPILING && this != RUNNING;
    }

    public boolean isFailure() {
        return isTerminal() && this != ACCEPTED;
    }
}
