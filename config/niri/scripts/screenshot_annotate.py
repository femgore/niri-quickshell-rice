#!/usr/bin/env python3
import argparse
import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw


GEOM_RE = re.compile(r"^\s*(-?\d+),(-?\d+)\s+(\d+)x(\d+)\s*$")


def parse_geometry(value):
    match = GEOM_RE.match(value or "")
    if not match:
        raise ValueError(f"invalid geometry: {value}")
    return tuple(int(part) for part in match.groups())


def clamp_rect(x, y, w, h, max_w, max_h):
    x1 = max(0, min(max_w, int(round(x))))
    y1 = max(0, min(max_h, int(round(y))))
    x2 = max(0, min(max_w, int(round(x + w))))
    y2 = max(0, min(max_h, int(round(y + h))))
    if x2 < x1:
        x1, x2 = x2, x1
    if y2 < y1:
        y1, y2 = y2, y1
    return x1, y1, x2, y2


def color_to_rgba(value):
    value = str(value or "#000000").strip()
    if value.startswith("#"):
        value = value[1:]
    if len(value) == 6:
        value += "ff"
    if len(value) != 8:
        return (0, 0, 0, 255)
    return tuple(int(value[i:i + 2], 16) for i in range(0, 8, 2))


def local_rect(shape, geom_x, geom_y):
    x = float(shape.get("x", 0)) - geom_x
    y = float(shape.get("y", 0)) - geom_y
    w = float(shape.get("w", 0))
    h = float(shape.get("h", 0))
    return x, y, w, h


def apply_pixelate(image, box):
    x1, y1, x2, y2 = box
    if x2 - x1 < 2 or y2 - y1 < 2:
        return
    region = image.crop(box)
    small_w = max(1, (x2 - x1) // 10)
    small_h = max(1, (y2 - y1) // 10)
    region = region.resize((small_w, small_h), Image.Resampling.BILINEAR)
    region = region.resize((x2 - x1, y2 - y1), Image.Resampling.NEAREST)
    image.paste(region, box)


def annotate(args):
    geom_x, geom_y, geom_w, geom_h = parse_geometry(args.geometry)
    source = Image.open(args.image).convert("RGBA")
    image = source.crop((geom_x, geom_y, geom_x + geom_w, geom_y + geom_h))

    with open(args.annotations, "r", encoding="utf-8") as handle:
        shapes = json.load(handle)

    draw = ImageDraw.Draw(image, "RGBA")
    for shape in shapes:
        tool = shape.get("tool")
        color = color_to_rgba(shape.get("color"))
        width = max(1, int(round(float(shape.get("size", 18)))))

        if tool in {"rect", "ellipse", "pixelate"}:
            box = clamp_rect(*local_rect(shape, geom_x, geom_y), image.width, image.height)
            if box[2] <= box[0] or box[3] <= box[1]:
                continue
            if tool == "rect":
                draw.rectangle(box, fill=color)
            elif tool == "ellipse":
                draw.ellipse(box, fill=color)
            else:
                apply_pixelate(image, box)
        elif tool == "brush":
            points = []
            for point in shape.get("points", []):
                points.append((
                    float(point.get("x", 0)) - geom_x,
                    float(point.get("y", 0)) - geom_y,
                ))
            if len(points) == 1:
                x, y = points[0]
                r = width / 2
                draw.ellipse((x - r, y - r, x + r, y + r), fill=color)
            elif len(points) > 1:
                draw.line(points, fill=color, width=width, joint="curve")

    if args.output == "-":
        image.save(sys.stdout.buffer, format="PNG")
    else:
        image.save(args.output)


def sample(args):
    image = Image.open(args.image).convert("RGBA")
    x = max(0, min(image.width - 1, int(round(args.x))))
    y = max(0, min(image.height - 1, int(round(args.y))))
    r, g, b, _a = image.getpixel((x, y))
    print(f"#{r:02x}{g:02x}{b:02x}")


def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    ann = subparsers.add_parser("annotate")
    ann.add_argument("--image", required=True)
    ann.add_argument("--geometry", required=True)
    ann.add_argument("--annotations", required=True)
    ann.add_argument("--output", required=True)
    ann.set_defaults(func=annotate)

    smp = subparsers.add_parser("sample")
    smp.add_argument("--image", required=True)
    smp.add_argument("--x", type=float, required=True)
    smp.add_argument("--y", type=float, required=True)
    smp.set_defaults(func=sample)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
