package com.alibaba.cloud.ai.studio.admin.dto.dashboard;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class PromptVersionsStats {
    private int total;
    private int releaseCount;
    private int preCount;
}
