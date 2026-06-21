package com.alibaba.cloud.ai.studio.admin.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * Prompt 版本对比响应 DTO。
 * <p>
 * 承载同一 Prompt 两个版本（versionA → versionB）的结构化差异：
 * template 走行级文本 diff；variables / modelConfig 在两方均为合法 JSON 时走规范化（按键排序 + pretty-print）后的行级 diff，否则退化文本 diff。
 * 元信息标量（versionDescription / status / createTime / previousVersion）不进入 fields，统一放在 metaA / metaB 由 UI 自行对比。
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PromptVersionDiffResponse {

    /**
     * Prompt 业务键
     */
    private String promptKey;

    /**
     * 对比的"旧"侧版本号（diff 方向起点，add/remove 以 A → B 为方向）
     */
    private String versionA;

    /**
     * 对比的"新"侧版本号（diff 方向终点）
     */
    private String versionB;

    /**
     * 顶层快速判断位：任一"内容字段"（template / variables / modelConfig）有差异即为 true。
     * <p>
     * 不统计 createTime 等元信息差异（两版创建时刻几乎必然不同，计入会使其恒为 true）。
     */
    private boolean anyChange;

    /**
     * A 侧轻量元信息（不含大字段，便于 UI 展示表头；标量差异由 UI 自行对比）
     */
    private VersionMeta metaA;

    /**
     * B 侧轻量元信息（不含大字段，便于 UI 展示表头；标量差异由 UI 自行对比）
     */
    private VersionMeta metaB;

    /**
     * 内容字段的逐字段差异，覆盖 template / variables / modelConfig
     */
    private List<FieldDiff> fields;

    /**
     * 版本轻量元信息（标量，不含大字段），供 UI 展示表头并自行比对差异。
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class VersionMeta {

        /**
         * 版本描述
         */
        private String versionDescription;

        /**
         * 版本状态：pre-预发布版本，release-正式版本
         */
        private String status;

        /**
         * 版本创建时间，时间戳毫秒
         */
        private Long createTime;

        /**
         * 前置版本
         */
        private String previousVersion;
    }

    /**
     * 单个内容字段的差异描述。
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class FieldDiff {

        /**
         * 字段名，取值：template | variables | modelConfig
         */
        private String field;

        /**
         * 该字段是否有差异
         */
        private boolean changed;

        /**
         * diff 类型，取值：text | json | none。
         * <p>
         * changed=false 时为 "none"；"json" 表示两方均为合法 JSON、经规范化后行级 diff；"text" 表示按原始字符串（或退化）行级 diff。
         */
        private String diffType;

        /**
         * 差异块；changed=false 时为空数组（不回吐未变更内容）
         */
        private List<DiffHunk> hunks;
    }

    /**
     * 单个差异块（行级），add/remove 以 versionA → versionB 为方向。
     */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class DiffHunk {

        /**
         * 块类型，取值：add | remove | equal | context。
         * <p>
         * add：B 侧有、A 侧无；remove：A 侧有、B 侧无；equal：两侧相同；context：上下文行。
         */
        private String type;

        /**
         * A 侧行号（可选，无对应行时为 null）
         */
        private Integer oldStart;

        /**
         * B 侧行号（可选，无对应行时为 null）
         */
        private Integer newStart;

        /**
         * 该块包含的行内容
         */
        private List<String> lines;
    }
}
