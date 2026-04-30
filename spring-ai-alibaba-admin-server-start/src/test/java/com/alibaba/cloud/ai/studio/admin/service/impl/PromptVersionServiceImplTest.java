package com.alibaba.cloud.ai.studio.admin.service.impl;

import com.alibaba.cloud.ai.studio.admin.dto.PromptVersionDetail;
import com.alibaba.cloud.ai.studio.admin.entity.PromptVersionDO;
import com.alibaba.cloud.ai.studio.admin.exception.StudioException;
import com.alibaba.cloud.ai.studio.admin.mapper.PromptVersionMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PromptVersionServiceImplTest {

    @Mock
    private PromptVersionMapper promptVersionMapper;

    @InjectMocks
    private PromptVersionServiceImpl promptVersionService;

    // Characterization Test 1: 版本存在时，返回正确的 PromptVersionDetail
    @Test
    void getByPromptKeyAndVersion_whenExists_returnsDetail() throws StudioException {
        LocalDateTime now = LocalDateTime.of(2024, 1, 15, 10, 0, 0);
        PromptVersionDO do1 = PromptVersionDO.builder()
                .promptKey("test-key")
                .version("v1")
                .template("hello {{name}}")
                .variables("[\"name\"]")
                .modelConfig("{\"temperature\":0.7}")
                .status("release")
                .createTime(now)
                .previousVersion(null)
                .build();

        when(promptVersionMapper.selectByPromptKeyAndVersion("test-key", "v1")).thenReturn(do1);

        PromptVersionDetail result = promptVersionService.getByPromptKeyAndVersion("test-key", "v1");

        // 断言基于 fromDO 的实际转换逻辑
        assertEquals("test-key", result.getPromptKey());
        assertEquals("v1", result.getVersion());
        assertEquals("hello {{name}}", result.getTemplate());
        assertEquals("[\"name\"]", result.getVariables());
        assertEquals("{\"temperature\":0.7}", result.getModelConfig());
        assertEquals("release", result.getStatus());
        assertNull(result.getPreviousVersion());
        // createTime 由 LocalDateTime 转 epoch ms，系统时区
        long expectedMs = now.atZone(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli();
        assertEquals(expectedMs, result.getCreateTime());
    }

    // Characterization Test 2: 版本不存在时，抛 StudioException(NOT_FOUND)
    @Test
    void getByPromptKeyAndVersion_whenNotExists_throwsStudioException() {
        when(promptVersionMapper.selectByPromptKeyAndVersion("no-key", "v99")).thenReturn(null);

        StudioException ex = assertThrows(StudioException.class,
                () -> promptVersionService.getByPromptKeyAndVersion("no-key", "v99"));

        assertEquals(StudioException.NOT_FOUND, ex.getErrCode());
        assertEquals("Prompt版本不存在: no-key@v99", ex.getErrMsg());
    }
}
