#!/usr/bin/env python3
"""Generate OryxOS SVG diagrams using Python standard library only."""

import os

OUTPUT_DIR = "/Users/oker/robustmq-spring-ai-alibaba-admin/docs/images"


# ─────────────────────────────────────────────────────────────────────────────
# SVG 1 – oryxos-core-features.svg
# ─────────────────────────────────────────────────────────────────────────────

def make_core_features():
    W, H = 960, 560
    PAD_X = 40
    PAD_Y_TOP = 100   # below header
    CARD_W = 267
    CARD_H = 170
    GAP_X = 20
    GAP_Y = 20
    ROW_START_Y = 108

    cards = [
        {
            "title": "Agent 运行时与多渠道接入",
            "color": "#4A90D9",
            "items": [
                "Feishu / WeCom / REST API",
                "14 LLM Provider",
                "Session JSONL 持久化",
            ],
            "icon": "channels",
        },
        {
            "title": "技能系统与 Sub Agent 协议",
            "color": "#52B366",
            "items": [
                "stdin/stdout JSON Skill",
                "Agent Card 规范",
                "Planner 意图路由",
            ],
            "icon": "chain",
        },
        {
            "title": "记忆与上下文管理",
            "color": "#D4A843",
            "items": [
                "Episodic BM25 检索",
                "Long-term MEMORY.md",
                "Entity Bank",
            ],
            "icon": "layers",
        },
        {
            "title": "多租户隔离与权限管理",
            "color": "#8B5CF6",
            "items": [
                "Profile 隔离",
                "双级角色 RBAC",
                "Identity Passthrough",
            ],
            "icon": "isolation",
        },
        {
            "title": "治理与审计日志",
            "color": "#E05252",
            "items": [
                "4类审计事件",
                "异步写入",
                "CSV 导出",
            ],
            "icon": "logs",
        },
        {
            "title": "管控平面",
            "color": "#E0734A",
            "items": [
                "Profile/Agent/Session 管理",
                "Kill Switch",
                "热配置",
            ],
            "icon": "dashboard",
        },
    ]

    def icon_channels(cx, cy, color):
        """3 channel circles → central box."""
        lines = []
        r = 10
        positions = [(cx - 28, cy - 22), (cx - 28, cy), (cx - 28, cy + 22)]
        for px, py in positions:
            lines.append(f'<circle cx="{px}" cy="{py}" r="{r}" fill="{color}" opacity="0.25" stroke="{color}" stroke-width="1.5"/>')
        # arrows → center box
        box_x, box_y = cx + 4, cy - 14
        for px, py in positions:
            lines.append(f'<line x1="{px + r}" y1="{py}" x2="{box_x}" y2="{box_y + 14}" stroke="{color}" stroke-width="1" opacity="0.6" marker-end="url(#arr)"/>')
        lines.append(f'<rect x="{box_x}" y="{box_y}" width="28" height="28" rx="4" fill="{color}" opacity="0.18" stroke="{color}" stroke-width="1.5"/>')
        return "\n".join(lines)

    def icon_chain(cx, cy, color):
        """3 small squares in a horizontal chain."""
        lines = []
        sz = 16
        spacing = 24
        start_x = cx - spacing
        for i in range(3):
            bx = start_x + i * spacing - sz // 2
            by = cy - sz // 2
            lines.append(f'<rect x="{bx}" y="{by}" width="{sz}" height="{sz}" rx="3" fill="{color}" opacity="0.2" stroke="{color}" stroke-width="1.5"/>')
            if i < 2:
                lines.append(f'<line x1="{bx + sz}" y1="{cy}" x2="{bx + spacing}" y2="{cy}" stroke="{color}" stroke-width="1.5" marker-end="url(#arr)"/>')
        return "\n".join(lines)

    def icon_layers(cx, cy, color):
        """3 stacked rectangles."""
        lines = []
        for i, (ow, oh) in enumerate([(56, 12), (44, 12), (32, 12)]):
            rx = cx - ow // 2
            ry = cy - 22 + i * 16
            lines.append(f'<rect x="{rx}" y="{ry}" width="{ow}" height="{oh}" rx="3" fill="{color}" opacity="{0.15 + i * 0.12:.2f}" stroke="{color}" stroke-width="1.5"/>')
        return "\n".join(lines)

    def icon_isolation(cx, cy, color):
        """Two separated boxes."""
        lines = []
        lines.append(f'<rect x="{cx - 42}" y="{cy - 18}" width="34" height="36" rx="4" fill="{color}" opacity="0.15" stroke="{color}" stroke-width="1.5"/>')
        lines.append(f'<rect x="{cx + 8}" y="{cy - 18}" width="34" height="36" rx="4" fill="{color}" opacity="0.15" stroke="{color}" stroke-width="1.5"/>')
        lines.append(f'<line x1="{cx - 4}" y1="{cy - 22}" x2="{cx - 4}" y2="{cy + 22}" stroke="{color}" stroke-width="2" stroke-dasharray="4,3" opacity="0.7"/>')
        return "\n".join(lines)

    def icon_logs(cx, cy, color):
        """Log lines stacked."""
        lines = []
        for i in range(4):
            w = 52 - i * 6
            lx = cx - 26
            ly = cy - 20 + i * 14
            lines.append(f'<rect x="{lx}" y="{ly}" width="{w}" height="8" rx="2" fill="{color}" opacity="{0.12 + i * 0.07:.2f}" stroke="{color}" stroke-width="1"/>')
        return "\n".join(lines)

    def icon_dashboard(cx, cy, color):
        """Simple dashboard arc + needle."""
        lines = []
        lines.append(f'<path d="M{cx-28},{cy+10} A 28 28 0 0 1 {cx+28},{cy+10}" fill="none" stroke="{color}" stroke-width="2" opacity="0.4"/>')
        lines.append(f'<line x1="{cx}" y1="{cy+10}" x2="{cx+14}" y2="{cy-14}" stroke="{color}" stroke-width="2.5" opacity="0.8"/>')
        lines.append(f'<circle cx="{cx}" cy="{cy+10}" r="4" fill="{color}" opacity="0.7"/>')
        # tick marks
        import math
        for angle_deg in [180, 210, 240, 270, 300, 330, 360]:
            angle_rad = math.radians(angle_deg)
            ox = cx + 24 * math.cos(angle_rad)
            oy = cy + 10 + 24 * math.sin(angle_rad)
            ix = cx + 19 * math.cos(angle_rad)
            iy = cy + 10 + 19 * math.sin(angle_rad)
            lines.append(f'<line x1="{ox:.1f}" y1="{oy:.1f}" x2="{ix:.1f}" y2="{iy:.1f}" stroke="{color}" stroke-width="1.5" opacity="0.5"/>')
        return "\n".join(lines)

    ICON_FUNCS = [icon_channels, icon_chain, icon_layers, icon_isolation, icon_logs, icon_dashboard]

    parts = []
    parts.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="\'PingFang SC\',\'Microsoft YaHei\',Arial,sans-serif">')

    # defs
    parts.append("""  <defs>
    <marker id="arr" markerWidth="7" markerHeight="7" refX="6" refY="3.5" orient="auto">
      <path d="M0,0 L7,3.5 L0,7 Z" fill="#999"/>
    </marker>
    <filter id="shadow" x="-5%" y="-5%" width="110%" height="115%">
      <feDropShadow dx="0" dy="2" stdDeviation="3" flood-color="#00000018"/>
    </filter>
  </defs>""")

    # background
    parts.append(f'  <rect width="{W}" height="{H}" fill="#F8FAFF"/>')

    # header background band
    parts.append(f'  <rect x="0" y="0" width="{W}" height="95" fill="#EEF3FF"/>')
    parts.append(f'  <line x1="0" y1="95" x2="{W}" y2="95" stroke="#D0DBFF" stroke-width="1"/>')

    # title
    parts.append(f'  <text x="{W//2}" y="38" text-anchor="middle" font-size="22" font-weight="bold" fill="#1A3A6B">OryxOS 核心功能模块</text>')
    parts.append(f'  <text x="{W//2}" y="64" text-anchor="middle" font-size="14" fill="#6B7A99">企业级 AI Agent OS — 运行时 + 治理层</text>')

    # small decorative dots
    for i, color in enumerate(["#4A90D9", "#52B366", "#D4A843", "#8B5CF6", "#E05252", "#E0734A"]):
        parts.append(f'  <circle cx="{W//2 - 75 + i * 30}" cy="80" r="4" fill="{color}" opacity="0.6"/>')

    # cards
    for idx, card in enumerate(cards):
        row = idx // 3
        col = idx % 3
        cx_offset = PAD_X + col * (CARD_W + GAP_X)
        cy_offset = ROW_START_Y + row * (CARD_H + GAP_Y)
        color = card["color"]

        # card shadow + body
        parts.append(f'  <rect x="{cx_offset + 2}" y="{cy_offset + 2}" width="{CARD_W}" height="{CARD_H}" rx="10" fill="#00000012"/>')
        parts.append(f'  <rect x="{cx_offset}" y="{cy_offset}" width="{CARD_W}" height="{CARD_H}" rx="10" fill="white" filter="url(#shadow)"/>')

        # left accent bar
        parts.append(f'  <rect x="{cx_offset}" y="{cy_offset}" width="5" height="{CARD_H}" rx="5" fill="{color}"/>')
        parts.append(f'  <rect x="{cx_offset}" y="{cy_offset + 10}" width="5" height="{CARD_H - 20}" fill="{color}"/>')

        # title background strip
        parts.append(f'  <rect x="{cx_offset + 5}" y="{cy_offset}" width="{CARD_W - 5}" height="38" rx="0" fill="{color}" opacity="0.08"/>')
        parts.append(f'  <rect x="{cx_offset + 5}" y="{cy_offset}" width="{CARD_W - 15}" height="38" rx="0" fill="{color}" opacity="0.00"/>')  # spacer

        # title text (wrap if needed — just clip)
        title = card["title"]
        parts.append(f'  <text x="{cx_offset + 16}" y="{cy_offset + 24}" font-size="13" font-weight="bold" fill="{color}">{title}</text>')

        # star badge
        parts.append(f'  <text x="{cx_offset + CARD_W - 16}" y="{cy_offset + 24}" text-anchor="end" font-size="13" fill="{color}">★</text>')

        # label "核心阶段"
        parts.append(f'  <text x="{cx_offset + CARD_W - 16}" y="{cy_offset + 36}" text-anchor="end" font-size="9" fill="{color}" opacity="0.8">核心阶段</text>')

        # separator line
        parts.append(f'  <line x1="{cx_offset + 14}" y1="{cy_offset + 44}" x2="{cx_offset + CARD_W - 14}" y2="{cy_offset + 44}" stroke="{color}" stroke-width="0.8" opacity="0.3"/>')

        # bullet items
        for i, item in enumerate(card["items"]):
            iy = cy_offset + 64 + i * 26
            # bullet dot
            parts.append(f'  <circle cx="{cx_offset + 20}" cy="{iy - 4}" r="3.5" fill="{color}" opacity="0.7"/>')
            parts.append(f'  <text x="{cx_offset + 30}" y="{iy}" font-size="11.5" fill="#3A4566">{item}</text>')

        # icon in bottom-right area
        icon_cx = cx_offset + CARD_W - 48
        icon_cy = cy_offset + CARD_H - 44
        # light circle bg for icon
        parts.append(f'  <circle cx="{icon_cx}" cy="{icon_cy}" r="36" fill="{color}" opacity="0.06"/>')
        parts.append(ICON_FUNCS[idx](icon_cx, icon_cy, color))

    # footer
    parts.append(f'  <text x="{W//2}" y="{H - 10}" text-anchor="middle" font-size="10" fill="#A0AABB">OryxOS Core Feature Overview  |  ★ = 核心阶段</text>')

    parts.append('</svg>')
    return "\n".join(parts)


