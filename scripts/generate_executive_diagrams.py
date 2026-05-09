from __future__ import annotations

import io
import math
import tempfile
import textwrap
import urllib.error
import urllib.request
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw, ImageFont

REPO_ROOT = Path(__file__).resolve().parents[1]
DOCS_DIR = REPO_ROOT / "docs"
ICON_CACHE_DIR = Path(tempfile.gettempdir()) / "fabric-iq-diagram-icons"

ICON_URLS = {
    # Fabric workload icons
    "fabric": "https://raw.githubusercontent.com/FabricTools/fabric-icons/main/node_modules/@fabric-msft/svg-icons/dist/svg/fabric_48_color.svg",
    "one_lake": "https://raw.githubusercontent.com/FabricTools/fabric-icons/main/node_modules/@fabric-msft/svg-icons/dist/svg/one_lake_48_color.svg",
    "data_factory": "https://raw.githubusercontent.com/FabricTools/fabric-icons/main/node_modules/@fabric-msft/svg-icons/dist/svg/data_factory_48_color.svg",
    "graph_intelligence": "https://raw.githubusercontent.com/FabricTools/fabric-icons/main/node_modules/@fabric-msft/svg-icons/dist/svg/graph_intelligence_48_color.svg",
    "power_bi": "https://raw.githubusercontent.com/FabricTools/fabric-icons/main/node_modules/@fabric-msft/svg-icons/dist/svg/power_bi_48_color.svg",
    "copilot": "https://raw.githubusercontent.com/FabricTools/fabric-icons/main/node_modules/@fabric-msft/svg-icons/dist/svg/copilot_48_color.svg",
    "databases": "https://raw.githubusercontent.com/FabricTools/fabric-icons/main/node_modules/@fabric-msft/svg-icons/dist/svg/databases_48_color.svg",
    "data_warehouse": "https://raw.githubusercontent.com/FabricTools/fabric-icons/main/node_modules/@fabric-msft/svg-icons/dist/svg/data_warehouse_48_color.svg",
    # Azure architecture icons
    "storage_accounts": "https://raw.githubusercontent.com/benc-uk/icon-collection/master/azure-icons/Storage-Accounts.svg",
    "storage_files": "https://raw.githubusercontent.com/benc-uk/icon-collection/master/azure-icons/Storage-Azure-Files.svg",
    "blob": "https://raw.githubusercontent.com/benc-uk/icon-collection/master/azure-icons/Blob-Block.svg",
    "cosmos": "https://raw.githubusercontent.com/benc-uk/icon-collection/master/azure-icons/Azure-Cosmos-DB.svg",
    "cognitive_services": "https://raw.githubusercontent.com/benc-uk/icon-collection/master/azure-icons/Cognitive-Services.svg",
    "app_services": "https://raw.githubusercontent.com/benc-uk/icon-collection/master/azure-icons/App-Services.svg",
    "monitor": "https://raw.githubusercontent.com/benc-uk/icon-collection/master/azure-icons/Monitor.svg",
    "log_analytics": "https://raw.githubusercontent.com/benc-uk/icon-collection/master/azure-icons/Log-Analytics-Workspaces.svg",
    "alerts": "https://raw.githubusercontent.com/benc-uk/icon-collection/master/azure-icons/Alerts.svg",
    "logic_apps": "https://raw.githubusercontent.com/benc-uk/icon-collection/master/azure-icons/Logic-Apps.svg",
}


def get_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = []
    if bold:
        candidates = [
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
            "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf",
        ]
    else:
        candidates = [
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf",
        ]
    for c in candidates:
        p = Path(c)
        if p.exists():
            return ImageFont.truetype(str(p), size=size)
    return ImageFont.load_default()


def ensure_icons() -> None:
    ICON_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    for name, url in ICON_URLS.items():
        target = ICON_CACHE_DIR / f"{name}.svg"
        if target.exists():
            continue
        try:
            with urllib.request.urlopen(url, timeout=30) as response:
                target.write_bytes(response.read())
        except (urllib.error.URLError, TimeoutError) as exc:
            raise RuntimeError(f"Failed to download icon '{name}' from {url}") from exc


