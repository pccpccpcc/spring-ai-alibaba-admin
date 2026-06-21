package com.alibaba.cloud.ai.studio.admin;

import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

/**
 * 所有需要中间件的集成测试基类。
 *
 * <p>
 * 这些测试连接<strong>本地真实中间件</strong>（docker-compose / 本机安装的 MySQL、Redis、RocketMQ），
 * 不使用 Testcontainers，也不对中间件做 mock。执行前请先确保本地中间件已就绪：
 * {@code scripts/deps-start.sh} 或 {@code scripts/deps-status.sh}。
 * </p>
 *
 * <p>
 * 为避免污染真实业务库（默认 {@code admin}），测试使用独立的 {@code admin_test} 数据库（首次运行前需由
 * root 创建并授权给 {@code admin} 用户，详见 {@code docs/test-plan.md}）。Redis 使用 db 1，与控制台默认
 * 的 db 0 隔离。RocketMQ 复用本地的 {@code topic_saa_studio_document_index} 主题与消费组。
 * </p>
 */
public abstract class RealMiddlewareSpringBootTest {

    private static final String MYSQL_HOST = System.getenv().getOrDefault("TEST_MYSQL_HOST", "localhost");

    private static final int MYSQL_PORT = Integer.parseInt(System.getenv().getOrDefault("TEST_MYSQL_PORT", "3306"));

    private static final String MYSQL_DATABASE = System.getenv().getOrDefault("TEST_MYSQL_DATABASE", "admin_test");

    private static final String MYSQL_USER = System.getenv().getOrDefault("TEST_MYSQL_USER", "admin");

    private static final String MYSQL_PASSWORD = System.getenv().getOrDefault("TEST_MYSQL_PASSWORD", "admin");

    private static final String REDIS_HOST = System.getenv().getOrDefault("TEST_REDIS_HOST", "localhost");

    private static final int REDIS_PORT = Integer.parseInt(System.getenv().getOrDefault("TEST_REDIS_PORT", "6379"));

    private static final String ROCKETMQ_ENDPOINTS = System.getenv()
        .getOrDefault("TEST_ROCKETMQ_ENDPOINTS", "localhost:18080");

    @DynamicPropertySource
    static void middlewareProperties(DynamicPropertyRegistry registry) {
        String jdbcUrl = String.format(
                "jdbc:mysql://%s:%d/%s?useUnicode=true&characterEncoding=utf-8&zeroDateTimeBehavior=convertToNull"
                        + "&allowMultiQueries=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai",
                MYSQL_HOST, MYSQL_PORT, MYSQL_DATABASE);

        registry.add("spring.datasource.url", () -> jdbcUrl);
        registry.add("spring.datasource.username", () -> MYSQL_USER);
        registry.add("spring.datasource.password", () -> MYSQL_PASSWORD);
        registry.add("spring.datasource.driver-class-name", () -> "com.mysql.cj.jdbc.Driver");

        registry.add("spring.jpa.properties.jakarta.persistence.jdbc.url", () -> jdbcUrl);
        registry.add("spring.jpa.properties.jakarta.persistence.jdbc.user", () -> MYSQL_USER);
        registry.add("spring.jpa.properties.jakarta.persistence.jdbc.password", () -> MYSQL_PASSWORD);
        registry.add("spring.jpa.properties.jakarta.persistence.jdbc.driver", () -> "com.mysql.cj.jdbc.Driver");

        registry.add("spring.data.redis.host", () -> REDIS_HOST);
        registry.add("spring.data.redis.port", () -> REDIS_PORT);
        // 与控制台默认 db 0 隔离，避免污染真实 token 缓存。
        registry.add("spring.data.redis.database", () -> 1);

        registry.add("rocketmq.endpoints", () -> ROCKETMQ_ENDPOINTS);
    }

}
