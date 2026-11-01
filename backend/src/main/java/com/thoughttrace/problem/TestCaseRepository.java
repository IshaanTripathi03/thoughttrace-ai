package com.thoughttrace.problem;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface TestCaseRepository extends JpaRepository<TestCase, UUID> {

    List<TestCase> findByProblemIdOrderByOrderIndexAsc(UUID problemId);

    List<TestCase> findByProblemIdAndSampleTrueOrderByOrderIndexAsc(UUID problemId);
}
