package com.alibaba.cloud.ai.studio.admin.utils;

import com.alibaba.cloud.ai.studio.admin.dto.PromptVersionDiffResponse.DiffHunk;
import com.alibaba.cloud.ai.studio.admin.dto.PromptVersionDiffResponse.FieldDiff;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.github.difflib.DiffUtils;
import com.github.difflib.patch.AbstractDelta;
import com.github.difflib.patch.Chunk;
import com.github.difflib.patch.DeltaType;
import com.github.difflib.patch.Patch;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.TreeMap;

/**
 * Prompt 版本对比的 diff 计算工具。
 *
 * <p>纯逻辑：给定两个字段值，产出结构化差异（{@link FieldDiff}）。不碰 DB / Service，
 * 由 {@code PromptVersionDiffService}（步骤 4）取到两版数据后调用本工具。
 *
 * <p>规则（见 {@code docs/requirements/prompt-version-diff.md} 与 {@code -solution.md}）：
 * <ul>
 *   <li><b>template</b>：换行归一（CRLF→LF，#11）后行级文本 diff，diffType=text</li>
 *   <li><b>variables / modelConfig</b>：
 *     <ul>
 *       <li>两方都合法 JSON → 规范化（readTree→按键排序→prettyPrint）后行级 diff，diffType=json
 *         （键顺序无关 #12、数值归一 0.70≡0.7）</li>
 *       <li>至少一方 null/空串/非法 JSON → 退化文本 diff，diffType=text（null≡""，#6 分支 1）</li>
 *     </ul>
 *   </li>
 *   <li>字段无差异 → changed=false、diffType=none、hunks=[]（#5，不回吐相同内容）</li>
 * </ul>
 *
 * <p>{@link FieldDiff} / {@link DiffHunk} 复用 {@code PromptVersionDiffResponse} 的内嵌类型
 * （dto 包），本工具不重复定义。
 */
@Component
@RequiredArgsConstructor
public class PromptVersionDiffCalculator {

    private final ObjectMapper objectMapper;

    // ===================== 公开 API =====================

    /**
     * template 字段：固定文本 diff（先换行归一）。
     */
    public FieldDiff diffTemplate(String a, String b) {
        return textDiff("template", a, b);
    }

    /**
     * variables / modelConfig 字段：先尝试 JSON 规范化 diff，至少一方 null/空串/非法则退化文本 diff。
     */
    public FieldDiff diffJsonField(String fieldName, String a, String b) {
        String na = normalizeNull(a);
        String nb = normalizeNull(b);
        // 两方归一后相同（含 null≡""）→ 无差异
        if (na.equals(nb)) {
            return unchanged(fieldName);
        }
        String canonA = canonicalize(na);
        String canonB = canonicalize(nb);
        if (canonA != null && canonB != null) {
            // 两方都合法 JSON：规范化后行级 diff（prettyPrint 已是 \n，不再换行归一）
            return doDiff(fieldName, canonA, canonB, "json", false);
        }
        // 至少一方非法/空 → 退化文本 diff（含换行归一）
        return textDiff(fieldName, na, nb);
    }

    // ===================== 文本 diff =====================

    private FieldDiff textDiff(String field, String a, String b) {
        String na = normalizeNull(a);
        String nb = normalizeNull(b);
        if (na.equals(nb)) {
            return unchanged(field);
        }
        return doDiff(field, na, nb, "text", true);
    }

    private FieldDiff doDiff(String field, String a, String b, String diffType, boolean normalizeNewlines) {
        String aa = normalizeNewlines ? normalizeCRLF(a) : a;
        String bb = normalizeNewlines ? normalizeCRLF(b) : b;
        if (aa.equals(bb)) {
            return unchanged(field);
        }
        List<DiffHunk> hunks = buildHunks(splitLines(aa), splitLines(bb));
        boolean changed = hunks.stream().anyMatch(h -> !"equal".equals(h.getType()));
        if (!changed) {
            return unchanged(field);
        }
        return FieldDiff.builder()
                .field(field)
                .changed(true)
                .diffType(diffType)
                .hunks(hunks)
                .build();
    }

    // ===================== 行级 diff（java-diff-utils）重建 hunks =====================

