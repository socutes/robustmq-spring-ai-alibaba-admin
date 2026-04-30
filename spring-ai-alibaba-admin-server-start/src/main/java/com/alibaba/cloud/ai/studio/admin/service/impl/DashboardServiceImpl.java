package com.alibaba.cloud.ai.studio.admin.service.impl;

import com.alibaba.cloud.ai.studio.admin.dto.dashboard.*;
import com.alibaba.cloud.ai.studio.admin.mapper.*;
import com.alibaba.cloud.ai.studio.admin.service.DashboardService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class DashboardServiceImpl implements DashboardService {

    private final PromptMapper promptMapper;
    private final PromptVersionMapper promptVersionMapper;
    private final ExperimentMapper experimentMapper;
    private final DatasetMapper datasetMapper;
    private final EvaluatorMapper evaluatorMapper;

    @Override
    public DashboardOverviewResult getOverview() {
        log.info("获取 dashboard overview 数据");
        return DashboardOverviewResult.builder()
                .prompts(buildPromptsStats())
                .promptVersions(buildPromptVersionsStats())
                .experiments(buildExperimentStats())
                .datasets(buildDatasetsStats())
                .evaluators(buildEvaluatorsStats())
                .recentActivity(buildRecentActivity())
                .build();
    }

    private PromptsStats buildPromptsStats() {
        int total = promptMapper.countTotal();
        int thisMonth = promptMapper.countThisMonth();
        return PromptsStats.builder().total(total).addedThisMonth(thisMonth).build();
    }

    private PromptVersionsStats buildPromptVersionsStats() {
        int total = promptVersionMapper.countTotal();
        int release = promptVersionMapper.countByStatus("release");
        int pre = promptVersionMapper.countByStatus("pre");
        return PromptVersionsStats.builder().total(total).releaseCount(release).preCount(pre).build();
    }

    private ExperimentStats buildExperimentStats() {
        List<Map<String, Object>> groups = experimentMapper.countGroupByStatus();
        Map<String, Integer> statusMap = new HashMap<>();
        int total = 0;
        for (Map<String, Object> row : groups) {
            String status = String.valueOf(row.get("status"));
            int cnt = ((Number) row.get("cnt")).intValue();
            statusMap.put(status, cnt);
            total += cnt;
        }
        return ExperimentStats.builder()
                .total(total)
                .draftCount(statusMap.getOrDefault("DRAFT", 0))
                .runningCount(statusMap.getOrDefault("RUNNING", 0))
                .completedCount(statusMap.getOrDefault("COMPLETED", 0))
                .failedCount(statusMap.getOrDefault("FAILED", 0))
                .stoppedCount(statusMap.getOrDefault("STOPPED", 0))
                .build();
    }

    private DatasetsStats buildDatasetsStats() {
        int total = datasetMapper.selectCount(null);
        return DatasetsStats.builder().total(total).build();
    }

    private EvaluatorsStats buildEvaluatorsStats() {
        int total = evaluatorMapper.count(null);
        return EvaluatorsStats.builder().total(total).build();
    }

    private List<RecentActivityItem> buildRecentActivity() {
        List<RecentActivityItem> items = new ArrayList<>();

        // 最近 Prompt 版本发布
        List<Map<String, Object>> recentVersions = promptVersionMapper.selectRecentVersions(10);
        for (Map<String, Object> row : recentVersions) {
            String promptKey = String.valueOf(row.get("promptKey"));
            String version = String.valueOf(row.get("version"));
            String status = String.valueOf(row.get("status"));
            long ts = toEpochMs(row.get("createTime"));
            items.add(RecentActivityItem.builder()
                    .eventType("PROMPT_VERSION_PUBLISHED")
                    .entityKey(promptKey)
                    .entityVersion(version)
                    .description("发布 Prompt " + promptKey + " " + version + "（" + status + "）")
                    .timestamp(ts)
                    .build());
        }

        // 最近实验状态变更
        List<Map<String, Object>> recentExperiments = experimentMapper.selectRecentExperiments(10);
        for (Map<String, Object> row : recentExperiments) {
            String name = String.valueOf(row.get("name"));
            String status = String.valueOf(row.get("status"));
            long ts = toEpochMs(row.get("updateTime"));
            items.add(RecentActivityItem.builder()
                    .eventType("EXPERIMENT_UPDATED")
                    .entityKey(name)
                    .entityVersion(null)
                    .description("实验 " + name + " 状态：" + status)
                    .timestamp(ts)
                    .build());
        }

        // 按时间倒序，取前 20 条
        items.sort(Comparator.comparingLong(RecentActivityItem::getTimestamp).reversed());
        return items.size() > 20 ? items.subList(0, 20) : items;
    }

    private long toEpochMs(Object value) {
        if (value instanceof LocalDateTime ldt) {
            return ldt.toInstant(ZoneOffset.of("+8")).toEpochMilli();
        }
        if (value instanceof java.sql.Timestamp ts) {
            return ts.getTime();
        }
        return 0L;
    }
}