def render_icon(name: str, size: int = 52) -> Image.Image:
    svg_path = ICON_CACHE_DIR / f"{name}.svg"
    png_data = cairosvg.svg2png(url=str(svg_path), output_width=size, output_height=size)
    return Image.open(io.BytesIO(png_data)).convert("RGBA")


def measure_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    font: ImageFont.FreeTypeFont | ImageFont.ImageFont,
) -> tuple[int, int]:
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


def rounded_box(draw: ImageDraw.ImageDraw, xy: tuple[int, int, int, int], fill: str, outline: str, width: int = 2, radius: int = 22) -> None:
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def draw_arrow(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int], color: str = "#4B5563", width: int = 4) -> None:
    sx, sy = start
    ex, ey = end
    draw.line([sx, sy, ex, ey], fill=color, width=width)
    angle = math.atan2(ey - sy, ex - sx)
    head_len = 14
    a1 = angle + math.pi * 0.85
    a2 = angle - math.pi * 0.85
    p1 = (ex + head_len * math.cos(a1), ey + head_len * math.sin(a1))
    p2 = (ex + head_len * math.cos(a2), ey + head_len * math.sin(a2))
    draw.polygon([(ex, ey), p1, p2], fill=color)


def draw_card(
    canvas: Image.Image,
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    w: int,
    h: int,
    title: str,
    subtitle: str,
    icon: str,
    fill: str = "#FFFFFF",
    border: str = "#CBD5E1",
) -> None:
    rounded_box(draw, (x, y, x + w, y + h), fill=fill, outline=border, width=2, radius=20)
    icon_img = render_icon(icon, size=52)
    canvas.alpha_composite(icon_img, (x + 20, y + 18))

    title_font = get_font(28, bold=True)
    subtitle_font = get_font(20)
    draw.text((x + 88, y + 24), title, font=title_font, fill="#0F172A")

    wrapped = textwrap.fill(subtitle, width=42)
    draw.multiline_text((x + 88, y + 64), wrapped, font=subtitle_font, fill="#334155", spacing=4)


def add_title_band(draw: ImageDraw.ImageDraw, width: int, title: str, subtitle: str) -> None:
    draw.rectangle((0, 0, width, 126), fill="#0A2342")
    draw.text((36, 30), title, font=get_font(42, bold=True), fill="#FFFFFF")
    draw.text((36, 82), subtitle, font=get_font(22), fill="#DCE7F7")


def generate_architecture_diagram() -> None:
    img = Image.new("RGBA", (2200, 1400), "#F8FAFC")
    draw = ImageDraw.Draw(img)
    add_title_band(
        draw,
        2200,
        "Microsoft Fabric IQ – Executive Architecture",
        "Enterprise knowledge graph demo with Microsoft service icons and production-ready flow",
    )

    cards = [
        (100, 190, "Enterprise Sources", "OneDrive, OneNote, Email, Org Data", "storage_files", "#F0F9FF"),
        (640, 190, "Landing Zone", "Azure Blob + Azure Files storage accounts", "storage_accounts", "#EFF6FF"),
        (1180, 190, "Fabric Ingestion", "Fabric Data Factory pipelines and transformation", "data_factory", "#F5F3FF"),
        (1720, 190, "AI Understanding", "Azure AI Document Intelligence extraction", "cognitive_services", "#FFF7ED"),
        (100, 460, "Operational Persistence", "Cosmos DB parsed documents and confidence payloads", "cosmos", "#FEF2F2"),
        (640, 460, "OneLake Curated Zone", "Standardized semantic-ready data products", "one_lake", "#ECFDF5"),
        (1180, 460, "Fabric Semantic + Ontology", "Graph intelligence and governed ontology layer", "graph_intelligence", "#F0FDFA"),
        (1720, 460, "Experience Layer", "Fabric Data Agent, Copilot and Ionic executive UI", "copilot", "#F5F3FF"),
    ]

    for x, y, title, sub, icon, fill in cards:
        draw_card(img, draw, x, y, 380, 200, title, sub, icon, fill=fill)

    line_y1 = 290
    for x1, x2 in [(480, 640), (1020, 1180), (1560, 1720)]:
        draw_arrow(draw, (x1, line_y1), (x2, line_y1))

    line_y2 = 560
    for x1, x2 in [(480, 640), (1020, 1180), (1560, 1720)]:
        draw_arrow(draw, (x1, line_y2), (x2, line_y2))

    for x in [290, 830, 1370, 1910]:
        draw_arrow(draw, (x, 390), (x, 460))

    rounded_box(draw, (100, 770, 2100, 1270), fill="#FFFBEB", outline="#F59E0B", width=3, radius=26)
    draw.text((130, 810), "Azure Monitor & Incident Operations", font=get_font(34, bold=True), fill="#92400E")

    sre_cards = [
        (130, 870, "Azure Monitor", "Infrastructure + app telemetry", "monitor"),
        (620, 870, "Log Analytics", "Centralized diagnostics and KQL", "log_analytics"),
        (1110, 870, "Alerting", "Metric + query thresholds", "alerts"),
        (1600, 870, "Logic Apps Response", "Automated incident enrichment", "logic_apps"),
    ]
    for x, y, title, sub, icon in sre_cards:
        draw_card(img, draw, x, y, 430, 300, title, sub, icon, fill="#FFF7ED", border="#FDBA74")

    for x1, x2 in [(560, 620), (1050, 1110), (1540, 1600)]:
        draw_arrow(draw, (x1, 1020), (x2, 1020), color="#B45309")

    draw.text(
        (130, 1210),
        "Outcome: trusted, governed and citation-ready employee knowledge for executive decision support.",
        font=get_font(22),
        fill="#78350F",
    )

    img.convert("RGB").save(DOCS_DIR / "architecture-diagram.png", format="PNG", optimize=True)


