package com.thoughttrace.problem;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ProblemRepository extends JpaRepository<Problem, UUID> {

    Optional<Problem> findBySlug(String slug);

    boolean existsBySlug(String slug);

    List<Problem> findByActiveTrueOrderByDifficultyAscTitleAsc();

    List<Problem> findByActiveTrueAndDifficultyOrderByTitleAsc(Difficulty difficulty);
}
