package com.thoughttrace.common.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * @param baseUrl          Judge0 CE base URL
 * @param authToken        value for the X-Auth-Token header; blank in local dev
 * @param javaLanguageId   Judge0 language id (62 = Java OpenJDK 13)
 * @param pollIntervalMs   delay between result polls
 * @param pollTimeoutMs    give up on a submission token after this long
 */
@ConfigurationProperties(prefix = "thoughttrace.judge0")
public record Judge0Properties(
        String baseUrl,
        String authToken,
        int javaLanguageId,
        long pollIntervalMs,
        long pollTimeoutMs) {
}
