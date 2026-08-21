#!/usr/bin/env python3
"""Build the synthetic, caption-ready Reverie demo cut.

The script intentionally stops before subtitle burning. Caption timing is produced
from this cut's final audio by the bundled Whisper workflow, per the subtitle skill.
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "video"
SOURCE = OUT / "source"
WORK = OUT / "work"
SLIDES = WORK / "slides"
UNCAPTIONED = OUT / "Mosaic-Reverie-Demo-uncaptioned.mp4"

WIDTH, HEIGHT = 1920, 1080
INK = "#17130f"
CREAM = "#f8f1e6"
INDIGO = "#5940f5"
PERSIMMON = "#ff6846"
SAGE = "#88a18d"


SEGMENTS = [
    (
        "01-problem",
        ROOT / "design/marketing/repository/mosaic-repository-hero.png",
        "Kind acts usually disappear into private moments. Mosaic gives a group one shared goal without turning kindness into a leaderboard. Every verified contribution becomes one equal-size ceramic tile, so a quiet check-in counts exactly as much as a larger act.",
    ),
    (
        "02-join",
        ROOT / "design/marketing/app-store/01-together.png",
        "A judge can open the seeded showcase and join in seconds with a guest name and a privacy choice. Supabase anonymous authentication removes the account wall, while challenge membership and row-level security still protect every record. If the network disappears, Mosaic automatically opens a bundled read-only showcase.",
    ),
    (
        "03-mission",
        ROOT / "design/marketing/app-store/02-start-small.png",
        "Each mission is small, specific, and verifiable. A participant can use a reflection, photo, short video, receipt, or organizer confirmation. The app validates media locally, uploads evidence to private storage, and uses short-lived signed URLs instead of exposing a public evidence bucket.",
    ),
    (
        "04-consent",
        ROOT / "design/marketing/app-store/03-private-by-design.png",
        "Consent is not one vague switch. Evidence visibility, inclusion in the community story, attribution, and recap export are separate decisions. Anonymous identity is the default, memories stay sealed until reveal, and organizers can review proof without receiving permission to publish it.",
    ),
    (
        "05-moderate",
        SOURCE / "organizer.png",
        "The organizer sees a private moderation queue built from synthetic submissions. Approval of evidence and approval of a memory remain independent. Every transition is re-authorized in an Edge Function and database function, so a modified client cannot place a tile, reveal early, or read another participant's proof.",
    ),
    (
        "06-collaborate",
        SOURCE / "two-simulator.png",
        "Here are two iPhone Simulators using the same seeded challenge from different viewpoints. One participant follows the shared progress while the other places a prepared tile. Hosted mode refreshes through a private challenge channel that broadcasts only invalidation events—never evidence, identity records, or private memory content.",
    ),
    (
        "07-reveal",
        ROOT / "design/marketing/app-store/05-the-reveal.png",
        "At the synchronized reveal, the sealed artwork resolves into the image the group made together. Only consented memories appear. The Impact Receipt summarizes verified actions, self-attested reflections, approved memories, and revived chains without ranking people. The recap engine exports real portrait H.264 video with AAC audio.",
    ),
    (
        "08-architecture",
        SOURCE / "architecture.png",
        "The iOS client talks to anonymous Auth, narrowly scoped Edge Functions, Postgres with explicit Data API grants and row-level security, private Storage, and Realtime. Required-reason privacy manifests cover the app and widget. Public privacy and terms pages are reachable from Profile, and billing is absent from the Hackathon build.",
    ),
    (
        "09-close",
        SOURCE / "verification.png",
        "Mosaic ships with reproducible XcodeGen configuration, database policy tests, serialized media export tests, detailed architecture documentation, and a public judge path. It is an equal-weight, privacy-first way to make kindness visible—without making people perform for points. The repository, documentation, policies, and demo are ready for Reverie Hacks.",
    ),
]


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Georgia Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Georgia.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
    ]
    for candidate in candidates:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size=size)
    return ImageFont.load_default(size=size)


def cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    ratio = max(size[0] / image.width, size[1] / image.height)
    resized = image.resize((round(image.width * ratio), round(image.height * ratio)), Image.Resampling.LANCZOS)
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def contain_on_canvas(source: Path, destination: Path) -> None:
    image = Image.open(source).convert("RGB")
    if image.width / image.height > 1.35:
        canvas = cover(image, (WIDTH, HEIGHT))
    else:
        background = cover(image, (WIDTH, HEIGHT)).filter(ImageFilter.GaussianBlur(38))
        veil = Image.new("RGB", (WIDTH, HEIGHT), INK)
        canvas = Image.blend(background, veil, 0.70)
        ratio = min(960 / image.height, 830 / image.width)
        foreground = image.resize((round(image.width * ratio), round(image.height * ratio)), Image.Resampling.LANCZOS)
        shadow = Image.new("RGBA", (foreground.width + 70, foreground.height + 70), (0, 0, 0, 0))
        shadow_draw = ImageDraw.Draw(shadow)
        shadow_draw.rounded_rectangle((35, 35, foreground.width + 35, foreground.height + 35), 52, fill=(0, 0, 0, 130))
        shadow = shadow.filter(ImageFilter.GaussianBlur(22))
        x = (WIDTH - foreground.width) // 2
        y = (HEIGHT - foreground.height) // 2
        canvas.paste(shadow, (x - 35, y - 20), shadow)
        canvas.paste(foreground, (x, y))
    canvas.save(destination, quality=95)


def rounded_phone(canvas: Image.Image, image: Image.Image, x: int, y: int, height: int) -> None:
    scale = height / image.height
    phone = image.resize((round(image.width * scale), height), Image.Resampling.LANCZOS).convert("RGBA")
    mask = Image.new("L", phone.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, phone.width, phone.height), 54, fill=255)
    shadow = Image.new("RGBA", (phone.width + 80, phone.height + 80), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((40, 40, phone.width + 40, phone.height + 40), 62, fill=(0, 0, 0, 125))
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    canvas.paste(shadow, (x - 40, y - 20), shadow)
    canvas.paste(phone, (x, y), mask)


def build_two_simulator_slide() -> None:
    left = Image.open(SOURCE / "simulator-a-home.png").convert("RGB")
    right = Image.open(SOURCE / "simulator-b-placement.png").convert("RGB")
    canvas = Image.new("RGB", (WIDTH, HEIGHT), INK)
    draw = ImageDraw.Draw(canvas)
    draw.text((95, 62), "TWO VIEWPOINTS. ONE PRIVATE CHALLENGE.", font=font(30, True), fill=PERSIMMON)
    draw.text((95, 110), "Realtime shares invalidations—not private evidence.", font=font(48, True), fill=CREAM)
    phone_height = 820
    phone_width = round(left.width * phone_height / left.height)
    gap = 120
    total = phone_width * 2 + gap
    start = (WIDTH - total) // 2
    rounded_phone(canvas, left, start, 210, phone_height)
    rounded_phone(canvas, right, start + phone_width + gap, 210, phone_height)
    canvas.save(SOURCE / "two-simulator.png", quality=95)


def draw_box(draw: ImageDraw.ImageDraw, rect: tuple[int, int, int, int], title: str, detail: str, color: str) -> None:
    draw.rounded_rectangle(rect, 28, fill="#fffaf2", outline=color, width=6)
    x1, y1, _, _ = rect
    draw.text((x1 + 28, y1 + 24), title, font=font(32, True), fill=INK)
    draw.multiline_text((x1 + 28, y1 + 72), detail, font=font(23), fill="#655f58", spacing=8)


def build_architecture_slide() -> None:
    canvas = Image.new("RGB", (WIDTH, HEIGHT), CREAM)
    draw = ImageDraw.Draw(canvas)
    draw.text((95, 60), "PRIVACY IS THE ARCHITECTURE", font=font(30, True), fill=INDIGO)
    draw.text((95, 108), "Trust boundaries stay on the server.", font=font(54, True), fill=INK)
    boxes = [
        ((95, 250, 425, 465), "iOS clients", "Anonymous session\nOffline recovery", PERSIMMON),
        ((495, 250, 825, 465), "Edge Functions", "Auth checks\nLifecycle commands", INDIGO),
        ((895, 250, 1225, 465), "Postgres", "Explicit grants\nRLS on every table", SAGE),
        ((1295, 250, 1625, 465), "Private Storage", "Signed URLs\nConsent-aware media", PERSIMMON),
    ]
    for index, item in enumerate(boxes):
        draw_box(draw, *item)
        if index < len(boxes) - 1:
            x = item[0][2] + 25
            draw.line((x, 358, x + 42, 358), fill="#8e877e", width=5)
            draw.polygon(((x + 42, 348), (x + 60, 358), (x + 42, 368)), fill="#8e877e")
    draw_box(draw, (285, 590, 785, 835), "Private Realtime", "challenge:<uuid> invalidations only\nNo owner, evidence, or memory payloads", INDIGO)
    draw_box(draw, (880, 590, 1380, 835), "Privacy + recovery", "App and widget manifests\nPublic policies · cached read-only showcase", SAGE)
    draw.text((95, 965), "MOSAIC · REVERIE HACKS 2026", font=font(25, True), fill="#7b746c")
    canvas.save(SOURCE / "architecture.png", quality=95)


def build_verification_slide() -> None:
    canvas = Image.new("RGB", (WIDTH, HEIGHT), INK)
    draw = ImageDraw.Draw(canvas)
    draw.text((95, 70), "JUDGE-READY, REPRODUCIBLE, OPEN", font=font(30, True), fill=PERSIMMON)
    draw.text((95, 120), "Mosaic", font=font(92, True), fill=CREAM)
    cards = [
        ((95, 310, 575, 675), "58 × 3", "iOS tests\nincluding real H.264/AAC recap exports", INDIGO),
        ((625, 310, 1105, 675), "RLS + pgTAP", "Database policies\nEdge Function integration checks", SAGE),
        ((1155, 310, 1635, 675), "Privacy first", "Target manifests\npublic policy and terms", PERSIMMON),
    ]
    for item in cards:
        draw_box(draw, *item)
    draw.text((95, 790), "github.com/shellcat-com/Mosaic", font=font(42, True), fill=CREAM)
    draw.text((95, 860), "shellcat-com.github.io/Mosaic/privacy/", font=font(31), fill="#cfc7ba")
    draw.text((95, 930), "Documentation PDF and demo attached to the Reverie 2026 release.", font=font(28), fill="#cfc7ba")
    canvas.save(SOURCE / "verification.png", quality=95)


def duration(path: Path) -> float:
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1", str(path)],
        check=True,
        text=True,
        capture_output=True,
    )
    return float(result.stdout.strip())


def main() -> None:
    WORK.mkdir(parents=True, exist_ok=True)
    SLIDES.mkdir(parents=True, exist_ok=True)
    SOURCE.mkdir(parents=True, exist_ok=True)

    build_two_simulator_slide()
    build_architecture_slide()
    build_verification_slide()

    required = [path for _, path, _ in SEGMENTS if not path.exists()]
    if required:
        raise SystemExit("Missing video source files:\n" + "\n".join(f"- {path}" for path in required))

    rate = os.environ.get("MOSAIC_DEMO_SPEECH_RATE", "155")
    segment_files: list[Path] = []
    total = 0.0

    for name, source, narration in SEGMENTS:
        slide = SLIDES / f"{name}.jpg"
        audio = WORK / f"{name}.aiff"
        video = WORK / f"{name}.mp4"
        contain_on_canvas(source, slide)
        run("say", "-v", "Samantha", "-r", rate, "-o", str(audio), narration)
        seconds = duration(audio)
        total += seconds
        fade_out = max(0.0, seconds - 0.35)
        run(
            "ffmpeg", "-y", "-loglevel", "error",
            "-loop", "1", "-framerate", "30", "-i", str(slide), "-i", str(audio),
            "-t", f"{seconds:.3f}",
            "-vf", f"fade=t=in:st=0:d=0.35,fade=t=out:st={fade_out:.3f}:d=0.35,format=yuv420p",
            "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-r", "30",
            "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2", "-shortest", str(video),
        )
        segment_files.append(video)

    concat = WORK / "concat.txt"
    concat.write_text("".join(f"file '{path.as_posix()}'\n" for path in segment_files), encoding="utf-8")
    run("ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(concat), "-c", "copy", str(UNCAPTIONED))

    final_duration = duration(UNCAPTIONED)
    if not 165 <= final_duration < 180:
        raise SystemExit(
            f"Built {final_duration:.1f}s at speech rate {rate}; set MOSAIC_DEMO_SPEECH_RATE and rerun for 165–179s."
        )
    print(f"Built {UNCAPTIONED} ({final_duration:.1f}s, narration {total:.1f}s)")


if __name__ == "__main__":
    main()
