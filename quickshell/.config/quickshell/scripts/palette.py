#!/usr/bin/env python3
"""Generate a full shell palette (Catppuccin-shaped, dark) from a wallpaper.

    palette.py IMAGE            print the palette JSON (cached per image)
    palette.py IMAGE --apply    also write it to $XDG_CACHE_HOME/quickshell/palette.json
    palette.py --self-test      check the contrast rules on random images

How it works: the image is shrunk and clustered (k-means). The most vivid
cluster gives the highlight hue; the dominant cluster tints every surface, so
the shell feels like the wallpaper. Accent colours keep the shape of the
Catppuccin palette (red stays reddish, green greenish: they carry meaning) but
drift towards the wallpaper's hue and saturation. All text/accent colours are
then nudged until they meet minimum contrast against the base.
"""
import colorsys
import hashlib
import json
import os
import sys

import numpy as np
from PIL import Image

VERSION = 4
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "quickshell")

# Catppuccin Mocha accents as (hue°, saturation, lightness) + whether the hue carries meaning.
ACCENTS = {
    "rosewater": (10, 0.55, 0.89, False),
    "flamingo": (0, 0.59, 0.88, False),
    "pink": (316, 0.72, 0.86, False),
    "mauve": (267, 0.84, 0.81, False),
    "red": (343, 0.81, 0.75, True),
    "maroon": (350, 0.65, 0.77, True),
    "peach": (23, 0.92, 0.75, True),
    "yellow": (41, 0.86, 0.83, True),
    "green": (115, 0.54, 0.76, True),
    "teal": (170, 0.57, 0.73, False),
    "sky": (189, 0.71, 0.73, False),
    "sapphire": (199, 0.76, 0.69, False),
    "blue": (217, 0.92, 0.76, False),
    "lavender": (232, 0.97, 0.85, False),
}


def hsl_hex(h, s, l):
    r, g, b = colorsys.hls_to_rgb((h % 360) / 360.0, min(max(l, 0), 1), min(max(s, 0), 1))
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


def hex_rgb(hx):
    return tuple(int(hx[i:i + 2], 16) / 255 for i in (1, 3, 5))


def luminance(hx):
    def lin(c):
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(c) for c in hex_rgb(hx))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def ensure_contrast(h, s, l, against, minimum, lighter=True):
    """Move lightness until hsl(h,s,l) has `minimum` contrast against `against`."""
    step = 0.01 if lighter else -0.01
    hx = hsl_hex(h, s, l)
    while contrast(hx, against) < minimum and 0.02 < l < 0.98:
        l += step
        hx = hsl_hex(h, s, l)
    return hx


def circ_dist(a, b):
    d = abs(a - b) % 360
    return min(d, 360 - d)


def clusters(img, k=8, iters=12):
    """k-means over a small copy; returns [(rgb 0..1, share)] by share desc."""
    img = img.convert("RGB")
    img.thumbnail((96, 96))
    px = np.asarray(img, dtype=np.float32).reshape(-1, 3) / 255.0
    rng = np.random.default_rng(7)
    centers = px[rng.choice(len(px), size=min(k, len(px)), replace=False)]
    for _ in range(iters):
        d = ((px[:, None, :] - centers[None, :, :]) ** 2).sum(axis=2)
        lab = d.argmin(axis=1)
        for i in range(len(centers)):
            m = px[lab == i]
            if len(m):
                centers[i] = m.mean(axis=0)
    counts = np.bincount(lab, minlength=len(centers)) / len(px)
    out = [(tuple(centers[i]), float(counts[i])) for i in range(len(centers)) if counts[i] > 0]
    out.sort(key=lambda x: -x[1])
    return out


