package com.alibaba.cloud.ai.studio.admin.service.impl;

import com.alibaba.cloud.ai.studio.admin.dto.ChatSession;
import com.alibaba.cloud.ai.studio.admin.dto.ModelConfigInfo;
import com.alibaba.cloud.ai.studio.admin.dto.PromptRunResponse;
import com.alibaba.cloud.ai.studio.admin.dto.request.PromptRunRequest;
import com.alibaba.cloud.ai.studio.admin.repository.ModelConfigRepository;
import com.alibaba.cloud.ai.studio.admin.service.client.ChatClientFactoryDelegate;
import com.alibaba.cloud.ai.studio.admin.utils.ModelConfigParser;
import com.alibaba.cloud.ai.studio.core.base.manager.ModelManager;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.micrometer.observation.ObservationRegistry;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.ChatClientResponse;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.messages.SystemMessage;
import org.springframework.ai.chat.messages.UserMessage;
import org.springframework.ai.chat.metadata.ChatGenerationMetadata;
import org.springframework.ai.chat.model.ChatResponse;
import org.springframework.ai.chat.model.Generation;
import org.springframework.ai.chat.prompt.Prompt;
import reactor.core.publisher.Flux;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertAll;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class PromptRunServiceImplTest {

    @Test
    @SuppressWarnings("unchecked")
    void runReturnsSessionInfoThenStreamChunksAndMetricsForRenderedPrompt() {
        ObjectMapper objectMapper = new ObjectMapper();
        ModelConfigRepository modelConfigRepository = mock(ModelConfigRepository.class);
        ModelManager modelManager = mock(ModelManager.class);
        ChatClientFactoryDelegate chatClientFactoryDelegate = mock(ChatClientFactoryDelegate.class);
        ModelConfigParser modelConfigParser = new ModelConfigParser(objectMapper, modelConfigRepository, modelManager);
        ChatSessionServiceImpl chatSessionService = new ChatSessionServiceImpl(chatClientFactoryDelegate,
                modelConfigParser);
        PromptRunServiceImpl service = new PromptRunServiceImpl(chatSessionService, chatClientFactoryDelegate,
                modelConfigParser, objectMapper, ObservationRegistry.NOOP);

        ChatClient chatClient = mock(ChatClient.class);
        ChatClient.ChatClientRequestSpec requestSpec = mock(ChatClient.ChatClientRequestSpec.class);
        ChatClient.StreamResponseSpec streamSpec = mock(ChatClient.StreamResponseSpec.class);
        ArgumentCaptor<Prompt> promptCaptor = ArgumentCaptor.forClass(Prompt.class);
        ArgumentCaptor<Map<String, Object>> modelParametersCaptor = ArgumentCaptor.forClass(Map.class);

        when(modelConfigRepository.existsById(101L)).thenReturn(true);
        when(chatClientFactoryDelegate.createChatClient(eq(101L), modelParametersCaptor.capture(), anyList(),
                any(Map.class)))
                .thenReturn(chatClient);
        when(chatClient.prompt(promptCaptor.capture())).thenReturn(requestSpec);
        when(requestSpec.toolCallbacks(anyList())).thenReturn(requestSpec);
        when(requestSpec.stream()).thenReturn(streamSpec);
        when(streamSpec.chatClientResponse()).thenReturn(Flux.just(messageChunk("Hello "), messageChunk("Ada"),
                finishChunk("trace-001")));

        PromptRunRequest request = new PromptRunRequest();
        request.setNewSession(true);
        request.setPromptKey("playground");
        request.setVersion("v1");
        request.setTemplate("You are {{name}}.");
        request.setVariables("{\"name\":\"Ada\"}");
        request.setModelConfig("{\"modelId\":101,\"temperature\":0.2}");
        request.setMessage("Say hi");

        List<PromptRunResponse> responses = service.run(request).collectList().block();

        Prompt prompt = promptCaptor.getValue();
        List<Message> messages = prompt.getInstructions();
        String sessionId = responses.get(0).getSessionId();
        ChatSession session = service.getSession(sessionId);

        assertAll(
                () -> assertEquals(4, responses.size()),
                () -> assertEquals("session_info", responses.get(0).getType()),
                () -> assertEquals(sessionId, responses.get(0).getSessionId()),
                () -> assertEquals(false, responses.get(0).getNewSession()),
                () -> assertEquals(1, responses.get(0).getMessageCount()),
                () -> assertNull(responses.get(0).getError()),
                () -> assertEquals("message", responses.get(1).getType()),
                () -> assertEquals("Hello ", responses.get(1).getContent()),
                () -> assertEquals("message", responses.get(2).getType()),
                () -> assertEquals("Ada", responses.get(2).getContent()),
                () -> assertEquals("metrics", responses.get(3).getType()),
                () -> assertEquals("trace-001", responses.get(3).getMetrics().getTraceId()));

        assertAll(
                () -> assertEquals(2, messages.size()),
                () -> assertInstanceOf(SystemMessage.class, messages.get(0)),
                () -> assertEquals("You are Ada.", messages.get(0).getText()),
                () -> assertInstanceOf(UserMessage.class, messages.get(1)),
                () -> assertEquals("Say hi", messages.get(1).getText()));

        assertAll(
                () -> assertEquals(2, session.getMessageCount()),
                () -> assertEquals("user", session.getMessages().get(0).getRole()),
                () -> assertEquals("Say hi", session.getMessages().get(0).getContent()),
                () -> assertEquals("assistant", session.getMessages().get(1).getRole()),
                () -> assertEquals("Hello Ada", session.getMessages().get(1).getContent()),
                () -> assertEquals(101L, session.getModelConfig().getModelId()),
                () -> assertEquals(0.2, session.getModelConfig().getParameter("temperature")),
                () -> assertEquals(0.2, modelParametersCaptor.getValue().get("temperature")));

        verify(modelConfigRepository, times(2)).existsById(101L);
    }

    @Test
    @SuppressWarnings("unchecked")
    void runWithExistingSessionCarriesPreviousUserAndAssistantMessages() {
        ObjectMapper objectMapper = new ObjectMapper();
        ModelConfigRepository modelConfigRepository = mock(ModelConfigRepository.class);
        ModelManager modelManager = mock(ModelManager.class);
        ChatClientFactoryDelegate chatClientFactoryDelegate = mock(ChatClientFactoryDelegate.class);
        ModelConfigParser modelConfigParser = new ModelConfigParser(objectMapper, modelConfigRepository, modelManager);
        ChatSessionServiceImpl chatSessionService = new ChatSessionServiceImpl(chatClientFactoryDelegate,
                modelConfigParser);
        PromptRunServiceImpl service = new PromptRunServiceImpl(chatSessionService, chatClientFactoryDelegate,
                modelConfigParser, objectMapper, ObservationRegistry.NOOP);

        ChatClient chatClient = mock(ChatClient.class);
        ChatClient.ChatClientRequestSpec requestSpec = mock(ChatClient.ChatClientRequestSpec.class);
        ChatClient.StreamResponseSpec streamSpec = mock(ChatClient.StreamResponseSpec.class);
        ArgumentCaptor<Prompt> promptCaptor = ArgumentCaptor.forClass(Prompt.class);

        when(modelConfigRepository.existsById(101L)).thenReturn(true);
        when(chatClientFactoryDelegate.createChatClient(eq(101L), any(Map.class), anyList(), any(Map.class)))
                .thenReturn(chatClient);
        when(chatClient.prompt(promptCaptor.capture())).thenReturn(requestSpec);
        when(requestSpec.toolCallbacks(anyList())).thenReturn(requestSpec);
        when(requestSpec.stream()).thenReturn(streamSpec);
        when(streamSpec.chatClientResponse()).thenReturn(
                Flux.just(messageChunk("Hello "), messageChunk("Ada"), finishChunk("trace-001")),
                Flux.just(messageChunk("Second "), messageChunk("reply"), finishChunk("trace-002")));

        PromptRunRequest firstRequest = new PromptRunRequest();
        firstRequest.setNewSession(true);
        firstRequest.setPromptKey("playground");
        firstRequest.setVersion("v1");
        firstRequest.setTemplate("You are {{name}}.");
        firstRequest.setVariables("{\"name\":\"Ada\"}");
        firstRequest.setModelConfig("{\"modelId\":101,\"temperature\":0.2}");
        firstRequest.setMessage("Say hi");

        List<PromptRunResponse> firstResponses = service.run(firstRequest).collectList().block();
        String sessionId = firstResponses.get(0).getSessionId();

        PromptRunRequest secondRequest = new PromptRunRequest();
        secondRequest.setSessionId(sessionId);
        secondRequest.setNewSession(false);
        secondRequest.setPromptKey("playground");
        secondRequest.setVersion("v1");
        secondRequest.setTemplate("You are {{name}}.");
        secondRequest.setVariables("{\"name\":\"Ada\"}");
        secondRequest.setModelConfig("{\"modelId\":101,\"temperature\":0.2}");
        secondRequest.setMessage("Continue");

        List<PromptRunResponse> secondResponses = service.run(secondRequest).collectList().block();
        Prompt secondPrompt = promptCaptor.getAllValues().get(1);
        List<Message> secondPromptMessages = secondPrompt.getInstructions();
        ChatSession session = service.getSession(sessionId);

        assertAll(
                () -> assertEquals(4, secondResponses.size()),
                () -> assertEquals("session_info", secondResponses.get(0).getType()),
                () -> assertEquals(sessionId, secondResponses.get(0).getSessionId()),
                () -> assertEquals(false, secondResponses.get(0).getNewSession()),
                () -> assertEquals(3, secondResponses.get(0).getMessageCount()),
                () -> assertEquals("message", secondResponses.get(1).getType()),
                () -> assertEquals("Second ", secondResponses.get(1).getContent()),
                () -> assertEquals("message", secondResponses.get(2).getType()),
                () -> assertEquals("reply", secondResponses.get(2).getContent()),
                () -> assertEquals("metrics", secondResponses.get(3).getType()),
                () -> assertEquals("trace-002", secondResponses.get(3).getMetrics().getTraceId()));

        assertAll(
                () -> assertEquals(4, secondPromptMessages.size()),
                () -> assertInstanceOf(SystemMessage.class, secondPromptMessages.get(0)),
                () -> assertEquals("You are Ada.", secondPromptMessages.get(0).getText()),
                () -> assertInstanceOf(UserMessage.class, secondPromptMessages.get(1)),
                () -> assertEquals("Say hi", secondPromptMessages.get(1).getText()),
                () -> assertInstanceOf(AssistantMessage.class, secondPromptMessages.get(2)),
                () -> assertEquals("Hello Ada", secondPromptMessages.get(2).getText()),
                () -> assertInstanceOf(UserMessage.class, secondPromptMessages.get(3)),
                () -> assertEquals("Continue", secondPromptMessages.get(3).getText()));

        assertAll(
                () -> assertEquals(4, session.getMessageCount()),
                () -> assertEquals("user", session.getMessages().get(0).getRole()),
                () -> assertEquals("Say hi", session.getMessages().get(0).getContent()),
                () -> assertEquals("assistant", session.getMessages().get(1).getRole()),
                () -> assertEquals("Hello Ada", session.getMessages().get(1).getContent()),
                () -> assertEquals("user", session.getMessages().get(2).getRole()),
                () -> assertEquals("Continue", session.getMessages().get(2).getContent()),
                () -> assertEquals("assistant", session.getMessages().get(3).getRole()),
                () -> assertEquals("Second reply", session.getMessages().get(3).getContent()));
    }

    private static ChatClientResponse messageChunk(String content) {
        ChatResponse chatResponse = new ChatResponse(List.of(new Generation(new AssistantMessage(content))));
        return ChatClientResponse.builder().chatResponse(chatResponse).build();
    }

    private static ChatClientResponse finishChunk(String traceId) {
        ChatGenerationMetadata metadata = ChatGenerationMetadata.builder().finishReason("STOP").build();
        ChatResponse chatResponse = new ChatResponse(List.of(new Generation(new AssistantMessage(""), metadata)));
        return ChatClientResponse.builder().chatResponse(chatResponse).context("traceId", traceId).build();
    }
}
