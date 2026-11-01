package com.thoughttrace.common.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.List;

@ConfigurationProperties(prefix = "thoughttrace.cors")
public record CorsProperties(List<String> allowedOrigins) {
}
