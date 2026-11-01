package com.thoughttrace.submission;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface SubmissionRepository extends JpaRepository<Submission, UUID> {

    Page<Submission> findByUserIdOrderBySubmittedAtDesc(UUID userId, Pageable pageable);

    List<Submission> findByUserIdAndProblemIdOrderBySubmittedAtDesc(UUID userId, UUID problemId);

    long countByUserIdAndProblemIdAndStatus(UUID userId, UUID problemId, SubmissionStatus status);
}
