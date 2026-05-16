#!/usr/bin/env python3
"""Generate 4 SVG diagrams for the AI coding tools article."""

import xml.etree.ElementTree as ET
import os

OUT_DIR = os.path.dirname(os.path.abspath(__file__))


def make_svg(width, height, bg="#FAFBFF"):
    root = ET.Element("svg")
    root.set("xmlns", "http://www.w3.org/2000/svg")
    root.set("width", str(width))
    root.set("height", str(height))
    root.set("viewBox", f"0 0 {width} {height}")
    # background rect
    bg_rect = ET.SubElement(root, "rect")
    bg_rect.set("width", str(width))
    bg_rect.set("height", str(height))
    bg_rect.set("fill", bg)
    return root


def add_text(parent, x, y, text, size=12, fill="#333", weight="normal",
             anchor="middle", style="", dy="0"):
    t = ET.SubElement(parent, "text")
    t.set("x", str(x))
    t.set("y", str(y))
    t.set("font-size", str(size))
    t.set("fill", fill)
    t.set("font-weight", weight)
    t.set("text-anchor", anchor)
    t.set("font-family", "PingFang SC, Noto Sans CJK SC, Microsoft YaHei, sans-serif")
    if dy != "0":
        t.set("dy", dy)
    if style:
        t.set("style", style)
    t.text = text
    return t


def add_rect(parent, x, y, w, h, fill="#fff", stroke="#ccc", rx=6, stroke_width=1):
    r = ET.SubElement(parent, "rect")
    r.set("x", str(x))
    r.set("y", str(y))
    r.set("width", str(w))
    r.set("height", str(h))
    r.set("fill", fill)
    r.set("stroke", stroke)
    r.set("rx", str(rx))
    r.set("stroke-width", str(stroke_width))
    return r


def add_line(parent, x1, y1, x2, y2, stroke="#999", width=2, dash=""):
    l = ET.SubElement(parent, "line")
    l.set("x1", str(x1))
    l.set("y1", str(y1))
    l.set("x2", str(x2))
    l.set("y2", str(y2))
    l.set("stroke", stroke)
    l.set("stroke-width", str(width))
    if dash:
        l.set("stroke-dasharray", dash)
    return l


def add_arrow(parent, x1, y1, x2, y2, stroke="#999", width=2, dash="", marker_id="arrow"):
    path = ET.SubElement(parent, "line")
    path.set("x1", str(x1))
    path.set("y1", str(y1))
    path.set("x2", str(x2))
    path.set("y2", str(y2))
    path.set("stroke", stroke)
    path.set("stroke-width", str(width))
    path.set("marker-end", f"url(#{marker_id})")
    if dash:
        path.set("stroke-dasharray", dash)
    return path


def add_marker(defs, marker_id, color="#999"):
    marker = ET.SubElement(defs, "marker")
    marker.set("id", marker_id)
    marker.set("markerWidth", "10")
    marker.set("markerHeight", "7")
    marker.set("refX", "9")
    marker.set("refY", "3.5")
    marker.set("orient", "auto")
    poly = ET.SubElement(marker, "polygon")
    poly.set("points", "0 0, 10 3.5, 0 7")
    poly.set("fill", color)
    return marker


def add_badge(parent, cx, cy, text, fill, text_color="#fff", rx=10, pad_x=10, h=20):
    # measure-ish: assume ~7px per char for Chinese, 6px for ASCII
    estimated_w = max(len(text) * 13 + pad_x * 2, 60)
    r = add_rect(parent, cx - estimated_w // 2, cy - h // 2,
                 estimated_w, h, fill=fill, stroke="none", rx=rx)
    add_text(parent, cx, cy + 5, text, size=11, fill=text_color, anchor="middle")
    return r


