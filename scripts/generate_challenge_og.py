
import json
import re
import html
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


# ==========================================
# PATHS
# ==========================================

ROOT = Path(__file__).resolve().parent.parent

SOURCE_JSON = ROOT / "assets" / "challenges.json"

PUBLIC = ROOT / "public"
TEMPLATE = PUBLIC / "challenge.html"

HTML_DIR = PUBLIC / "challenge"
IMAGE_DIR = PUBLIC / "og"

BASE_URL = "https://la-pharos.web.app"

HTML_DIR.mkdir(parents=True, exist_ok=True)
IMAGE_DIR.mkdir(parents=True, exist_ok=True)


# ==========================================
# DESIGN
# ==========================================

WIDTH = 1200
HEIGHT = 630

BG = "#153D30"
WHITE = "#FFFFFF"
LIME = "#D8F29B"
MUTED = "#D3E0D5"
DIVIDER = "#456659"

LEFT = 75
RIGHT = 1125
CONTENT_WIDTH = RIGHT - LEFT


# ==========================================
# FONT
# ==========================================

FONT_CANDIDATES = [
    "/System/Library/Fonts/AppleSDGothicNeo.ttc",
    "/System/Library/Fonts/Supplemental/AppleGothic.ttf",
    "/Library/Fonts/AppleSDGothicNeo.ttc",
]


def font_path():
    for candidate in FONT_CANDIDATES:
        if Path(candidate).exists():
            return candidate

    raise RuntimeError(
        "한글 폰트를 찾을 수 없습니다. "
        "FONT_CANDIDATES에 설치된 한글 폰트를 추가하세요."
    )


FONT_PATH = font_path()


def get_font(size):
    return ImageFont.truetype(FONT_PATH, size)


# ==========================================
# TEXT HELPERS
# ==========================================

def text_width(draw, text, font):
    box = draw.textbbox(
        (0, 0),
        str(text),
        font=font,
    )

    return box[2] - box[0]


def text_height(draw, text, font):
    box = draw.textbbox(
        (0, 0),
        str(text),
        font=font,
    )

    return box[3] - box[1]


def wrap_text(draw, text, font, max_width):
    lines = []
    current = ""

    for word in str(text).split():
        test = f"{current} {word}".strip()

        if text_width(draw, test, font) <= max_width:
            current = test
            continue

        if current:
            lines.append(current)
            current = ""

        # 긴 단어는 글자 단위로 줄바꿈
        for char in word:
            test = current + char

            if text_width(draw, test, font) <= max_width:
                current = test
            else:
                if current:
                    lines.append(current)

                current = char

    if current:
        lines.append(current)

    return lines or [""]


def fit_lines(
    draw,
    text,
    max_width,
    max_lines,
    start_size,
    min_size=24,
):
    for size in range(start_size, min_size - 1, -2):
        font = get_font(size)

        lines = wrap_text(
            draw,
            text,
            font,
            max_width,
        )

        if (
            len(lines) <= max_lines
            and all(
                text_width(draw, line, font) <= max_width
                for line in lines
            )
        ):
            return font, lines

    # 최소 크기까지 줄였는데도 길다면 말줄임표
    font = get_font(min_size)

    lines = wrap_text(
        draw,
        text,
        font,
        max_width,
    )

    if len(lines) > max_lines:
        lines = lines[:max_lines]

        last = lines[-1]

        while (
            last
            and text_width(
                draw,
                last + "…",
                font,
            ) > max_width
        ):
            last = last[:-1]

        lines[-1] = last.rstrip() + "…"

    return font, lines


# ==========================================
# DRAW HELPERS
# ==========================================

def draw_check_icon(draw, x, y, size=36):
    """
    목표 텍스트 왼쪽의 원형 체크 아이콘
    """

    draw.ellipse(
        (
            x,
            y,
            x + size,
            y + size,
        ),
        outline=LIME,
        width=3,
    )

    draw.line(
        [
            (x + size * 0.27, y + size * 0.52),
            (x + size * 0.44, y + size * 0.70),
            (x + size * 0.76, y + size * 0.31),
        ],
        fill=LIME,
        width=4,
        joint="curve",
    )


# ==========================================
# OG IMAGE GENERATOR
# ==========================================

