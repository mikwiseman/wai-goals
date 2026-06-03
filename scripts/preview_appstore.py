#!/usr/bin/env python3
"""Generate a self-contained HTML preview of all App Store metadata and screenshots.

Reads fastlane/metadata/, fastlane/screenshots/, fastlane/app_store_rating_config.json,
and the app icon, then produces build/appstore_preview.html — a dark-themed dashboard
with locale tabs, character counts, screenshot gallery, and validation warnings.

Auto-detects locales, app name, and app icon from the project directory.

Usage:
    python3 scripts/preview_appstore.py [--no-open]
"""

import base64
import json
import os
import sys
import webbrowser
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
METADATA_DIR = ROOT / "fastlane" / "metadata"
SCREENSHOTS_DIR = ROOT / "fastlane" / "screenshots"
RATING_CONFIG = ROOT / "fastlane" / "app_store_rating_config.json"
OUTPUT_DIR = ROOT / "build"
OUTPUT_FILE = OUTPUT_DIR / "appstore_preview.html"

# Directories to exclude when auto-detecting locales
EXCLUDED_METADATA_DIRS = {"review_information", "trade_representative_contact_information"}

# Comprehensive App Store locale labels
LOCALE_LABELS = {
    "ar-SA": "Arabic",
    "ca": "Catalan",
    "cs": "Czech",
    "da": "Danish",
    "de-DE": "German",
    "el": "Greek",
    "en-AU": "English (Australia)",
    "en-CA": "English (Canada)",
    "en-GB": "English (UK)",
    "en-US": "English (US)",
    "es-ES": "Spanish (Spain)",
    "es-MX": "Spanish (Mexico)",
    "fi": "Finnish",
    "fr-CA": "French (Canada)",
    "fr-FR": "French (France)",
    "he": "Hebrew",
    "hi": "Hindi",
    "hr": "Croatian",
    "hu": "Hungarian",
    "id": "Indonesian",
    "it": "Italian",
    "ja": "Japanese",
    "ko": "Korean",
    "ms": "Malay",
    "nl-NL": "Dutch",
    "no": "Norwegian",
    "pl": "Polish",
    "pt-BR": "Portuguese (Brazil)",
    "pt-PT": "Portuguese (Portugal)",
    "ro": "Romanian",
    "ru": "Russian",
    "sk": "Slovak",
    "sv": "Swedish",
    "th": "Thai",
    "tr": "Turkish",
    "uk": "Ukrainian",
    "vi": "Vietnamese",
    "zh-Hans": "Chinese (Simplified)",
    "zh-Hant": "Chinese (Traditional)",
}

CHAR_LIMITS = {
    "name": 30,
    "subtitle": 30,
    "keywords": 100,
    "promotional_text": 170,
    "description": 4000,
}

LOCALE_FIELDS = [
    "name", "subtitle", "keywords", "description",
    "promotional_text", "release_notes",
    "privacy_url", "support_url", "marketing_url",
]

REVIEW_FIELDS = ["first_name", "last_name", "email_address", "phone_number", "notes"]

RATING_LABELS = {
    "CARTOON_FANTASY_VIOLENCE": "Cartoon/Fantasy Violence",
    "REALISTIC_VIOLENCE": "Realistic Violence",
    "PROLONGED_GRAPHIC_SADISTIC_REALISTIC_VIOLENCE": "Prolonged Graphic Violence",
    "PROFANITY_CRUDE_HUMOR": "Profanity/Crude Humor",
    "MATURE_SUGGESTIVE": "Mature/Suggestive Themes",
    "HORROR": "Horror/Fear Themes",
    "MEDICAL_TREATMENT_INFO": "Medical/Treatment Info",
    "ALCOHOL_TOBACCO_DRUGS": "Alcohol, Tobacco, or Drugs",
    "GAMBLING": "Simulated Gambling",
    "SEXUAL_CONTENT_NUDITY": "Sexual Content/Nudity",
    "GRAPHIC_SEXUAL_CONTENT_NUDITY": "Graphic Sexual Content",
    "UNRESTRICTED_WEB_ACCESS": "Unrestricted Web Access",
    "GAMBLING_CONTESTS": "Gambling & Contests",
}

RATING_BOOL_LABELS = {
    "lootBox": "Loot Boxes",
    "gunsOrOtherWeapons": "Guns/Weapons",
    "ageAssurance": "Age Assurance",
    "advertising": "Advertising",
    "healthOrWellnessTopics": "Health/Wellness Topics",
    "userGeneratedContent": "User-Generated Content",
    "parentalControls": "Parental Controls",
    "messagingAndChat": "Messaging & Chat",
}

