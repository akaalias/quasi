#!/usr/bin/env python3
"""Builds answer-marks.pdf: how the marks of the page's examples look today, and three directions
that tell the answers apart. Every card draws the same short sentence of sounds; what changes is
the ending, so each direction is about making the endings differ.

Usage: design/answer-marks/make_marks.py
"""
import os, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PAPER, CARD, INK, QUIET, RULE, BRAND = "#FBF8F2", "#F1EBDF", "#1E1B16", "#8A8173", "#DDD3C1", "#C8551F"

# The endings, as the sounds play them: (time in ms, pitch as MIDI note, role).
# G5 79, Ab5 80, B5 83, C6 84, E6 88; the failure falls to about B4 (71).
SCENES = [
    ("A simple voice note", "kept", [(0, 84, "home")]),
    ("Create one task", "task", [(0, 79, "pick"), (260, 84, "chord")]),
    ("Create three tasks", "task", [(0, 79, "pick"), (200, 79, "pick"), (400, 79, "pick"), (660, 84, "chord")]),
    ("Send a message", "message", [(0, 79, "pick"), (180, 88, "pick"), (620, 84, "chord")]),
    ("Quasi asks which Alex", "asking", [(0, 84, "hang"), (320, 88, "hang")]),
    ("Set a reminder", "reminder", [(0, 88, "pick"), (260, 84, "chord")]),
    ("Start a timer", "timer", [(0, 84, "pick"), (160, 79, "pick"), (320, 84, "pick"), (480, 79, "pick"), (700, 84, "chord")]),
    ("You change your mind", "cancelled", [(0, 88, "pick"), (170, 83, "pick"), (450, 84, "home")]),
    ("The internet is gone", "failed", [(0, 80, "fall"), (355, 71, "fall")]),
    ("The audio did not arrive", "lost", []),
    ("Nobody is listening", "deaf", []),
]

W, H = 330, 74      # one mark row, in px
MID = 40            # its baseline


def circle(x, y, r, stroke=QUIET, fill="none", width=2.4, dash=None, opacity=1):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    return f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"{d} opacity="{opacity}"/>'


def rect(x, y, w, h, r, stroke=QUIET, fill="none", width=2.4, opacity=1):
    return f'<rect x="{x:.1f}" y="{y:.1f}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" opacity="{opacity}"/>'


def line(points, stroke=QUIET, width=1.6, dash=None, opacity=1):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    pts = " ".join(f"{x:.1f},{y:.1f}" for x, y in points)
    return f'<polyline points="{pts}" fill="none" stroke="{stroke}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"{d} opacity="{opacity}"/>'


def path(d, stroke=QUIET, fill="none", width=2.4):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>'


def svg(body, width=W):
    return f'<svg viewBox="0 0 {width} {H}" width="{width}" height="{H}">{body}</svg>'


# ---------------------------------------------------------------- Today

def prefix_today(kind):
    """The question, the wood block, the ticking: as the page draws them now."""
    out = [circle(18, MID + 2, 8), circle(38, MID - 6, 8)]
    if kind == "deaf":
        return [circle(18, MID, 9, dash="3 3")], 40
    wood_fail = kind == "lost"
    out.append(rect(56, MID - 12, 14, 24, 5, stroke=INK if wood_fail else QUIET))
    if wood_fail:
        out.append(line([(55, MID + 16), (71, MID - 16)], stroke=QUIET, width=2.4))
        return out, 80
    out += [circle(86 + i * 17, MID, 4, fill=QUIET, width=0) for i in range(3)]
    return out, 128


def today(scene):
    name, kind, notes = scene
    out, x = prefix_today(kind)
    for i, (_, _, role) in enumerate(notes):
        last = i == len(notes) - 1
        if role in ("chord", "home"):
            out.append(circle(x + 14, MID, 13)); x += 34
        elif role == "fall":
            y = MID if i == 0 else MID + 8
            out.append(circle(x + 8, y, 7 if i == 0 else 11, stroke=INK))
            if last: out.append(line([(x + 1, y + 14), (x + 17, y - 14)], stroke=QUIET, width=2.4))
            x += 26
        elif role == "hang":
            out.append(circle(x + 9, MID - (8 if i else 0), 9)); x += 22
        else:
            lift = -9 if kind == "message" and i == 1 else 0
            out.append(circle(x + 7, MID + lift, 7)); x += 20
    return svg("".join(out))


