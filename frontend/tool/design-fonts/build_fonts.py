#!/usr/bin/env python3
"""Builds the fonts the design gallery renders with (test/helpers/design_gallery.dart).

`flutter test` has no system fonts, and it does not fall back glyph by glyph
inside a font family, so on its own it draws every Chinese character and
every icon as an empty box. On a phone that fallback comes from the system
(Chinese) and from the icon font Flutter bundles with the app. This script
bakes the same coverage into one TrueType file per family:

    Inter (Latin)   + Noto Sans SC (Chinese) -> Inter-Regular / -SemiBold / -Bold
    Caveat (Latin)  + Ma Shan Zheng          -> Caveat
    MaterialIcons                          -> copied from the Flutter SDK cache

Only TrueType outlines merge, and the app ships Inter as OpenType/CFF, so
Inter is taken from the upstream release's `extras/ttf` (same version:
4.0). That download is cached next to the output. MaterialIcons lives in
the Flutter SDK, which the build script has no path to: copy it in from a
Flutter checkout and add it to the manifest, as the README shows.

The Chinese faces are subset to the characters the app's strings and the
gallery's sample notes use, which keeps each file a few hundred kilobytes.

Usage (needs `pip install fonttools`):

    python3 tool/design-fonts/build_fonts.py build/design-fonts

    flutter test test/design/design_gallery_test.dart
"""
import io
import json
import os
import shutil
import sys
import urllib.request
import zipfile

from fontTools import subset
from fontTools.merge import Merger
from fontTools.ttLib.scaleUpem import scale_upem
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools.ttLib import TTFont

INTER_RELEASE = "https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip"
INTER_WEIGHTS = ("Regular", "SemiBold", "Bold")

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONTS = os.path.join(ROOT, "assets", "fonts")

# Everything the gallery may have to draw: the app's strings in every
# language, plus the sample notes.
CHARACTER_SOURCES = [
    "lib/l10n/app_zh.arb",
    "lib/l10n/app_en.arb",
    "lib/l10n/app_ja.arb",
    "lib/l10n/app_ko.arb",
    "test/helpers/design_gallery.dart",
]


def characters():
    seen = set(chr(c) for c in range(0x20, 0x7F))
    seen.update("，。！？；：、“”‘’（）《》【】…—·￥×÷±°✓✔★☆✨→←↑↓•–")
    for rel in CHARACTER_SOURCES:
        with open(os.path.join(ROOT, rel), encoding="utf-8") as handle:
            seen.update(handle.read())
    return "".join(c for c in sorted(seen) if c.isprintable())


def inter_truetype(cache_dir):
    """Paths of the static TrueType Inter faces, downloaded on first use."""
    ttf_dir = os.path.join(cache_dir, "Inter-4.0", "extras", "ttf")
    missing = [
        name
        for name in INTER_WEIGHTS
        if not os.path.exists(os.path.join(ttf_dir, f"Inter-{name}.ttf"))
    ]
    if not missing:
        return {name: os.path.join(ttf_dir, f"Inter-{name}.ttf") for name in INTER_WEIGHTS}

    print(f"downloading {INTER_RELEASE}")
    with urllib.request.urlopen(INTER_RELEASE) as response:
        archive = zipfile.ZipFile(io.BytesIO(response.read()))
    os.makedirs(ttf_dir, exist_ok=True)
    for name in INTER_WEIGHTS:
        member = f"extras/ttf/Inter-{name}.ttf"
        with archive.open(member) as source, open(os.path.join(ttf_dir, f"Inter-{name}.ttf"), "wb") as target:
            target.write(source.read())
    return {name: os.path.join(ttf_dir, f"Inter-{name}.ttf") for name in INTER_WEIGHTS}


def pin_to_default_instance(font):
    """Flattens a variable font to its default instance, in place.

    Noto Sans SC and Caveat ship as variable fonts; a variable font cannot
    be merged with another face.
    """
    if "fvar" not in font:
        return
    instantiateVariableFont(
        font,
        {axis.axisTag: axis.defaultValue for axis in font["fvar"].axes},
        inplace=True,
    )


