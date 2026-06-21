package com.alibaba.cloud.ai.studio.core.rag.advisor;

import com.alibaba.cloud.ai.studio.core.agent.AgentContext;
import com.alibaba.cloud.ai.studio.core.config.CommonConfig;
import com.alibaba.cloud.ai.studio.runtime.domain.agent.AgentRequest;
import com.alibaba.cloud.ai.studio.runtime.domain.app.AgentConfig;
import com.alibaba.cloud.ai.studio.runtime.domain.app.FileSearchOptions;
import org.junit.jupiter.api.Test;
import org.springframework.ai.chat.client.ChatClientRequest;
import org.springframework.ai.chat.client.ChatClientResponse;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.messages.SystemMessage;
import org.springframework.ai.chat.messages.UserMessage;
import org.springframework.ai.chat.model.ChatResponse;
import org.springframework.ai.chat.model.Generation;
import org.springframework.ai.chat.prompt.Prompt;
import org.springframework.ai.document.Document;
import org.springframework.ai.rag.Query;
import org.springframework.ai.rag.retrieval.search.DocumentRetriever;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;

import static com.alibaba.cloud.ai.studio.core.rag.RagConstants.FILE_SEARCH_CALL;
import static com.alibaba.cloud.ai.studio.core.rag.RagConstants.FILE_SEARCH_RESULT;
import static org.junit.jupiter.api.Assertions.assertAll;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;

class KnowledgeBaseRetrievalAdvisorTest {

    @Test
    void beforeInjectsRetrievedDocumentsIntoSystemPromptAndRequestContext() {
        List<Document> documents = List.of(new Document("Doc A"), new Document("Doc B"));
        AtomicReference<Query> queryCaptor = new AtomicReference<>();
        DocumentRetriever retriever = query -> {
            queryCaptor.set(query);
            return documents;
        };
        AgentContext agentContext = agentContext(false, Map.of("tone", "brief"));
        KnowledgeBaseRetrievalAdvisor advisor = KnowledgeBaseRetrievalAdvisor.builder()
            .documentRetriever(retriever)
            .commonConfig(new CommonConfig())
            .agentContext(agentContext)
            .build();

        ChatClientRequest request = ChatClientRequest.builder()
            .prompt(new Prompt(new ArrayList<>(List.of(new SystemMessage("Use {documents}; tone={tone}"),
                    new UserMessage("What happened?")))))
            .context(new HashMap<>())
            .build();

        ChatClientRequest advised = advisor.before(request, null);

        assertAll(
                () -> assertEquals("Use Doc A" + System.lineSeparator() + "Doc B; tone=brief",
                        advised.prompt().getSystemMessage().getText()),
                () -> assertSame(documents, advised.context().get(FILE_SEARCH_RESULT)),
                () -> assertEquals("What happened?", queryCaptor.get().text()),
                () -> assertEquals("What happened?",
                        ((Map<?, ?>) queryCaptor.get().context().get(FILE_SEARCH_CALL)).get("query")));
    }

    @Test
    void afterAddsFileSearchMetadataForNonStreamResponses() {
        List<Document> documents = List.of(new Document("Doc A"));
        AgentContext agentContext = agentContext(false, Map.of());
        KnowledgeBaseRetrievalAdvisor advisor = KnowledgeBaseRetrievalAdvisor.builder()
            .documentRetriever(query -> documents)
            .commonConfig(new CommonConfig())
            .agentContext(agentContext)
            .build();
        Map<String, Object> context = Map.of(FILE_SEARCH_CALL, Map.of("query", "q"), FILE_SEARCH_RESULT, documents);
        ChatClientResponse response = ChatClientResponse.builder()
            .chatResponse(new ChatResponse(List.of(new Generation(new AssistantMessage("done")))))
            .context(context)
            .build();

        ChatClientResponse advised = advisor.after(response, null);

        assertAll(
                () -> assertEquals(Map.of("query", "q"), advised.chatResponse().getMetadata().get(FILE_SEARCH_CALL)),
                () -> assertSame(documents, advised.chatResponse().getMetadata().get(FILE_SEARCH_RESULT)));
    }

    private static AgentContext agentContext(boolean stream, Map<String, Object> promptVariables) {
        AgentConfig config = new AgentConfig();
        config.setFileSearch(FileSearchOptions.builder().enableSearch(true).topK(3).build());

        AgentRequest request = new AgentRequest();
        AgentContext context = new AgentContext();
        context.setConfig(config);
        context.setRequest(request);
        context.setPromptVariables(promptVariables);
        context.setStream(stream);
        return context;
    }

}
