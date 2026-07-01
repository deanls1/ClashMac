#!/usr/bin/env python3
"""生成 Clash Mac 的全套图标资源。

产出三类资源，覆盖 应用图标 / Dock / 托盘：
  1. AppIcon.appiconset —— macOS「Big Sur」规范：连续圆角 squircle + 内边距 + 柔和投影，
     覆盖 16/32/128/256/512 的 @1x/@2x 共 10 个尺寸。
  2. AppLogo.imageset —— 近满幅圆角图标（无大留白），供应用内 UI（解锁页、设置预览等）使用。
  3. TrayTemplate.imageset —— 单色「模板」图标（isTemplate），供状态栏托盘使用，
     自动适配菜单栏明暗，且在 16~18pt 下依旧锐利。

设计：蓝→紫对角渐变的连续圆角底 + 白色粗体圆角「C」（Clash）搭配右侧连接节点点，
     在大尺寸富有质感、在托盘小尺寸依旧清晰可辨。

依赖 Pillow：python3 -m pip install pillow
"""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "ClashMac/Resources/Assets.xcassets"
APP_ICON_DIR = ASSETS / "AppIcon.appiconset"
LOGO_DIR = ASSETS / "AppLogo.imageset"
TRAY_DIR = ASSETS / "TrayTemplate.imageset"

# 渲染主图的超采样分辨率（越大越平滑，下采样出目标尺寸）。
MASTER = 2048

# 品牌配色：蓝 -> 紫 对角渐变。
COLOR_TOP = (60, 126, 246)     # #3C7EF6
COLOR_BOTTOM = (122, 60, 236)  # #7A3CEC

APP_ICON_SIZES = {
    "icon-16.png": 16,
    "icon-16@2x.png": 32,
    "icon-32.png": 32,
    "icon-32@2x.png": 64,
    "icon-128.png": 128,
    "icon-128@2x.png": 256,
    "icon-256.png": 256,
    "icon-256@2x.png": 512,
    "icon-512.png": 512,
    "icon-512@2x.png": 1024,
}

LOGO_SIZES = {
    "logo-128.png": 128,
    "logo-256.png": 256,
}

TRAY_SIZES = {
    "tray-18.png": 18,
    "tray-18@2x.png": 36,
}


def _lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def superellipse_mask(size: int, frac: float, exponent: float = 5.0, points: int = 1024) -> Image.Image:
    """返回一张 L 模式蒙版：居中的连续圆角（超椭圆）方形，边长 = size*frac。"""
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    half = size * frac / 2.0
    cx = cy = size / 2.0
    poly: list[tuple[float, float]] = []
    for i in range(points):
        t = 2.0 * math.pi * i / points
        ct, st = math.cos(t), math.sin(t)
        x = math.copysign(abs(ct) ** (2.0 / exponent), ct)
        y = math.copysign(abs(st) ** (2.0 / exponent), st)
        poly.append((cx + x * half, cy + y * half))
    draw.polygon(poly, fill=255)
    return mask


def diagonal_gradient(size: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    """对角线性渐变（左上 -> 右下）。低分辨率生成后放大，足够平滑且快。"""
    n = 96
    small = Image.new("RGB", (n, n))
    px = small.load()
    for y in range(n):
        for x in range(n):
            t = (x + y) / (2 * (n - 1))
            px[x, y] = (
                int(_lerp(top[0], bottom[0], t)),
                int(_lerp(top[1], bottom[1], t)),
                int(_lerp(top[2], bottom[2], t)),
            )
    return small.resize((size, size), Image.BICUBIC)


def add_top_highlight(base: Image.Image, size: int) -> Image.Image:
    """在左上方叠加一层柔和高光，增加立体质感。"""
    overlay = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(overlay)
    r = size * 0.62
    cx, cy = size * 0.32, size * 0.24
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=110)
    overlay = overlay.filter(ImageFilter.GaussianBlur(size * 0.09))
    white = Image.new("RGB", (size, size), (255, 255, 255))
    return Image.composite(white, base, overlay)