def generate_image(challenge):
    challenge_id = challenge["id"]

    title = (
        challenge.get("title")
        or "독서 챌린지"
    )

    description = (
        challenge.get("shortDescription")
        or ""
    )

    goal = (
        challenge.get("goalDisplayText")
        or challenge.get("goalDescription")
        or ""
    )

    image = Image.new(
        "RGB",
        (WIDTH, HEIGHT),
        BG,
    )

    draw = ImageDraw.Draw(image)

    # ======================================
    # TOP LABEL
    # ======================================

    draw.text(
        (LEFT, 65),
        "LABRARY  /  READING CHALLENGE",
        font=get_font(26),
        fill=LIME,
    )

    # 우측 상단 체크 아이콘 제거
    # 상단은 심플하게 브랜드 라벨만 유지

    # ======================================
    # CHALLENGE TITLE
    # ======================================

    title_font, title_lines = fit_lines(
        draw,
        title,
        max_width=CONTENT_WIDTH,
        max_lines=3,
        start_size=78,
        min_size=42,
    )

    title_line_height = title_font.size + 15

    # 제목과 설명을 하나의 콘텐츠 블록으로 구성
    title_y = 177

    # 제목이 3줄이라면 설명과 겹치지 않도록
    # 제목 폰트를 조금 더 축소
    if len(title_lines) >= 3:
        title_font, title_lines = fit_lines(
            draw,
            title,
            max_width=CONTENT_WIDTH,
            max_lines=3,
            start_size=53,
            min_size=36,
        )

        title_line_height = title_font.size + 9
        title_y = 147

    for line in title_lines:
        draw.text(
            (LEFT, title_y),
            line,
            font=title_font,
            fill=WHITE,
        )

        title_y += title_line_height

    # ======================================
    # DESCRIPTION
    # ======================================

    description_font, description_lines = fit_lines(
        draw,
        description,
        max_width=CONTENT_WIDTH,
        max_lines=2,
        start_size=30,
        min_size=23,
    )

    # 목표 영역 시작 전까지만 설명 표시
    description_y = max(
        title_y + 25,
        365,
    )

    description_line_height = (
        description_font.size + 13
    )

    # 설명이 목표 영역을 침범하지 않도록 조정
    description_y = min(
        description_y,
        425 - description_line_height * (
            len(description_lines) - 1
        ),
    )

    for line in description_lines:
        draw.text(
            (LEFT + 2, description_y),
            line,
            font=description_font,
            fill=MUTED,
        )

        description_y += description_line_height

    # ======================================
    # GOAL SECTION
    # ======================================

    # 목표 영역 구분선
    goal_divider_y = 480

    draw.line(
        [
            (LEFT, goal_divider_y),
            (RIGHT, goal_divider_y),
        ],
        fill=DIVIDER,
        width=2,
    )

    if goal.strip():
        goal_y = 501

        # 왼쪽 원형 체크 아이콘
        draw_check_icon(
            draw,
            x=LEFT + 2,
            y=goal_y,
            size=36,
        )

        # 목표 텍스트
        goal_font, goal_lines = fit_lines(
            draw,
            goal,
            max_width=CONTENT_WIDTH - 58,
            max_lines=1,
            start_size=29,
            min_size=23,
        )

        goal_text = (
            goal_lines[0]
            if goal_lines
            else ""
        )

        draw.text(
            (LEFT + 56, goal_y + 1),
            goal_text,
            font=goal_font,
            fill=WHITE,
        )

    # ======================================
    # FOOTER
    # ======================================

    footer_divider_y = 557

    draw.line(
        [
            (LEFT, footer_divider_y),
            (RIGHT, footer_divider_y),
        ],
        fill=DIVIDER,
        width=2,
    )

    draw.text(
        (LEFT, 578),
        "Read. Challenge. Grow.",
        font=get_font(23),
        fill=LIME,
    )

    brand = "Labrary."
    brand_font = get_font(29)

    brand_width = text_width(
        draw,
        brand,
        brand_font,
    )

    draw.text(
        (
            RIGHT - brand_width,
            573,
        ),
        brand,
        font=brand_font,
        fill=WHITE,
    )

    # ======================================
    # SAVE
    # ======================================

    output = (
        IMAGE_DIR
        / f"{challenge_id}.png"
    )

    image.save(
        output,
        "PNG",
        optimize=True,
    )

    return output


