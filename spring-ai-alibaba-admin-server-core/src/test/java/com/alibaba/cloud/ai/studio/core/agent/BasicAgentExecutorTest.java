package com.alibaba.cloud.ai.studio.core.agent;

import com.alibaba.cloud.ai.studio.core.agent.tool.CompositeToolCallbackProvider;
import com.alibaba.cloud.ai.studio.core.base.manager.AppComponentManager;
import com.alibaba.cloud.ai.studio.core.base.manager.DocumentRetrieverManager;
import com.alibaba.cloud.ai.studio.core.base.manager.FileManager;
import com.alibaba.cloud.ai.studio.core.base.service.McpServerService;
import com.alibaba.cloud.ai.studio.core.base.service.PluginService;
import com.alibaba.cloud.ai.studio.core.base.service.ToolExecutionService;
import com.alibaba.cloud.ai.studio.core.config.CommonConfig;
import com.alibaba.cloud.ai.studio.core.model.llm.ModelFactory;
import com.alibaba.cloud.ai.studio.runtime.domain.agent.AgentResponse;
import com.alibaba.cloud.ai.studio.runtime.domain.app.AgentConfig;
import com.alibaba.cloud.ai.studio.runtime.domain.chat.ToolCallType;
import com.alibaba.cloud.ai.studio.runtime.domain.agent.AgentStatus;
import org.junit.jupiter.api.Test;
import org.springframework.ai.chat.memory.ChatMemory;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.messages.ToolResponseMessage;
import org.springframework.ai.chat.metadata.ChatResponseMetadata;
import org.springframework.ai.chat.model.ChatResponse;
import org.springframework.ai.chat.model.Generation;
import org.springframework.ai.model.tool.ToolExecutionResult;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertAll;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;

class BasicAgentExecutorTest {

    @Test
    void convertToolResultReturnsInProgressAssistantMessageWithToolResultCall() {
        TestableBasicAgentExecutor executor = new TestableBasicAgentExecutor();
        CompositeToolCallbackProvider provider = new CompositeToolCallbackProvider(new AgentConfig(),
                mock(PluginService.class), mock(ToolExecutionService.class), mock(McpServerService.class),
                mock(AppComponentManager.class), Map.of());
        ToolExecutionResult toolExecutionResult = ToolExecutionResult.builder()
            .conversationHistory(List.<Message>of(new AssistantMessage("call weather"),
                    new ToolResponseMessage(List.of(new ToolResponseMessage.ToolResponse("call-1", "getWeather",
                            "{\"temp\":18}")))))
            .build();
        ChatResponse llmToolCallResponse = new ChatResponse(List.of(new Generation(new AssistantMessage(""))),
                ChatResponseMetadata.builder().model("qwen-test").build());

        AgentResponse response = executor.exposeConvertToolResult(llmToolCallResponse, toolExecutionResult, provider);

        assertAll(
                () -> assertEquals("qwen-test", response.getModel()),
                () -> assertEquals(AgentStatus.IN_PROGRESS, response.getStatus()),
                () -> assertEquals(1, response.getMessage().getToolCalls().size()),
                () -> assertEquals(ToolCallType.TOOL_RESULT, response.getMessage().getToolCalls().get(0).getType()),
                () -> assertEquals("getWeather", response.getMessage().getToolCalls().get(0).getFunction().getName()),
                () -> assertEquals("{\"temp\":18}",
                        response.getMessage().getToolCalls().get(0).getFunction().getOutput()));
    }

    private static class TestableBasicAgentExecutor extends BasicAgentExecutor {

        TestableBasicAgentExecutor() {
            super(mock(ToolExecutionService.class), mock(PluginService.class), mock(McpServerService.class),
                    mock(AppComponentManager.class), mock(DocumentRetrieverManager.class), mock(ChatMemory.class),
                    new CommonConfig(), mock(ModelFactory.class), mock(FileManager.class));
        }

        AgentResponse exposeConvertToolResult(ChatResponse response, ToolExecutionResult toolExecutionResult,
                CompositeToolCallbackProvider provider) {
            return convertToolResult(response, toolExecutionResult, provider);
        }

    }

}
