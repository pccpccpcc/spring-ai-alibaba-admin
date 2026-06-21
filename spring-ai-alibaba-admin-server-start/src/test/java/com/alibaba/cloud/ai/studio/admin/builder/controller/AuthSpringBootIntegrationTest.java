package com.alibaba.cloud.ai.studio.admin.builder.controller;

import com.alibaba.cloud.ai.studio.admin.TestInfrastructureConfig;
import com.alibaba.cloud.ai.studio.admin.RealMiddlewareSpringBootTest;
import com.alibaba.cloud.ai.studio.core.base.manager.TokenManager;
import com.alibaba.cloud.ai.studio.core.utils.security.PasswordCryptUtils;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.Map;

import static org.hamcrest.Matchers.is;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Import(TestInfrastructureConfig.class)
class AuthSpringBootIntegrationTest extends RealMiddlewareSpringBootTest {

    private static final String ACCOUNT_ID = "account-auth-it";

    private static final String WORKSPACE_ID = "workspace-auth-it";

    private static final String USERNAME = "admin";

    private static final String PASSWORD = "right-password";

    private static final String ENCODED_PASSWORD = PasswordCryptUtils.encode(PASSWORD);

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private TokenManager tokenManager;

    @BeforeEach
    void setUpAccount() {
        jdbcTemplate.update("delete from api_key");
        jdbcTemplate.update("delete from workspace");
        jdbcTemplate.update("delete from account");

        jdbcTemplate.update("""
                insert into account
                    (account_id, username, email, mobile, password, nickname, icon, type, status,
                     gmt_create, gmt_modified, creator, modifier)
                values
                    (?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, ?, ?)
                """, ACCOUNT_ID, USERNAME, "admin@example.com", "13800000000", ENCODED_PASSWORD,
                "Admin", "", "admin", 1, ACCOUNT_ID, ACCOUNT_ID);

        jdbcTemplate.update("""
                insert into workspace
                    (workspace_id, account_id, status, name, description, config,
                     gmt_create, gmt_modified, creator, modifier)
                values
                    (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, ?, ?)
                """, WORKSPACE_ID, ACCOUNT_ID, 1, "Default", "Default workspace", "{}", ACCOUNT_ID, ACCOUNT_ID);
    }

    @Test
    void loginValidatesDatabasePasswordAndStoresUsableTokensInRedis() throws Exception {
        MvcResult loginResult = mockMvc.perform(post("/console/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(Map.of("username", USERNAME, "password", PASSWORD))))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.code", is(200)))
            .andExpect(jsonPath("$.data.access_token").isString())
            .andExpect(jsonPath("$.data.refresh_token").isString())
            .andReturn();

        JsonNode data = data(loginResult);
        String accessToken = data.path("access_token").asText();
        String refreshToken = data.path("refresh_token").asText();

        assertFalse(accessToken.isBlank());
        assertFalse(refreshToken.isBlank());
        assertEquals(ACCOUNT_ID, tokenManager.getAccountIdFromAccessToken(accessToken));
        assertEquals(ACCOUNT_ID, tokenManager.getAccountIdFromRefreshToken(refreshToken));

        mockMvc.perform(get("/console/v1/accounts/profile").header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.code", is(200)))
            .andExpect(jsonPath("$.data.account_id", is(ACCOUNT_ID)))
            .andExpect(jsonPath("$.data.default_workspace_id", is(WORKSPACE_ID)));
    }

    @Test
    void loginRejectsWrongPasswordAndUnknownUserWithUnauthorized() throws Exception {
        mockMvc.perform(post("/console/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(Map.of("username", USERNAME, "password", "wrong-password"))))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.code", is(401)))
            .andExpect(jsonPath("$.message", is("Login error, please check username and password.")));

        mockMvc.perform(post("/console/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(Map.of("username", "missing", "password", PASSWORD))))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.code", is(401)))
            .andExpect(jsonPath("$.message", is("Login error, please check username and password.")));
    }

    @Test
    void refreshTokenRotatesRefreshTokenAndNewAccessTokenCanAuthorizeRequests() throws Exception {
        JsonNode loginData = data(login(USERNAME, PASSWORD));
        String oldRefreshToken = loginData.path("refresh_token").asText();

        MvcResult refreshResult = mockMvc.perform(post("/console/v1/auth/refresh-token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(Map.of("refresh_token", oldRefreshToken))))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.code", is(200)))
            .andExpect(jsonPath("$.data.access_token").isString())
            .andExpect(jsonPath("$.data.refresh_token").isString())
            .andReturn();

        JsonNode refreshData = data(refreshResult);
        String newAccessToken = refreshData.path("access_token").asText();
        String newRefreshToken = refreshData.path("refresh_token").asText();

        assertNotEquals(oldRefreshToken, newRefreshToken);
        assertNull(tokenManager.getAccountIdFromRefreshToken(oldRefreshToken));
        assertEquals(ACCOUNT_ID, tokenManager.getAccountIdFromAccessToken(newAccessToken));
        assertEquals(ACCOUNT_ID, tokenManager.getAccountIdFromRefreshToken(newRefreshToken));

        mockMvc.perform(get("/console/v1/accounts/profile").header(HttpHeaders.AUTHORIZATION, "Bearer " + newAccessToken))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.account_id", is(ACCOUNT_ID)));

        mockMvc.perform(post("/console/v1/auth/refresh-token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(Map.of("refresh_token", oldRefreshToken))))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.code", is(401)))
            .andExpect(jsonPath("$.message", is("Refresh token is invalid.")));
    }

    @Test
    void logoutInvalidatesAccessTokenForAuthenticatedConsoleRequests() throws Exception {
        String accessToken = data(login(USERNAME, PASSWORD)).path("access_token").asText();

        mockMvc.perform(post("/console/v1/auth/logout").header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.code", is(200)));

        assertNull(tokenManager.getAccountIdFromAccessToken(accessToken));

        mockMvc.perform(get("/console/v1/accounts/profile").header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.code", is(401)))
            .andExpect(jsonPath("$.message", is("Access token is invalid.")));
    }

    private MvcResult login(String username, String password) throws Exception {
        return mockMvc.perform(post("/console/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(Map.of("username", username, "password", password))))
            .andExpect(status().isOk())
            .andReturn();
    }

    private JsonNode data(MvcResult result) throws Exception {
        return objectMapper.readTree(result.getResponse().getContentAsString()).path("data");
    }

}
