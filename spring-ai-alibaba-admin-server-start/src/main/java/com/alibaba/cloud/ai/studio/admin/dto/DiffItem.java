package com.alibaba.cloud.ai.studio.admin.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DiffItem {

    /** 两版本该字段是否有差异（null 视同空字符串参与比较） */
    private Boolean changed;

    /** 版本 A 的原始字符串值；字段为 null 时返回 "" */
    private String valueA;

    /** 版本 B 的原始字符串值；字段为 null 时返回 "" */
    private String valueB;
}
