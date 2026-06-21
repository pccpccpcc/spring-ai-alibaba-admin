package com.alibaba.cloud.ai.studio.core.base.service.impl;

import com.alibaba.cloud.ai.studio.core.base.domain.RpcResult;
import com.alibaba.cloud.ai.studio.core.base.manager.HttpClientManager;
import com.alibaba.cloud.ai.studio.core.base.service.PluginService;
import com.alibaba.cloud.ai.studio.runtime.domain.plugin.Plugin;
import com.alibaba.cloud.ai.studio.runtime.domain.plugin.Tool;
import com.alibaba.cloud.ai.studio.runtime.domain.plugin.ToolExecutionRequest;
import com.alibaba.cloud.ai.studio.runtime.domain.plugin.ToolExecutionResult;
import com.alibaba.cloud.ai.studio.runtime.domain.tool.ApiParameter;
import org.apache.http.HttpHeaders;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.MediaType;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertAll;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class ToolExecutionServiceImplTest {

    @Test
    @SuppressWarnings("unchecked")
    void callOpenApiBuildsUrlAuthHeadersQueryPathAndBodyParameters() {
        PluginService pluginService = mock(PluginService.class);
        HttpClientManager httpClientManager = mock(HttpClientManager.class);
        ToolExecutionServiceImpl service = new ToolExecutionServiceImpl(pluginService, httpClientManager);

        ArgumentCaptor<Map<String, Object>> headersCaptor = ArgumentCaptor.forClass(Map.class);
        ArgumentCaptor<Map<String, Object>> bodyCaptor = ArgumentCaptor.forClass(Map.class);
        ArgumentCaptor<String> urlCaptor = ArgumentCaptor.forClass(String.class);
        when(httpClientManager.doPostJsonWithRequestId(eq("request-1"), urlCaptor.capture(), headersCaptor.capture(),
                bodyCaptor.capture()))
            .thenReturn(RpcResult.success("{\"ok\":true}"));

        ToolExecutionResult result = service.callOpenApi(request());

        Map<String, Object> headers = headersCaptor.getValue();
        Map<String, Object> body = bodyCaptor.getValue();
        String url = urlCaptor.getValue();

        assertAll(
                () -> assertTrue(result.isSuccess()),
                () -> assertEquals("{\"ok\":true}", result.getOutput()),
                () -> assertTrue(url.startsWith("https://api.example.test/orders/42?")),
                () -> assertTrue(url.contains("q=search")),
                () -> assertEquals("trace-value", headers.get("X-Trace")),
                () -> assertEquals("Bearer token-1", headers.get(HttpHeaders.AUTHORIZATION)),
                () -> assertEquals("json-body", body.get("payload")),
                () -> assertEquals(false, body.containsKey("orderId")),
                () -> assertEquals(false, body.containsKey("q")));

        verify(httpClientManager).doPostJsonWithRequestId(eq("request-1"), anyString(), eq(headers), eq(body));
    }

    private static ToolExecutionRequest request() {
        Plugin.PluginConfig pluginConfig = new Plugin.PluginConfig();
        pluginConfig.setServer("https://api.example.test");
        pluginConfig.setHeaders(Map.of("X-Trace", "trace-value"));
        Plugin.ApiAuth auth = new Plugin.ApiAuth();
        auth.setType(Plugin.ApiAuthType.API_KEY);
        auth.setAuthorizationType(Plugin.AuthorizationType.BEARER);
        auth.setAuthorizationValue("token-1");
        pluginConfig.setAuth(auth);

        Plugin plugin = new Plugin();
        plugin.setConfig(pluginConfig);

        Tool.ToolConfig toolConfig = new Tool.ToolConfig();
        toolConfig.setPath("/orders");
        toolConfig.setRequestMethod("Post");
        toolConfig.setContentType(MediaType.APPLICATION_JSON_VALUE);
        toolConfig.setInputParams(List.of(parameter("orderId", "Path", "Number", true),
                parameter("q", "Query", "String", false), parameter("payload", "Body", "String", true)));

        Tool tool = new Tool();
        tool.setPlugin(plugin);
        tool.setConfig(toolConfig);

        ToolExecutionRequest request = new ToolExecutionRequest();
        request.setRequestId("request-1");
        request.setTool(tool);
        request.setArguments(new HashMap<>(Map.of("orderId", 42, "q", "search", "payload", "json-body")));
        return request;
    }

    private static ApiParameter parameter(String key, String location, String type, boolean required) {
        ApiParameter parameter = new ApiParameter();
        parameter.setKey(key);
        parameter.setLocation(location);
        parameter.setType(type);
        parameter.setRequired(required);
        return parameter;
    }

}
