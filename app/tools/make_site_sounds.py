#!/usr/bin/env python3
"""Writes the one sound file the web page has that the app does not: the click of the recorder's button.

The button is a small mechanical click: it goes down, and a moment later it comes back up, a
little quieter and brighter. Each half is a short burst of noise through a resonance, over a
soft knock.

(The page's other sound of its own, someone talking without words, is not a file: the page
makes it anew for every play, in site/assets/player.js.)

Usage: app/tools/make_site_sounds.py      (writes site/assets/sounds/press.wav)
"""
import math, os, random, struct, wave

RATE = 44100

class Resonance:
    """A two-pole resonator."""
    def __init__(self, width): self.r = math.exp(-math.pi * width / RATE); self.y1 = self.y2 = 0.0
    def step(self, x, freq):
        y = (1 - self.r) * x + 2 * self.r * math.cos(2 * math.pi * freq / RATE) * self.y1 - self.r * self.r * self.y2
        self.y2, self.y1 = self.y1, y
        return y

# The button: down at the start, up again RELEASE seconds later (the page's drawing follows this).
RELEASE = 0.11
noise = random.Random(5)
click = [0.0] * int(RATE * 0.3)
for start, level, ring, knock in ((0.0, 1.0, 2300, 170), (RELEASE, 0.9, 3100, 240)):
    body = Resonance(900)
    for i in range(int(RATE * 0.08)):
        time = i / RATE
        burst = noise.uniform(-1, 1) * math.exp(-time / 0.0035)
        click[int(RATE * start) + i] += level * (9.0 * body.step(burst, ring) + 0.5 * math.sin(2 * math.pi * knock * time) * math.exp(-time / 0.012))
peak = max(abs(s) for s in click)
path = os.path.join(os.path.dirname(__file__), "..", "..", "site", "assets", "sounds", "press.wav")
with wave.open(path, "wb") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(RATE)
    f.writeframes(b"".join(struct.pack("<h", int(s / peak * 0.5 * 32767)) for s in click))
