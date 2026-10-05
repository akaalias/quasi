#!/usr/bin/env python3
"""Writes the sounds the iPhone app plays as a recording passes each step.

Two instruments, two meanings. Wood (claves) is the machinery: the note arrived, the transcript
was made. A soft station chime is the conversation: the start of a recording asks a question, two
rising notes left hanging, and the end answers it.

    question              recording started
    wood_1, wood_2        captured, transcribed (rising)
    wood_fail_1, _2       captured or transcribed failed: a dull note that rings, and nothing follows
    ticking               the machinery at work: an even tick-tock, half a second apart, as one long
                          file so that the rhythm cannot drift
    answer_nothing        processed, nothing to do: the home note, plainly
    answer_tasks_N        N tasks added (1 to 5): N quick notes, then the home chord
    answer_failed         processing failed: the question falls away unanswered

Usage: tools/make_step_sounds.py      (writes QuasiPhone/Sounds/*.wav)
"""
import math, os, random, struct, wave

RATE = 44100
C5, E5, FS5, G5, AB5, B5, C6, E6, G6 = 523.25, 659.25, 739.99, 783.99, 830.61, 987.77, 1046.50, 1318.51, 1567.98
HALL = ((0.043, 0.20), (0.071, 0.14), (0.113, 0.10), (0.167, 0.07), (0.229, 0.04))   # delay (s), level


def wood(freq, decay=30, click=0.22, overtone=0.25, hollow=0.0, seconds=0.5):
    """Claves: a quickly dying tone, one overtone and the noise of the strike."""
    random.seed(7)
    out, noise = [], 0.0
    for i in range(int(RATE * seconds)):
        t = i / RATE
        rise = 0.5 - 0.5 * math.cos(math.pi * min(1.0, t / 0.003))
        s = math.exp(-t * decay) * math.sin(2 * math.pi * freq * t)
        s += overtone * math.exp(-t * decay * 2.2) * math.sin(2 * math.pi * freq * 2.42 * t)
        s += hollow * math.exp(-t * decay * 0.7) * math.sin(2 * math.pi * freq * 0.5 * t)
        noise += 0.18 * (random.uniform(-1, 1) - noise)
        out.append(rise * (s + click * math.exp(-t * 380) * noise))
    return out


def chime(freq, level=1.0, seconds=1.4, decay=2.6, glow=0.55):
    """A soft, muffled station chime: a mellow tone with a gentle onset and a slight shimmer."""
    out = []
    for i in range(int(RATE * seconds)):
        t = i / RATE
        rise = 0.5 - 0.5 * math.cos(math.pi * min(1.0, t / 0.018))
        body = math.exp(-t * decay)
        s = sum(0.5 * body * math.sin(2 * math.pi * freq * d * t + glow * body * math.sin(2 * math.pi * freq * d * t))
                for d in (0.998, 1.002))
        s += 0.10 * math.exp(-t * decay * 2.5) * math.sin(2 * math.pi * freq * 2 * t)
        out.append(rise * s)
    for _ in range(2):                      # roll off the highs, as through a ceiling loudspeaker
        last, soft = 0.0, []
        for s in out:
            last += 0.22 * (s - last)
            soft.append(last)
        out = soft
    return [level * 2.2 * s for s in out]


def render(name, events, loudness=0.75):
    """Mixes (start time in seconds, samples) into one file, with a little hall."""
    length = int(RATE * (max(t + len(s) / RATE for t, s in events) + 0.4))
    out = [0.0] * length
    for t, samples in events:
        offset = int(RATE * t)
        for i, s in enumerate(samples):
            out[offset + i] += s
    dry = out[:]
    for delay, level in HALL:
        offset = int(RATE * delay)
        for i in range(length - offset):
            out[i + offset] += dry[i] * level
    fade = int(RATE * 0.08)
    for i in range(fade):
        out[-1 - i] *= i / fade
    peak = max(abs(s) for s in out)
    with wave.open(os.path.join(FOLDER, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(s / peak * loudness * 32767)) for s in out))


FOLDER = os.path.join(os.path.dirname(__file__), "..", "QuasiPhone", "Sounds")
os.makedirs(FOLDER, exist_ok=True)

# The question: two rising notes, the second a leading tone that wants to resolve upwards.
render("question", [(0.0, chime(G5, seconds=0.5, decay=5)), (0.22, chime(B5, seconds=1.0, decay=3))])

# The machinery, climbing towards the answer.
render("wood_1", [(0.0, wood(E6))])
render("wood_2", [(0.0, wood(G6))])
# A failure sits a tritone below the note before it.
render("wood_fail_1", [(0.0, wood(B5 / math.sqrt(2), decay=4.5, click=0.15, overtone=0.05, hollow=0.45, seconds=1.5))])
render("wood_fail_2", [(0.0, wood(E6 / math.sqrt(2), decay=4.5, click=0.15, overtone=0.05, hollow=0.45, seconds=1.5))])

# The machinery at work: two quiet, dry ticks a little apart in pitch, alternating every half second.
# One file of just under 30 seconds (the longest a system sound may be): played as separate
# sounds, the gaps between them came out uneven.
tick, tock = wood(1250, decay=95, click=0.35, overtone=0.1, seconds=0.12), wood(980, decay=95, click=0.35, overtone=0.1, seconds=0.12)
render("ticking", [(beat * 0.5, tick if beat % 2 == 0 else tock) for beat in range(58)], loudness=0.16)

# The answers.
home_chord = [chime(C6), chime(E6, 0.6), chime(G5, 0.6)]
render("answer_nothing", [(0.0, chime(C6, 0.8, seconds=1.0, decay=3.5))], loudness=0.6)
for count in range(1, 6):
    pickups = [(i * 0.2, chime(G5, seconds=0.4, decay=7)) for i in range(count)]
    landing = (count - 1) * 0.2 + 0.26
    render(f"answer_tasks_{count}", pickups + [(landing, note) for note in home_chord])
render("answer_failed", [(0.0, chime(AB5, seconds=0.6, decay=4)), (0.35, chime(FS5 / 1.5, seconds=2.0, decay=1.5, glow=0.3))])