def dachshund_mask(size: int, R: float, cx: float, cy: float) -> Image.Image:
    """腊肠犬「点点」侧面剪影蒙版（面朝右）。返回 L 模式：255=犬身，0=镂空/背景。

    以身长 R 为基准的比例绘制：尾巴 + 四条短腿 + 长身 + 头 + 长吻 + 垂耳，
    并镂空出眼睛与身上两颗斑点（呼应名字「点点」）。
    """
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)

    def capsule(x0: float, y0: float, x1: float, y1: float) -> None:
        r = min(abs(x1 - x0), abs(y1 - y0)) / 2.0
        d.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=255)

    def disc(px: float, py: float, r: float, fill: int = 255) -> None:
        d.ellipse([px - r, py - r, px + r, py + r], fill=fill)

    def thick_seg(x0: float, y0: float, x1: float, y1: float, w: float) -> None:
        d.line([x0, y0, x1, y1], fill=255, width=max(1, int(round(w))))
        r = w / 2.0
        for px, py in ((x0, y0), (x1, y1)):
            d.ellipse([px - r, py - r, px + r, py + r], fill=255)

    # 尾巴（左后，微微上翘）
    thick_seg(cx - 0.34 * R, cy - 0.02 * R, cx - 0.47 * R, cy - 0.20 * R, 0.055 * R)

    # 四条短腿
    lw = 0.078 * R
    leg_top = cy + 0.05 * R
    leg_bot = cy + 0.27 * R
    for lx in (cx - 0.29 * R, cx - 0.15 * R, cx + 0.05 * R, cx + 0.17 * R):
        capsule(lx - lw / 2, leg_top, lx + lw / 2, leg_bot)

    # 长身体
    th = 0.25 * R
    capsule(cx - 0.37 * R, cy - th / 2, cx + 0.21 * R, cy + th / 2)

    # 头
    hx, hy, hr = cx + 0.25 * R, cy - 0.05 * R, 0.165 * R
    disc(hx, hy, hr)

    # 长吻（右端圆润作鼻头）
    capsule(hx - 0.02 * R, cy - 0.015 * R, cx + 0.47 * R, cy + 0.12 * R)

    # 垂耳（从头后侧垂下的长椭圆）
    d.ellipse(
        [cx + 0.09 * R, cy - 0.12 * R, cx + 0.09 * R + 0.15 * R, cy - 0.12 * R + 0.34 * R],
        fill=255,
    )

    # —— 镂空细节 ——
    disc(cx + 0.31 * R, cy - 0.09 * R, 0.032 * R, fill=0)   # 眼睛（一颗「点」）
    disc(cx + 0.44 * R, cy + 0.05 * R, 0.024 * R, fill=0)   # 鼻孔
    disc(cx - 0.07 * R, cy - 0.02 * R, 0.045 * R, fill=0)   # 身上斑点「点点」
    disc(cx + 0.06 * R, cy + 0.02 * R, 0.038 * R, fill=0)   # 身上斑点「点点」

    return m


def draw_mark(target: Image.Image, size: int, rect_side: float, color: tuple[int, int, int, int]) -> None:
    """在 target 上绘制腊肠犬「点点」剪影。"""
    cx = cy = size / 2.0
    R = rect_side * 0.86  # 相对绘制区留出边距，避免鼻尖/尾巴顶到边缘。
    # 犬身整体略上移，使四条腿与画面居中更协调。
    mask = dachshund_mask(size, R, cx, cy - R * 0.02)
    layer = Image.new("RGBA", (size, size), (color[0], color[1], color[2], 255))
    layer.putalpha(mask)
    target.alpha_composite(layer)


def render_colored(size: int, frac: float, shadow: bool) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = superellipse_mask(size, frac)

    grad = diagonal_gradient(size, COLOR_TOP, COLOR_BOTTOM)
    grad = add_top_highlight(grad, size)
    body = grad.convert("RGBA")
    body.putalpha(mask)

    if shadow:
        sh = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        black = Image.new("RGBA", (size, size), (20, 24, 60, 255))
        black.putalpha(mask)
        sh.alpha_composite(black, dest=(0, int(size * 0.02)))
        sh = sh.filter(ImageFilter.GaussianBlur(size * 0.028))
        # 降低整体阴影强度
        alpha = sh.getchannel("A").point(lambda a: int(a * 0.42))
        sh.putalpha(alpha)
        canvas.alpha_composite(sh)

    canvas.alpha_composite(body)

    rect_side = size * frac
    draw_mark(canvas, size, rect_side, (255, 255, 255, 255))
    return canvas


def render_tray(size: int) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_mark(canvas, size, size, (0, 0, 0, 255))
    return canvas


def save_downscaled(master: Image.Image, path: Path, out_size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img = master.resize((out_size, out_size), Image.LANCZOS)
    img.save(path)


def write_contents(directory: Path, images: list[dict], properties: dict | None = None) -> None:
    contents = {"images": images, "info": {"author": "xcode", "version": 1}}
    if properties:
        contents["properties"] = properties
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    app_master = render_colored(MASTER, frac=0.805, shadow=True)
    logo_master = render_colored(MASTER, frac=0.94, shadow=False)
    tray_master = render_tray(512)

    for filename, px in APP_ICON_SIZES.items():
        save_downscaled(app_master, APP_ICON_DIR / filename, px)
    for filename, px in LOGO_SIZES.items():
        save_downscaled(logo_master, LOGO_DIR / filename, px)
    for filename, px in TRAY_SIZES.items():
        save_downscaled(tray_master, TRAY_DIR / filename, px)

    write_contents(
        LOGO_DIR,
        [
            {"idiom": "mac", "scale": "1x", "filename": "logo-128.png"},
            {"idiom": "mac", "scale": "2x", "filename": "logo-256.png"},
        ],
        {"template-rendering-intent": "original"},
    )
    write_contents(
        TRAY_DIR,
        [
            {"idiom": "mac", "scale": "1x", "filename": "tray-18.png"},
            {"idiom": "mac", "scale": "2x", "filename": "tray-18@2x.png"},
        ],
        {"template-rendering-intent": "template"},
    )

    print(
        f"Generated {len(APP_ICON_SIZES)} app icons, "
        f"{len(LOGO_SIZES)} logo images, {len(TRAY_SIZES)} tray templates"
    )


if __name__ == "__main__":
    main()
