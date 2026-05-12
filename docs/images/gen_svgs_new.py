#!/usr/bin/env python3
"""Generate two OryxOS SVG diagrams."""

import os

OUTPUT_DIR = "/Users/oker/robustmq-spring-ai-alibaba-admin/docs/images"

# ─────────────────────────────────────────────────────────────────────────────
# SVG 1: oryxos-memory-layers.svg
# ─────────────────────────────────────────────────────────────────────────────

def make_memory_layers_svg():
    W, H = 960, 460
    lines = []

    def a(s): lines.append(s)

    a(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">')
    a(f'  <rect width="{W}" height="{H}" fill="#F8FAFF"/>')

    # Top title
    a('  <text x="480" y="32" text-anchor="middle" font-family="Arial,sans-serif" '
      'font-size="16" font-weight="bold" fill="#2C5F9E">三层记忆体系（oryx-memory crate）</text>')

    # ── Left panel ────────────────────────────────────────────────────────────
    LEFT_X = 20
    LEFT_W = 580
    LAYER_H = 110
    GAP = 10
    LAYER_START_Y = 50

    layer_defs = [
        {
            "title": "Episodic Memory（情节记忆）",
            "title_color": "#2C5F9E",
            "bg": "#E8F4FD",
            "border": "#4A90D9",
            "lines": [
                "技术：redb KV（主键 profile_id + session_id + turn_index）+ tantivy BM25 索引",
                "检索：bm25_score×0.6 + recency_score×0.4，top_k 重排",
            ],
            "icon_type": "cylinders",
        },
        {
            "title": "Long-term Memory（长期记忆）",
            "title_color": "#2A7A3A",
            "bg": "#EDF9EE",
            "border": "#52B366",
            "lines": [
                "技术：MEMORY.md 文件，路径 data/memory/{profile_id}/{agent_id}/MEMORY.md",
                "触发：Session 结束 / 用户说「记住这个」时写入",
                "读取：每次 Session 开始注入 System Prompt 前缀",
            ],
            "icon_type": "doc",
        },
        {
            "title": "Entity Bank（实体库）",
            "title_color": "#5B33A8",
            "bg": "#F3EEFF",
            "border": "#8B5CF6",
            "lines": [
                "技术：redb 表，key = (profile_id, entity_name)，value = 属性 JSON",
                "触发：识别到新实体时写入；Episodic 检索后自动拉取相关实体属性",
            ],
            "icon_type": "kv",
        },
    ]

    for i, ldef in enumerate(layer_defs):
        ly = LAYER_START_Y + i * (LAYER_H + GAP)
        # Background rect
        a(f'  <rect x="{LEFT_X}" y="{ly}" width="{LEFT_W}" height="{LAYER_H}" '
          f'rx="8" fill="{ldef["bg"]}" stroke="{ldef["border"]}" stroke-width="2"/>')

        # Title
        a(f'  <text x="{LEFT_X + 14}" y="{ly + 24}" font-family="Arial,sans-serif" '
          f'font-size="13" font-weight="bold" fill="{ldef["title_color"]}">{ldef["title"]}</text>')

        # Body lines
        for j, ln in enumerate(ldef["lines"]):
            a(f'  <text x="{LEFT_X + 14}" y="{ly + 44 + j*18}" font-family="Arial,sans-serif" '
              f'font-size="11" fill="#333">{ln}</text>')

        # Right icon area inside left panel
        ICON_X = LEFT_X + LEFT_W - 180
        ICON_Y = ly + 20
        ICON_W = 170
        ICON_H = LAYER_H - 30

        if ldef["icon_type"] == "cylinders":
            # redb cylinder
            cx1 = ICON_X + 35
            cy1 = ICON_Y + 15
            a(f'  <ellipse cx="{cx1}" cy="{cy1}" rx="28" ry="8" fill="#9DC8EF" stroke="#4A90D9" stroke-width="1.5"/>')
            a(f'  <rect x="{cx1-28}" y="{cy1}" width="56" height="36" fill="#9DC8EF" stroke="#4A90D9" stroke-width="1.5"/>')
            a(f'  <ellipse cx="{cx1}" cy="{cy1+36}" rx="28" ry="8" fill="#7BB8E8" stroke="#4A90D9" stroke-width="1.5"/>')
            a(f'  <text x="{cx1}" y="{cy1+22}" text-anchor="middle" font-family="Arial,sans-serif" font-size="10" fill="#1A3A5C">redb</text>')
            # tantivy cylinder
            cx2 = ICON_X + 115
            cy2 = ICON_Y + 15
            a(f'  <ellipse cx="{cx2}" cy="{cy2}" rx="28" ry="8" fill="#9DC8EF" stroke="#4A90D9" stroke-width="1.5"/>')
            a(f'  <rect x="{cx2-28}" y="{cy2}" width="56" height="36" fill="#9DC8EF" stroke="#4A90D9" stroke-width="1.5"/>')
            a(f'  <ellipse cx="{cx2}" cy="{cy2+36}" rx="28" ry="8" fill="#7BB8E8" stroke="#4A90D9" stroke-width="1.5"/>')
            a(f'  <text x="{cx2}" y="{cy2+22}" text-anchor="middle" font-family="Arial,sans-serif" font-size="10" fill="#1A3A5C">tantivy</text>')
            # Arrow between cylinders
            a(f'  <line x1="{cx1+28}" y1="{cy1+18}" x2="{cx2-28}" y2="{cy2+18}" stroke="#4A90D9" stroke-width="1.5" marker-end="url(#arrowBlue)"/>')
            # Result label
            a(f'  <rect x="{ICON_X+30}" y="{ICON_Y+60}" width="110" height="22" rx="4" fill="#4A90D9"/>')
            a(f'  <text x="{ICON_X+85}" y="{ICON_Y+75}" text-anchor="middle" font-family="Arial,sans-serif" font-size="10" fill="white">检索结果（top_k）</text>')
            # Arrow down to result
            mid_x = (cx1 + cx2) // 2
            a(f'  <line x1="{mid_x}" y1="{cy1+44}" x2="{ICON_X+85}" y2="{ICON_Y+60}" stroke="#4A90D9" stroke-width="1.5" marker-end="url(#arrowBlue)"/>')

        elif ldef["icon_type"] == "doc":
            # Document icon
            doc_x = ICON_X + 20
            doc_y = ICON_Y + 8
            a(f'  <rect x="{doc_x}" y="{doc_y}" width="52" height="64" rx="3" fill="#C8EAC8" stroke="#52B366" stroke-width="1.5"/>')
            a(f'  <polygon points="{doc_x+38},{doc_y} {doc_x+52},{doc_y+14} {doc_x+38},{doc_y+14}" fill="#52B366"/>')
            a(f'  <line x1="{doc_x+8}" y1="{doc_y+22}" x2="{doc_x+44}" y2="{doc_y+22}" stroke="#52B366" stroke-width="1"/>')
            a(f'  <line x1="{doc_x+8}" y1="{doc_y+32}" x2="{doc_x+44}" y2="{doc_y+32}" stroke="#52B366" stroke-width="1"/>')
            a(f'  <line x1="{doc_x+8}" y1="{doc_y+42}" x2="{doc_x+36}" y2="{doc_y+42}" stroke="#52B366" stroke-width="1"/>')
            a(f'  <text x="{doc_x+26}" y="{doc_y+78}" text-anchor="middle" font-family="Arial,sans-serif" font-size="9" fill="#2A7A3A">MEMORY.md</text>')
            # Arrow
            a(f'  <line x1="{doc_x+52}" y1="{doc_y+32}" x2="{ICON_X+110}" y2="{doc_y+32}" stroke="#52B366" stroke-width="1.5" marker-end="url(#arrowGreen)"/>')
            # System Prompt box
            a(f'  <rect x="{ICON_X+110}" y="{doc_y+18}" width="50" height="28" rx="4" fill="#52B366"/>')
            a(f'  <text x="{ICON_X+135}" y="{doc_y+29}" text-anchor="middle" font-family="Arial,sans-serif" font-size="9" fill="white">System</text>')
            a(f'  <text x="{ICON_X+135}" y="{doc_y+40}" text-anchor="middle" font-family="Arial,sans-serif" font-size="9" fill="white">Prompt</text>')

        elif ldef["icon_type"] == "kv":
            # KV table
            kv_x = ICON_X + 10
            kv_y = ICON_Y + 10
            a(f'  <rect x="{kv_x}" y="{kv_y}" width="150" height="80" rx="4" fill="white" stroke="#8B5CF6" stroke-width="1.5"/>')
            # Header
            a(f'  <rect x="{kv_x}" y="{kv_y}" width="150" height="20" rx="4" fill="#8B5CF6"/>')
            a(f'  <text x="{kv_x+75}" y="{kv_y+14}" text-anchor="middle" font-family="Arial,sans-serif" font-size="10" fill="white">Entity Bank (profile_id, entity_name) → JSON</text>')
            # Row 1
            a(f'  <line x1="{kv_x}" y1="{kv_y+40}" x2="{kv_x+150}" y2="{kv_y+40}" stroke="#D4C4F8" stroke-width="1"/>')
            a(f'  <text x="{kv_x+8}" y="{kv_y+34}" font-family="Arial,sans-serif" font-size="9" fill="#333">(P1, "Alice")</text>')
            a(f'  <text x="{kv_x+90}" y="{kv_y+34}" font-family="Arial,sans-serif" font-size="9" fill="#333">{{role:"dev",...}}</text>')
            # Row 2
            a(f'  <line x1="{kv_x}" y1="{kv_y+60}" x2="{kv_x+150}" y2="{kv_y+60}" stroke="#D4C4F8" stroke-width="1"/>')
            a(f'  <text x="{kv_x+8}" y="{kv_y+54}" font-family="Arial,sans-serif" font-size="9" fill="#333">(P1, "RobustMQ")</text>')
            a(f'  <text x="{kv_x+90}" y="{kv_y+54}" font-family="Arial,sans-serif" font-size="9" fill="#333">{{type:"MQ",...}}</text>')
            # Row 3
            a(f'  <text x="{kv_x+8}" y="{kv_y+74}" font-family="Arial,sans-serif" font-size="9" fill="#999">...</text>')

    # ── Right panel: Profile isolation ────────────────────────────────────────
    RP_X = 620
    RP_Y = 50
    RP_W = 320
    RP_H = 380

    a(f'  <rect x="{RP_X}" y="{RP_Y}" width="{RP_W}" height="{RP_H}" rx="8" fill="white" stroke="#CCCCCC" stroke-width="1.5"/>')
    a(f'  <text x="{RP_X + RP_W//2}" y="{RP_Y + 22}" text-anchor="middle" font-family="Arial,sans-serif" '
      f'font-size="13" font-weight="bold" fill="#CC2222">Profile 级物理隔离</text>')

    def profile_box(px, py, pw, ph, label, color, border):
        a(f'  <rect x="{px}" y="{py}" width="{pw}" height="{ph}" rx="6" fill="{color}" stroke="{border}" stroke-width="2"/>')
        a(f'  <text x="{px + pw//2}" y="{py + 18}" text-anchor="middle" font-family="Arial,sans-serif" '
          f'font-size="12" font-weight="bold" fill="{border}">{label}</text>')
        # inner items
        items = [
            ("Episodic 存储（tantivy Segment）", "#4A90D9"),
            ("Memory 文件目录", "#52B366"),
            ("Entity Bank 分区", "#8B5CF6"),
        ]
        for k, (item_text, item_color) in enumerate(items):
            iy = py + 34 + k * 28
            a(f'  <rect x="{px+10}" y="{iy}" width="{pw-20}" height="22" rx="4" fill="white" stroke="{item_color}" stroke-width="1.2"/>')
            a(f'  <text x="{px + pw//2}" y="{iy+14}" text-anchor="middle" font-family="Arial,sans-serif" font-size="10" fill="{item_color}">{item_text}</text>')

    PA_X = RP_X + 12
    PA_Y = RP_Y + 38
    PB_X = RP_X + 12
    PB_Y = RP_Y + 210
    PW = RP_W - 24
    PH = 155

    profile_box(PA_X, PA_Y, PW, PH, "Profile A", "#EEF5FF", "#4A90D9")
    profile_box(PB_X, PB_Y, PW, PH, "Profile B", "#F5EEFF", "#8B5CF6")

    # Red dashed separator line
    sep_y = (PA_Y + PH + PB_Y) // 2
    a(f'  <line x1="{PA_X+10}" y1="{sep_y}" x2="{PA_X+PW-10}" y2="{sep_y}" '
      f'stroke="#CC2222" stroke-width="1.5" stroke-dasharray="6,4"/>')
    a(f'  <text x="{RP_X + RP_W//2}" y="{sep_y - 4}" text-anchor="middle" font-family="Arial,sans-serif" '
      f'font-size="11" fill="#CC2222">× 不可跨界访问</text>')

    # ── Arrow defs ────────────────────────────────────────────────────────────
    a('''  <defs>
    <marker id="arrowBlue" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">
      <polygon points="0 0, 8 3, 0 6" fill="#4A90D9"/>
    </marker>
    <marker id="arrowGreen" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">
      <polygon points="0 0, 8 3, 0 6" fill="#52B366"/>
    </marker>
    <marker id="arrowBlack" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">
      <polygon points="0 0, 8 3, 0 6" fill="#333333"/>
    </marker>
  </defs>''')

    a('</svg>')
    return "\n".join(lines)


# ─────────────────────────────────────────────────────────────────────────────
# SVG 2: oryxos-control-plane-modules.svg
# ─────────────────────────────────────────────────────────────────────────────

def make_control_plane_svg():
    W, H = 960, 500
    lines = []

    def a(s): lines.append(s)

    a(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">')
    a(f'  <rect width="{W}" height="{H}" fill="#F8FAFF"/>')

    # Defs (arrows)
    a('''  <defs>
    <marker id="arrowBlack" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">
      <polygon points="0 0, 8 3, 0 6" fill="#333333"/>
    </marker>
    <marker id="arrowGray" markerWidth="7" markerHeight="5" refX="7" refY="2.5" orient="auto">
      <polygon points="0 0, 7 2.5, 0 5" fill="#888888"/>
    </marker>
  </defs>''')

    # Top title
    a('  <text x="480" y="30" text-anchor="middle" font-family="Arial,sans-serif" '
      'font-size="16" font-weight="bold" fill="#1A2F5E">Control Plane — 模块结构与数据模型</text>')

    # ── Upper section: Maven modules ──────────────────────────────────────────
    UP_Y = 44
    UP_H = 200
    a(f'  <rect x="10" y="{UP_Y}" width="{W-20}" height="{UP_H}" rx="6" fill="white" stroke="#CCCCCC" stroke-width="1"/>')
    a(f'  <text x="20" y="{UP_Y+18}" font-family="Arial,sans-serif" font-size="11" fill="#666">Maven 模块层次（依赖方向 →）</text>')

    modules = [
        {
            "name": "oryx-control-start",
            "color": "#4A90D9",
            "bg": "#EEF5FF",
            "items": ["SpringBootApplication", "全局异常处理", "安全配置"],
        },
        {
            "name": "oryx-control-api",
            "color": "#52B366",
            "bg": "#EDF9EE",
            "items": ["REST Controller（~30个）", "JWT 过滤器", "@PreAuthorize"],
        },
        {
            "name": "oryx-control-core",
            "color": "#E09A52",
            "bg": "#FDF5EC",
            "items": ["Service 层", "MyBatis-Plus Mapper", "Redisson 分布式锁"],
        },
        {
            "name": "oryx-control-runtime",
            "color": "#888888",
            "bg": "#F4F4F4",
            "items": ["DTO / VO / 枚举", "分页封装", "无业务逻辑"],
        },
    ]

    MOD_W = 180
    MOD_H = 120
    MOD_GAP = (W - 20 - 4 * MOD_W - 40) // 3  # space between modules
    START_X = 30
    MOD_Y = UP_Y + 38
    ARROW_Y = MOD_Y + MOD_H // 2

    for i, mod in enumerate(modules):
        mx = START_X + i * (MOD_W + MOD_GAP)
        a(f'  <rect x="{mx}" y="{MOD_Y}" width="{MOD_W}" height="{MOD_H}" rx="8" '
          f'fill="{mod["bg"]}" stroke="{mod["color"]}" stroke-width="2"/>')
        a(f'  <rect x="{mx}" y="{MOD_Y}" width="{MOD_W}" height="26" rx="8" fill="{mod["color"]}"/>')
        a(f'  <rect x="{mx}" y="{MOD_Y+18}" width="{MOD_W}" height="8" fill="{mod["color"]}"/>')
        a(f'  <text x="{mx + MOD_W//2}" y="{MOD_Y+17}" text-anchor="middle" font-family="Arial,sans-serif" '
          f'font-size="10" font-weight="bold" fill="white">{mod["name"]}</text>')
        for j, item in enumerate(mod["items"]):
            a(f'  <text x="{mx + MOD_W//2}" y="{MOD_Y + 44 + j*22}" text-anchor="middle" '
              f'font-family="Arial,sans-serif" font-size="10" fill="#333">{item}</text>')
        # Arrow to next module
        if i < len(modules) - 1:
            ax1 = mx + MOD_W
            ax2 = mx + MOD_W + MOD_GAP
            a(f'  <line x1="{ax1}" y1="{ARROW_Y}" x2="{ax2}" y2="{ARROW_Y}" stroke="#333" stroke-width="2" marker-end="url(#arrowBlack)"/>')

    # Divider
    DIV_Y = UP_Y + UP_H + 4
    a(f'  <line x1="10" y1="{DIV_Y}" x2="{W-10}" y2="{DIV_Y}" stroke="#BBBBBB" stroke-width="1.5" stroke-dasharray="8,4"/>')

    # ── Lower section: ER diagram ─────────────────────────────────────────────
    ER_Y = DIV_Y + 4
    ER_H = H - ER_Y - 10
    a(f'  <rect x="10" y="{ER_Y}" width="{W-20}" height="{ER_H}" rx="6" fill="white" stroke="#CCCCCC" stroke-width="1"/>')
    a(f'  <text x="20" y="{ER_Y+18}" font-family="Arial,sans-serif" font-size="11" fill="#666">核心数据表（外键关系）</text>')

    # Table positions (cx, cy = center)
    tables = {
        "profile":             {"cx": 400, "cy": ER_Y + 130, "color": "#4A90D9", "bg": "#EEF5FF",
                                "fields": ["id (PK)", "name", "status", "quota_config_id"]},
        "profile_member":      {"cx": 650, "cy": ER_Y + 70,  "color": "#52B366", "bg": "#EDF9EE",
                                "fields": ["id (PK)", "profile_id (FK)", "enterprise_user_id", "role"]},
        "agent_config":        {"cx": 650, "cy": ER_Y + 200, "color": "#E09A52", "bg": "#FDF5EC",
                                "fields": ["id (PK)", "profile_id (FK)", "name", "system_prompt"]},
        "sub_agent_registry":  {"cx": 140, "cy": ER_Y + 130, "color": "#8B5CF6", "bg": "#F3EEFF",
                                "fields": ["id (PK)", "profile_id (FK)", "name", "base_url"]},
        "quota_config":        {"cx": 400, "cy": ER_Y + 52,  "color": "#D9534F", "bg": "#FFF0F0",
                                "fields": ["id (PK)", "profile_id (FK)", "max_llm_calls", "max_tokens"]},
        "audit_event":         {"cx": 820, "cy": ER_Y + 140, "color": "#555555", "bg": "#F4F4F4",
                                "fields": ["id (PK)", "profile_id (FK)", "agent_id (FK)", "event_type", "content_hash"]},
        "hot_config":          {"cx": 650, "cy": ER_Y + 330, "color": "#0097A7", "bg": "#E0F7FA",
                                "fields": ["id (PK)", "profile_id (FK)", "agent_id (FK)", "config_key", "version"]},
    }

    TBL_W = 158
    TBL_ROW_H = 17

    def draw_table(key, t):
        cx, cy = t["cx"], t["cy"]
        n_rows = len(t["fields"])
        header_h = 22
        body_h = n_rows * TBL_ROW_H
        total_h = header_h + body_h
        x = cx - TBL_W // 2
        y = cy - total_h // 2
        # Body
        a(f'  <rect x="{x}" y="{y}" width="{TBL_W}" height="{total_h}" rx="5" fill="{t["bg"]}" stroke="{t["color"]}" stroke-width="1.8"/>')
        # Header
        a(f'  <rect x="{x}" y="{y}" width="{TBL_W}" height="{header_h}" rx="5" fill="{t["color"]}"/>')
        a(f'  <rect x="{x}" y="{y + header_h - 4}" width="{TBL_W}" height="4" fill="{t["color"]}"/>')
        a(f'  <text x="{cx}" y="{y+15}" text-anchor="middle" font-family="Arial,sans-serif" '
          f'font-size="10" font-weight="bold" fill="white">{key}</text>')
        for k, fld in enumerate(t["fields"]):
            fy = y + header_h + k * TBL_ROW_H
            if k % 2 == 1:
                a(f'  <rect x="{x+1}" y="{fy}" width="{TBL_W-2}" height="{TBL_ROW_H}" fill="rgba(0,0,0,0.04)"/>')
            a(f'  <text x="{x+8}" y="{fy+12}" font-family="Arial,sans-serif" font-size="9" fill="#333">{fld}</text>')
        # Return bounding info
        return x, y, total_h

    bounds = {}
    for key, t in tables.items():
        x, y, total_h = draw_table(key, t)
        bounds[key] = {"cx": t["cx"], "cy": t["cy"], "x": x, "y": y,
                       "x2": x + TBL_W, "y2": y + total_h, "total_h": total_h}

    def edge_point(key, direction):
        b = bounds[key]
        if direction == "left":   return b["x"],  b["cy"]
        if direction == "right":  return b["x2"], b["cy"]
        if direction == "top":    return b["cx"],  b["y"]
        if direction == "bottom": return b["cx"],  b["y2"]

    def draw_rel(src_key, src_dir, dst_key, dst_dir, label, color="#555555"):
        x1, y1 = edge_point(src_key, src_dir)
        x2, y2 = edge_point(dst_key, dst_dir)
        # Simple polyline: horizontal then vertical
        mid_x = (x1 + x2) // 2
        mid_y = (y1 + y2) // 2
        a(f'  <line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="1.2" stroke-dasharray="5,3"/>')
        a(f'  <text x="{mid_x}" y="{mid_y - 4}" text-anchor="middle" font-family="Arial,sans-serif" font-size="9" fill="{color}">{label}</text>')

    # Relationships
    draw_rel("profile", "right", "profile_member", "left", "1:N", "#4A90D9")
    draw_rel("profile", "right", "agent_config", "left", "1:N", "#E09A52")
    draw_rel("profile", "left", "sub_agent_registry", "right", "1:N", "#8B5CF6")
    draw_rel("profile", "top", "quota_config", "bottom", "1:1", "#D9534F")
    draw_rel("agent_config", "right", "audit_event", "left", "1:N", "#555555")
    draw_rel("agent_config", "bottom", "hot_config", "top", "1:N", "#0097A7")

    a('</svg>')
    return "\n".join(lines)


# ─────────────────────────────────────────────────────────────────────────────
# Write files
# ─────────────────────────────────────────────────────────────────────────────

def main():
    svg1 = make_memory_layers_svg()
    path1 = os.path.join(OUTPUT_DIR, "oryxos-memory-layers.svg")
    with open(path1, "w", encoding="utf-8") as f:
        f.write(svg1)
    print(f"Written: {path1}  ({len(svg1)} bytes)")

    svg2 = make_control_plane_svg()
    path2 = os.path.join(OUTPUT_DIR, "oryxos-control-plane-modules.svg")
    with open(path2, "w", encoding="utf-8") as f:
        f.write(svg2)
    print(f"Written: {path2}  ({len(svg2)} bytes)")


if __name__ == "__main__":
    main()
