package com.alibaba.cloud.ai.studio.admin.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VersionMeta {

    /** 版本号 */
    private String version;

    /** 版本状态：pre / release */
    private String status;

    /** 创建时间，epoch 毫秒，与 PromptVersionDetail.createTime 格式一致 */
    private Long createTime;
}