# ─────────────────────────────────────────────
# SVG 1: aicoding-cognition-stages.svg
# ─────────────────────────────────────────────
def gen_svg1():
    W, H = 960, 380
    root = make_svg(W, H, "#FAFBFF")
    defs = ET.SubElement(root, "defs")
    add_marker(defs, "arrow-gray", "#999")
    add_marker(defs, "arrow-gray-dash", "#999")

    # Title
    add_text(root, W // 2, 38, "AI 编程的认知三阶段", size=18, fill="#1A3A6B", weight="bold")
    add_text(root, W // 2, 62, "大多数人卡在第二阶段到第三阶段的过渡上", size=12, fill="#666")

    card_w, card_h = 240, 210
    gap = 40
    total_w = 3 * card_w + 2 * gap
    start_x = (W - total_w) // 2
    card_y = 82

    cards = [
        {
            "bg": "#E8F4FD", "border": "#4A90D9", "bar": "#4A90D9",
            "stage": "第一阶段", "title": "把 AI 当写代码工具",
            "title_color": "#1A3A6B",
            "lines": ["让 AI 生成代码、补函数", "改 bug、解释源码", "天花板：1.5x 速度提升"],
            "badge_text": "Copilot 时代", "badge_fill": "#4A90D9",
            "pin": False,
        },
        {
            "bg": "#FEF6E8", "border": "#E09A52", "bar": "#E09A52",
            "stage": "第二阶段", "title": "学习各种奇技淫巧",
            "title_color": "#E09A52",
            "lines": ["prompt 技巧 / agent 模式", "hook 配置 / MCP 集成", "越学越多，越多越乱"],
            "badge_text": "当下最大人群", "badge_fill": "#E09A52",
            "pin": True,
        },
        {
            "bg": "#EDF9EE", "border": "#52B366", "bar": "#52B366",
            "stage": "第三阶段", "title": "意识到这是工作流的事",
            "title_color": "#52B366",
            "lines": ["AI 介入整条工程链路", "从需求到上线全覆盖", "人的角色：设计者"],
            "badge_text": "少数人已达到", "badge_fill": "#52B366",
            "pin": False,
        },
    ]

    for i, c in enumerate(cards):
        x = start_x + i * (card_w + gap)
        # Card background
        add_rect(root, x, card_y, card_w, card_h, fill=c["bg"],
                 stroke=c["border"], rx=8, stroke_width=2)
        # Top color bar
        bar = ET.SubElement(root, "rect")
        bar.set("x", str(x))
        bar.set("y", str(card_y))
        bar.set("width", str(card_w))
        bar.set("height", "12")
        bar.set("fill", c["bar"])
        bar.set("rx", "8")
        # round only top corners trick: draw extra rect below
        bar2 = ET.SubElement(root, "rect")
        bar2.set("x", str(x))
        bar2.set("y", str(card_y + 6))
        bar2.set("width", str(card_w))
        bar2.set("height", "6")
        bar2.set("fill", c["bar"])

        # Stage label
        add_text(root, x + card_w // 2, card_y + 30, c["stage"],
                 size=11, fill="#888", anchor="middle")
        # Main title
        add_text(root, x + card_w // 2, card_y + 52, c["title"],
                 size=14, fill=c["title_color"], weight="bold", anchor="middle")
        # Lines
        for j, line in enumerate(c["lines"]):
            add_text(root, x + card_w // 2, card_y + 80 + j * 22,
                     line, size=11, fill="#555", anchor="middle")
        # Badge
        add_badge(root, x + card_w // 2, card_y + card_h - 22,
                  c["badge_text"], fill=c["badge_fill"])

        # Pin annotation for stage 2
        if c["pin"]:
            # red triangle + text above-right of card
            tx = x + card_w - 10
            ty = card_y - 18
            # draw a small red arrow pointing down-left
            tri = ET.SubElement(root, "polygon")
            tri.set("points", f"{tx},{ty} {tx+8},{ty-14} {tx-8},{ty-14}")
            tri.set("fill", "#E03030")
            add_text(root, tx, ty - 20, "大多数人卡在这里",
                     size=10, fill="#E03030", weight="bold", anchor="middle")

    # Arrows between cards
    arrow_colors = ["#999", "#999"]
    dashes = ["", "6,4"]
    labels = ["认知跃迁", "认知跃迁"]
    for i in range(2):
        ax1 = start_x + (i + 1) * card_w + i * gap
        ax2 = ax1 + gap
        ay = card_y + card_h // 2
        add_arrow(root, ax1, ay, ax2, ay, stroke="#999", width=3,
                  dash=dashes[i], marker_id="arrow-gray")
        add_text(root, (ax1 + ax2) // 2, ay - 12,
                 labels[i], size=11, fill="#999",
                 style="font-style:italic", anchor="middle")

    return root


# ─────────────────────────────────────────────
# SVG 2: aicoding-seven-layers.svg
# ─────────────────────────────────────────────
def gen_svg2():
    W, H = 960, 660
    root = make_svg(W, H, "#F8FAFF")
    defs = ET.SubElement(root, "defs")

    add_text(root, W // 2, 38, "AI 编程工具七层架构", size=18, fill="#1A3A6B", weight="bold")

    layers = [
        # (num, name, sub, bg, border, tag_fill, tags)  — bottom to top, displayed top-to-bottom reversed
        (7, "方法论层", "用工具的思想", "#FFE0E0", "#E05252", "#E05252",
         ["SDD", "Harness Engineering", "Vibe Coding"]),
        (6, "工作流层", "AI 自动化运行", "#FFE8D8", "#E09A52", "#E09A52",
         ["Headless Mode", "GitHub Actions", "CI/CD", "事件触发"]),
        (5, "协议生态层", "连接外部世界", "#FFF0F0", "#E07070", "#E07070",
         ["MCP", "gh CLI", "REST API", "企业内部系统"]),
        (4, "协作机制层", "AI 团队协作", "#F3EEFF", "#8B5CF6", "#8B5CF6",
         ["Subagents", "Worktrees", "Plan Mode"]),
        (3, "配置约束层", "让 AI 遵守规则", "#FFF8E0", "#D4A843", "#D4A843",
         ["CLAUDE.md", "AGENTS.md", "Skills", "Hooks", "Permissions"]),
        (2, "工具层", "每天直接打交道", "#E0F0E8", "#52B366", "#52B366",
         ["Cursor", "Claude Code", "Copilot", "Windsurf", "Aider", "Cline"]),
        (1, "模型层", "AI 的原料", "#DDEEFF", "#4A90D9", "#4A90D9",
         ["Claude", "GPT-4o", "Gemini", "DeepSeek", "Qwen", "Ollama"]),
    ]

    layer_h = 55
    layer_w = 860
    left_x = 50
    top_y = 58

    for idx, (num, name, sub, bg, border, tag_fill, tags) in enumerate(layers):
        y = top_y + idx * (layer_h + 4)
        add_rect(root, left_x, y, layer_w, layer_h, fill=bg, stroke=border, rx=6, stroke_width=2)

        # Number circle
        circ = ET.SubElement(root, "circle")
        circ.set("cx", str(left_x + 28))
        circ.set("cy", str(y + layer_h // 2))
        circ.set("r", "16")
        circ.set("fill", border)
        add_text(root, left_x + 28, y + layer_h // 2 + 5,
                 str(num), size=13, fill="#fff", weight="bold", anchor="middle")

        # Layer name + sub
        add_text(root, left_x + 60, y + layer_h // 2 - 8,
                 f"  {name}", size=13, fill="#222", weight="bold", anchor="start")
        add_text(root, left_x + 60, y + layer_h // 2 + 10,
                 f"  {sub}", size=10, fill="#666", anchor="start")

        # Tags on right side
        tag_x = left_x + 260
        tag_y_center = y + layer_h // 2
        for ti, tag in enumerate(tags):
            tx = tag_x + ti * 120
            if tx + 100 > left_x + layer_w - 20:
                break
            tag_w = max(len(tag) * 11 + 14, 70)
            add_rect(root, tx, tag_y_center - 11, tag_w, 22,
                     fill=tag_fill, stroke="none", rx=11)
            add_text(root, tx + tag_w // 2, tag_y_center + 5,
                     tag, size=11, fill="#fff", anchor="middle")

    # Right-side vertical bracket annotations
    bracket_data = [
        (top_y + 5 * (layer_h + 4), 2, "工具基础", "#4A90D9"),   # layers 1-2 (idx 5,6)
        (top_y + 2 * (layer_h + 4), 3, "工程能力", "#8B5CF6"),   # layers 3-5 (idx 2,3,4)
        (top_y + 0 * (layer_h + 4), 2, "杠杆价值", "#E05252"),   # layers 6-7 (idx 0,1)
    ]
    bx = left_x + layer_w + 14
    for by_start, count, label, color in bracket_data:
        by_end = by_start + count * (layer_h + 4) - 4
        bcy = (by_start + by_end) // 2
        # vertical line
        vl = ET.SubElement(root, "line")
        vl.set("x1", str(bx + 8))
        vl.set("y1", str(by_start))
        vl.set("x2", str(bx + 8))
        vl.set("y2", str(by_end))
        vl.set("stroke", color)
        vl.set("stroke-width", "3")
        # rotated text
        t = ET.SubElement(root, "text")
        t.set("x", str(bx + 22))
        t.set("y", str(bcy + 30))
        t.set("font-size", "12")
        t.set("fill", color)
        t.set("font-weight", "bold")
        t.set("font-family", "PingFang SC, Noto Sans CJK SC, Microsoft YaHei, sans-serif")
        t.set("transform", f"rotate(-90, {bx+22}, {bcy+20})")
        t.set("text-anchor", "middle")
        t.text = label

    return root


# ─────────────────────────────────────────────
# SVG 3: aicoding-three-scenarios.svg
# ─────────────────────────────────────────────
def gen_svg3():
    W, H = 960, 540
    root = make_svg(W, H, "#F8FAFF")

    add_text(root, W // 2, 34, "三个场景下的七层工具协作",
             size=16, fill="#1A3A6B", weight="bold")

    # Row labels (top to bottom = layer 7 down to layer 1)
    rows = [
        ("方法论层", "#E05252"),
        ("工作流层", "#E09A52"),
        ("协议生态层", "#E07070"),
        ("协作机制层", "#8B5CF6"),
        ("配置约束层", "#D4A843"),
        ("工具层", "#52B366"),
        ("模型层", "#4A90D9"),
    ]

    cols = ["写新模块", "大型项目改造", "接入 CI/CD"]

    # heat: 2=core(dark), 1=mid, 0=low
    # [col0, col1, col2] for each row
    heat_data = [
        # method
        [(2, "SDD 先行 / Spec-Kit"), (1, "OpenSpec delta"), (0, "—")],
        # workflow
        [(0, "—"), (0, "—"), (2, "GitHub Actions / 事件触发")],
        # protocol
        [(0, "—"), (1, "MCP 接外部系统"), (2, "gh CLI / MCP")],
        # collaboration
        [(1, "Plan Mode 确认"), (2, "Subagents 并行"), (0, "—")],
        # config
        [(2, "CLAUDE.md / Hooks"), (2, "Permissions / Hooks"), (1, "CLAUDE.md review 标准")],
        # tools
        [(2, "Claude Code"), (1, "Claude Code 执行"), (2, "claude -p Headless")],
        # model
        [(1, "Claude 模型"), (1, "Claude 模型"), (1, "Claude 模型")],
    ]

    left_label_w = 90
    top_label_h = 50
    cell_w = (W - left_label_w - 20) // 3
    cell_h = 60
    grid_top = 54 + top_label_h
    grid_left = left_label_w + 10

    # Col headers
    for ci, col_name in enumerate(cols):
        cx = grid_left + ci * cell_w + cell_w // 2
        add_rect(root, grid_left + ci * cell_w + 2, 52, cell_w - 4, top_label_h - 4,
                 fill="#E8EEF8", stroke="#C0CCE0", rx=6)
        add_text(root, cx, 52 + (top_label_h - 4) // 2 + 6,
                 col_name, size=13, fill="#1A3A6B", weight="bold", anchor="middle")

    for ri, (row_name, row_color) in enumerate(rows):
        ry = grid_top + ri * cell_h
        # Row label
        add_text(root, left_label_w // 2 + 5, ry + cell_h // 2 + 5,
                 row_name, size=10, fill=row_color, weight="bold", anchor="middle")

        for ci in range(3):
            cx = grid_left + ci * cell_w
            heat, content = heat_data[ri][ci]

            if heat == 2:
                bg = row_color
                txt_color = "#fff"
                font_size = 11
                fw = "bold"
            elif heat == 1:
                # 50% blend with white: simple approach - use lighter shade
                # parse hex color and lighten
                r_hex = int(row_color[1:3], 16)
                g_hex = int(row_color[3:5], 16)
                b_hex = int(row_color[5:7], 16)
                r2 = int(r_hex + (255 - r_hex) * 0.55)
                g2 = int(g_hex + (255 - g_hex) * 0.55)
                b2 = int(b_hex + (255 - b_hex) * 0.55)
                bg = f"#{r2:02X}{g2:02X}{b2:02X}"
                txt_color = "#333"
                font_size = 11
                fw = "normal"
            else:
                bg = "#F5F5F5"
                txt_color = "#AAA"
                font_size = 12
                fw = "normal"

            add_rect(root, cx + 2, ry + 2, cell_w - 4, cell_h - 4,
                     fill=bg, stroke="#DDD", rx=4, stroke_width=1)

            # wrap text if long
            if len(content) > 10:
                # split at "/"
                parts = content.split(" / ")
                if len(parts) > 1 and heat > 0:
                    for pi, part in enumerate(parts[:2]):
                        add_text(root, cx + cell_w // 2,
                                 ry + cell_h // 2 - 6 + pi * 16,
                                 part, size=font_size, fill=txt_color,
                                 weight=fw, anchor="middle")
                else:
                    add_text(root, cx + cell_w // 2, ry + cell_h // 2 + 5,
                             content, size=font_size, fill=txt_color,
                             weight=fw, anchor="middle")
            else:
                add_text(root, cx + cell_w // 2, ry + cell_h // 2 + 5,
                         content, size=font_size, fill=txt_color,
                         weight=fw, anchor="middle")

    # Legend
    legend_x = W - 240
    legend_y = H - 28
    add_rect(root, legend_x - 8, legend_y - 16, 230, 24,
             fill="#EEEEFF", stroke="#CCCCEE", rx=6)
    add_rect(root, legend_x, legend_y - 8, 14, 14, fill="#4A90D9", stroke="none", rx=2)
    add_text(root, legend_x + 18, legend_y + 4, "核心层",
             size=11, fill="#333", anchor="start")
    add_rect(root, legend_x + 68, legend_y - 8, 14, 14, fill="#97BFE8", stroke="none", rx=2)
    add_text(root, legend_x + 86, legend_y + 4, "辅助层",
             size=11, fill="#333", anchor="start")
    add_rect(root, legend_x + 138, legend_y - 8, 14, 14, fill="#F5F5F5",
             stroke="#CCC", rx=2)
    add_text(root, legend_x + 156, legend_y + 4, "不涉及",
             size=11, fill="#AAA", anchor="start")

    return root


# ─────────────────────────────────────────────
# SVG 4: aicoding-tool-decision.svg
# ─────────────────────────────────────────────
def gen_svg4():
    W, H = 720, 520
    root = make_svg(W, H, "#FAFBFF")
    defs = ET.SubElement(root, "defs")
    add_marker(defs, "arr-blue", "#4A90D9")
    add_marker(defs, "arr-orange", "#E09A52")
    add_marker(defs, "arr-green", "#52B366")
    add_marker(defs, "arr-gray", "#999")
    add_marker(defs, "arr-red", "#E05252")

    add_text(root, W // 2, 32, "新工具来了，要不要学？",
             size=16, fill="#1A3A6B", weight="bold")
    add_text(root, W // 2, 54, "三个问题，过滤 95% 的工具噪音",
             size=12, fill="#666")

    cx = 300  # main flow center x

    # Start circle
    circ = ET.SubElement(root, "circle")
    circ.set("cx", str(cx))
    circ.set("cy", "88")
    circ.set("r", "28")
    circ.set("fill", "#4A90D9")
    add_text(root, cx, 93, "新工具出现", size=11, fill="#fff", weight="bold")

    # Arrow down to Q1
    add_arrow(root, cx, 116, cx, 148, stroke="#4A90D9", width=2, marker_id="arr-blue")

    def add_diamond(parent, cx, cy, w, h, fill, stroke, label_lines, q_label, q_color):
        hw, hh = w // 2, h // 2
        pts = f"{cx},{cy-hh} {cx+hw},{cy} {cx},{cy+hh} {cx-hw},{cy}"
        poly = ET.SubElement(parent, "polygon")
        poly.set("points", pts)
        poly.set("fill", fill)
        poly.set("stroke", stroke)
        poly.set("stroke-width", "2")
        # Q label circle
        qc = ET.SubElement(parent, "circle")
        qc.set("cx", str(cx - hw - 18))
        qc.set("cy", str(cy))
        qc.set("r", "12")
        qc.set("fill", stroke)
        add_text(parent, cx - hw - 18, cy + 5, q_label, size=10, fill="#fff",
                 weight="bold", anchor="middle")
        for li, line in enumerate(label_lines):
            offset = (li - (len(label_lines) - 1) / 2) * 15
            add_text(parent, cx, cy + offset + 5, line, size=11, fill="#333",
                     anchor="middle")

    # Q1 diamond
    q1_y = 188
    add_diamond(root, cx, q1_y, 230, 70,
                "#EAF3FC", "#4A90D9",
                ["它属于七层架构的哪一层？"],
                "Q1", "#4A90D9")

    # Q1 right -> reject
    add_arrow(root, cx + 115, q1_y, 500, q1_y, stroke="#999", width=2, marker_id="arr-gray")
    add_text(root, (cx + 115 + 500) // 2, q1_y - 8, "说不清楚", size=10, fill="#999")
    add_rect(root, 502, q1_y - 22, 164, 44, fill="#F0F0F0", stroke="#BBBBBB", rx=8)
    add_text(root, 584, q1_y - 4, "很可能是营销噪音", size=10, fill="#888", anchor="middle")
    add_text(root, 584, q1_y + 12, "忽略", size=10, fill="#888", anchor="middle")

    # Q1 down arrow
    add_arrow(root, cx, q1_y + 35, cx, q1_y + 65, stroke="#4A90D9", width=2, marker_id="arr-blue")
    add_text(root, cx + 12, q1_y + 52, "定位清晰", size=10, fill="#4A90D9", anchor="start")

    # Q2 diamond
    q2_y = q1_y + 115
    add_diamond(root, cx, q2_y, 260, 70,
                "#FFF4E8", "#E09A52",
                ["它在这一层比现有工具", "好在哪？"],
                "Q2", "#E09A52")

    # Q2 right -> reject
    add_arrow(root, cx + 130, q2_y, 500, q2_y, stroke="#999", width=2, marker_id="arr-gray")
    add_text(root, (cx + 130 + 500) // 2, q2_y - 8, "说不出具体差异", size=10, fill="#999")
    add_rect(root, 502, q2_y - 28, 164, 56, fill="#F0F0F0", stroke="#BBBBBB", rx=8)
    add_text(root, 584, q2_y - 10, "迭代优化，非结构性", size=10, fill="#888", anchor="middle")
    add_text(root, 584, q2_y + 6, "变化，可选学", size=10, fill="#888", anchor="middle")

    # Q2 down arrow
    add_arrow(root, cx, q2_y + 35, cx, q2_y + 65, stroke="#E09A52", width=2, marker_id="arr-orange")
    add_text(root, cx + 12, q2_y + 52, "有明确差异", size=10, fill="#E09A52", anchor="start")

    # Q3 diamond
    q3_y = q2_y + 115
    add_diamond(root, cx, q3_y, 240, 70,
                "#EDF9EE", "#52B366",
                ["你当下的场景需要它吗？"],
                "Q3", "#52B366")

    # Q3 right -> reject
    add_arrow(root, cx + 120, q3_y, 500, q3_y, stroke="#999", width=2, marker_id="arr-gray")
    add_text(root, (cx + 120 + 500) // 2, q3_y - 8, "暂时不需要", size=10, fill="#999")
    add_rect(root, 502, q3_y - 22, 164, 44, fill="#F0F0F0", stroke="#BBBBBB", rx=8)
    add_text(root, 584, q3_y - 4, "加入观察列表", size=10, fill="#888", anchor="middle")
    add_text(root, 584, q3_y + 12, "继续当前工作", size=10, fill="#888", anchor="middle")

    # Q3 down arrow to final
    add_arrow(root, cx, q3_y + 35, cx, q3_y + 65, stroke="#52B366", width=2, marker_id="arr-green")
    add_text(root, cx + 12, q3_y + 52, "需要", size=10, fill="#52B366", anchor="start")

    # Final node
    final_y = q3_y + 90
    add_rect(root, cx - 100, final_y - 20, 200, 40, fill="#52B366", stroke="none", rx=20)
    add_text(root, cx, final_y + 6, "值得投入学习", size=14, fill="#fff",
             weight="bold", anchor="middle")

    # Structural change callout box — left side
    box_x = 14
    box_y = q1_y + 20
    box_w = 150
    box_h = 100
    add_rect(root, box_x, box_y, box_w, box_h, fill="#FFF0F0", stroke="#E05252", rx=8,
             stroke_width=2)
    # dashed line from box right edge to main flow
    dash_line = ET.SubElement(root, "line")
    dash_line.set("x1", str(box_x + box_w))
    dash_line.set("y1", str(box_y + box_h // 2))
    dash_line.set("x2", str(cx - 115))
    dash_line.set("y2", str(q1_y))
    dash_line.set("stroke", "#E05252")
    dash_line.set("stroke-width", "1.5")
    dash_line.set("stroke-dasharray", "5,3")

    add_text(root, box_x + box_w // 2, box_y + 18,
             "结构性变化？立刻学！", size=10, fill="#E05252", weight="bold", anchor="middle")
    texts = ["改变某一层的基本玩法", "例：MCP 改变协议层", "例：SDD 改变方法论层"]
    for ti, t in enumerate(texts):
        add_text(root, box_x + box_w // 2, box_y + 38 + ti * 20,
                 t, size=9, fill="#555", anchor="middle")

    return root


def save_and_validate(root, filename):
    path = os.path.join(OUT_DIR, filename)
    tree = ET.ElementTree(root)
    ET.indent(tree, space="  ")
    tree.write(path, encoding="utf-8", xml_declaration=True)
    # Validate
    ET.parse(path)
    print(f"OK: {path}")


if __name__ == "__main__":
    save_and_validate(gen_svg1(), "aicoding-cognition-stages.svg")
    save_and_validate(gen_svg2(), "aicoding-seven-layers.svg")
    save_and_validate(gen_svg3(), "aicoding-three-scenarios.svg")
    save_and_validate(gen_svg4(), "aicoding-tool-decision.svg")
    print("All 4 SVGs generated and validated.")