def generate_pipeline_diagram() -> None:
    img = Image.new("RGBA", (2200, 1200), "#F8FAFC")
    draw = ImageDraw.Draw(img)
    add_title_band(
        draw,
        2200,
        "Microsoft Fabric Data Pipeline – Employee Knowledge",
        "Operational ingestion, enrichment, storage and analytics refresh sequence",
    )

    steps = [
        (120, 210, "1. Source Files", "PPTX/PDF/DOCX/TXT/ONE/EML and project metadata", "blob", "#EFF6FF"),
        (560, 210, "2. Ingest", "Fabric pipeline lands files in raw OneLake zone", "data_factory", "#F5F3FF"),
        (1000, 210, "3. Parse + Classify", "Azure AI extracts entities and confidence", "cognitive_services", "#FFF7ED"),
        (1440, 210, "4. Persist", "Cosmos DB stores parsed JSON records", "cosmos", "#FEF2F2"),
        (120, 560, "5. Curate", "OneLake curated layer aligns ontology keys", "one_lake", "#ECFDF5"),
        (560, 560, "6. Model", "Semantic model and DAX-ready dimensions", "power_bi", "#FEFCE8"),
        (1000, 560, "7. Ontology", "Fabric graph intelligence relationship map", "graph_intelligence", "#F0FDFA"),
        (1440, 560, "8. Agent + UI", "Copilot/Fabric Agent surfaces grounded answers", "copilot", "#F5F3FF"),
    ]

    for x, y, title, sub, icon, fill in steps:
        draw_card(img, draw, x, y, 380, 240, title, sub, icon, fill=fill)

    for x1, x2 in [(500, 560), (940, 1000), (1380, 1440)]:
        draw_arrow(draw, (x1, 330), (x2, 330))
        draw_arrow(draw, (x1, 680), (x2, 680))

    draw_arrow(draw, (1630, 450), (1630, 560))
    draw_arrow(draw, (310, 560), (310, 450))

    rounded_box(draw, (120, 900, 2080, 1120), fill="#FFFFFF", outline="#CBD5E1", width=2, radius=22)
    draw.text(
        (160, 940),
        "Controls: schema standardization • confidence thresholds • data quality checks • governed semantic refresh",
        font=get_font(24, bold=True),
        fill="#1E293B",
    )
    draw.text(
        (160, 995),
        "Executive benefit: fast onboarding, discoverable expertise, explainable lineage, and consistent KPI analytics.",
        font=get_font(22),
        fill="#475569",
    )

    img.convert("RGB").save(DOCS_DIR / "data-pipeline-diagram.png", format="PNG", optimize=True)


