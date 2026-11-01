package com.thoughttrace.problem;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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

import java.util.UUID;

@Entity
@Table(name = "test_cases")
@Getter
@Setter
@Builder
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor
public class TestCase {

    @Id
    @GeneratedValue
    @UuidGenerator
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "problem_id", nullable = false)
    private Problem problem;

    @Column(nullable = false, columnDefinition = "text")
    private String input;

    @Column(name = "expected_output", nullable = false, columnDefinition = "text")
    private String expectedOutput;

    /** Hidden cases are never returned to the client, only used for grading. */
    @Column(name = "is_hidden", nullable = false)
    private boolean hidden;

    /** Sample cases are shown on the problem page. */
    @Column(name = "is_sample", nullable = false)
    private boolean sample;

    @Column(name = "order_index", nullable = false)
    private int orderIndex;
}
