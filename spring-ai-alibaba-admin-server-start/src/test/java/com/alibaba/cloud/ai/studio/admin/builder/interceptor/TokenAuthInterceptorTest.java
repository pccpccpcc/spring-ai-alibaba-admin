package com.alibaba.cloud.ai.studio.admin.builder.interceptor;

import com.alibaba.cloud.ai.studio.core.base.manager.TokenManager;
import com.alibaba.cloud.ai.studio.core.base.service.AccountService;
import com.alibaba.cloud.ai.studio.core.context.RequestContextHolder;
import com.alibaba.cloud.ai.studio.runtime.domain.account.Account;
import com.alibaba.cloud.ai.studio.runtime.enums.AccountType;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import static org.junit.jupiter.api.Assertions.assertAll;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class TokenAuthInterceptorTest {

    @AfterEach
    void tearDown() {
        RequestContextHolder.clearRequestContext();
    }

    @Test
    void preHandleRejectsMissingOrUnknownAccessTokenWithUnauthorized() {
        AccountService accountService = mock(AccountService.class);
        TokenManager tokenManager = mock(TokenManager.class);
        TokenAuthInterceptor interceptor = new TokenAuthInterceptor(accountService, tokenManager);

        MockHttpServletResponse missingResponse = new MockHttpServletResponse();
        boolean missing = interceptor.preHandle(new MockHttpServletRequest(), missingResponse, new Object());

        MockHttpServletRequest unknownRequest = new MockHttpServletRequest();
        unknownRequest.addHeader(HttpHeaders.AUTHORIZATION, "Bearer unknown-token");
        MockHttpServletResponse unknownResponse = new MockHttpServletResponse();
        boolean unknown = interceptor.preHandle(unknownRequest, unknownResponse, new Object());

        assertAll(
                () -> assertFalse(missing),
                () -> assertEquals(HttpServletResponse.SC_UNAUTHORIZED, missingResponse.getStatus()),
                () -> assertFalse(unknown),
                () -> assertEquals(HttpServletResponse.SC_UNAUTHORIZED, unknownResponse.getStatus()));
    }

    @Test
    void preHandleAcceptsValidAccessTokenAndSetsRequestContext() {
        AccountService accountService = mock(AccountService.class);
        TokenManager tokenManager = mock(TokenManager.class);
        TokenAuthInterceptor interceptor = new TokenAuthInterceptor(accountService, tokenManager);
        when(tokenManager.getAccountIdFromAccessToken("access-token")).thenReturn("account-1");
        Account account = new Account();
        account.setAccountId("account-1");
        account.setUsername("admin");
        account.setDefaultWorkspaceId("workspace-1");
        account.setType(AccountType.ADMIN);
        when(accountService.getAccount("account-1")).thenReturn(account);

        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader(HttpHeaders.AUTHORIZATION, "Bearer access-token");
        MockHttpServletResponse response = new MockHttpServletResponse();

        boolean accepted = interceptor.preHandle(request, response, new Object());

        assertAll(
                () -> assertTrue(accepted),
                () -> assertEquals(200, response.getStatus()),
                () -> assertEquals("account-1", RequestContextHolder.getRequestContext().getAccountId()),
                () -> assertEquals("workspace-1", RequestContextHolder.getRequestContext().getWorkspaceId()));
    }

}