# ---------------------------------------------------------------- 1. The melody, drawn

def small_prefix(kind, color=RULE):
    """The shared start, small and quiet, so that the ending carries the card."""
    if kind == "deaf":
        return [circle(14, MID, 7, stroke=QUIET, dash="2.5 2.5", width=2)], 34
    out = [circle(12, MID + 1, 5, stroke=color, width=2), circle(25, MID - 4, 5, stroke=color, width=2)]
    if kind == "lost":
        out += [rect(36, MID - 9, 10, 18, 3, stroke=INK, width=2), line([(34, MID + 12), (48, MID - 12)], stroke=QUIET, width=2)]
        return out, 64
    out += [rect(36, MID - 8, 9, 16, 3, stroke=color, width=2)] + [circle(55 + i * 9, MID, 2.4, fill=color, width=0) for i in range(3)]
    return out, 92


def melody(scene):
    name, kind, notes = scene
    out, x0 = small_prefix(kind)
    if not notes:
        return svg("".join(out))
    color = INK if kind == "failed" else BRAND
    span = max(t for t, _, _ in notes) or 1
    width = min(190, 60 + span * 0.24)
    y = lambda pitch: MID + 6 - (pitch - 79) * 2.6
    pts = [(x0 + 10 + (t / span) * width if len(notes) > 1 else x0 + 20, y(p)) for t, p, _ in notes]
    out.append(line(pts, stroke=color, width=1.6, opacity=.55))
    for (px, py), (_, p, role) in zip(pts, notes):
        if role == "chord":   # the chord: the home note with its third and fifth on a stem
            out += [line([(px, y(79)), (px, y(88))], stroke=color, width=1.6), circle(px, y(88), 4, stroke=color, fill=PAPER, width=2),
                    circle(px, y(79), 4, stroke=color, fill=PAPER, width=2), circle(px, py, 9, stroke=color, fill=color, width=2)]
        elif role == "home":
            out.append(circle(px, py, 9, stroke=color, fill=PAPER, width=2.4))
        elif role == "hang":
            out.append(circle(px, py, 6, stroke=color, fill=PAPER, width=2.2))
        else:
            out.append(circle(px, py, 4.5, stroke=color, fill=color if role == "pick" else PAPER, width=2))
    if kind == "asking":     # left hanging: the line goes on, dotted, into nothing
        lx, ly = pts[-1]
        out.append(line([(lx + 8, ly), (lx + 40, ly - 8)], stroke=color, width=1.6, dash="2 4"))
    if kind == "failed":
        lx, ly = pts[-1]
        out.append(line([(lx - 8, ly + 9), (lx + 8, ly - 9)], stroke=QUIET, width=2.2))
    return svg("".join(out))


# ---------------------------------------------------------------- 2. A shape for each kind

def square(x, y, s, color):
    return rect(x - s / 2, y - s / 2, s, s, 2.5, stroke=color, width=2.2)


def bell(x, y, color):
    return path(f"M{x-8} {y+6} h16 M{x-6} {y+6} v-6 a6 6 0 0 1 12 0 v6 M{x-2} {y+9.5} h4", stroke=color, width=2.2)


def shapes(scene):
    name, kind, notes = scene
    out, x = small_prefix(kind)
    color = INK if kind == "failed" else BRAND
    end = lambda filled=True: circle(x + 13, MID, 12, stroke=color, fill=color if filled else PAPER, width=2.4)
    if kind == "kept":
        out.append(end(False))
    elif kind == "task":
        for _ in notes[:-1]:
            out.append(square(x + 7, MID, 12, color)); x += 18
        x += 2; out.append(end())
    elif kind == "message":
        out.append(circle(x + 6, MID + 6, 4.5, stroke=color, fill=color, width=0))
        out.append(path(f"M{x+10} {MID+3} Q{x+20} {MID-16} {x+32} {MID-8}", stroke=color, width=2))
        out.append(path(f"M{x+27} {MID-12} L{x+33} {MID-8} L{x+28} {MID-3}", stroke=color, width=2))
        x += 40; out.append(end())
    elif kind == "asking":
        out.append(circle(x + 8, MID + 2, 6, stroke=color, width=2.2))
        out.append(path(f"M{x+30} {MID-2} a11 11 0 1 1 7 10", stroke=color, width=2.4))      # a ring left open
        out.append(circle(x + 41, MID + 10, 2, stroke=color, fill=color, width=0))
    elif kind == "reminder":
        out.append(bell(x + 9, MID - 2, color)); x += 26; out.append(end())
    elif kind == "timer":
        for i in range(4):
            h = 16 if i % 2 == 0 else 9
            out.append(line([(x + 3, MID - h / 2), (x + 3, MID + h / 2)], stroke=color, width=2.6)); x += 9
        x += 6; out.append(end())
    elif kind == "cancelled":
        out.append(path(f"M{x+4} {MID-8} L{x+16} {MID+6}", stroke=color, width=2.2))
        out.append(path(f"M{x+9} {MID+7} L{x+16} {MID+6} L{x+16} {MID-1}", stroke=color, width=2.2))
        x += 24; out.append(end(False))
    elif kind == "failed":
        out.append(circle(x + 13, MID + 4, 12, stroke=INK, width=2.4))
        out.append(line([(x + 3, MID + 18), (x + 23, MID - 10)], stroke=QUIET, width=2.4))
    return svg("".join(out))


