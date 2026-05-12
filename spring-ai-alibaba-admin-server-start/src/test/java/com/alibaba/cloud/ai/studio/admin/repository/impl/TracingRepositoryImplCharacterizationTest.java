package com.alibaba.cloud.ai.studio.admin.repository.impl;

import com.alibaba.cloud.ai.studio.admin.dto.SpanEventDTO;
import com.alibaba.cloud.ai.studio.admin.dto.SpanLinkDTO;
import com.alibaba.cloud.ai.studio.admin.dto.TraceSpanDTO;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Characterization Test — TracingRepositoryImpl 内部转换逻辑
 *
 * 原则：断言全部来自对现有代码的实际运行观察，不根据"应该是什么"推断。
 * 覆盖：convertToTraceSpanDTO、convertSpanKind、convertStatusCode、
 *        convertMicrosecondsToISO8601、convertSpanLinks、convertSpanEvents
 */
class TracingRepositoryImplCharacterizationTest {

    private TracingRepositoryImpl impl;

    @BeforeEach
    void setUp() throws Exception {
        // @RequiredArgsConstructor 生成 (ElasticsearchClientWrapper, TracingQueryBuilder)
        // 两个依赖均传 null，测试只走纯逻辑路径，不调用 ES
        impl = new TracingRepositoryImpl(null, null);
    }

    // ─── convertSpanKind ────────────────────────────────────────────────────

    @Test
    void spanKind_null_returnsInternal() throws Exception {
        assertEquals("SPAN_KIND_INTERNAL", invokeConvertSpanKind(null));
    }

    @Test
    void spanKind_client_returnsClient() throws Exception {
        assertEquals("SPAN_KIND_CLIENT", invokeConvertSpanKind("client"));
    }

    @Test
    void spanKind_server_returnsServer() throws Exception {
        assertEquals("SPAN_KIND_SERVER", invokeConvertSpanKind("server"));
    }

    @Test
    void spanKind_producer_returnsProducer() throws Exception {
        assertEquals("SPAN_KIND_PRODUCER", invokeConvertSpanKind("producer"));
    }

    @Test
    void spanKind_consumer_returnsConsumer() throws Exception {
        assertEquals("SPAN_KIND_CONSUMER", invokeConvertSpanKind("consumer"));
    }

    @Test
    void spanKind_internal_returnsInternal() throws Exception {
        assertEquals("SPAN_KIND_INTERNAL", invokeConvertSpanKind("internal"));
    }

    @Test
    void spanKind_unknown_returnsInternal() throws Exception {
        // 任何未知值走 default 分支
        assertEquals("SPAN_KIND_INTERNAL", invokeConvertSpanKind("UNKNOWN_KIND"));
    }

    @Test
    void spanKind_mixedCase_isCaseInsensitive() throws Exception {
        // 代码中 kind.toLowerCase() 后再 switch，大写也能匹配
        assertEquals("SPAN_KIND_CLIENT", invokeConvertSpanKind("CLIENT"));
        assertEquals("SPAN_KIND_SERVER", invokeConvertSpanKind("SERVER"));
    }

    // ─── convertStatusCode ──────────────────────────────────────────────────

    @Test
    void statusCode_null_returnsUnset() throws Exception {
        assertEquals("UNSET", invokeConvertStatusCode(null));
    }

    @Test
    void statusCode_ok_returnsOk() throws Exception {
        assertEquals("OK", invokeConvertStatusCode("OK"));
    }

    @Test
    void statusCode_error_returnsError() throws Exception {
        assertEquals("ERROR", invokeConvertStatusCode("ERROR"));
    }

    @Test
    void statusCode_unset_returnsUnset() throws Exception {
        assertEquals("UNSET", invokeConvertStatusCode("UNSET"));
    }

    @Test
    void statusCode_lowercaseOk_returnsOk() throws Exception {
        // 代码中 statusCode.toUpperCase() 后再 switch
        assertEquals("OK", invokeConvertStatusCode("ok"));
    }

    @Test
    void statusCode_unknown_returnsUnset() throws Exception {
        assertEquals("UNSET", invokeConvertStatusCode("SOMETHING_ELSE"));
    }

    // ─── convertMicrosecondsToISO8601 ───────────────────────────────────────

    @Test
    void convertTime_null_returnsNull() throws Exception {
        assertNull(invokeConvertMicrosecondsToISO8601(null));
    }

    @Test
    void convertTime_zeroEpoch_returnsEpochString() throws Exception {
        // 0 微秒 = 1970-01-01T00:00:00Z
        String result = invokeConvertMicrosecondsToISO8601(0L);
        assertEquals("1970-01-01T00:00:00Z", result);
    }

    @Test
    void convertTime_knownValue_producesCorrectISO8601() throws Exception {
        // 1_000_000 微秒 = 1000 毫秒 = 1970-01-01T00:00:01Z
        String result = invokeConvertMicrosecondsToISO8601(1_000_000L);
        assertEquals("1970-01-01T00:00:01Z", result);
    }

    @Test
    void convertTime_format_endsWithZ() throws Exception {
        String result = invokeConvertMicrosecondsToISO8601(1_715_000_000_000_000L);
        assertNotNull(result);
        assertTrue(result.endsWith("Z"), "ISO8601 UTC 格式应以 Z 结尾，实际: " + result);
    }

    // ─── convertToTraceSpanDTO ──────────────────────────────────────────────

