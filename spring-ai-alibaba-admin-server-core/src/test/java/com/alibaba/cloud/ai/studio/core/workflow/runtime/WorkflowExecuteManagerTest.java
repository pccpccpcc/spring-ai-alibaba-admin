package com.alibaba.cloud.ai.studio.core.workflow.runtime;

import com.alibaba.cloud.ai.studio.core.config.CommonConfig;
import com.alibaba.cloud.ai.studio.core.workflow.WorkflowInnerService;
import com.alibaba.cloud.ai.studio.core.workflow.processor.AbstractExecuteProcessor;
import com.alibaba.cloud.ai.studio.runtime.domain.workflow.Edge;
import com.alibaba.cloud.ai.studio.runtime.domain.workflow.Node;
import org.jgrapht.graph.DirectedAcyclicGraph;
import org.junit.jupiter.api.Test;
import org.springframework.ai.chat.memory.ChatMemory;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertAll;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;

class WorkflowExecuteManagerTest {

    @Test
    void constructGraphAcceptsMinimalStartLlmEndDag() {
        WorkflowExecuteManager manager = new WorkflowExecuteManager(Map.<String, AbstractExecuteProcessor>of(),
                mock(WorkflowInnerService.class), mock(ChatMemory.class), new CommonConfig());

        DirectedAcyclicGraph<String, Edge> graph = manager.constructGraph(
                List.of(node("Start_1", "Start"), node("LLM_1", "LLM"), node("End_1", "End")),
                List.of(edge("e1", "Start_1", "LLM_1"), edge("e2", "LLM_1", "End_1")));

        assertAll(
                () -> assertEquals(3, graph.vertexSet().size()),
                () -> assertEquals(2, graph.edgeSet().size()),
                () -> assertTrue(graph.containsEdge("Start_1", "LLM_1")),
                () -> assertTrue(graph.containsEdge("LLM_1", "End_1")),
                () -> assertTrue(graph.incomingEdgesOf("Start_1").isEmpty()),
                () -> assertTrue(graph.outgoingEdgesOf("End_1").isEmpty()));
    }

    private static Node node(String id, String type) {
        Node node = new Node();
        node.setId(id);
        node.setType(type);
        return node;
    }

    private static Edge edge(String id, String source, String target) {
        Edge edge = new Edge();
        edge.setId(id);
        edge.setSource(source);
        edge.setTarget(target);
        return edge;
    }

}