# ─────────────────────────────────────────────────────────────────────────────
# SVG 2 – oryxos-sub-agent-protocol.svg
# ─────────────────────────────────────────────────────────────────────────────

def make_sub_agent_protocol():
    W, H = 960, 520

    parts = []
    parts.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="\'PingFang SC\',\'Microsoft YaHei\',Arial,sans-serif">')

    # defs
    parts.append("""  <defs>
    <marker id="arrowB" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">
      <path d="M0,0 L8,4 L0,8 Z" fill="#4A90D9"/>
    </marker>
    <marker id="arrowG" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">
      <path d="M0,0 L8,4 L0,8 Z" fill="#52B366"/>
    </marker>
    <marker id="arrowR" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">
      <path d="M0,0 L8,4 L0,8 Z" fill="#E05252"/>
    </marker>
    <marker id="arrowGray" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">
      <path d="M0,0 L8,4 L0,8 Z" fill="#888"/>
    </marker>
    <filter id="cardShadow" x="-5%" y="-5%" width="110%" height="115%">
      <feDropShadow dx="0" dy="2" stdDeviation="3" flood-color="#00000015"/>
    </filter>
  </defs>""")

    # full background
    parts.append(f'  <rect width="{W}" height="{H}" fill="#F8FAFF"/>')

    # ── Section bands
    # Registration band: y=50..270
    parts.append(f'  <rect x="0" y="50" width="{W}" height="230" fill="#EEF6FF" rx="0"/>')
    # Invoke band: y=290..490
    parts.append(f'  <rect x="0" y="290" width="{W}" height="220" fill="#F0FFF4" rx="0"/>')

    # Divider line
    parts.append(f'  <line x1="0" y1="270" x2="{W}" y2="270" stroke="#C8D8EE" stroke-width="1.5" stroke-dasharray="6,4"/>')

    # ── Section labels
    parts.append(f'  <rect x="20" y="56" width="160" height="28" rx="6" fill="#4A90D9" opacity="0.15"/>')
    parts.append(f'  <text x="30" y="75" font-size="13" font-weight="bold" fill="#1A5BA8">Sub Agent 注册流程</text>')

    parts.append(f'  <rect x="20" y="294" width="160" height="28" rx="6" fill="#52B366" opacity="0.15"/>')
    parts.append(f'  <text x="30" y="313" font-size="13" font-weight="bold" fill="#1A7A40">Sub Agent 调用流程</text>')

    # ── Participants (Registration): 4 actors
    # x positions for 4 actors evenly spaced in ~730px (leaving room for right annotation)
    reg_actors = [
        {"label": "Sub Agent",       "color": "#52B366", "text_color": "white"},
        {"label": "OryxOS 注册中心",  "color": "#4A90D9", "text_color": "white"},
        {"label": "健康检查器",        "color": "#7BB8E8", "text_color": "#1A3A6B"},
        {"label": "管控平面",          "color": "#8899AA", "text_color": "white"},
    ]
    BOX_W, BOX_H = 140, 36
    reg_xs = [55, 245, 435, 625]
    reg_y = 100

    for i, actor in enumerate(reg_actors):
        bx = reg_xs[i]
        by = reg_y
        parts.append(f'  <rect x="{bx}" y="{by}" width="{BOX_W}" height="{BOX_H}" rx="7" fill="{actor["color"]}" filter="url(#cardShadow)"/>')
        parts.append(f'  <text x="{bx + BOX_W//2}" y="{by + 23}" text-anchor="middle" font-size="12" font-weight="bold" fill="{actor["text_color"]}">{actor["label"]}</text>')

    def reg_cx(i): return reg_xs[i] + BOX_W // 2

    # ── Registration steps (arrows between actors)
    # Step baseline: starts at reg_y + BOX_H
    steps_reg = [
        # (from_idx, to_idx, label, y_offset, color_key)
        (0, 1, "POST /register（携带 Agent Card）", 40, "#4A90D9", "arrowB"),
        (1, 3, "存储 Agent Card", 80, "#8899AA", "arrowGray"),
        (2, 0, "GET /health（每 30s）", 120, "#7BB8E8", "arrowB"),
        (2, 1, "更新状态（HEALTHY / UNHEALTHY）", 160, "#4A90D9", "arrowB"),
    ]

    base_y = reg_y + BOX_H

    for from_i, to_i, label, y_off, color, marker in steps_reg:
        y = base_y + y_off
        x1 = reg_cx(from_i) + (1 if from_i < to_i else -1) * (BOX_W // 2 - 2)
        x2 = reg_cx(to_i) + (1 if to_i > from_i else 1) * (BOX_W // 2 - 2)
        # Step number
        step_num = steps_reg.index((from_i, to_i, label, y_off, color, marker)) + 1
        mid_x = (x1 + x2) // 2
        # dashed vertical guides
        for actor_i in [from_i, to_i]:
            ax = reg_cx(actor_i)
            parts.append(f'  <line x1="{ax}" y1="{reg_y + BOX_H}" x2="{ax}" y2="{base_y + 175}" stroke="{reg_actors[actor_i]["color"]}" stroke-width="1" stroke-dasharray="3,4" opacity="0.35"/>')

        parts.append(f'  <line x1="{x1}" y1="{y}" x2="{x2}" y2="{y}" stroke="{color}" stroke-width="1.8" marker-end="url(#{marker})"/>')
        parts.append(f'  <rect x="{mid_x - 120}" y="{y - 17}" width="240" height="15" rx="3" fill="white" opacity="0.75"/>')
        parts.append(f'  <text x="{mid_x}" y="{y - 5}" text-anchor="middle" font-size="11" fill="#2A3C6B">{label}</text>')
        # step badge
        parts.append(f'  <circle cx="{min(x1,x2) + 8}" cy="{y - 9}" r="9" fill="{color}" opacity="0.85"/>')
        parts.append(f'  <text x="{min(x1,x2) + 8}" y="{y - 5}" text-anchor="middle" font-size="9" font-weight="bold" fill="white">{step_num}</text>')

    # draw lifelines properly (ensure all actors get lifeline in reg section)
    for actor_i in [0, 1, 2, 3]:
        ax = reg_cx(actor_i)
        parts.append(f'  <line x1="{ax}" y1="{reg_y + BOX_H}" x2="{ax}" y2="{base_y + 178}" stroke="{reg_actors[actor_i]["color"]}" stroke-width="1" stroke-dasharray="3,4" opacity="0.3"/>')

    # ── Participants (Invocation): 4 actors
    inv_actors = [
        {"label": "用户 (Feishu/WeCom)", "color": "#8B5CF6", "text_color": "white"},
        {"label": "OryxOS Gateway",       "color": "#4A90D9", "text_color": "white"},
        {"label": "Planner",              "color": "#D4A843", "text_color": "white"},
        {"label": "Sub Agent",            "color": "#52B366", "text_color": "white"},
    ]
    inv_xs = [55, 245, 435, 625]
    inv_y = 308

    for i, actor in enumerate(inv_actors):
        bx = inv_xs[i]
        by = inv_y
        parts.append(f'  <rect x="{bx}" y="{by}" width="{BOX_W}" height="{BOX_H}" rx="7" fill="{actor["color"]}" filter="url(#cardShadow)"/>')
        parts.append(f'  <text x="{bx + BOX_W//2}" y="{by + 23}" text-anchor="middle" font-size="11.5" font-weight="bold" fill="{actor["text_color"]}">{actor["label"]}</text>')

    def inv_cx(i): return inv_xs[i] + BOX_W // 2

    inv_base_y = inv_y + BOX_H
    # lifelines for invoke section
    for actor_i in range(4):
        ax = inv_cx(actor_i)
        parts.append(f'  <line x1="{ax}" y1="{inv_y + BOX_H}" x2="{ax}" y2="{inv_base_y + 165}" stroke="{inv_actors[actor_i]["color"]}" stroke-width="1" stroke-dasharray="3,4" opacity="0.3"/>')

    steps_inv = [
        # (from_i, to_i, label, y_off, color, marker, is_self_loop)
        (0, 1, "发送消息", 36, "#8B5CF6", "arrowB", False),
        (1, 2, "意图识别", 72, "#4A90D9", "arrowB", False),
        (2, 2, "关键词匹配 skill_name", 108, "#D4A843", "arrowGray", True),
        (2, 3, "POST /api/v1/chat（注入 X-OryxOS-Identity）", 136, "#52B366", "arrowG", False),
        (3, 2, "响应结果", 162, "#52B366", "arrowR", False),
        (2, 0, "回复消息", 188, "#8B5CF6", "arrowB", False),  # skip steps for clarity: Planner→Gateway→User shown as one
    ]

    for step_i, (from_i, to_i, label, y_off, color, marker, is_self) in enumerate(steps_inv):
        y = inv_base_y + y_off
        if is_self:
            ax = inv_cx(from_i)
            # self-loop arc
            parts.append(f'  <path d="M{ax+2},{y-16} C{ax+55},{y-22} {ax+55},{y+10} {ax+2},{y+4}" fill="none" stroke="{color}" stroke-width="1.8" marker-end="url(#arrowGray)"/>')
            parts.append(f'  <rect x="{ax + 10}" y="{y - 20}" width="200" height="15" rx="3" fill="white" opacity="0.8"/>')
            parts.append(f'  <text x="{ax + 20}" y="{y - 8}" font-size="10.5" fill="#6B4A00">{label}</text>')
        else:
            x1 = inv_cx(from_i) + (1 if from_i < to_i else -1) * (BOX_W // 2 - 2)
            x2 = inv_cx(to_i) + (1 if to_i > from_i else 1) * (BOX_W // 2 - 2)
            mid_x = (x1 + x2) // 2
            lw = 1.8
            # dashed for return
            dash = "stroke-dasharray=\"5,3\"" if from_i > to_i else ""
            parts.append(f'  <line x1="{x1}" y1="{y}" x2="{x2}" y2="{y}" stroke="{color}" stroke-width="{lw}" {dash} marker-end="url(#{marker})"/>')
            label_x = mid_x
            parts.append(f'  <rect x="{label_x - 150}" y="{y - 17}" width="300" height="15" rx="3" fill="white" opacity="0.75"/>')
            parts.append(f'  <text x="{label_x}" y="{y - 5}" text-anchor="middle" font-size="10.5" fill="#2A3C6B">{label}</text>')
            # step badge
            parts.append(f'  <circle cx="{min(x1,x2) + 8}" cy="{y - 9}" r="9" fill="{color}" opacity="0.85"/>')
            parts.append(f'  <text x="{min(x1,x2) + 8}" y="{y - 5}" text-anchor="middle" font-size="9" font-weight="bold" fill="white">{step_i + 1}</text>')

    # ── Right-side annotation box
    ann_x = 790
    ann_y_reg = 94
    ann_w = 155
    ann_h = 100
    parts.append(f'  <rect x="{ann_x}" y="{ann_y_reg}" width="{ann_w}" height="{ann_h}" rx="8" fill="#EEF2FA" stroke="#C0CCE0" stroke-width="1.2"/>')
    parts.append(f'  <text x="{ann_x + 10}" y="{ann_y_reg + 18}" font-size="11" font-weight="bold" fill="#1A3A6B">Agent Card 字段</text>')
    for li, line in enumerate(["agent_id: &lt;uuid&gt;", "skill_name: &lt;str&gt;", "endpoint: &lt;url&gt;", "version: semver"]):
        parts.append(f'  <text x="{ann_x + 10}" y="{ann_y_reg + 36 + li * 16}" font-size="10" fill="#445577" font-family="monospace">{line}</text>')

    ann_y_inv = 302
    ann_h2 = 112
    parts.append(f'  <rect x="{ann_x}" y="{ann_y_inv}" width="{ann_w}" height="{ann_h2}" rx="8" fill="#EEF9F1" stroke="#AADDC0" stroke-width="1.2"/>')
    parts.append(f'  <text x="{ann_x + 10}" y="{ann_y_inv + 18}" font-size="11" font-weight="bold" fill="#1A7A40">关键 Headers</text>')
    for li, line in enumerate(["X-OryxOS-Identity:", "  &lt;JWT&gt;", "X-Devops-Transmitted", "-Auth: &lt;JWT&gt;"]):
        parts.append(f'  <text x="{ann_x + 10}" y="{ann_y_inv + 36 + li * 17}" font-size="10" fill="#2A6644" font-family="monospace">{line}</text>')

    # ── Title banner at very top
    parts.append(f'  <rect x="0" y="0" width="{W}" height="46" fill="#1A3A6B"/>')
    parts.append(f'  <text x="{W//2}" y="29" text-anchor="middle" font-size="16" font-weight="bold" fill="white">OryxOS — Sub Agent 注册 &amp; 调用协议</text>')

    # footer
    parts.append(f'  <text x="{W//2}" y="{H - 6}" text-anchor="middle" font-size="10" fill="#A0AABB">OryxOS Sub Agent Protocol  |  上: 注册流程  |  下: 调用流程</text>')

    parts.append('</svg>')
    return "\n".join(parts)


if __name__ == "__main__":
    svg1 = make_core_features()
    svg2 = make_sub_agent_protocol()

    path1 = os.path.join(OUTPUT_DIR, "oryxos-core-features.svg")
    path2 = os.path.join(OUTPUT_DIR, "oryxos-sub-agent-protocol.svg")

    with open(path1, "w", encoding="utf-8") as f:
        f.write(svg1)
    print(f"Written: {path1}")

    with open(path2, "w", encoding="utf-8") as f:
        f.write(svg2)
    print(f"Written: {path2}")
