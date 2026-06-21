package com.alibaba.cloud.ai.studio.admin;

import org.springframework.ai.chat.client.observation.ChatClientObservationConvention;
import org.springframework.ai.chat.observation.ChatModelObservationConvention;
import org.springframework.ai.model.tool.ToolCallingManager;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.context.annotation.Profile;

import static org.mockito.Mockito.mock;

@TestConfiguration
@Profile("test")
public class TestInfrastructureConfig {

    @Bean
    @Primary
    public ChatModelObservationConvention customChatModelObservationConvention() {
        return mock(ChatModelObservationConvention.class);
    }

    @Bean
    @Primary
    public ChatClientObservationConvention customObservationConvention() {
        return mock(ChatClientObservationConvention.class);
    }

    @Bean
    @Primary
    public ToolCallingManager toolCallingManager() {
        return mock(ToolCallingManager.class);
    }

}
