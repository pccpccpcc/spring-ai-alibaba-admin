package com.alibaba.cloud.ai.studio.admin.service.impl;

import com.alibaba.cloud.ai.studio.admin.dto.PromptVersionDiffResponse;
import com.alibaba.cloud.ai.studio.admin.dto.PromptVersionDiffResponse.FieldDiff;
import com.alibaba.cloud.ai.studio.admin.dto.PromptVersionDiffResponse.VersionMeta;
import com.alibaba.cloud.ai.studio.admin.entity.PromptVersionDO;
import com.alibaba.cloud.ai.studio.admin.exception.StudioException;
import com.alibaba.cloud.ai.studio.admin.mapper.PromptMapper;
import com.alibaba.cloud.ai.studio.admin.mapper.PromptVersionMapper;
import com.alibaba.cloud.ai.studio.admin.service.PromptVersionDiffService;
import com.alibaba.cloud.ai.studio.admin.utils.PromptVersionDiffCalculator;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.ZoneId;
import java.util.List;

/**
 * Prompt 版本对比 Service 实现。
 *
 * <p>见 {@code docs/requirements/prompt-version-diff-solution.md} 步骤 4：
 * 取 A/B 两版（复用 mapper）、promptKey 存在校验、委托 diff 工具、组装 Response。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PromptVersionDiffServiceImpl implements PromptVersionDiffService {

    private final PromptVersionMapper promptVersionMapper;

    private final PromptMapper promptMapper;

    private final PromptVersionDiffCalculator diffCalculator;

    @Override
    public PromptVersionDiffResponse diff(String promptKey, String versionA, String versionB) throws StudioException {
        log.info("对比Prompt版本: promptKey={}, versionA={}, versionB={}", promptKey, versionA, versionB);

        // 1. promptKey 存在校验（对齐 PromptVersionServiceImpl#create，需求 #3）
        if (promptMapper.selectByPromptKey(promptKey) == null) {
            throw new StudioException(StudioException.NOT_FOUND,
                    String.format("Prompt不存在，promptKey: %s，请先创建对应的Prompt", promptKey));
        }

        // 2. 取 A/B 两版，任一不存在抛 NOT_FOUND（对齐 getByPromptKeyAndVersion，需求 #2）
        PromptVersionDO doA = promptVersionMapper.selectByPromptKeyAndVersion(promptKey, versionA);
        PromptVersionDO doB = promptVersionMapper.selectByPromptKeyAndVersion(promptKey, versionB);
        if (doA == null || doB == null) {
            throw new StudioException(StudioException.NOT_FOUND,
                    String.format("Prompt版本不存在: %s@(%s, %s)", promptKey, versionA, versionB));
        }

        // 3. 三个内容字段 diff（template 文本；variables / modelConfig JSON 优先、退化文本）
        FieldDiff templateDiff = diffCalculator.diffTemplate(doA.getTemplate(), doB.getTemplate());
        FieldDiff variablesDiff = diffCalculator.diffJsonField("variables", doA.getVariables(), doB.getVariables());
        FieldDiff modelConfigDiff = diffCalculator.diffJsonField("modelConfig", doA.getModelConfig(), doB.getModelConfig());
        List<FieldDiff> fields = List.of(templateDiff, variablesDiff, modelConfigDiff);

        // 4. 组装响应
        boolean anyChange = fields.stream().anyMatch(FieldDiff::isChanged);
        return PromptVersionDiffResponse.builder()
                .promptKey(promptKey)
                .versionA(versionA)
                .versionB(versionB)
                .anyChange(anyChange)
                .metaA(toMeta(doA))
                .metaB(toMeta(doB))
                .fields(fields)
                .build();
    }

    /**
     * DO → VersionMeta（轻量元信息；createTime 转毫秒，对齐 PromptVersionDetail#fromDO）。
     */
    private VersionMeta toMeta(PromptVersionDO d) {
        return VersionMeta.builder()
                .versionDescription(d.getVersionDesc())
                .status(d.getStatus())
                .createTime(d.getCreateTime() != null
                        ? d.getCreateTime().atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
                        : null)
                .previousVersion(d.getPreviousVersion())
                .build();
    }
}
