package com.alibaba.cloud.ai.studio.admin.service.impl;

import com.alibaba.cloud.ai.studio.admin.RealMiddlewareSpringBootTest;
import com.alibaba.cloud.ai.studio.admin.TestInfrastructureConfig;
import com.alibaba.cloud.ai.studio.admin.dto.PromptVersionDetail;
import com.alibaba.cloud.ai.studio.admin.entity.PromptDO;
import com.alibaba.cloud.ai.studio.admin.entity.PromptVersionDO;
import com.alibaba.cloud.ai.studio.admin.mapper.PromptMapper;
import com.alibaba.cloud.ai.studio.admin.mapper.PromptVersionMapper;
import com.alibaba.cloud.ai.studio.admin.service.PromptVersionService;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Prompt 版本对比改造 · 老方法基线测试（characterization / golden test）。
 *
 * <p>目的：在改造前用真实数据固定"改造链路上、本期不变动老方法"的返回，作为基线；
 * 改造后用相同用例再跑，确保这些老方法返回不变，防止 diff 改造意外破坏取数链。
 *
 * <p>覆盖的老方法（链路上、本期不改，diff 接口将完全依赖它们）：
 * <ul>
 *   <li>{@link PromptMapper#selectByPromptKey} —— promptKey 存在校验依赖</li>
 *   <li>{@link PromptVersionMapper#selectByPromptKeyAndVersion} —— diff 取 A/B 两版的底层依赖</li>
 *   <li>{@link PromptVersionService#getByPromptKeyAndVersion} —— 封装取数 + DO→DTO，离 diff 取数最近</li>
 * </ul>
 *
 * <p>数据：真实 admin 业务库（不 mock）。运行需：
 * <ul>
 *   <li>本地中间件就绪（MySQL/Redis/RocketMQ 等，见 {@code scripts/deps-status.sh}）</li>
 *   <li>环境变量 {@code TEST_MYSQL_DATABASE=admin} 指向含真实数据的业务库</li>
 * </ul>
 * 本测试禁用 schema-test.sql，不在业务库建测试表（只读）。
 *
 * <p>基线机制：基线文件不存在 → 生成之并 pass；存在 → 与基线逐字对比，不一致则 fail
 * （并把实际输出写到 {@code *.actual.json} 便于 diff）。
 */
@SpringBootTest
@ActiveProfiles("test")
@Import(TestInfrastructureConfig.class)
// 仅在连 admin 业务库（含真实数据）时跑；CI 用 admin_test 无 pcctest 数据，自动跳过，不破坏 CI。
@EnabledIfEnvironmentVariable(named = "TEST_MYSQL_DATABASE", matches = "admin")
class PromptVersionBaselineTest extends RealMiddlewareSpringBootTest {

    /** 真实数据样本：admin 库中现存的唯一 prompt/version。 */
    private static final String PROMPT_KEY = "pcctest";
    private static final String VERSION = "1.0.0";

    private static final Path BASELINE_DIR = Paths.get("src", "test", "resources", "baseline");
    private static final Path BASELINE_FILE = BASELINE_DIR.resolve("prompt-version-baseline.json");

    @Autowired
    private PromptVersionService promptVersionService;

    @Autowired
    private PromptVersionMapper promptVersionMapper;

    @Autowired
    private PromptMapper promptMapper;

    @Autowired
    private ObjectMapper objectMapper;

    /**
     * 禁用 schema-test.sql：基线测试连 admin 业务库（含真实数据），不能在业务库建
     * account/workspace/api_key 测试表。只读查询，不污染。
     */
    @DynamicPropertySource
    static void disableSchemaInit(DynamicPropertyRegistry registry) {
        registry.add("spring.sql.init.mode", () -> "never");
    }

    @Test
    void baseline_prompt_version_unchanged_methods() throws Exception {
        ObjectMapper sorted = objectMapper.copy()
                .configure(SerializationFeature.ORDER_MAP_ENTRIES_BY_KEYS, true);

        PromptDO promptDO = promptMapper.selectByPromptKey(PROMPT_KEY);
        PromptVersionDO versionDO = promptVersionMapper.selectByPromptKeyAndVersion(PROMPT_KEY, VERSION);
        PromptVersionDetail detail = promptVersionService.getByPromptKeyAndVersion(PROMPT_KEY, VERSION);

        Map<String, Object> snapshot = new LinkedHashMap<>();
        snapshot.put("mapper.selectByPromptKey", promptDO);
        snapshot.put("mapper.selectByPromptKeyAndVersion", versionDO);
        snapshot.put("service.getByPromptKeyAndVersion", detail);

        String actual = sorted.writerWithDefaultPrettyPrinter().writeValueAsString(snapshot);

        if (!Files.exists(BASELINE_FILE)) {
            Files.createDirectories(BASELINE_DIR);
            Files.writeString(BASELINE_FILE, actual);
            System.out.println("[BASELINE] 首次生成基线 → " + BASELINE_FILE.toAbsolutePath());
            return;
        }

        String expected = Files.readString(BASELINE_FILE);
        if (!actual.equals(expected)) {
            Path actualFile = BASELINE_FILE.resolveSibling("prompt-version-baseline.actual.json");
            Files.writeString(actualFile, actual);
            throw new AssertionError(
                    "老方法返回与基线不一致！改造可能破坏了不变动方法。实际输出已写入 " + actualFile + "\n"
                            + "--- expected ---\n" + expected + "\n--- actual ---\n" + actual);
        }
        System.out.println("[BASELINE] 老方法返回与基线一致 ✓");
    }
}
