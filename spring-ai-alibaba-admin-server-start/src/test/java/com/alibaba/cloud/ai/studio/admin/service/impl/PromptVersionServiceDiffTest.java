package com.alibaba.cloud.ai.studio.admin.service.impl;

import com.alibaba.cloud.ai.studio.admin.dto.PromptVersionDiffResult;
import com.alibaba.cloud.ai.studio.admin.entity.PromptDO;
import com.alibaba.cloud.ai.studio.admin.entity.PromptVersionDO;
import com.alibaba.cloud.ai.studio.admin.exception.StudioException;
import com.alibaba.cloud.ai.studio.admin.mapper.PromptMapper;
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
class PromptVersionServiceDiffTest {

    @Mock
    private PromptVersionMapper promptVersionMapper;

    @Mock
    private PromptMapper promptMapper;

    @InjectMocks
    private PromptVersionServiceImpl promptVersionService;

    // E01: versionA == versionB → 抛 StudioException(INVALID_PARAM)
    @Test
    void diffVersions_sameVersion_throwsInvalidParam() {
        StudioException ex = assertThrows(StudioException.class,
                () -> promptVersionService.diffVersions("key", "v1", "v1"));
        assertEquals(StudioException.INVALID_PARAM, ex.getErrCode());
    }

    // E02: versionA 不存在 → 抛 StudioException(NOT_FOUND)
    @Test
    void diffVersions_versionANotFound_throwsNotFound() {
        when(promptMapper.selectByPromptKey("key")).thenReturn(new PromptDO());
        when(promptVersionMapper.selectByPromptKeyAndVersion("key", "v1")).thenReturn(null);

        StudioException ex = assertThrows(StudioException.class,
                () -> promptVersionService.diffVersions("key", "v1", "v2"));
        assertEquals(StudioException.NOT_FOUND, ex.getErrCode());
        assertTrue(ex.getErrMsg().contains("v1"));
    }

    // E04: template 为 null → valueA/valueB 返回 ""，changed 基于空字符串比较
    @Test
    void diffVersions_nullTemplate_treatedAsEmpty() throws StudioException {
        when(promptMapper.selectByPromptKey("key")).thenReturn(new PromptDO());

        PromptVersionDO doA = PromptVersionDO.builder()
                .promptKey("key").version("v1").template(null)
                .variables("[\"q\"]").modelConfig("{}")
                .status("release").createTime(LocalDateTime.now()).build();
        PromptVersionDO doB = PromptVersionDO.builder()
                .promptKey("key").version("v2").template(null)
                .variables("[\"q\"]").modelConfig("{}")
                .status("pre").createTime(LocalDateTime.now()).build();

        when(promptVersionMapper.selectByPromptKeyAndVersion("key", "v1")).thenReturn(doA);
        when(promptVersionMapper.selectByPromptKeyAndVersion("key", "v2")).thenReturn(doB);

        PromptVersionDiffResult result = promptVersionService.diffVersions("key", "v1", "v2");

        assertEquals("", result.getDiffs().getTemplate().getValueA());
        assertEquals("", result.getDiffs().getTemplate().getValueB());
        assertFalse(result.getDiffs().getTemplate().getChanged()); // 两个都是 ""，不变
    }

    // happy path: 两版本存在，template 不同 → changed=true
    @Test
    void diffVersions_happyPath_returnsCorrectDiff() throws StudioException {
        when(promptMapper.selectByPromptKey("key")).thenReturn(new PromptDO());

        PromptVersionDO doA = PromptVersionDO.builder()
                .promptKey("key").version("v1")
                .template("你是客服").variables("[\"q\"]").modelConfig("{\"temperature\":0.7}")
                .status("release").createTime(LocalDateTime.of(2024, 1, 1, 0, 0)).build();
        PromptVersionDO doB = PromptVersionDO.builder()
                .promptKey("key").version("v2")
                .template("你是专业客服").variables("[\"q\"]").modelConfig("{\"temperature\":0.3}")
                .status("pre").createTime(LocalDateTime.of(2024, 2, 1, 0, 0)).build();

        when(promptVersionMapper.selectByPromptKeyAndVersion("key", "v1")).thenReturn(doA);
        when(promptVersionMapper.selectByPromptKeyAndVersion("key", "v2")).thenReturn(doB);

        PromptVersionDiffResult result = promptVersionService.diffVersions("key", "v1", "v2");

        assertEquals("key", result.getPromptKey());
        assertEquals("v1", result.getVersionA().getVersion());
        assertEquals("v2", result.getVersionB().getVersion());
        assertTrue(result.getDiffs().getTemplate().getChanged());
        assertEquals("你是客服", result.getDiffs().getTemplate().getValueA());
        assertEquals("你是专业客服", result.getDiffs().getTemplate().getValueB());
        assertFalse(result.getDiffs().getVariables().getChanged()); // 相同
        assertTrue(result.getDiffs().getModelConfig().getChanged());
    }
}
