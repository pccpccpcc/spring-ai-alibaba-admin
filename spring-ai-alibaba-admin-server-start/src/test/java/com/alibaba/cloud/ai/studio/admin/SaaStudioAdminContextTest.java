package com.alibaba.cloud.ai.studio.admin;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationContext;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;

import static org.junit.jupiter.api.Assertions.assertNotNull;

@SpringBootTest
@ActiveProfiles("test")
@Import(TestInfrastructureConfig.class)
class SaaStudioAdminContextTest extends RealMiddlewareSpringBootTest {

    @Test
    void contextLoadsWithTestDatasourceRedisAndMqProfile(ApplicationContext context) {
        assertNotNull(context);
    }

}