def generate_semantic_erd() -> None:
    img = Image.new("RGBA", (2200, 1200), "#F8FAFC")
    draw = ImageDraw.Draw(img)
    add_title_band(
        draw,
        2200,
        "Semantic Model ERD – Employee Knowledge",
        "Business entities, relationships and analytics grain for Microsoft Fabric",
    )

    def draw_erd_entity(x: int, y: int, title: str, fields: list[str], icon: str, fill: str) -> tuple[int, int, int, int]:
        h = 90 + 42 * len(fields)
        rounded_box(draw, (x, y, x + 430, y + h), fill=fill, outline="#94A3B8", width=2, radius=18)
        icon_img = render_icon(icon, size=46)
        img.alpha_composite(icon_img, (x + 16, y + 18))
        draw.text((x + 76, y + 20), title, font=get_font(28, bold=True), fill="#0F172A")
        draw.line((x + 16, y + 74, x + 414, y + 74), fill="#CBD5E1", width=2)
        ty = y + 88
        for f in fields:
            draw.text((x + 24, ty), f, font=get_font(20), fill="#334155")
            ty += 38
        return (x, y, x + 430, y + h)

    emp = draw_erd_entity(120, 220, "dim_employee", ["PK employee_id", "name", "department_id", "manager_id", "title"], "fabric", "#EFF6FF")
    dept = draw_erd_entity(690, 220, "dim_department", ["PK department_id", "department_name", "cost_center"], "data_warehouse", "#F5F3FF")
    skill = draw_erd_entity(1260, 220, "dim_skill", ["PK skill_id", "skill_name", "skill_domain"], "graph_intelligence", "#F0FDFA")
    proj = draw_erd_entity(120, 620, "dim_project", ["PK project_id", "project_name", "status", "start_date"], "power_bi", "#FEFCE8")
    doc = draw_erd_entity(690, 620, "fact_document", ["PK doc_id", "FK employee_id", "doc_type", "confidence_score", "ingested_at"], "databases", "#FEF2F2")
    rel = draw_erd_entity(1260, 620, "bridge_employee_skill_project", ["FK employee_id", "FK skill_id", "FK project_id", "role", "evidence_doc_id"], "one_lake", "#ECFDF5")

    def connector_point(box: tuple[int, int, int, int], side: str) -> tuple[int, int]:
        x1, y1, x2, y2 = box
        if side == "r":
            return (x2, (y1 + y2) // 2)
        if side == "l":
            return (x1, (y1 + y2) // 2)
        if side == "b":
            return ((x1 + x2) // 2, y2)
        return ((x1 + x2) // 2, y1)

    draw_arrow(draw, connector_point(emp, "r"), connector_point(dept, "l"), color="#475569")
    draw_arrow(draw, connector_point(emp, "r"), connector_point(skill, "l"), color="#475569")
    draw_arrow(draw, connector_point(emp, "b"), connector_point(proj, "t"), color="#475569")
    draw_arrow(draw, connector_point(emp, "b"), connector_point(doc, "t"), color="#475569")
    draw_arrow(draw, connector_point(skill, "b"), connector_point(rel, "t"), color="#475569")
    draw_arrow(draw, connector_point(proj, "r"), connector_point(rel, "l"), color="#475569")
    draw_arrow(draw, connector_point(doc, "r"), connector_point(rel, "l"), color="#475569")

    draw.text((120, 1080), "Model intent: enable governed employee expertise analytics and ontology-backed agent retrieval.", font=get_font(22), fill="#334155")

    img.convert("RGB").save(DOCS_DIR / "semantic-model-erd.png", format="PNG", optimize=True)


def generate_ontology_diagram() -> None:
    img = Image.new("RGBA", (2200, 1300), "#F8FAFC")
    draw = ImageDraw.Draw(img)
    add_title_band(
        draw,
        2200,
        "Fabric IQ Ontology Visualization",
        "Executive graph view of people, knowledge assets, capabilities and project contribution",
    )

    def draw_ontology_node(x: int, y: int, title: str, icon: str, fill: str) -> tuple[int, int]:
        rounded_box(draw, (x - 150, y - 70, x + 150, y + 70), fill=fill, outline="#94A3B8", width=2, radius=24)
        icon_img = render_icon(icon, size=42)
        img.alpha_composite(icon_img, (x - 130, y - 22))
        w, h = measure_text(draw, title, get_font(26, bold=True))
        draw.text((x - (w // 2) + 18, y - (h // 2)), title, font=get_font(26, bold=True), fill="#0F172A")
        return (x, y)

    p_employee = draw_ontology_node(520, 340, "Employee", "fabric", "#EFF6FF")
    p_manager = draw_ontology_node(520, 620, "Manager", "fabric", "#EFF6FF")
    p_department = draw_ontology_node(900, 340, "Department", "data_warehouse", "#F5F3FF")
    p_skill = draw_ontology_node(1280, 220, "Skill", "graph_intelligence", "#F0FDFA")
    p_project = draw_ontology_node(1280, 460, "Project", "power_bi", "#FEFCE8")
    p_document = draw_ontology_node(900, 620, "Document", "databases", "#FEF2F2")
    p_onelake = draw_ontology_node(1660, 340, "OntologyGraph", "one_lake", "#ECFDF5")

    def draw_labeled_edge(a: tuple[int, int], b: tuple[int, int], label: str, color: str = "#475569") -> None:
        draw_arrow(draw, a, b, color=color, width=4)
        mx, my = (a[0] + b[0]) // 2, (a[1] + b[1]) // 2
        rounded_box(draw, (mx - 110, my - 24, mx + 110, my + 24), fill="#FFFFFF", outline="#CBD5E1", width=1, radius=14)
        tw, th = measure_text(draw, label, get_font(18, bold=True))
        draw.text((mx - tw // 2, my - th // 2), label, font=get_font(18, bold=True), fill="#1E293B")

    draw_labeled_edge((p_employee[0], p_employee[1] + 72), (p_manager[0], p_manager[1] - 72), "REPORTS_TO")
    draw_labeled_edge((p_employee[0] + 152, p_employee[1]), (p_department[0] - 152, p_department[1]), "BELONGS_TO")
    draw_labeled_edge((p_employee[0] + 120, p_employee[1] - 50), (p_skill[0] - 140, p_skill[1] + 50), "HAS")
    draw_labeled_edge((p_employee[0] + 130, p_employee[1] + 46), (p_project[0] - 140, p_project[1] - 46), "CONTRIBUTES_TO")
    draw_labeled_edge((p_employee[0] + 155, p_employee[1] + 70), (p_document[0] - 155, p_document[1] - 70), "OWNS")

    for src in [p_employee, p_manager, p_department, p_skill, p_project, p_document]:
        draw_arrow(draw, (src[0] + 155, src[1]), (p_onelake[0] - 155, p_onelake[1]), color="#0F766E", width=3)

    rounded_box(draw, (120, 880, 2080, 1220), fill="#FFFFFF", outline="#CBD5E1", width=2, radius=22)
    draw.text((160, 930), "Business outcomes", font=get_font(30, bold=True), fill="#0F172A")
    outcomes = [
        "• Faster discovery of internal expertise and project contributors",
        "• Relationship-aware responses in Fabric Data Agent with citations",
        "• Governed ontology-backed navigation from employee to evidence documents",
    ]
    y = 980
    for o in outcomes:
        draw.text((170, y), o, font=get_font(24), fill="#334155")
        y += 74

    img.convert("RGB").save(DOCS_DIR / "ontology-diagram.png", format="PNG", optimize=True)


def main() -> None:
    ensure_icons()
    generate_architecture_diagram()
    generate_pipeline_diagram()
    generate_semantic_erd()
    generate_ontology_diagram()
    print("Updated diagrams:")
    for name in [
        "architecture-diagram.png",
        "data-pipeline-diagram.png",
        "semantic-model-erd.png",
        "ontology-diagram.png",
    ]:
        p = DOCS_DIR / name
        print(f" - {p} ({p.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
