#!/usr/bin/env python3
"""Generate SVG diagrams: oryxos-runtime-modules.svg and oryxos-circuit-breaker.svg"""

import os
import math

OUTPUT_DIR = "/Users/oker/robustmq-spring-ai-alibaba-admin/docs/images"


# ─────────────────────────────────────────────────────────────────────────────
# SVG 1 – oryxos-runtime-modules.svg
# ─────────────────────────────────────────────────────────────────────────────

def make_runtime_modules():
    W, H = 960, 480

    # ── Layout constants ──────────────────────────────────────────────────────
    BOX_W, BOX_H = 120, 50
    # Column centre-x positions
    COL_X = {
        "left":   110,   # entry layer
        "mid":    430,   # core layer
        "right":  750,   # base layer
    }
    # Left column: single box, vertically centred
    LEFT_Y = 215  # top-y of the gateway box (centre ~240)

    # Mid column: 4 boxes, gap 20px between them, centred in canvas
    MID_GAP = 20
    mid_total_h = 4 * BOX_H + 3 * MID_GAP   # 4*50 + 3*20 = 260
    MID_START_Y = (H - mid_total_h) // 2 + 10   # ~(480-260)/2 = 110, +10 = 120

    # Right column: 3 boxes
    RIGHT_GAP = 28
    right_total_h = 3 * BOX_H + 2 * RIGHT_GAP  # 3*50 + 2*28 = 206
    RIGHT_START_Y = (H - right_total_h) // 2 + 10   # ~147

    # Box data
    left_boxes = [
        {
            "id": "gateway",
            "label": "oryx-gateway",
            "note": "入口 crate / axum HTTP",
            "note2": "Channel Adapter 启动",
            "color": "#4A90D9",
            "x": COL_X["left"] - BOX_W // 2,
            "y": LEFT_Y,
        }
    ]

    mid_boxes = [
        {
            "id": "router",
            "label": "oryx-router",
            "note": "LLM 路由 / 熔断器",
            "color": "#E09A52",
        },
        {
            "id": "session",
            "label": "oryx-session",
            "note": "JSONL 会话 / Fork / Compact",
            "color": "#52B366",
        },
        {
            "id": "skill",
            "label": "oryx-skill",
            "note": "Skill 执行 / Sub Agent 客户端",
            "color": "#8B5CF6",
        },
        {
            "id": "memory",
            "label": "oryx-memory",
            "note": "三层记忆 / redb + tantivy",
            "color": "#3AAFA9",
        },
    ]
    for i, b in enumerate(mid_boxes):
        b["x"] = COL_X["mid"] - BOX_W // 2
        b["y"] = MID_START_Y + i * (BOX_H + MID_GAP)

    right_boxes = [
        {
            "id": "policy",
            "label": "oryx-policy",
            "note": "Tool Policy / 内存查询 <5ms",
            "color": "#5A7FA8",
        },
        {
            "id": "audit",
            "label": "oryx-audit",
            "note": "mpsc channel / 批量上报",
            "color": "#E05252",
        },
        {
            "id": "quota",
            "label": "oryx-quota",
            "note": "DashMap / 配额执行",
            "color": "#C4A535",
        },
    ]
    for i, b in enumerate(right_boxes):
        b["x"] = COL_X["right"] - BOX_W // 2
        b["y"] = RIGHT_START_Y + i * (BOX_H + RIGHT_GAP)

    # Helper: box centre
    def cx(b): return b["x"] + BOX_W // 2
    def cy(b): return b["y"] + BOX_H // 2

    parts = []
    parts.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
                 f'viewBox="0 0 {W} {H}" '
                 f'font-family="\'PingFang SC\',\'Microsoft YaHei\',Arial,sans-serif">')

    # ── defs ──────────────────────────────────────────────────────────────────
    parts.append("""  <defs>
    <!-- solid blue arrow for gateway→mid (thick) -->
    <marker id="arrBlue" markerWidth="9" markerHeight="9" refX="8" refY="4.5" orient="auto">
      <path d="M0,0 L9,4.5 L0,9 Z" fill="#4A90D9"/>
    </marker>
    <!-- solid blue arrow for gateway→right (thinner) -->
    <marker id="arrBlueS" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">
      <path d="M0,0 L8,4 L0,8 Z" fill="#4A90D9"/>
    </marker>
    <!-- orange dashed arrow: router→quota -->
    <marker id="arrOrange" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">
      <path d="M0,0 L8,4 L0,8 Z" fill="#E09A52"/>
    </marker>
    <!-- purple dashed arrow: skill→policy / skill→audit -->
    <marker id="arrPurple" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">
      <path d="M0,0 L8,4 L0,8 Z" fill="#8B5CF6"/>
    </marker>
    <filter id="shadow" x="-8%" y="-8%" width="116%" height="120%">
      <feDropShadow dx="0" dy="2" stdDeviation="3" flood-color="#00000018"/>
    </filter>
  </defs>""")

    # ── Background ────────────────────────────────────────────────────────────
    parts.append(f'  <rect width="{W}" height="{H}" fill="#F8FAFF"/>')

    # Light column bands
    # Left band
    parts.append(f'  <rect x="30" y="50" width="160" height="{H - 60}" rx="10" fill="#EEF3FF" opacity="0.5"/>')
    # Mid band
    parts.append(f'  <rect x="350" y="50" width="160" height="{H - 60}" rx="10" fill="#FFF8EE" opacity="0.5"/>')
    # Right band
    parts.append(f'  <rect x="670" y="50" width="160" height="{H - 60}" rx="10" fill="#EEF8F7" opacity="0.5"/>')

    # Column labels
    label_y = 64
    parts.append(f'  <text x="{COL_X["left"]}" y="{label_y}" text-anchor="middle" '
                 f'font-size="11" fill="#7A8AAA" font-style="italic">入口层</text>')
    parts.append(f'  <text x="{COL_X["mid"]}" y="{label_y}" text-anchor="middle" '
                 f'font-size="11" fill="#7A8AAA" font-style="italic">核心层</text>')
    parts.append(f'  <text x="{COL_X["right"]}" y="{label_y}" text-anchor="middle" '
                 f'font-size="11" fill="#7A8AAA" font-style="italic">基础层</text>')

    # ── Title ─────────────────────────────────────────────────────────────────
    parts.append(f'  <text x="{W // 2}" y="30" text-anchor="middle" font-size="16" '
                 f'font-weight="bold" fill="#4A90D9">Agent Runtime — Crate 模块结构</text>')

    # ── Helper to draw a crate box ────────────────────────────────────────────
    def draw_box(b):
        x, y, color = b["x"], b["y"], b["color"]
        note = b["note"]
        note2 = b.get("note2", "")
        label = b["label"]
        lines = []
        # shadow rect
        lines.append(f'  <rect x="{x+2}" y="{y+2}" width="{BOX_W}" height="{BOX_H}" '
                     f'rx="6" fill="#00000012"/>')
        # main rect
        lines.append(f'  <rect x="{x}" y="{y}" width="{BOX_W}" height="{BOX_H}" '
                     f'rx="6" fill="white" stroke="{color}" stroke-width="2"/>')
        # label
        lines.append(f'  <text x="{x + BOX_W // 2}" y="{y + 19}" text-anchor="middle" '
                     f'font-size="12" font-weight="bold" fill="{color}">{label}</text>')
        # note line 1
        lines.append(f'  <text x="{x + BOX_W // 2}" y="{y + 32}" text-anchor="middle" '
                     f'font-size="9.5" fill="#888">{note}</text>')
        if note2:
            lines.append(f'  <text x="{x + BOX_W // 2}" y="{y + 44}" text-anchor="middle" '
                         f'font-size="9.5" fill="#888">{note2}</text>')
        return "\n".join(lines)

    # ── Draw boxes ────────────────────────────────────────────────────────────
    gw = left_boxes[0]
    parts.append(draw_box(gw))
    for b in mid_boxes:
        parts.append(draw_box(b))
    for b in right_boxes:
        parts.append(draw_box(b))

    # ── Arrow helpers ─────────────────────────────────────────────────────────
    def arrow_hline(x1, y1, x2, y2, color, marker, width=1.8, dash=""):
        """Straight horizontal-ish arrow."""
        dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
        return (f'  <line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" '
                f'stroke="{color}" stroke-width="{width}"{dash_attr} '
                f'marker-end="url(#{marker})"/>')

    def arrow_bent(x1, y1, x2, y2, color, marker, width=1.5, dash="", bend_dx=40):
        """Polyline with a horizontal-then-vertical bend (elbow arrow)."""
        dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
        mid_x = x1 + bend_dx
        pts = f"{x1:.1f},{y1:.1f} {mid_x:.1f},{y1:.1f} {mid_x:.1f},{y2:.1f} {x2:.1f},{y2:.1f}"
        return (f'  <polyline points="{pts}" '
                f'fill="none" stroke="{color}" stroke-width="{width}"{dash_attr} '
                f'marker-end="url(#{marker})"/>')

    # ── Arrows: gateway → mid boxes (blue solid, thick) ──────────────────────
    gw_right_x = gw["x"] + BOX_W      # right edge of gateway
    for mb in mid_boxes:
        # from gateway right edge → mid box left edge, with bend
        src_x = gw_right_x
        src_y = cy(gw)
        dst_x = mb["x"]
        dst_y = cy(mb)
        # use a bent polyline: go right to midpoint column, then down/up to target
        mid_elbow_x = (src_x + dst_x) // 2
        pts = (f"{src_x},{src_y:.1f} {mid_elbow_x},{src_y:.1f} "
               f"{mid_elbow_x},{dst_y:.1f} {dst_x},{dst_y:.1f}")
        parts.append(f'  <polyline points="{pts}" fill="none" stroke="#4A90D9" '
                     f'stroke-width="2" marker-end="url(#arrBlue)"/>')

    # ── Arrows: gateway → right boxes (blue solid, thinner) ──────────────────
    for rb in right_boxes:
        src_x = gw_right_x
        src_y = cy(gw)
        dst_x = rb["x"]
        dst_y = cy(rb)
        mid_elbow_x = src_x + 70
        pts = (f"{src_x},{src_y:.1f} {mid_elbow_x},{src_y:.1f} "
               f"{mid_elbow_x},{dst_y:.1f} {dst_x},{dst_y:.1f}")
        parts.append(f'  <polyline points="{pts}" fill="none" stroke="#4A90D9" '
                     f'stroke-width="1.2" stroke-dasharray="" '
                     f'marker-end="url(#arrBlueS)"/>')

    # ── Arrow: oryx-router → oryx-quota (orange dashed) ──────────────────────
    router = mid_boxes[0]   # oryx-router
    quota = right_boxes[2]  # oryx-quota
    src_x = router["x"] + BOX_W
    src_y = cy(router)
    dst_x = quota["x"]
    dst_y = cy(quota)
    mid_elbow_x = src_x + 30
    pts = (f"{src_x},{src_y:.1f} {mid_elbow_x},{src_y:.1f} "
           f"{mid_elbow_x},{dst_y:.1f} {dst_x},{dst_y:.1f}")
    parts.append(f'  <polyline points="{pts}" fill="none" stroke="#E09A52" '
                 f'stroke-width="1.5" stroke-dasharray="5,3" '
                 f'marker-end="url(#arrOrange)"/>')

    # ── Arrow: oryx-skill → oryx-policy (purple dashed) ──────────────────────
    skill = mid_boxes[2]    # oryx-skill
    policy = right_boxes[0] # oryx-policy
    src_x = skill["x"] + BOX_W
    src_y = cy(skill)
    dst_x = policy["x"]
    dst_y = cy(policy)
    mid_elbow_x = src_x + 25
    pts = (f"{src_x},{src_y:.1f} {mid_elbow_x},{src_y:.1f} "
           f"{mid_elbow_x},{dst_y:.1f} {dst_x},{dst_y:.1f}")
    parts.append(f'  <polyline points="{pts}" fill="none" stroke="#8B5CF6" '
                 f'stroke-width="1.5" stroke-dasharray="5,3" '
                 f'marker-end="url(#arrPurple)"/>')

    # ── Arrow: oryx-skill → oryx-audit (purple dashed) ───────────────────────
    audit = right_boxes[1]  # oryx-audit
    src_x = skill["x"] + BOX_W
    src_y = cy(skill)
    dst_x = audit["x"]
    dst_y = cy(audit)
    mid_elbow_x = src_x + 48
    pts = (f"{src_x},{src_y:.1f} {mid_elbow_x},{src_y:.1f} "
           f"{mid_elbow_x},{dst_y:.1f} {dst_x},{dst_y:.1f}")
    parts.append(f'  <polyline points="{pts}" fill="none" stroke="#8B5CF6" '
                 f'stroke-width="1.5" stroke-dasharray="5,3" '
                 f'marker-end="url(#arrPurple)"/>')

    # ── Legend ────────────────────────────────────────────────────────────────
    legend_x = W - 200
    legend_y = H - 88
    parts.append(f'  <rect x="{legend_x}" y="{legend_y}" width="185" height="78" '
                 f'rx="6" fill="white" stroke="#D0D8EE" stroke-width="1"/>')
    parts.append(f'  <text x="{legend_x + 8}" y="{legend_y + 16}" font-size="10" '
                 f'font-weight="bold" fill="#445">图例</text>')
    # solid blue line
    parts.append(f'  <line x1="{legend_x + 8}" y1="{legend_y + 30}" '
                 f'x2="{legend_x + 38}" y2="{legend_y + 30}" '
                 f'stroke="#4A90D9" stroke-width="2" marker-end="url(#arrBlue)"/>')
    parts.append(f'  <text x="{legend_x + 44}" y="{legend_y + 34}" font-size="9.5" fill="#555">'
                 f'依赖（实线）</text>')
    # dashed orange
    parts.append(f'  <line x1="{legend_x + 8}" y1="{legend_y + 50}" '
                 f'x2="{legend_x + 38}" y2="{legend_y + 50}" '
                 f'stroke="#E09A52" stroke-width="1.5" stroke-dasharray="5,3" '
                 f'marker-end="url(#arrOrange)"/>')
    parts.append(f'  <text x="{legend_x + 44}" y="{legend_y + 54}" font-size="9.5" fill="#555">'
                 f'调用关系（虚线）</text>')
    # dashed purple
    parts.append(f'  <line x1="{legend_x + 8}" y1="{legend_y + 68}" '
                 f'x2="{legend_x + 38}" y2="{legend_y + 68}" '
                 f'stroke="#8B5CF6" stroke-width="1.5" stroke-dasharray="5,3" '
                 f'marker-end="url(#arrPurple)"/>')
    parts.append(f'  <text x="{legend_x + 44}" y="{legend_y + 72}" font-size="9.5" fill="#555">'
                 f'策略/审计调用（虚线）</text>')

    parts.append('</svg>')
    return "\n".join(parts)