# ---------------------------------------------------------------- 3. One badge per answer

def strip(kind):
    """The shared start as one short grey strip of marks."""
    if kind == "deaf":
        return [], 8
    out = [line([(10, MID), (52, MID)], stroke=RULE, width=6)]
    if kind == "lost":
        out = [line([(10, MID), (30, MID)], stroke=RULE, width=6)]
        return out, 38
    return out, 62


def badge(scene):
    name, kind, notes = scene
    out, x = strip(kind)
    cx, cy, r = x + 24, MID, 20
    if kind == "kept":
        out.append(circle(cx, cy, r, stroke=BRAND, fill=PAPER, width=2.6))
    elif kind == "task":
        n = len(notes) - 1
        out.append(circle(cx, cy, r, stroke=BRAND, fill=BRAND, width=0))
        for i in range(n):
            out.append(circle(cx + (i - (n - 1) / 2) * 9, cy, 3, stroke=PAPER, fill=PAPER, width=0))
    elif kind == "message":
        out.append(circle(cx, cy, r, stroke=BRAND, fill=BRAND, width=0))
        out.append(circle(cx + 21, cy - 19, 5, stroke=BRAND, fill=BRAND, width=0))
        out.append(path(f"M{cx-7} {cy+5} L{cx+7} {cy-7} M{cx} {cy-7} h7 v7", stroke=PAPER, width=2.4))
    elif kind == "asking":
        out.append(circle(cx, cy, r, stroke=BRAND, fill=PAPER, width=2.6))
        out.append(path(f"M{cx-r} {cy} a{r} {r} 0 0 0 {2*r} 0 z", stroke="none", fill=BRAND, width=0))
    elif kind == "reminder":
        out.append(circle(cx, cy, r, stroke=BRAND, fill=BRAND, width=0))
        out.append(bell(cx, cy - 1, PAPER))
    elif kind == "timer":
        out.append(circle(cx, cy, r, stroke=BRAND, fill=BRAND, width=0))
        for i in range(12):
            import math
            a = i * math.pi / 6
            r1 = r - (6 if i % 3 == 0 else 3.5)
            out.append(line([(cx + r1 * math.sin(a), cy - r1 * math.cos(a)), (cx + (r - 1.5) * math.sin(a), cy - (r - 1.5) * math.cos(a))], stroke=PAPER, width=1.8))
        out.append(line([(cx, cy), (cx, cy - 10)], stroke=PAPER, width=2.4))
    elif kind == "cancelled":
        out.append(circle(cx, cy, r, stroke=BRAND, fill=PAPER, width=2.6))
        out.append(path(f"M{cx+8} {cy+6} A9 9 0 1 0 {cx-8} {cy-4}", stroke=BRAND, width=2.4))
        out.append(path(f"M{cx-12} {cy-10} L{cx-8} {cy-4} L{cx-2} {cy-7}", stroke=BRAND, width=2.4))
    elif kind == "failed":
        out.append(circle(cx, cy, r, stroke=INK, fill=PAPER, width=2.6))
        out.append(line([(cx - 13, cy + 15), (cx + 13, cy - 15)], stroke=INK, width=2.6))
    elif kind == "lost":
        out.append(circle(cx, cy, r - 4, stroke=INK, fill=PAPER, width=2.4, dash="4 4"))
    elif kind == "deaf":
        out.append(circle(cx, cy, r - 4, stroke=QUIET, fill=PAPER, width=2.2, dash="2 4"))
    return svg("".join(out))


