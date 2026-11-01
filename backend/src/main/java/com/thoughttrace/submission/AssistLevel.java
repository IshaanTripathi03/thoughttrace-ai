package com.thoughttrace.submission;

/**
 * How much help the learner had received by the time they submitted.
 * Feeds the proficiency calculation: only NONE counts as an independent solve.
 */
public enum AssistLevel {
    NONE,
    HINT,
    DEBUG,
    EXPLAIN,
    SOLUTION
}