# ==========================================
# HTML META GENERATOR
# ==========================================

def remove_existing_og_tags(source):
    """
    기존 og:* 메타태그 삭제
    중복 메타태그 방지
    """

    return re.sub(
        r'<meta\s+[^>]*property=["\']og:[^>]*>',
        "",
        source,
        flags=re.IGNORECASE,
    )


def generate_html(challenge, template):
    challenge_id = challenge["id"]

    title = (
        challenge.get("title")
        or "독서 챌린지"
    )

    description = (
        challenge.get("shortDescription")
        or "Labrary에서 독서 챌린지에 참여해보세요."
    )

    url = (
        f"{BASE_URL}/challenge/{challenge_id}"
    )

    image_url = (
        f"{BASE_URL}/og/{challenge_id}.png"
    )

    def esc(value):
        return html.escape(
            str(value),
            quote=True,
        )

    # ======================================
    # OPEN GRAPH META
    # ======================================

    meta = f"""
  <!-- Dynamic Open Graph -->
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="Labrary">
  <meta property="og:title" content="{esc(title)} | Labrary">
  <meta property="og:description" content="{esc(description)}">
  <meta property="og:url" content="{esc(url)}">
  <meta property="og:image" content="{esc(image_url)}">
  <meta property="og:image:secure_url" content="{esc(image_url)}">
  <meta property="og:image:type" content="image/png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="{esc(title)}">

  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="{esc(title)} | Labrary">
  <meta name="twitter:description" content="{esc(description)}">
  <meta name="twitter:image" content="{esc(image_url)}">

  <link rel="canonical" href="{esc(url)}">
"""

    # 기존 OG 태그 제거
    page = remove_existing_og_tags(template)

    # 개별 메타데이터 삽입
    page = page.replace(
        "</head>",
        meta + "\n</head>",
        1,
    )

    # HTML title 수정
    page = re.sub(
        r"<title>.*?</title>",
        f"<title>{esc(title)} | Labrary</title>",
        page,
        count=1,
        flags=re.DOTALL,
    )

    # ======================================
    # SAVE HTML
    # ======================================

    output = (
        HTML_DIR
        / f"{challenge_id}.html"
    )

    output.write_text(
        page,
        encoding="utf-8",
    )

    return output


# ==========================================
# MAIN
# ==========================================

def main():

    if not SOURCE_JSON.exists():
        raise FileNotFoundError(
            SOURCE_JSON
        )

    if not TEMPLATE.exists():
        raise FileNotFoundError(
            TEMPLATE
        )

    challenges = json.loads(
        SOURCE_JSON.read_text(
            encoding="utf-8"
        )
    )

    if not isinstance(challenges, list):
        raise ValueError(
            "challenges.json은 배열이어야 합니다."
        )

    template = TEMPLATE.read_text(
        encoding="utf-8"
    )

    valid = []

    for challenge in challenges:

        # 커스텀 챌린지 제외
        if challenge.get("isCustom") is True:
            continue

        # 아카이브 챌린지 제외
        if challenge.get("isArchived") is True:
            continue

        challenge_id = challenge.get(
            "id",
            "",
        )

        # 파일명 및 URL 안전성 확인
        if not re.fullmatch(
            r"[A-Za-z0-9_-]+",
            challenge_id,
        ):
            print(
                f"SKIP invalid ID: {challenge_id}"
            )
            continue

        valid.append(challenge)

        # 공유 이미지 생성
        generate_image(challenge)

        # 챌린지별 HTML 생성
        generate_html(
            challenge,
            template,
        )

        print(
            f"Generated: {challenge_id}"
        )

    # ======================================
    # PUBLIC JSON SYNC
    # ======================================

    (
        PUBLIC
        / "challenges.json"
    ).write_text(
        json.dumps(
            valid,
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )

    print()
    print(
        f"Complete: {len(valid)} challenges"
    )
    print(
        f"Images: {IMAGE_DIR}"
    )
    print(
        f"Pages: {HTML_DIR}"
    )


if __name__ == "__main__":
    main()