FREQUENCY_LABELS = {0: "None", 1: "Infrequent/Mild", 2: "Frequent/Intense"}


def detect_locales() -> list:
    """Auto-detect locales from fastlane/metadata/ subdirectories."""
    if not METADATA_DIR.is_dir():
        return []
    locales = []
    for d in sorted(METADATA_DIR.iterdir()):
        if d.is_dir() and d.name not in EXCLUDED_METADATA_DIRS:
            locales.append(d.name)
    return locales


def detect_app_icon() -> Path | None:
    """Auto-detect app icon via glob for AppIcon*.png in .xcassets."""
    candidates = list(ROOT.rglob("AppIcon.appiconset/AppIcon*.png"))
    if candidates:
        # Prefer the largest file (most likely the 1024x1024)
        return max(candidates, key=lambda p: p.stat().st_size)
    return None


def detect_app_name(locales: list) -> str:
    """Auto-detect app name from first locale's name.txt, fallback to directory name."""
    if locales:
        name_file = METADATA_DIR / locales[0] / "name.txt"
        if name_file.is_file():
            name = name_file.read_text(encoding="utf-8").strip()
            if name:
                return name
    return ROOT.name


def locale_label(locale: str) -> str:
    """Get human-readable label for a locale code."""
    return LOCALE_LABELS.get(locale, locale)


def read_file(path: Path) -> str:
    if path.is_file():
        return path.read_text(encoding="utf-8").strip()
    return ""


def encode_image(path: Path) -> str:
    if not path.is_file():
        return ""
    data = path.read_bytes()
    b64 = base64.b64encode(data).decode("ascii")
    suffix = path.suffix.lower()
    mime = "image/png" if suffix == ".png" else "image/jpeg"
    return f"data:{mime};base64,{b64}"


def char_count_class(field: str, length: int) -> str:
    limit = CHAR_LIMITS.get(field)
    if limit is None:
        return ""
    ratio = length / limit
    if ratio > 1.0:
        return "count-red"
    if ratio > 0.85:
        return "count-amber"
    return "count-green"


def load_locale_data(locale: str) -> dict:
    locale_dir = METADATA_DIR / locale
    data = {}
    for field in LOCALE_FIELDS:
        data[field] = read_file(locale_dir / f"{field}.txt")
    return data


def load_screenshots(locale: str) -> list:
    ss_dir = SCREENSHOTS_DIR / locale
    if not ss_dir.is_dir():
        return []
    images = []
    for f in sorted(ss_dir.iterdir()):
        if f.suffix.lower() in (".png", ".jpg", ".jpeg") and "framed" in f.name:
            images.append({"name": f.name, "data_uri": encode_image(f)})
    if not images:
        for f in sorted(ss_dir.iterdir()):
            if f.suffix.lower() in (".png", ".jpg", ".jpeg"):
                images.append({"name": f.name, "data_uri": encode_image(f)})
    return images


def load_rating_config() -> dict:
    if RATING_CONFIG.is_file():
        return json.loads(RATING_CONFIG.read_text(encoding="utf-8"))
    return {}


def load_review_info() -> dict:
    review_dir = METADATA_DIR / "review_information"
    data = {}
    for field in REVIEW_FIELDS:
        data[field] = read_file(review_dir / f"{field}.txt")
    return data


def find_missing_files(locales: list) -> list:
    missing = []
    for locale in locales:
        locale_dir = METADATA_DIR / locale
        for field in LOCALE_FIELDS:
            path = locale_dir / f"{field}.txt"
            if not path.is_file() or not path.read_text(encoding="utf-8").strip():
                missing.append(f"{locale}/{field}.txt")
    for field in REVIEW_FIELDS:
        path = METADATA_DIR / "review_information" / f"{field}.txt"
        if not path.is_file() or not path.read_text(encoding="utf-8").strip():
            missing.append(f"review_information/{field}.txt")
    shared = ["copyright.txt", "primary_category.txt", "secondary_category.txt"]
    for f in shared:
        path = METADATA_DIR / f
        if not path.is_file() or not path.read_text(encoding="utf-8").strip():
            missing.append(f)
    if not RATING_CONFIG.is_file():
        missing.append("app_store_rating_config.json")
    return missing


def field_label(field: str) -> str:
    return field.replace("_", " ").title()