    /**
     * 用 java-diff-utils 算出 deltas，再结合原文重建 equal/add/remove 的行级 hunks。
     * 连续同类型行合并进同一个 hunk。
     */
    private List<DiffHunk> buildHunks(List<String> aLines, List<String> bLines) {
        Patch<String> patch = DiffUtils.diff(aLines, bLines);
        List<AbstractDelta<String>> deltas = patch.getDeltas();
        List<DiffHunk> hunks = new ArrayList<>();
        int ai = 0;  // 已处理的 source 行数
        int bi = 0;  // 已处理的 target 行数
        for (AbstractDelta<String> delta : deltas) {
            Chunk<String> src = delta.getSource();
            Chunk<String> tgt = delta.getTarget();
            int srcStart = src.getPosition();
            int tgtStart = tgt.getPosition();
            // delta 之前的 equal 段
            if (srcStart > ai) {
                hunks.add(hunk("equal", ai + 1, bi + 1, aLines.subList(ai, srcStart)));
            }
            List<String> srcLines = src.getLines();
            List<String> tgtLines = tgt.getLines();
            DeltaType type = delta.getType();
            if (type == DeltaType.DELETE) {
                hunks.add(hunk("remove", srcStart + 1, null, srcLines));
            } else if (type == DeltaType.INSERT) {
                hunks.add(hunk("add", null, tgtStart + 1, tgtLines));
            } else { // CHANGE
                if (!srcLines.isEmpty()) {
                    hunks.add(hunk("remove", srcStart + 1, null, srcLines));
                }
                if (!tgtLines.isEmpty()) {
                    hunks.add(hunk("add", null, tgtStart + 1, tgtLines));
                }
            }
            ai = srcStart + srcLines.size();
            bi = tgtStart + tgtLines.size();
        }
        // 末尾 equal 段
        if (ai < aLines.size()) {
            hunks.add(hunk("equal", ai + 1, bi + 1, aLines.subList(ai, aLines.size())));
        }
        return hunks;
    }

    private DiffHunk hunk(String type, Integer oldStart, Integer newStart, List<String> lines) {
        return DiffHunk.builder()
                .type(type)
                .oldStart(oldStart)
                .newStart(newStart)
                .lines(lines == null || lines.isEmpty() ? Collections.emptyList() : new ArrayList<>(lines))
                .build();
    }

    // ===================== 辅助 =====================

    private FieldDiff unchanged(String field) {
        return FieldDiff.builder()
                .field(field)
                .changed(false)
                .diffType("none")
                .hunks(Collections.emptyList())
                .build();
    }

    /** null → ""（实现 #6 的 null≡"" 归一）。 */
    private String normalizeNull(String s) {
        return s == null ? "" : s;
    }

    /** 换行归一：CRLF / CR → LF（#11）。 */
    private String normalizeCRLF(String s) {
        return s.replace("\r\n", "\n").replace("\r", "\n");
    }

    private List<String> splitLines(String s) {
        if (s.isEmpty()) {
            return Collections.emptyList();
        }
        return Arrays.asList(s.split("\n", -1));
    }

    /**
     * 合法 JSON → 按键排序 + prettyPrint 的规范化字符串；非法/空 → null。
     * 数值经 readTree 再序列化天然归一（0.70→0.7）。
     */
    private String canonicalize(String s) {
        if (s == null || s.isEmpty()) {
            return null;
        }
        try {
            JsonNode tree = objectMapper.readTree(s);
            // ORDER_MAP_ENTRIES_BY_KEYS 对 JsonNode 不生效（ObjectNode 保留插入顺序），
            // 递归转 TreeMap（含嵌套）实现按键排序，满足"键顺序无关"（#12）。
            return objectMapper.writerWithDefaultPrettyPrinter().writeValueAsString(toSorted(tree));
        } catch (JsonProcessingException e) {
            return null;
        }
    }

    /** 递归把 JsonNode 转成按键排序的结构：对象→TreeMap，数组→List，值→原样。 */
    private Object toSorted(JsonNode node) {
        if (node.isObject()) {
            TreeMap<String, Object> map = new TreeMap<>();
            node.fields().forEachRemaining(e -> map.put(e.getKey(), toSorted(e.getValue())));
            return map;
        } else if (node.isArray()) {
            List<Object> list = new ArrayList<>();
            node.forEach(e -> list.add(toSorted(e)));
            return list;
        }
        return node;
    }

}
