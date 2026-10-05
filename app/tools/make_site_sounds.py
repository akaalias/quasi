#!/usr/bin/env python3
"""Writes the one sound the web page has that the app does not: someone talking, without words.

The page's timeline plays a whole voice note. For the part where the person speaks it needs
something that sounds like speech but says nothing: a low murmur with the rhythm and vowels of
talking. It is synthesized here (a buzzing source through two moving resonances, in syllables),
so there is no recording of anyone and nothing to license.

Usage: app/tools/make_site_sounds.py      (writes site/assets/sounds/talking.wav and prints the
                                           loudness of 34 slices, for the bars in the timeline)
"""
import math, os, random, struct, wave

RATE = 44100
LENGTH = 3.6
random.seed(11)

# Syllables in three phrases, with short gaps inside a phrase and a breath between phrases.
VOWELS = [(700, 1150), (420, 1900), (310, 2200), (520, 950), (360, 820), (600, 1600)]
syllables, t = [], 0.05
for phrase in (5, 4, 6):
    for _ in range(phrase):
        length = random.uniform(0.13, 0.24)
        if t + length > LENGTH - 0.05:
            break
        syllables.append((t, length, random.choice(VOWELS), random.uniform(0.6, 1.0)))
        t += length + random.uniform(0.02, 0.06)
    t += random.uniform(0.22, 0.32)

def at(time):
    """Loudness and the two resonances at a moment: inside a syllable, or silence."""
    for start, length, vowel, level in syllables:
        if start <= time < start + length:
            x = (time - start) / length
            return level * math.sin(math.pi * x) ** 0.7, vowel
    return 0.0, None

class Resonance:
    """A two-pole resonator whose centre can move from sample to sample."""
    def __init__(self, width): self.r = math.exp(-math.pi * width / RATE); self.y1 = self.y2 = 0.0
    def step(self, x, freq):
        y = (1 - self.r) * x + 2 * self.r * math.cos(2 * math.pi * freq / RATE) * self.y1 - self.r * self.r * self.y2
        self.y2, self.y1 = self.y1, y
        return y

low, high = Resonance(90), Resonance(130)
f1, f2 = 500.0, 1400.0
phase, out, soft = 0.0, [], 0.0
for i in range(int(RATE * LENGTH)):
    time = i / RATE
    level, vowel = at(time)
    if vowel:                                   # glide towards this syllable's vowel
        f1 += (vowel[0] - f1) * 0.002
        f2 += (vowel[1] - f2) * 0.002
    pitch = 118 * (1 + 0.06 * math.sin(2 * math.pi * 0.7 * time) + 0.03 * math.sin(2 * math.pi * 2.3 * time)) * (1 - 0.04 * time / LENGTH)
    phase = (phase + pitch / RATE) % 1.0
    buzz = (2 * phase - 1) * level + 0.04 * level * random.uniform(-1, 1)      # the voice, with a little breath
    sample = 6.0 * low.step(buzz, f1) + 3.5 * high.step(buzz, f2)
    soft += 0.35 * (sample - soft)              # heard from a little away
    out.append(soft)

peak = max(abs(s) for s in out)
path = os.path.join(os.path.dirname(__file__), "..", "..", "site", "assets", "sounds", "talking.wav")
with wave.open(path, "wb") as f:
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(RATE)
    f.writeframes(b"".join(struct.pack("<h", int(s / peak * 0.42 * 32767)) for s in out))

slices = 34
size = len(out) // slices
loudness = [math.sqrt(sum(s * s for s in out[n * size:(n + 1) * size]) / size) for n in range(slices)]
top = max(loudness)
print([round(v / top, 2) for v in loudness])