# ─────────────────────────────────────────────────────────────────────────────
# SVG 2 – oryxos-circuit-breaker.svg
# ─────────────────────────────────────────────────────────────────────────────

def make_circuit_breaker():
    W, H = 720, 400

    # Three state nodes horizontally centred
    NODE_R = 60
    NODE_Y = 190   # centre-y of nodes
    # x centres
    nodes = [
        {"id": "closed",   "label": "Closed",   "color": "#52B366", "cx": 145},
        {"id": "open",     "label": "Open",     "color": "#E05252", "cx": 360},
        {"id": "halfopen", "label": "HalfOpen", "color": "#E09A52", "cx": 575},
    ]

    parts = []
    parts.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
                 f'viewBox="0 0 {W} {H}" '
                 f'font-family="\'PingFang SC\',\'Microsoft YaHei\',Arial,sans-serif">')

    parts.append("""  <defs>
    <marker id="arrRed" markerWidth="9" markerHeight="9" refX="8" refY="4.5" orient="auto">
      <path d="M0,0 L9,4.5 L0,9 Z" fill="#E05252"/>
    </marker>
    <marker id="arrOrange" markerWidth="9" markerHeight="9" refX="8" refY="4.5" orient="auto">
      <path d="M0,0 L9,4.5 L0,9 Z" fill="#E09A52"/>
    </marker>
    <marker id="arrGreen" markerWidth="9" markerHeight="9" refX="8" refY="4.5" orient="auto">
      <path d="M0,0 L9,4.5 L0,9 Z" fill="#52B366"/>
    </marker>
    <filter id="nodeShadow" x="-15%" y="-15%" width="130%" height="130%">
      <feDropShadow dx="0" dy="3" stdDeviation="4" flood-color="#00000020"/>
    </filter>
  </defs>""")

    # Background
    parts.append(f'  <rect width="{W}" height="{H}" fill="#FAFBFF"/>')

    # Title
    parts.append(f'  <text x="{W // 2}" y="34" text-anchor="middle" font-size="14" '
                 f'font-weight="bold" fill="#333">熔断器状态机（每个 LLM Provider 独立维护）</text>')

    # ── State node circles ────────────────────────────────────────────────────
    for n in nodes:
        ncx, ncy, color = n["cx"], NODE_Y, n["color"]
        # shadow
        parts.append(f'  <circle cx="{ncx}" cy="{ncy}" r="{NODE_R + 2}" '
                     f'fill="#00000018" filter="url(#nodeShadow)"/>')
        # fill circle
        parts.append(f'  <circle cx="{ncx}" cy="{ncy}" r="{NODE_R}" '
                     f'fill="{color}" opacity="0.15"/>')
        # border
        parts.append(f'  <circle cx="{ncx}" cy="{ncy}" r="{NODE_R}" '
                     f'fill="none" stroke="{color}" stroke-width="3"/>')
        # label
        parts.append(f'  <text x="{ncx}" y="{ncy + 6}" text-anchor="middle" '
                     f'font-size="15" font-weight="bold" fill="{color}">{n["label"]}</text>')

    # ── Description boxes below nodes ─────────────────────────────────────────
    desc_box_w = 168
    desc_box_h = 44
    desc_y = NODE_Y + NODE_R + 16

    desc_data = [
        {"cx": nodes[0]["cx"], "color": nodes[0]["color"], "bg": "#E8F9EE",
         "lines": ["health_bitmap 对应位 = 1", "请求正常通过"]},
        {"cx": nodes[1]["cx"], "color": nodes[1]["color"], "bg": "#FDEAEA",
         "lines": ["health_bitmap 对应位 = 0", "新请求直接跳过此 Provider"]},
        {"cx": nodes[2]["cx"], "color": nodes[2]["color"], "bg": "#FEF4E6",
         "lines": ["发送 GET /v1/models 探测", "结果决定下一步"]},
    ]

    for d in desc_data:
        bx = d["cx"] - desc_box_w // 2
        by = desc_y
        parts.append(f'  <rect x="{bx}" y="{by}" width="{desc_box_w}" height="{desc_box_h}" '
                     f'rx="6" fill="{d["bg"]}" stroke="{d["color"]}" stroke-width="1.2" opacity="0.9"/>')
        for li, line in enumerate(d["lines"]):
            parts.append(f'  <text x="{d["cx"]}" y="{by + 16 + li * 16}" '
                         f'text-anchor="middle" font-size="10" fill="#444">{line}</text>')

    # ── Transition arrows ──────────────────────────────────────────────────────
    # Helper: arc from node edge to node edge, above or below the line
    def arc_arrow(src_cx, dst_cx, node_y, node_r, label, color, marker_id,
                  arc_above=True, label_dy=-8):
        """Curved arc between two state circles."""
        # compute angle for edge points
        dx = dst_cx - src_cx
        dist = abs(dx)
        # start/end on the circle edge, slightly above or below midline
        offset_y = -18 if arc_above else 18
        x1 = src_cx + node_r * (1 if dx > 0 else -1) * 0.95
        y1 = node_y + offset_y
        x2 = dst_cx + node_r * (-1 if dx > 0 else 1) * 0.95
        y2 = node_y + offset_y

        mid_x = (x1 + x2) / 2
        bend = -55 if arc_above else 55
        ctrl_y = node_y + offset_y + bend

        path = (f'M{x1:.1f},{y1:.1f} '
                f'Q{mid_x:.1f},{ctrl_y:.1f} '
                f'{x2:.1f},{y2:.1f}')
        line_part = (f'  <path d="{path}" fill="none" stroke="{color}" '
                     f'stroke-width="2" marker-end="url(#{marker_id})"/>')

        # label near the midpoint of the arc
        label_x = mid_x
        label_y = ctrl_y + (14 if not arc_above else -14) + label_dy
        label_part = (f'  <text x="{label_x:.1f}" y="{label_y:.1f}" '
                      f'text-anchor="middle" font-size="11" fill="{color}">{label}</text>')
        return line_part + "\n" + label_part

    # Closed → Open: above
    parts.append(arc_arrow(
        nodes[0]["cx"], nodes[1]["cx"], NODE_Y, NODE_R,
        "连续 3 次调用失败",
        "#E05252", "arrRed",
        arc_above=True, label_dy=-4
    ))

    # Open → HalfOpen: above
    parts.append(arc_arrow(
        nodes[1]["cx"], nodes[2]["cx"], NODE_Y, NODE_R,
        "等待 30s 后",
        "#E09A52", "arrOrange",
        arc_above=True, label_dy=-4
    ))

    # HalfOpen → Closed: below
    parts.append(arc_arrow(
        nodes[2]["cx"], nodes[0]["cx"], NODE_Y, NODE_R,
        "探测成功 ✓",
        "#52B366", "arrGreen",
        arc_above=False, label_dy=10
    ))

    # HalfOpen → Open: tight arc (return arrow, same direction, small curve)
    # Draw as a short arc below the Open→HalfOpen arc, going backward
    # We draw it above but reversed: from halfopen back to open
    # Use a separate curve slightly offset
    ho_cx = nodes[2]["cx"]
    op_cx = nodes[1]["cx"]
    x1 = ho_cx - NODE_R * 0.95
    y1 = NODE_Y - 22
    x2 = op_cx + NODE_R * 0.95
    y2 = NODE_Y - 22
    mid_x = (x1 + x2) / 2
    ctrl_y = NODE_Y - 22 - 30  # same side but tighter
    path = f'M{x1:.1f},{y1:.1f} Q{mid_x:.1f},{ctrl_y:.1f} {x2:.1f},{y2:.1f}'
    parts.append(f'  <path d="{path}" fill="none" stroke="#E05252" '
                 f'stroke-width="2" stroke-dasharray="5,3" marker-end="url(#arrRed)"/>')
    parts.append(f'  <text x="{mid_x:.1f}" y="{ctrl_y - 6:.1f}" '
                 f'text-anchor="middle" font-size="11" fill="#E05252">探测失败 ✗</text>')

    # ── Footer note ────────────────────────────────────────────────────────────
    parts.append(f'  <text x="16" y="{H - 12}" font-size="11" fill="#999">'
                 f'Arc&lt;Mutex&lt;CircuitBreakerState&gt;&gt;，多并发请求共享</text>')

    parts.append('</svg>')
    return "\n".join(parts)


if __name__ == "__main__":
    svg1 = make_runtime_modules()
    svg2 = make_circuit_breaker()

    path1 = os.path.join(OUTPUT_DIR, "oryxos-runtime-modules.svg")
    path2 = os.path.join(OUTPUT_DIR, "oryxos-circuit-breaker.svg")

    with open(path1, "w", encoding="utf-8") as f:
        f.write(svg1)
    print(f"Written: {path1}")

    with open(path2, "w", encoding="utf-8") as f:
        f.write(svg2)
    print(f"Written: {path2}")
