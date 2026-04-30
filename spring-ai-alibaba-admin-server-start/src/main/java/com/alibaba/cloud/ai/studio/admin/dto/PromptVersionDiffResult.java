package com.alibaba.cloud.ai.studio.admin.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PromptVersionDiffResult {

    /** 被比较的 Prompt Key */
    private String promptKey;

    /** 版本 A 元信息 */
    private VersionMeta versionA;

    /** 版本 B 元信息 */
    private VersionMeta versionB;

    /** 各字段的对比结果 */
    private DiffFields diffs;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class DiffFields {

        /** Prompt 模板内容对比 */
        private DiffItem template;

        /** 变量列表对比 */
        private DiffItem variables;

        /** 模型参数对比 */
        private DiffItem modelConfig;
    }
}
