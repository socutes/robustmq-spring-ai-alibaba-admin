package com.alibaba.cloud.ai.studio.admin.dto.dashboard;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class RecentActivityItem {
    private String eventType;
    private String entityKey;
    private String entityVersion;
    private String description;
    private long timestamp;
}