    @Test
    void convertToTraceSpanDTO_fullMetadata_mapsAllFields() throws Exception {
        Map<String, Object> metadata = new HashMap<>();
        metadata.put("traceID", "trace-abc");
        metadata.put("spanID", "span-001");
        metadata.put("parentSpanID", "span-000");
        metadata.put("start", 1_000_000L);       // 微秒
        metadata.put("end", 2_000_000L);
        metadata.put("duration", 1_000_000L);
        metadata.put("kind", "server");
        metadata.put("service", "my-service");
        metadata.put("name", "GET /api/foo");
        metadata.put("statusCode", "OK");

        Map<String, Object> source = new HashMap<>();
        source.put("metadata", metadata);

        TraceSpanDTO dto = invokeConvertToTraceSpanDTO(source);

        assertEquals("trace-abc", dto.getTraceId());
        assertEquals("span-001", dto.getSpanId());
        assertEquals("span-000", dto.getParentSpanId());
        assertEquals("SPAN_KIND_SERVER", dto.getSpanKind());
        assertEquals("my-service", dto.getService());
        assertEquals("GET /api/foo", dto.getSpanName());
        assertEquals("OK", dto.getStatus());
        // duration 微秒 → 纳秒 (* 1000)
        assertEquals(1_000_000_000L, dto.getDurationNs());
        // errorCount 当前固定为 0（代码注释 FIXME）
        assertEquals(0, dto.getErrorCount());
    }

    @Test
    void convertToTraceSpanDTO_nullMetadata_returnsEmptyFields() throws Exception {
        Map<String, Object> source = new HashMap<>();
        // metadata 不存在

        TraceSpanDTO dto = invokeConvertToTraceSpanDTO(source);

        assertNull(dto.getTraceId());
        assertNull(dto.getSpanId());
        assertNull(dto.getParentSpanId());
        assertNull(dto.getDurationNs());
        assertNull(dto.getStartTime());
        assertNull(dto.getEndTime());
        // kind=null → SPAN_KIND_INTERNAL
        assertEquals("SPAN_KIND_INTERNAL", dto.getSpanKind());
        // statusCode=null → UNSET
        assertEquals("UNSET", dto.getStatus());
        assertEquals(0, dto.getErrorCount());
    }

    // ─── convertSpanLinks ───────────────────────────────────────────────────

    @Test
    void convertSpanLinks_null_returnsEmptyList() throws Exception {
        List<SpanLinkDTO> result = invokeConvertSpanLinks(null);
        assertNotNull(result);
        assertTrue(result.isEmpty());
    }

    @Test
    void convertSpanLinks_oneLink_mapsFields() throws Exception {
        Map<String, Object> link = new HashMap<>();
        link.put("traceID", "t1");
        link.put("spanID", "s1");
        Map<String, Object> attrs = Map.of("key", "val");
        link.put("attribute", attrs);

        List<SpanLinkDTO> result = invokeConvertSpanLinks(List.of(link));

        assertEquals(1, result.size());
        assertEquals("t1", result.get(0).getTraceId());
        assertEquals("s1", result.get(0).getSpanId());
        assertEquals(attrs, result.get(0).getAttributes());
    }

    // ─── convertSpanEvents ──────────────────────────────────────────────────

    @Test
    void convertSpanEvents_null_returnsEmptyList() throws Exception {
        List<SpanEventDTO> result = invokeConvertSpanEvents(null);
        assertNotNull(result);
        assertTrue(result.isEmpty());
    }

    @Test
    void convertSpanEvents_oneEvent_mapsFields() throws Exception {
        Map<String, Object> event = new HashMap<>();
        event.put("name", "exception");
        event.put("time", 1_000_000L); // 微秒
        Map<String, Object> attrs = Map.of("exception.type", "NullPointerException");
        event.put("attribute", attrs);

        List<SpanEventDTO> result = invokeConvertSpanEvents(List.of(event));

        assertEquals(1, result.size());
        assertEquals("exception", result.get(0).getName());
        assertEquals("1970-01-01T00:00:01Z", result.get(0).getTime());
        assertEquals(attrs, result.get(0).getAttributes());
    }

    // ─── 反射工具方法 ────────────────────────────────────────────────────────

    private String invokeConvertSpanKind(String kind) throws Exception {
        Method m = TracingRepositoryImpl.class.getDeclaredMethod("convertSpanKind", String.class);
        m.setAccessible(true);
        return (String) m.invoke(impl, kind);
    }

    private String invokeConvertStatusCode(String code) throws Exception {
        Method m = TracingRepositoryImpl.class.getDeclaredMethod("convertStatusCode", String.class);
        m.setAccessible(true);
        return (String) m.invoke(impl, code);
    }

    private String invokeConvertMicrosecondsToISO8601(Long us) throws Exception {
        Method m = TracingRepositoryImpl.class.getDeclaredMethod("convertMicrosecondsToISO8601", Long.class);
        m.setAccessible(true);
        return (String) m.invoke(impl, us);
    }

    private TraceSpanDTO invokeConvertToTraceSpanDTO(Map<String, Object> source) throws Exception {
        Method m = TracingRepositoryImpl.class.getDeclaredMethod("convertToTraceSpanDTO", Map.class);
        m.setAccessible(true);
        return (TraceSpanDTO) m.invoke(impl, source);
    }

    @SuppressWarnings("unchecked")
    private List<SpanLinkDTO> invokeConvertSpanLinks(List<Map<String, Object>> links) throws Exception {
        Method m = TracingRepositoryImpl.class.getDeclaredMethod("convertSpanLinks", List.class);
        m.setAccessible(true);
        return (List<SpanLinkDTO>) m.invoke(impl, links);
    }

    @SuppressWarnings("unchecked")
    private List<SpanEventDTO> invokeConvertSpanEvents(List<Map<String, Object>> events) throws Exception {
        Method m = TracingRepositoryImpl.class.getDeclaredMethod("convertSpanEvents", List.class);
        m.setAccessible(true);
        return (List<SpanEventDTO>) m.invoke(impl, events);
    }
}
