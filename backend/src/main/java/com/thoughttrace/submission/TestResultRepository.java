package com.thoughttrace.submission;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface TestResultRepository extends JpaRepository<TestResult, UUID> {

    List<TestResult> findBySubmissionIdOrderByTestCaseOrderIndexAsc(UUID submissionId);
}