def normalize(path, text, out_path, upem):
    """Reads [path] as a static face, keeps the characters in [text], scales
    to [upem] and writes [out_path] ready for merging."""
    font = TTFont(path)
    pin_to_default_instance(font)
    if text is not None:
        options = subset.Options()
        options.name_IDs = ["*"]
        options.name_legacy = True
        options.name_languages = ["*"]
        options.layout_features = ["*"]
        options.notdef_outline = True
        subsetter = subset.Subsetter(options)
        subsetter.populate(text=text)
        subsetter.subset(font)
    # Tables the merge cannot combine or that a static gallery face does not
    # need: `GDEF` carries a variation store, the rest are vertical-metrics
    # and hinting leftovers.
    for tag in ("GDEF", "BASE", "vhea", "vmtx", "STAT", "DSIG", "gasp"):
        if tag in font:
            del font[tag]
    if font["head"].unitsPerEm != upem:
        scale_upem(font, upem)
    # `post` format 2 (glyph names) is the only format that merges.
    post = font["post"]
    post.formatType = 2.0
    post.extraNames = []
    post.mapping = {}
    post.glyphOrder = font.getGlyphOrder()
    font.save(out_path)


def merge(paths, out_path):
    merged = Merger().merge(paths)
    merged.save(out_path)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    text = characters()

    # Inter is the widest face; everything is scaled to its em before merging.
    inter_paths = inter_truetype(os.path.join(out_dir, ".cache"))
    upem = TTFont(inter_paths["Regular"])["head"].unitsPerEm

    scratch = []
    inter = {}
    for name in INTER_WEIGHTS:
        latin = os.path.join(out_dir, f".latin-{name}.ttf")
        cjk = os.path.join(out_dir, f".cjk-{name}.ttf")
        scratch += [latin, cjk]
        normalize(inter_paths[name], None, latin, upem)
        normalize(os.path.join(FONTS, "NotoSansSC-Regular.ttf"), text, cjk, upem)
        target = f"Inter-{name}.ttf"
        merge([latin, cjk], os.path.join(out_dir, target))
        inter[name] = target

    latin = os.path.join(out_dir, ".caveat.ttf")
    cjk = os.path.join(out_dir, ".mashan.ttf")
    scratch += [latin, cjk]
    normalize(os.path.join(FONTS, "caveat", "Caveat.ttf"), None, latin, upem)
    normalize(
        os.path.join(FONTS, "mashanzheng", "MaShanZheng-Regular.ttf"), text, cjk, upem
    )
    merge([latin, cjk], os.path.join(out_dir, "Caveat.ttf"))

    for path in scratch:
        os.remove(path)

    icons = None
    icon_source = os.environ.get("MATERIAL_ICONS_FONT")
    if icon_source and os.path.exists(icon_source):
        icons = "MaterialIcons" + os.path.splitext(icon_source)[1]
        shutil.copy(icon_source, os.path.join(out_dir, icons))

    manifest = {
        "Inter": [inter["Regular"], inter["SemiBold"], inter["Bold"]],
        "Caveat": ["Caveat.ttf"],
        "RobotoMono": ["RobotoMono.ttf"],
        "MaterialIcons": [icons] if icons else [],
    }
    with open(os.path.join(out_dir, "manifest.json"), "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
    shutil.copy(os.path.join(FONTS, "roboto-mono", "RobotoMono.ttf"), out_dir)

    for family, files in manifest.items():
        for file in files:
            print(f"{family:15s} {file:24s} {os.path.getsize(os.path.join(out_dir, file)) // 1024:6d} KB")
    if not icons:
        print("MaterialIcons not supplied: icons render as boxes unless "
              "MATERIAL_ICONS_FONT points at MaterialIcons-Regular.otf "
              "(bin/cache/artifacts/material_fonts in a Flutter SDK)")


if __name__ == "__main__":
    main()