def render_field_html(field: str, value: str) -> str:
    limit = CHAR_LIMITS.get(field)
    length = len(value)
    count_html = ""
    if limit:
        cls = char_count_class(field, length)
        count_html = f'<span class="char-count {cls}">{length}/{limit}</span>'

    if field == "keywords":
        pills = ""
        if value:
            for kw in value.split(","):
                kw = kw.strip()
                if kw:
                    pills += f'<span class="pill">{kw}</span>'
        return f"""
        <div class="field">
            <div class="field-header">
                <span class="field-label">{field_label(field)}</span>
                {count_html}
            </div>
            <div class="pills">{pills}</div>
        </div>"""

    if field in ("privacy_url", "support_url", "marketing_url"):
        link = f'<a href="{value}" class="url-link">{value}</a>' if value else '<span class="empty">Not set</span>'
        return f"""
        <div class="field">
            <div class="field-header">
                <span class="field-label">{field_label(field)}</span>
            </div>
            <div class="field-value">{link}</div>
        </div>"""

    if field in ("description", "release_notes"):
        escaped = value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\n", "<br>")
        return f"""
        <div class="field">
            <div class="field-header">
                <span class="field-label">{field_label(field)}</span>
                {count_html}
            </div>
            <div class="field-value long-text">{escaped if value else '<span class="empty">Not set</span>'}</div>
        </div>"""

    escaped = value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    return f"""
    <div class="field">
        <div class="field-header">
            <span class="field-label">{field_label(field)}</span>
            {count_html}
        </div>
        <div class="field-value">{escaped if value else '<span class="empty">Not set</span>'}</div>
    </div>"""


def generate_tab_css(locales: list) -> str:
    """Generate pure-CSS tab switching rules for N locales."""
    rules = []
    for i, locale in enumerate(locales):
        tab_id = f"tab-{locale}"
        panel_index = i + 1
        rules.append(
            f"#tab-{locale}:checked ~ .tab-panel:nth-of-type({panel_index}) {{ display: block; }}"
        )
        rules.append(
            f'#tab-{locale}:checked ~ label[for="{tab_id}"] {{ color: #FFF; border-bottom-color: #70B2B2; }}'
        )
    return "\n".join(rules)


def generate_html(locales: list, app_name: str, app_icon: Path | None) -> str:
    icon_uri = encode_image(app_icon) if app_icon else ""
    copyright_text = read_file(METADATA_DIR / "copyright.txt")
    primary_cat = read_file(METADATA_DIR / "primary_category.txt")
    secondary_cat = read_file(METADATA_DIR / "secondary_category.txt")
    rating = load_rating_config()
    review = load_review_info()
    missing = find_missing_files(locales)

    locale_data = {}
    locale_screenshots = {}
    for locale in locales:
        locale_data[locale] = load_locale_data(locale)
        locale_screenshots[locale] = load_screenshots(locale)

    # Warning banner
    warning_html = ""
    if missing:
        items = "".join(f"<li>{m}</li>" for m in missing)
        warning_html = f"""
    <div class="warning-banner">
        <strong>Missing or empty metadata files:</strong>
        <ul>{items}</ul>
    </div>"""

    # Locale tabs (pure CSS radio)
    tabs_html = ""
    panels_html = ""
    for i, locale in enumerate(locales):
        checked = "checked" if i == 0 else ""
        tab_id = f"tab-{locale}"
        tabs_html += f"""
        <input type="radio" name="locale-tabs" id="{tab_id}" {checked} class="tab-radio">
        <label for="{tab_id}" class="tab-label">{locale_label(locale)}</label>"""

        data = locale_data[locale]
        fields_html = ""
        for field in LOCALE_FIELDS:
            fields_html += render_field_html(field, data[field])

        screenshots = locale_screenshots[locale]
        gallery_html = ""
        if screenshots:
            imgs = ""
            for ss in screenshots:
                imgs += f'<img src="{ss["data_uri"]}" alt="{ss["name"]}" title="{ss["name"]}">'
            gallery_html = f"""
            <div class="card">
                <h2>Screenshots</h2>
                <div class="gallery">{imgs}</div>
            </div>"""
        else:
            gallery_html = """
            <div class="card">
                <h2>Screenshots</h2>
                <div class="empty-state">No screenshots found</div>
            </div>"""

        panels_html += f"""
        <div class="tab-panel">
            <div class="card">
                <h2>App Listing</h2>
                {fields_html}
            </div>
            {gallery_html}
        </div>"""

    # Rating grid
    rating_rows = ""
    for key, label in RATING_LABELS.items():
        val = rating.get(key, 0)
        freq = FREQUENCY_LABELS.get(val, str(val))
        cls = "rating-none" if val == 0 else "rating-active"
        rating_rows += f'<div class="rating-row"><span class="rating-label">{label}</span><span class="rating-value {cls}">{freq}</span></div>'

    for key, label in RATING_BOOL_LABELS.items():
        val = rating.get(key, False)
        display = "Yes" if val else "No"
        cls = "rating-active" if val else "rating-none"
        rating_rows += f'<div class="rating-row"><span class="rating-label">{label}</span><span class="rating-value {cls}">{display}</span></div>'

    # Review info
    review_html = ""
    for field in REVIEW_FIELDS:
        val = review.get(field, "")
        label = field_label(field)
        escaped = val.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\n", "<br>")
        review_html += f"""
        <div class="field">
            <div class="field-header"><span class="field-label">{label}</span></div>
            <div class="field-value">{escaped if val else '<span class="empty">Not set</span>'}</div>
        </div>"""

    # Icon header
    icon_html = ""
    if icon_uri:
        icon_html = f'<img src="{icon_uri}" alt="App Icon" class="app-icon">'

    escaped_app_name = app_name.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{escaped_app_name} — App Store Preview</title>