PAGES = [
    ("Today", "How the examples look now",
     "Every card starts with the same four marks: the question, the wood block, the ticking. The endings differ only in how many small circles come before the big one, all in the same grey outline. Read side by side, the cards look alike.",
     today),
    ("Direction 1", "The melody, drawn",
     "Each note sits as high as it sounds, and a thin line joins them, so the card shows the tune: a message leaps up, calling off steps down, a timer goes back and forth, a question is left hanging. The shared start shrinks and greys out. Orange is what the app did; ink is what went wrong. The most faithful to the sounds, and the most like a score.",
     melody),
    ("Direction 2", "A shape for each kind",
     "The shared start shrinks and greys out, as in direction 1, and every kind of answer gets a small shape of its own before the closing circle: little boxes for tasks (still counted one by one), a bell for a reminder, a leap for a message, tick-tock strokes for a timer, a step back for calling off. A filled circle means something was done; an open one, that nothing was. The easiest to tell apart at a glance.",
     shapes),
    ("Direction 3", "One badge per answer",
     "The shared start becomes one short grey strip, the same on every card, and the answer is one badge. What it did is drawn inside it: the number of tasks as dots, a bell, a clock face, an arrow out. Something done is filled orange; a note kept, a question or calling off is an outline. The calmest, and the furthest from the sounds as heard.",
     badge),
]

# ---------------------------------------------------------------- Subtle: on top of today's marks

PITCH_LIFT = {79: 0, 83: -5, 84: -6, 88: -10}


def simple_bell(cx, cy, ink):
    """A bell in two parts: a dome and its clapper."""
    return path(f"M{cx-5} {cy+3} V{cy} a5 5 0 0 1 10 0 V{cy+3} Z", stroke=ink, fill=ink, width=1.4) + circle(cx, cy + 6.5, 1.6, stroke=ink, fill=ink, width=0)


CANCEL_SIGNS = {
    "dash": lambda cx, ink: line([(cx - 6, MID), (cx + 6, MID)], stroke=ink, width=2.4),
    "cross": lambda cx, ink: path(f"M{cx-4.5} {MID-4.5} L{cx+4.5} {MID+4.5} M{cx+4.5} {MID-4.5} L{cx-4.5} {MID+4.5}", stroke=ink, width=2.2),
    "back": lambda cx, ink: path(f"M{cx+4} {MID} H{cx-5} M{cx-1.5} {MID-3.5} L{cx-5} {MID} L{cx-1.5} {MID+3.5}", stroke=ink, width=2.2),
}
REMINDER_SIGNS = {
    "bell": lambda cx, ink: simple_bell(cx, MID - 3, ink),
    "dot": lambda cx, ink: circle(cx, MID, 3.4, stroke=ink, fill=ink, width=0),
}


def subtle(scene, pitch=False, sign=False, fill=False, lit=False, cancel="dash", reminder="bell"):
    """Today's marks, with one small addition, as the strike-through was added for failures.
    `lit` draws the card as it looks while its sound plays: the marks in orange."""
    name, kind, notes = scene
    tone = BRAND if lit and kind not in ("failed", "lost", "deaf") else QUIET
    out, x = prefix_today(kind)
    if lit:
        out = [o.replace(QUIET, BRAND) if kind not in ("failed", "lost", "deaf") else o for o in out]
    done = kind in ("task", "message", "reminder", "timer")
    for i, (_, p, role) in enumerate(notes):
        last = i == len(notes) - 1
        if role in ("chord", "home"):
            cx = x + 14
            filled = fill and done
            out.append(circle(cx, MID, 13, stroke=tone, fill=tone if filled else "none"))
            ink = PAPER if filled else tone
            if sign and kind == "task":
                out.append(path(f"M{cx-5.5} {MID+0.5} L{cx-1.5} {MID+4.5} L{cx+6} {MID-4.5}", stroke=ink, width=2.2))
            elif sign and kind == "message":
                out.append(path(f"M{cx-5} {MID+5} L{cx+5} {MID-5} M{cx-1} {MID-5} h6 v6", stroke=ink, width=2.2))
            elif sign and kind == "reminder":
                out.append(REMINDER_SIGNS[reminder](cx, ink))
            elif sign and kind == "timer":
                out.append(path(f"M{cx} {MID} V{MID-7} M{cx} {MID} L{cx+5} {MID+3}", stroke=ink, width=2.2))
                out.append(circle(cx, MID, 1.6, stroke=ink, fill=ink, width=0))
            elif sign and kind == "cancelled":
                out.append(CANCEL_SIGNS[cancel](cx, ink))
            x += 34
        elif role == "fall":
            y = MID if i == 0 else MID + 8
            out.append(circle(x + 8, y, 7 if i == 0 else 11, stroke=INK))
            if last: out.append(line([(x + 1, y + 14), (x + 17, y - 14)], stroke=QUIET, width=2.4))
            x += 26
        elif role == "hang":
            r, y = 9, MID - (8 if i else 0)
            if fill and last:     # a question: half answered
                out.append(circle(x + 9, y, r, stroke=tone))
                out.append(path(f"M{x} {y} a{r} {r} 0 0 0 {2*r} 0 z", stroke="none", fill=tone, width=0))
            else:
                out.append(circle(x + 9, y, r, stroke=tone))
            if sign and last:      # a question mark's dot, below the open note
                out.append(circle(x + 9, y + 17, 3.2, stroke=tone, fill=tone, width=0))
            x += 22
        else:
            lift = -9 if kind == "message" and i == 1 else 0
            if pitch:
                lift = PITCH_LIFT.get(p, 0) if kind != "message" else (-9 if i == 1 else 0)
            out.append(circle(x + 7, MID + lift, 7, stroke=tone)); x += 20
    return svg("".join(out), width=252)


