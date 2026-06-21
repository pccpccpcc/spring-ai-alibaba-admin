package com.alibaba.cloud.ai.studio.core.rag.retriever;

import com.alibaba.cloud.ai.studio.core.model.llm.ModelFactory;
import com.alibaba.cloud.ai.studio.core.rag.vectorstore.VectorStoreFactory;
import com.alibaba.cloud.ai.studio.core.rag.vectorstore.VectorStoreService;
import com.alibaba.cloud.ai.studio.runtime.domain.app.FileSearchOptions;
import com.alibaba.cloud.ai.studio.runtime.domain.knowledgebase.IndexConfig;
import com.alibaba.cloud.ai.studio.runtime.domain.knowledgebase.KnowledgeBase;
import org.junit.jupiter.api.Test;
import org.springframework.ai.document.Document;
import org.springframework.ai.rag.Query;
import org.springframework.ai.vectorstore.SearchRequest;
import org.springframework.ai.vectorstore.VectorStore;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class KnowledgeBaseDocumentRetrieverTest {

    @Test
    void retrieveMergesSortsFiltersAndLimitsDocumentsAcrossKnowledgeBases() {
        VectorStoreFactory vectorStoreFactory = mock(VectorStoreFactory.class);
        VectorStoreService vectorStoreService = mock(VectorStoreService.class);
        VectorStore firstStore = mock(VectorStore.class);
        VectorStore secondStore = mock(VectorStore.class);

        when(vectorStoreFactory.getVectorStoreService()).thenReturn(vectorStoreService);
        when(vectorStoreService.getVectorStore(any(IndexConfig.class))).thenReturn(firstStore, secondStore);
        when(firstStore.similaritySearch(any(SearchRequest.class))).thenReturn(List.of(document("low", 0.3),
                document("top", 0.91)));
        when(secondStore.similaritySearch(any(SearchRequest.class))).thenReturn(List.of(document("mid", 0.7),
                document("filtered", 0.19)));

        FileSearchOptions aggregateOptions = FileSearchOptions.builder().similarityThreshold(0.2F).topK(2).build();
        KnowledgeBaseDocumentRetriever retriever = new KnowledgeBaseDocumentRetriever(
                List.of(knowledgeBase("workspace-a"), knowledgeBase("workspace-b")), vectorStoreFactory,
                mock(ModelFactory.class), aggregateOptions);

        List<Document> results = retriever.retrieve(Query.builder().text("hello").context(Map.of()).build());

        assertEquals(List.of("top", "mid"), results.stream().map(Document::getText).toList());
        verify(vectorStoreService, times(2)).getVectorStore(any(IndexConfig.class));
    }

    private static KnowledgeBase knowledgeBase(String workspaceId) {
        KnowledgeBase knowledgeBase = new KnowledgeBase();
        knowledgeBase.setWorkspaceId(workspaceId);
        knowledgeBase.setIndexConfig(new IndexConfig());
        knowledgeBase.setSearchConfig(FileSearchOptions.builder()
            .searchType("semantic")
            .similarityThreshold(0.0F)
            .topK(5)
            .enableRerank(false)
            .build());
        return knowledgeBase;
    }

    private static Document document(String text, double score) {
        return Document.builder().text(text).score(score).build();
    }

}
