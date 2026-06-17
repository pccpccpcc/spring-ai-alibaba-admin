package com.alibaba.cloud.ai.studio.admin.service;

import com.alibaba.cloud.ai.studio.admin.dto.PromptVersionDiffResponse;
import com.alibaba.cloud.ai.studio.admin.exception.StudioException;

/**
 * Prompt 版本对比 Service。
 *
 * <p>对同一 Prompt 的任意两个版本（versionA → versionB）做结构化差异对比，
 * 复用 {@code PromptVersionMapper} / {@code PromptMapper} 取数，委托
 * {@link com.alibaba.cloud.ai.studio.admin.utils.PromptVersionDiffCalculator} 算差异。
 *
 * <p>独立于 {@code PromptVersionService}（决策 D3），不影响其现有调用方。
 */
public interface PromptVersionDiffService {

    /**
     * 对比同一 Prompt 的两个版本。
     *
     * @param promptKey Prompt 业务键
     * @param versionA 对比"旧"侧（diff 方向起点）
     * @param versionB 对比"新"侧（diff 方向终点）
     * @return 结构化差异
     * @throws StudioException NOT_FOUND：promptKey 或任一版本不存在（需求 #2 / #3）
     */
    PromptVersionDiffResponse diff(String promptKey, String versionA, String versionB) throws StudioException;
}