LIT = ["Create three tasks", "Send a message", "Set a reminder", "Start a timer", "You change your mind", "The internet is gone"]

SUBTLE = [
    ("Today", "How the examples look now",
     "Every card starts with the same four marks, and the endings differ only in how many small circles come before the big one. The strike-through for a failure is the one detail that sets an ending apart. Each direction below adds one more detail of that size, and keeps everything else as it is.",
     lambda s, lit=False: subtle(s, lit=lit)),
    ("Subtle 1", "Follow the pitch",
     "Only the positions change. The quick notes sit as high as they sound, as the message's leap already does: the reminder's bell sits high, the timer's tick-tock goes up and down, calling off steps down, tasks stay level. Nothing new to learn, and the shape of each ending gets its own outline.",
     lambda s, lit=False: subtle(s, pitch=True, lit=lit)),
    ("Subtle 2", "A sign in the last circle",
     "The closing circle carries a tiny sign, the way a failure carries its stroke: a check for tasks, an arrow out for a message, a bell for a reminder, a clock hand for a timer, an undo curve for calling off. A note kept stays empty. A question gets a dot under its open note. The most explicit of the three.",
     lambda s, lit=False: subtle(s, sign=True, lit=lit)),
    ("Subtle 3", "Fill what was done",
     "The closing circle is filled when something was done (tasks, a message, a reminder, a timer) and stays an outline when nothing was: a note kept, something called off. A question is half filled. One rule, readable from across the page, and it combines with either of the other two.",
     lambda s, lit=False: subtle(s, fill=True, lit=lit)),
]


CSS = f"""
@page {{ size: A4; margin: 0; }}
* {{ box-sizing: border-box; }}
body {{ margin: 0; -webkit-print-color-adjust: exact; print-color-adjust: exact; }}
.page {{ width: 210mm; height: 297mm; padding: 16mm 15mm 12mm; page-break-after: always; background: {PAPER}; color: {INK};
         font: 10pt/1.5 -apple-system, "SF Pro Text", Helvetica, sans-serif; overflow: hidden; }}
.kicker {{ font-weight: 600; font-size: 8pt; letter-spacing: .16em; text-transform: uppercase; color: {BRAND}; }}
h1 {{ font: 26pt/1.15 "New York", ui-serif, Georgia, serif; margin: 3mm 0 3mm; }}
p.lead {{ color: {QUIET}; max-width: 160mm; margin: 0 0 7mm; }}
.grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 4mm; }}
.card {{ background: {CARD}; border-radius: 14px; padding: 4mm 5mm 3.5mm; }}
.card svg {{ display: block; width: 100%; height: auto; }}
.card b {{ display: block; font-size: 10pt; margin-top: 1mm; }}
h2 {{ font: 600 8pt/1 -apple-system, Helvetica, sans-serif; letter-spacing: .16em; text-transform: uppercase; color: {QUIET}; margin: 7mm 0 3mm; }}
.grid.three {{ grid-template-columns: 1fr 1fr 1fr; gap: 3mm; }}
.card.small {{ padding: 2.5mm 4mm 2mm; }} .card.small b {{ font-size: 9pt; }}
"""


