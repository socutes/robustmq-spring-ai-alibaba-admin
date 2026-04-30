package com.alibaba.cloud.ai.studio.admin.controller;

import com.alibaba.cloud.ai.studio.admin.dto.dashboard.DashboardOverviewResult;
import com.alibaba.cloud.ai.studio.admin.service.DashboardService;
import com.alibaba.cloud.ai.studio.runtime.domain.Result;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Slf4j
@RestController
@RequestMapping("/api/dashboard")
@RequiredArgsConstructor
public class DashboardController {

    private final DashboardService dashboardService;

    @GetMapping("/overview")
    public Result<DashboardOverviewResult> overview() {
        log.info("获取 dashboard overview");
        return Result.success(dashboardService.getOverview());
    }
}
