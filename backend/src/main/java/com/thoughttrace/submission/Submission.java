package com.thoughttrace.submission;

import com.thoughttrace.auth.User;
import com.thoughttrace.problem.Problem;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.UuidGenerator;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "submissions")
@Getter
@Setter
@Builder
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor
public class Submission {

    @Id
    @GeneratedValue
    @UuidGenerator
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "problem_id", nullable = false)
    private Problem problem;

    /** Persisted before any call to Judge0 or the AI, so a failure downstream never loses work. */
    @Column(name = "source_code", nullable = false, columnDefinition = "text")
    private String sourceCode;

    @Column(nullable = false, length = 20)
    private String language;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private SubmissionStatus status;

    @Column(name = "submitted_at", nullable = false, updatable = false)
    private Instant submittedAt;

    @Column(name = "execution_time_ms")
    private Integer executionTimeMs;

    @Column(name = "memory_used_kb")
    private Integer memoryUsedKb;

    @Column(name = "was_assisted", nullable = false)
    private boolean assisted;

    @Enumerated(EnumType.STRING)
    @Column(name = "assist_level", nullable = false, length = 10)
    private AssistLevel assistLevel;

    @jakarta.persistence.PrePersist
    void onCreate() {
        if (submittedAt == null) {
            submittedAt = Instant.now();
        }
        if (language == null) {
            language = "java";
        }
        if (status == null) {
            status = SubmissionStatus.PENDING;
        }
        if (assistLevel == null) {
            assistLevel = AssistLevel.NONE;
        }
    }
}
