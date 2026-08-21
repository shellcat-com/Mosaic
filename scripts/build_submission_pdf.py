#!/usr/bin/env python3
"""Build the Reverie Hacks documentation PDF from its canonical Markdown source."""

from __future__ import annotations

import re
from pathlib import Path
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    HRFlowable,
    Image,
    KeepTogether,
    ListFlowable,
    ListItem,
    PageBreak,
    Paragraph,
    Preformatted,
    SimpleDocTemplate,
    Spacer,
)

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Mosaic-Reverie-Documentation.md"
OUTPUT = ROOT / "output/pdf/Mosaic-Reverie-Documentation.pdf"
HERO = ROOT / "design/marketing/repository/mosaic-repository-hero.png"
FRAUNCES = ROOT / "Mosaic/Resources/Fonts/Fraunces72ptSoft-SemiBold.ttf"

INK = colors.HexColor("#252336")
MUTED = colors.HexColor("#686278")
INDIGO = colors.HexColor("#5948A8")
SAGE = colors.HexColor("#718B76")
GOLD = colors.HexColor("#C4922C")
CANVAS = colors.HexColor("#F7F1E7")
PAPER = colors.HexColor("#FFFDF8")


def inline_markup(text: str) -> str:
    text = escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
    text = re.sub(r"`(.+?)`", r"<font name='Courier'>\1</font>", text)
    text = re.sub(r"\[([^]]+)\]\((https?://[^)]+)\)", r"<a href='\2' color='#5948A8'>\1</a>", text)
    text = re.sub(r"(?<![\"'=])(https?://[^\s<]+)", r"<a href='\1' color='#5948A8'>\1</a>", text)
    return text


def styles():
    base = getSampleStyleSheet()
    return {
        "title": ParagraphStyle(
            "MosaicTitle", parent=base["Title"], fontName="Fraunces", fontSize=30,
            leading=34, textColor=INK, alignment=TA_CENTER, spaceAfter=10,
        ),
        "subtitle": ParagraphStyle(
            "MosaicSubtitle", parent=base["Normal"], fontName="Helvetica-Bold", fontSize=12,
            leading=17, textColor=INDIGO, alignment=TA_CENTER, spaceAfter=16,
        ),
        "h1": ParagraphStyle(
            "MosaicH1", parent=base["Heading1"], fontName="Fraunces", fontSize=22,
            leading=26, textColor=INK, spaceBefore=13, spaceAfter=8, keepWithNext=True,
        ),
        "h2": ParagraphStyle(
            "MosaicH2", parent=base["Heading2"], fontName="Fraunces", fontSize=15,
            leading=19, textColor=INDIGO, spaceBefore=12, spaceAfter=6, keepWithNext=True,
        ),
        "body": ParagraphStyle(
            "MosaicBody", parent=base["BodyText"], fontName="Helvetica", fontSize=9.5,
            leading=14.2, textColor=INK, spaceAfter=7,
        ),
        "bullet": ParagraphStyle(
            "MosaicBullet", parent=base["BodyText"], fontName="Helvetica", fontSize=9.3,
            leading=13.5, textColor=INK, leftIndent=0, firstLineIndent=0, spaceAfter=3,
        ),
        "code": ParagraphStyle(
            "MosaicCode", parent=base["Code"], fontName="Courier", fontSize=7.5,
            leading=10.5, textColor=INK, backColor=colors.HexColor("#EEE8DC"),
            borderColor=colors.HexColor("#DDD2C0"), borderWidth=.5, borderPadding=8,
            spaceBefore=4, spaceAfter=9,
        ),
        "meta": ParagraphStyle(
            "MosaicMeta", parent=base["BodyText"], fontName="Helvetica", fontSize=9,
            leading=13, textColor=MUTED, alignment=TA_CENTER,
        ),
    }


