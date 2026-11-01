package com.thoughttrace.common.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * @param secret            base64-encoded signing key, at least 256 bits
 * @param expirationMinutes access token lifetime
 */
@ConfigurationProperties(prefix = "thoughttrace.jwt")
public record JwtProperties(String secret, long expirationMinutes) {
}
