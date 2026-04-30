package com.alibaba.cloud.ai.studio.admin.dto.dashboard;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class ExperimentStats {
    private int total;
    private int draftCount;
    private int runningCount;
    private int completedCount;
    private int failedCount;
    private int stoppedCount;
}