<style>
* {{ margin: 0; padding: 0; box-sizing: border-box; }}

body {{
    background: #000;
    color: #FFF;
    font-family: -apple-system, 'SF Pro Text', 'SF Pro Display', 'Helvetica Neue', system-ui, sans-serif;
    line-height: 1.5;
    padding: 40px 20px 80px;
}}

.container {{
    max-width: 900px;
    margin: 0 auto;
}}

h1 {{
    font-family: 'New York', 'Iowan Old Style', Georgia, serif;
    font-size: 28px;
    font-weight: 700;
    margin-bottom: 4px;
}}

h2 {{
    font-family: 'New York', 'Iowan Old Style', Georgia, serif;
    font-size: 20px;
    font-weight: 600;
    margin-bottom: 16px;
    color: #FFF;
}}

.header {{
    display: flex;
    align-items: center;
    gap: 20px;
    margin-bottom: 32px;
    padding-bottom: 24px;
    border-bottom: 1px solid #1A1A1A;
}}

.app-icon {{
    width: 80px;
    height: 80px;
    border-radius: 18px;
}}

.header-text .subtitle {{
    color: #999;
    font-size: 15px;
}}

.header-meta {{
    display: flex;
    gap: 16px;
    margin-top: 8px;
    font-size: 13px;
    color: #999;
}}

.header-meta span {{
    background: #111;
    padding: 4px 10px;
    border-radius: 6px;
    border: 1px solid #1A1A1A;
}}

.warning-banner {{
    background: #2A2200;
    border: 1px solid #DCA46E;
    border-radius: 12px;
    padding: 16px 20px;
    margin-bottom: 24px;
    color: #DCA46E;
    font-size: 14px;
}}

.warning-banner strong {{
    display: block;
    margin-bottom: 8px;
}}

.warning-banner ul {{
    margin-left: 20px;
}}

.warning-banner li {{
    margin-bottom: 2px;
}}

.card {{
    background: #111;
    border: 1px solid #1A1A1A;
    border-radius: 12px;
    padding: 24px;
    margin-bottom: 20px;
}}

.field {{
    margin-bottom: 16px;
    padding-bottom: 16px;
    border-bottom: 1px solid #1A1A1A;
}}

.field:last-child {{
    margin-bottom: 0;
    padding-bottom: 0;
    border-bottom: none;
}}

.field-header {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 6px;
}}

.field-label {{
    font-size: 12px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: #999;
}}

.field-value {{
    font-size: 15px;
    color: #FFF;
}}

.field-value.long-text {{
    font-size: 14px;
    line-height: 1.6;
    color: #CCC;
}}

.empty {{
    color: #555;
    font-style: italic;
}}

.char-count {{
    font-size: 12px;
    font-weight: 500;
    font-variant-numeric: tabular-nums;
}}