def generate(path):
    img = Image.open(path)
    cl = clusters(img)

    def hls(rgb):
        h, l, s = colorsys.rgb_to_hls(*rgb)
        return h * 360, s, l

    # Vivid cluster: population matters, but saturation and mid lightness matter more.
    def vividness(c):
        h, s, l = hls(c[0])
        return (c[1] ** 0.5) * (s ** 1.3) * (1 - abs(l - 0.55) * 1.2)

    vivid = max(cl, key=vividness)
    vh, vs, vl = hls(vivid[0])
    if vs < 0.12:                              # greyscale wallpaper: fall back to a cool neutral
        vh, vs = 225, 0.35

    dom_h, dom_s, _ = hls(cl[0][0])
    base_h = dom_h if dom_s > 0.10 else vh
    base_s = min(max(dom_s * 0.45, 0.10), 0.21)

    c = {}
    for name, l in (("base", 0.15), ("mantle", 0.115), ("crust", 0.085), ("surface0", 0.215),
                    ("surface1", 0.29), ("surface2", 0.36)):
        c[name] = hsl_hex(base_h, base_s, l)
    ov_s = min(base_s * 0.75, 0.25)
    for name, l in (("overlay0", 0.44), ("overlay1", 0.52), ("overlay2", 0.60)):
        c[name] = hsl_hex(base_h, ov_s, l)

    base = c["base"]
    txt_s = min(0.45, base_s * 1.6)
    c["text"] = ensure_contrast(base_h, txt_s, 0.88, base, 10.0)
    c["subtext1"] = ensure_contrast(base_h, txt_s * 0.85, 0.80, base, 8.0)
    c["subtext0"] = ensure_contrast(base_h, txt_s * 0.75, 0.72, base, 6.0)
    for name in ("overlay0", "overlay1", "overlay2"):
        need = {"overlay0": 3.4, "overlay1": 4.6, "overlay2": 5.6}[name]
        c[name] = ensure_contrast(base_h, ov_s, float(name[-1]) * 0.08 + 0.44, base, need)

    # Accents: semantic hues stay close to their meaning, the rest follow the wallpaper.
    shift = ((vh - 267 + 180) % 360) - 180
    sat_k = min(max(0.75 + vs * 0.45, 0.78), 1.05)
    for name, (h, s, l, semantic) in ACCENTS.items():
        d = max(-10, min(10, shift * 0.1)) if semantic else max(-22, min(22, shift * 0.3))
        c[name] = ensure_contrast(h + d, min(s * sat_k, 0.95), l, base, 6.5)

    # Highlight: the wallpaper's own accent, readable on the base.
    c["highlight"] = ensure_contrast(vh, min(max(vs, 0.55), 0.9), 0.78, base, 7.0)

    return {"version": VERSION, "source": os.path.abspath(path), "mode": "dark", "colors": c}


def cached(path):
    st = os.stat(path)
    key = hashlib.sha1(f"{os.path.abspath(path)}|{st.st_mtime_ns}|{st.st_size}|{VERSION}".encode()).hexdigest()
    cdir = os.path.join(CACHE, "palettes")
    f = os.path.join(cdir, key + ".json")
    if os.path.exists(f):
        with open(f) as fh:
            return json.load(fh)
    data = generate(path)
    os.makedirs(cdir, exist_ok=True)
    with open(f + ".tmp", "w") as fh:
        json.dump(data, fh)
    os.replace(f + ".tmp", f)
    return data


def self_test():
    rng = np.random.default_rng(1)
    for n in range(25):
        arr = (rng.random((40, 40, 3)) * (rng.random() * 255)).astype("uint8")
        if n % 5 == 0:
            arr[:] = rng.integers(0, 256, size=3)          # flat colour
        tmp = os.path.join(CACHE, "selftest.png")
        os.makedirs(CACHE, exist_ok=True)
        Image.fromarray(arr).save(tmp)
        c = generate(tmp)["colors"]
        assert contrast(c["text"], c["base"]) >= 9.5, ("text", n)
        assert contrast(c["subtext0"], c["base"]) >= 5.9, ("subtext0", n)
        assert contrast(c["overlay0"], c["base"]) >= 3.3, ("overlay0", n)
        for k in ACCENTS:
            assert contrast(c[k], c["base"]) >= 6.0, (k, n)
        assert luminance(c["crust"]) < luminance(c["mantle"]) < luminance(c["base"]) < luminance(c["surface0"])
    os.remove(tmp)
    print("palette self-test ok")


def main():
    args = sys.argv[1:]
    if args == ["--self-test"]:
        return self_test()
    if not args:
        print(__doc__)
        return 1
    data = cached(args[0])
    out = json.dumps(data, separators=(",", ":"))
    if "--apply" in args:
        os.makedirs(CACHE, exist_ok=True)
        dest = os.path.join(CACHE, "palette.json")
        with open(dest + ".tmp", "w") as fh:
            fh.write(out)
        os.replace(dest + ".tmp", dest)
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
