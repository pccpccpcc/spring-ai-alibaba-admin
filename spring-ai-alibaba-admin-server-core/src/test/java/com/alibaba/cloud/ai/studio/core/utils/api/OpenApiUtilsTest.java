package com.alibaba.cloud.ai.studio.core.utils.api;

import com.alibaba.cloud.ai.studio.runtime.domain.plugin.Plugin;
import com.alibaba.cloud.ai.studio.runtime.domain.plugin.Tool;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertAll;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class OpenApiUtilsTest {

    @Test
    void parseSchemaToFormReadsEndpointConfigAndBuildsValidRawApiSchema() throws Exception {
        String yaml = """
                openapi: 3.0.0
                info:
                  title: Weather API
                  version: 1.0.0
                servers:
                  - url: https://example.com/api
                paths:
                  /weatherInfo:
                    get:
                      description: Get weather
                      parameters:
                        - name: city
                          in: query
                          required: true
                          description: City name
                          schema:
                            type: string
                      responses:
                        "200":
                          description: OK
                          content:
                            application/json:
                              schema:
                                type: object
                                properties:
                                  status:
                                    type: integer
                                    description: Status code
                """;

        Map<String, Tool> tools = OpenApiUtils.parseSchemaToForm(yaml, true);
        Tool getWeather = tools.get("/weatherInfo");
        Plugin plugin = plugin();
        getWeather.setName("getWeather");
        String rawApiSchema = OpenApiUtils.buildOpenAPIYaml(plugin, getWeather);

        assertAll(
                () -> assertEquals(1, tools.size()),
                () -> assertNotNull(getWeather),
                () -> assertEquals("/weatherInfo", getWeather.getConfig().getPath()),
                () -> assertEquals("Get", getWeather.getConfig().getRequestMethod()),
                () -> assertEquals("https://example.com/api", getWeather.getConfig().getServer()),
                () -> assertEquals("city", getWeather.getConfig().getInputParams().get(0).getKey()),
                () -> assertEquals("Query", getWeather.getConfig().getInputParams().get(0).getLocation()),
                () -> assertTrue(rawApiSchema.contains("/weatherInfo")),
                () -> assertNull(OpenApiUtils.parseOpenAPIObject(rawApiSchema)));
    }

    private static Plugin plugin() {
        Plugin.PluginConfig config = new Plugin.PluginConfig();
        config.setServer("https://example.com/api");

        Plugin plugin = new Plugin();
        plugin.setName("weather");
        plugin.setDescription("weather plugin");
        plugin.setConfig(config);
        return plugin;
    }

}
