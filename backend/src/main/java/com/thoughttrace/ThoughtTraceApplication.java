package com.thoughttrace;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;

@SpringBootApplication
@EnableAsync
public class ThoughtTraceApplication {

    public static void main(String[] args) {
        SpringApplication.run(ThoughtTraceApplication.class, args);
    }
}