def page_chrome(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(PAPER)
    canvas.rect(0, 0, letter[0], letter[1], fill=1, stroke=0)
    canvas.setFillColor(INDIGO)
    canvas.rect(0, letter[1] - 9, letter[0], 9, fill=1, stroke=0)
    canvas.setStrokeColor(colors.HexColor("#DDD2C0"))
    canvas.line(0.72 * inch, 0.55 * inch, letter[0] - 0.72 * inch, 0.55 * inch)
    canvas.setFont("Helvetica", 7.5)
    canvas.setFillColor(MUTED)
    canvas.drawString(0.72 * inch, 0.35 * inch, "MOSAIC - REVERIE HACKS 2026")
    canvas.drawRightString(letter[0] - 0.72 * inch, 0.35 * inch, str(doc.page))
    canvas.restoreState()


def markdown_story(lines: list[str], style_map: dict[str, ParagraphStyle]):
    story = []
    paragraph_lines: list[str] = []
    bullet_lines: list[str] = []
    code_lines: list[str] = []
    in_code = False
    first_heading = True

    def flush_paragraph():
        nonlocal paragraph_lines
        if paragraph_lines:
            story.append(Paragraph(inline_markup(" ".join(paragraph_lines)), style_map["body"]))
            paragraph_lines = []

    def flush_bullets():
        nonlocal bullet_lines
        if bullet_lines:
            items = [ListItem(Paragraph(inline_markup(line), style_map["bullet"])) for line in bullet_lines]
            story.append(ListFlowable(items, bulletType="bullet", bulletColor=SAGE, leftIndent=17, bulletFontSize=7))
            story.append(Spacer(1, 5))
            bullet_lines = []

    for raw in lines:
        line = raw.rstrip()
        if line.startswith("```"):
            flush_paragraph()
            flush_bullets()
            if in_code:
                story.append(Preformatted("\n".join(code_lines), style_map["code"]))
                code_lines = []
            in_code = not in_code
            continue
        if in_code:
            code_lines.append(line)
            continue
        if not line:
            flush_paragraph()
            flush_bullets()
            continue
        if line.startswith("# "):
            flush_paragraph()
            flush_bullets()
            if first_heading:
                first_heading = False
                continue
            story.extend([PageBreak(), Paragraph(inline_markup(line[2:]), style_map["h1"]), HRFlowable(width="100%", thickness=1.2, color=GOLD, spaceAfter=7)])
            continue
        if line.startswith("## "):
            flush_paragraph()
            flush_bullets()
            story.append(Paragraph(inline_markup(line[3:]), style_map["h1"]))
            continue
        if line.startswith("### "):
            flush_paragraph()
            flush_bullets()
            story.append(Paragraph(inline_markup(line[4:]), style_map["h2"]))
            continue
        if line.startswith("- "):
            flush_paragraph()
            bullet_lines.append(line[2:])
            continue
        if re.match(r"^\d+\. ", line):
            flush_paragraph()
            bullet_lines.append(re.sub(r"^\d+\. ", "", line))
            continue
        paragraph_lines.append(line.rstrip("  "))

    flush_paragraph()
    flush_bullets()
    return story


def main():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    pdfmetrics.registerFont(TTFont("Fraunces", str(FRAUNCES)))
    style_map = styles()
    doc = SimpleDocTemplate(
        str(OUTPUT), pagesize=letter, rightMargin=0.72 * inch, leftMargin=0.72 * inch,
        topMargin=0.67 * inch, bottomMargin=0.72 * inch,
        title="Mosaic - Reverie Hacks 2026 Project Documentation",
        author="Mosaic",
        subject="App Development submission documentation",
    )

    cover = []
    if HERO.exists():
        hero = Image(str(HERO), width=6.85 * inch, height=3.425 * inch)
        cover.extend([Spacer(1, 24), hero, Spacer(1, 22)])
    cover.extend([
        Paragraph("Mosaic", style_map["title"]),
        Paragraph("REVERIE HACKS 2026 - APP DEVELOPMENT", style_map["subtitle"]),
        Paragraph("Small acts. One shared story.", style_map["title"]),
        Spacer(1, 12),
        HRFlowable(width="45%", thickness=2, color=GOLD, spaceAfter=16),
        Paragraph("A consent-first iOS experience that turns privately verified acts of kindness into one equal-weight collaborative ceramic artwork.", style_map["meta"]),
        Spacer(1, 18),
        Paragraph("Swift 6  |  SwiftUI  |  Supabase  |  iOS 18+", style_map["subtitle"]),
        Paragraph("github.com/shellcat-com/Mosaic", style_map["meta"]),
        PageBreak(),
    ])

    lines = SOURCE.read_text(encoding="utf-8").splitlines()[2:]
    story = cover + markdown_story(lines, style_map)
    doc.build(story, onFirstPage=page_chrome, onLaterPages=page_chrome)
    print(OUTPUT)


if __name__ == "__main__":
    main()
