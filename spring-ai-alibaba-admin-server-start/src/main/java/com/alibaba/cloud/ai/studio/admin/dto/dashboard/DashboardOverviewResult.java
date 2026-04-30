package com.alibaba.cloud.ai.studio.admin.dto.dashboard;

import lombok.Builder;
import lombok.Data;

import java.util.List;

@Data
@Builder
public class DashboardOverviewResult {
    private PromptsStats prompts;
    private PromptVersionsStats promptVersions;
    private ExperimentStats experiments;
    private DatasetsStats datasets;
    private EvaluatorsStats evaluators;
    private List<RecentActivityItem> recentActivity;
}
