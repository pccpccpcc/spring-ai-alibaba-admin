package com.alibaba.cloud.ai.studio.admin.builder.controller;

import com.alibaba.cloud.ai.studio.admin.builder.advice.GlobalExceptionHandler;
import com.alibaba.cloud.ai.studio.core.base.service.AccountService;
import com.alibaba.cloud.ai.studio.runtime.domain.account.LoginRequest;
import com.alibaba.cloud.ai.studio.runtime.domain.account.RefreshTokenRequest;
import com.alibaba.cloud.ai.studio.runtime.domain.account.TokenResponse;
import com.alibaba.cloud.ai.studio.runtime.enums.ErrorCode;
import com.alibaba.cloud.ai.studio.runtime.exception.BizException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.hamcrest.Matchers.is;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class AuthControllerTest {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void loginReturnsTokensForValidCredentialsAndUnauthorizedForInvalidCredentials() throws Exception {
        AccountService accountService = mock(AccountService.class);
        MockMvc mockMvc = mockMvc(accountService);
        TokenResponse tokenResponse = new TokenResponse();
        tokenResponse.setAccessToken("access-token");
        tokenResponse.setRefreshToken("refresh-token");
        when(accountService.login(any(LoginRequest.class))).thenReturn(tokenResponse)
            .thenThrow(new BizException(ErrorCode.ACCOUNT_LOGIN_ERROR.toError()));

        mockMvc.perform(post("/console/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
            .content(objectMapper.writeValueAsString(login("admin", "right"))))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data.access_token", is("access-token")))
            .andExpect(jsonPath("$.data.refresh_token", is("refresh-token")));

        mockMvc.perform(post("/console/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
            .content(objectMapper.writeValueAsString(login("admin", "wrong"))))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.code", is(401)))
            .andExpect(jsonPath("$.message", is("Login error, please check username and password.")));
    }

    @Test
    void refreshTokenReturnsUnauthorizedWhenRefreshTokenIsInvalid() throws Exception {
        AccountService accountService = mock(AccountService.class);
        MockMvc mockMvc = mockMvc(accountService);
        when(accountService.refreshToken(any(RefreshTokenRequest.class)))
            .thenThrow(new BizException(ErrorCode.INVALID_REFRESH_TOKEN.toError()));

        RefreshTokenRequest request = new RefreshTokenRequest();
        request.setRefreshToken("invalid-refresh");

        mockMvc.perform(post("/console/v1/auth/refresh-token").contentType(MediaType.APPLICATION_JSON)
            .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.code", is(401)))
            .andExpect(jsonPath("$.message", is("Refresh token is invalid.")));
    }

    @Test
    void logoutStripsBearerPrefixBeforeInvalidatingAccessToken() throws Exception {
        AccountService accountService = mock(AccountService.class);
        MockMvc mockMvc = mockMvc(accountService);

        mockMvc.perform(post("/console/v1/auth/logout").header(HttpHeaders.AUTHORIZATION, "Bearer access-token"))
            .andExpect(status().isOk());

        verify(accountService).logout("access-token");
    }

    private static MockMvc mockMvc(AccountService accountService) {
        return MockMvcBuilders.standaloneSetup(new AuthController(accountService))
            .setControllerAdvice(new GlobalExceptionHandler())
            .setMessageConverters(new MappingJackson2HttpMessageConverter())
            .build();
    }

    private static LoginRequest login(String username, String password) {
        LoginRequest request = new LoginRequest();
        request.setUsername(username);
        request.setPassword(password);
        return request;
    }

}