.count-green {{ color: #7FB896; }}
.count-amber {{ color: #DCA46E; }}
.count-red {{ color: #D48484; }}

.pills {{
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
}}

.pill {{
    background: #1A1A1A;
    color: #70B2B2;
    font-size: 13px;
    padding: 4px 12px;
    border-radius: 20px;
    border: 1px solid #2A3A3A;
}}

.url-link {{
    color: #70B2B2;
    text-decoration: none;
    font-size: 14px;
}}

.url-link:hover {{
    text-decoration: underline;
}}

/* Locale tabs — pure CSS */
.tabs-wrapper {{
    margin-bottom: 20px;
}}

.tab-radio {{
    display: none;
}}

.tab-label {{
    display: inline-block;
    padding: 8px 20px;
    font-size: 14px;
    font-weight: 500;
    color: #999;
    cursor: pointer;
    border-bottom: 2px solid transparent;
    transition: color 0.2s, border-color 0.2s;
    margin-right: 4px;
}}

.tab-label:hover {{
    color: #CCC;
}}

.tab-panel {{
    display: none;
}}

/* Show selected tab panel */
{generate_tab_css(locales)}

/* Gallery */
.gallery {{
    display: flex;
    gap: 12px;
    overflow-x: auto;
    scroll-snap-type: x mandatory;
    padding-bottom: 8px;
    -webkit-overflow-scrolling: touch;
}}

.gallery img {{
    height: 400px;
    width: auto;
    border-radius: 8px;
    scroll-snap-align: start;
    flex-shrink: 0;
}}

.gallery::-webkit-scrollbar {{
    height: 6px;
}}

.gallery::-webkit-scrollbar-track {{
    background: #1A1A1A;
    border-radius: 3px;
}}

.gallery::-webkit-scrollbar-thumb {{
    background: #333;
    border-radius: 3px;
}}

.empty-state {{
    color: #555;
    font-style: italic;
    text-align: center;
    padding: 40px 0;
}}

/* Rating grid */
.rating-grid {{
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px;
}}

.rating-row {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 8px 12px;
    background: #0A0A0A;
    border-radius: 8px;
}}

.rating-label {{
    font-size: 13px;
    color: #999;
}}

.rating-value {{
    font-size: 13px;
    font-weight: 500;
}}

.rating-none {{ color: #555; }}
.rating-active {{ color: #DCA46E; }}

/* Shared info grid */
.info-grid {{
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
}}

@media (max-width: 600px) {{
    .rating-grid, .info-grid {{
        grid-template-columns: 1fr;
    }}
    .header {{
        flex-direction: column;
        align-items: flex-start;
    }}
}}

.footer {{
    text-align: center;
    color: #555;
    font-size: 12px;
    margin-top: 40px;
    padding-top: 20px;
    border-top: 1px solid #1A1A1A;
}}
</style>
</head>
<body>
<div class="container">

    <div class="header">
        {icon_html}
        <div class="header-text">
            <h1>{escaped_app_name}</h1>
            <div class="subtitle">App Store Metadata Preview</div>
            <div class="header-meta">
                <span>{primary_cat}</span>
                <span>{secondary_cat}</span>
                <span>&copy; {copyright_text}</span>
            </div>
        </div>
    </div>

    {warning_html}

    <div class="tabs-wrapper">
        {tabs_html}
        {panels_html}
    </div>

    <div class="card">
        <h2>Age Rating</h2>
        <div class="rating-grid">
            {rating_rows}
        </div>
    </div>

    <div class="card">
        <h2>Review Information</h2>
        {review_html}
    </div>

    <div class="footer">
        Generated by appstore-skill &middot; fastlane metadata
    </div>

</div>
</body>
</html>"""

    return html


def main():
    no_open = "--no-open" in sys.argv

    if not METADATA_DIR.is_dir():
        print(
            "No fastlane/metadata/ directory found.\n"
            "Run /appstore or /appstore setup first to create the fastlane structure.",
            file=sys.stderr,
        )
        sys.exit(0)

    locales = detect_locales()
    if not locales:
        print(
            "No locale directories found in fastlane/metadata/.\n"
            "Run /appstore setup first to create locale directories (e.g., en-US/).",
            file=sys.stderr,
        )
        sys.exit(0)

    app_icon = detect_app_icon()
    app_name = detect_app_name(locales)

    print(f"App: {app_name}")
    print(f"Locales: {', '.join(locales)}")
    print(f"Icon: {app_icon or 'not found'}")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    try:
        html = generate_html(locales, app_name, app_icon)
        OUTPUT_FILE.write_text(html, encoding="utf-8")
    except PermissionError:
        print(f"Error: Cannot write to {OUTPUT_FILE}. Check directory permissions.", file=sys.stderr)
        sys.exit(1)
    except OSError as e:
        print(f"Error writing preview: {e}", file=sys.stderr)
        sys.exit(1)
    print(f"Preview generated: {OUTPUT_FILE}")

    if not no_open:
        try:
            webbrowser.open(f"file://{OUTPUT_FILE}")
            print("Opened in browser.")
        except Exception:
            print(f"Could not open browser. Open manually: file://{OUTPUT_FILE}")


if __name__ == "__main__":
    main()