def build_sign():
    draw = lambda sc, lit=False, **k: subtle(sc, sign=True, lit=lit, **k)
    cards = "".join(f'<div class="card small">{draw(sc)}<b>{sc[0]}</b></div>' for sc in SCENES)
    lit = "".join(f'<div class="card small">{draw(sc, lit=True)}<b>{sc[0]}</b></div>' for sc in SCENES
                  if sc[0] in ("Set a reminder", "Start a timer", "You change your mind"))
    change = next(sc for sc in SCENES if sc[1] == "cancelled")
    remind = next(sc for sc in SCENES if sc[1] == "reminder")
    names = {"dash": "A dash: taken away", "cross": "A small cross", "back": "An arrow back", "bell": "A bell, in two parts", "dot": "One dot: a point in time"}
    alts = "".join(f'<div class="card small">{draw(change, cancel=k)}<b>{names[k]}</b></div>' for k in CANCEL_SIGNS)
    alts += "".join(f'<div class="card small">{draw(remind, reminder=k)}<b>{names[k]}</b></div>' for k in REMINDER_SIGNS)
    lead = ("Revised: the question's dot is a small filled circle; the reminder's bell is reduced to a dome and its clapper; "
            "changing your mind is a short dash, something taken away, which cannot be mistaken for the failure's stroke: "
            "that one is diagonal and reaches past the circle. The alternatives for those two are at the bottom.")
    page = (f'<section class="page"><div class="kicker">Subtle 2, revised</div><h1>A sign in the last circle</h1><p class="lead">{lead}</p>'
            f'<div class="grid three">{cards}</div><h2>While the sound plays</h2><div class="grid three">{lit}</div>'
            f'<h2>Alternatives: changing your mind, the reminder</h2><div class="grid three">{alts}</div></section>')
    html = f'<!doctype html><html><head><meta charset="utf-8"><title>Answer marks, signs</title><style>{CSS}</style></head><body>{page}</body></html>'
    source = os.path.join(HERE, "answer-marks-sign.html")
    open(source, "w").write(html)
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
                    f"--print-to-pdf={os.path.join(HERE, 'answer-marks-sign.pdf')}", "file://" + source], check=True, capture_output=True)
    print("wrote answer-marks-sign.pdf")


def build_subtle():
    pages = []
    for kicker, title, lead, draw in SUBTLE:
        cards = "".join(f'<div class="card small">{draw(sc)}<b>{sc[0]}</b></div>' for sc in SCENES)
        lit = "".join(f'<div class="card small">{draw(sc, lit=True)}<b>{sc[0]}</b></div>' for sc in SCENES if sc[0] in LIT)
        pages.append(f'<section class="page"><div class="kicker">{kicker}</div><h1>{title}</h1><p class="lead">{lead}</p>'
                     f'<div class="grid three">{cards}</div><h2>While the sound plays</h2><div class="grid three">{lit}</div></section>')
    html = f'<!doctype html><html><head><meta charset="utf-8"><title>Answer marks, subtle</title><style>{CSS}</style></head><body>{"".join(pages)}</body></html>'
    source = os.path.join(HERE, "answer-marks-subtle.html")
    open(source, "w").write(html)
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
                    f"--print-to-pdf={os.path.join(HERE, 'answer-marks-subtle.pdf')}", "file://" + source], check=True, capture_output=True)
    print("wrote answer-marks-subtle.pdf")


def build():
    pages = []
    for kicker, title, lead, draw in PAGES:
        cards = "".join(f'<div class="card">{draw(s)}<b>{s[0]}</b></div>' for s in SCENES)
        pages.append(f'<section class="page"><div class="kicker">{kicker}</div><h1>{title}</h1><p class="lead">{lead}</p><div class="grid">{cards}</div></section>')
    html = f'<!doctype html><html><head><meta charset="utf-8"><title>Answer marks</title><style>{CSS}</style></head><body>{"".join(pages)}</body></html>'
    source = os.path.join(HERE, "answer-marks.html")
    open(source, "w").write(html)
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
                    f"--print-to-pdf={os.path.join(HERE, 'answer-marks.pdf')}", "file://" + source], check=True, capture_output=True)
    print("wrote answer-marks.pdf")


if __name__ == "__main__":
    build()
    build_subtle()
    build_sign()
