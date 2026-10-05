#!/usr/bin/env python3
"""Compares the app's simulator screenshots with the design's mock-ups.

For each of home, live, note and settings it renders the mock-up phone from
design/directions/make_directions.py at the simulator's pixel size, then writes
  <name>-overlay.png   the two laid exactly on top of each other: the design in blue-green, the app in
                       red, and dark where they agree. A red and a blue-green copy of the same line, a
                       little apart, is a size or spacing difference.
  <name>-side.png      mock-up left, app right
into app/build/overlay. Run app/tools/screens.sh first.
"""
import importlib.util, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "app", "build", "overlay")
SCREENS = os.path.join(ROOT, "app", "build", "screens")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
os.makedirs(OUT, exist_ok=True)

spec = importlib.util.spec_from_file_location("directions", os.path.join(ROOT, "design", "directions", "make_directions.py"))
directions = importlib.util.module_from_spec(spec)
sys.stdout = open(os.devnull, "w")
spec.loader.exec_module(directions)
sys.stdout = sys.__stdout__

A = directions.A
mocks = {"home": A["screens1"][0], "live": A["screens1"][1], "note": A["screens1"][2], "settings": A["screens2"][1]}
WIDTH, HEIGHT = 1206, 2622                      # the simulator's screenshot
POINTS = 402                                    # the simulator's screen width in points
ZOOM = POINTS / (52.8 * 96 / 25.4)              # the mock-up's screen is 52.8 mm wide inside its 1.6 mm frame
SCALE = WIDTH / POINTS
for name, shot in mocks.items():
    html = (f'<!doctype html><html><head><meta charset="utf-8"><style>:root{{{A["vars"]}}}{directions.BASE_CSS}'
            f'body{{background:#000}}.cap{{display:none}}.shot{{align-items:flex-start}}.phone{{border-radius:0;zoom:{ZOOM}}}</style></head>'
            f'<body>{shot}</body></html>')
    page = os.path.join(OUT, f"{name}-mock.html")
    open(page, "w").write(html)
    raw = os.path.join(OUT, f"{name}-mock-raw.png")
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--force-device-scale-factor={SCALE}",
                    "--window-size=450,1000", f"--screenshot={raw}", "file://" + page], check=True, capture_output=True)
    frame = round(1.6 * 96 / 25.4 * ZOOM * SCALE)
    mock = os.path.join(OUT, f"{name}-mock.png")
    subprocess.run(["magick", raw, "-crop", f"{WIDTH}x{HEIGHT}+{frame}+{frame}", "+repage", "-background", "white", "-extent", f"{WIDTH}x{HEIGHT}", mock], check=True)
    app = os.path.join(SCREENS, f"{name}.png")
    subprocess.run(["magick", mock, app, "-resize", "603x", "-bordercolor", "#888", "-border", "2", "+append", os.path.join(OUT, f"{name}-side.png")], check=True)
    # Red channel from the design, green and blue from the app: design-only ink turns blue-green, app-only ink red.
    subprocess.run(["magick", "(", mock, "-colorspace", "Gray", ")", "(", app, "-colorspace", "Gray", ")", "(", app, "-colorspace", "Gray", ")",
                    "-combine", "-resize", "804x", os.path.join(OUT, f"{name}-overlay.png")], check=True)
    os.remove(raw); os.remove(page)
print("Compared: " + ", ".join(mocks))
