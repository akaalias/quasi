#!/usr/bin/env python3
"""Builds the three design-direction PDFs for the iPhone app: one HTML file per direction,
printed to PDF with headless Chrome.

Usage: design/directions/make_directions.py
"""
import os, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

BASE_CSS = """
@page { size: A4; margin: 0; }
* { box-sizing: border-box; }
body { margin: 0; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
.page { width: 210mm; height: 297mm; padding: 17mm 16mm 14mm; page-break-after: always; position: relative;
        background: var(--paper); color: var(--text); font-family: var(--doc-body); font-size: 10.5pt; line-height: 1.5; overflow: hidden; }
.kicker { font: 600 8pt/1 -apple-system, "SF Pro Text", Helvetica, sans-serif; letter-spacing: .16em; text-transform: uppercase; color: var(--accent); }
h1 { font: var(--doc-h1); margin: 6mm 0 3mm; letter-spacing: -0.01em; }
h2 { font: var(--doc-h2); margin: 0 0 3mm; }
h3 { font: 600 9pt/1.3 -apple-system, "SF Pro Text", Helvetica, sans-serif; letter-spacing: .08em; text-transform: uppercase; color: var(--soft); margin: 6mm 0 2mm; }
p { margin: 0 0 3mm; }
.lead { font-size: 13pt; line-height: 1.45; max-width: 150mm; }
.foot { position: absolute; left: 16mm; right: 16mm; bottom: 9mm; display: flex; justify-content: space-between;
        font: 7.5pt -apple-system, Helvetica, sans-serif; color: var(--soft); }
table { border-collapse: collapse; width: 100%; font-size: 9.5pt; }
td, th { text-align: left; vertical-align: top; padding: 2.2mm 3mm 2.2mm 0; border-top: .3mm solid var(--rule); }
th { width: 34mm; font-weight: 600; color: var(--soft); }
ul { margin: 0 0 3mm; padding-left: 5mm; } li { margin-bottom: 1.4mm; break-inside: avoid; }
.cols { display: grid; grid-template-columns: 1fr 1fr; gap: 9mm; }
.phones { display: grid; grid-template-columns: repeat(3, 1fr); gap: 7mm; margin-top: 5mm; }
.shot { display: flex; flex-direction: column; align-items: center; }
.cap { margin-top: 4mm; font-size: 8.6pt; line-height: 1.4; color: var(--text); width: 56mm; }
.cap b { display: block; font: 600 8pt -apple-system, Helvetica, sans-serif; letter-spacing: .06em; text-transform: uppercase; color: var(--accent); margin-bottom: 1mm; }
.swatches { display: flex; gap: 3mm; margin: 2mm 0 0; } .sw { width: 13mm; height: 13mm; border-radius: 3mm; border: .3mm solid var(--rule); }
.type { font: var(--sample); margin: 2mm 0 0; }

/* ---- the phone ---- */
.phone { width: 56mm; height: 119mm; border-radius: 9mm; border: 1.6mm solid #0c0c0d; background: var(--bg); color: var(--ink);
         font-family: var(--ui); font-size: 6.6pt; line-height: 1.35; position: relative; overflow: hidden; }
.island { position: absolute; top: 2mm; left: 50%; transform: translateX(-50%); width: 17mm; height: 4.6mm; border-radius: 3mm; background: #000; z-index: 9;
          display: flex; align-items: center; justify-content: space-between; padding: 0 1.5mm; color: #fff; font: 600 5pt -apple-system, sans-serif; }
.island.wide { width: 30mm; }
.sb { height: 8.5mm; display: flex; justify-content: space-between; align-items: flex-end; padding: 0 5mm 1mm; font: 600 5.6pt -apple-system, sans-serif; }
.pad { padding: 0 3.6mm; }
.row { display: flex; align-items: center; justify-content: space-between; gap: 2mm; }
.muted { color: var(--mute); } .accent { color: var(--accent); }
.title { font: var(--title); margin: 1.5mm 0 2mm; }
.chip { display: inline-block; padding: .5mm 1.6mm; border-radius: 3mm; background: var(--chip); font-size: 5.6pt; margin: .6mm .6mm 0 0; }
.card { background: var(--surface); border-radius: 3mm; padding: 2.4mm 2.6mm; margin-bottom: 2mm; }
.rule { border-top: .2mm solid var(--line); margin: 2mm 0; }
.btn { display: inline-block; padding: 1.1mm 2.6mm; border-radius: 4mm; background: var(--chip); font-weight: 600; font-size: 5.8pt; margin-right: 1mm; }
.btn.primary { background: var(--accent); color: var(--on-accent); }
.wave { display: flex; align-items: center; gap: .5mm; height: 12mm; }
.wave i { display: block; width: .7mm; border-radius: 1mm; background: var(--accent); }
.sheet { position: absolute; left: 0; right: 0; bottom: 0; background: var(--sheet); border-radius: 6mm 6mm 0 0; padding: 2mm 3.6mm 4mm; box-shadow: 0 -2mm 8mm rgba(0,0,0,.18); }
.grab { width: 9mm; height: 1mm; border-radius: 1mm; background: var(--line); margin: 0 auto 2.4mm; }
.dim { position: absolute; inset: 0; background: rgba(0,0,0,.28); }
.lock { background: linear-gradient(165deg, var(--lock1), var(--lock2)); color: #fff; }
.clock { text-align: center; font: 300 22pt -apple-system, sans-serif; margin-top: 7mm; line-height: 1; }
.date { text-align: center; font: 600 6pt -apple-system, sans-serif; opacity: .85; margin-top: 12mm; }
.la { position: absolute; left: 2.4mm; right: 2.4mm; background: var(--la); color: var(--la-ink); border-radius: 5mm; padding: 2.6mm 3mm; }
.toggle { width: 6.4mm; height: 3.8mm; border-radius: 2mm; background: var(--line); position: relative; flex: none; }
.toggle.on { background: var(--accent); } .toggle::after { content: ""; position: absolute; top: .4mm; left: .4mm; width: 3mm; height: 3mm; border-radius: 50%; background: #fff; }
.toggle.on::after { left: 3mm; }
.set { background: var(--surface); border-radius: 3mm; padding: 0 2.6mm; margin-bottom: 2.4mm; }
.set .row { padding: 1.9mm 0; border-top: .2mm solid var(--line); } .set .row:first-child { border-top: 0; }
.sec { font: 600 5.2pt -apple-system, sans-serif; letter-spacing: .08em; text-transform: uppercase; color: var(--mute); margin: 2.4mm 0 1.2mm 1mm; }
.dot { display: inline-block; width: 1.6mm; height: 1.6mm; border-radius: 50%; background: var(--accent); vertical-align: middle; }
.dot.off { background: var(--line); } .dot.red { background: #e5484d; }
.tabbar { position: absolute; left: 6mm; right: 6mm; bottom: 3mm; height: 9mm; border-radius: 5mm; background: rgba(255,255,255,.72); border: .2mm solid rgba(0,0,0,.08);
          box-shadow: 0 1mm 4mm rgba(0,0,0,.12); display: flex; align-items: center; justify-content: space-around; font: 600 5.2pt -apple-system, sans-serif; }
.acc { position: absolute; left: 6mm; right: 6mm; bottom: 13.5mm; height: 8mm; border-radius: 4mm; background: rgba(255,255,255,.82); border: .2mm solid rgba(0,0,0,.08);
       box-shadow: 0 1mm 4mm rgba(0,0,0,.12); display: flex; align-items: center; justify-content: space-between; padding: 0 3mm; font-weight: 600; }
mark { background: var(--mark); color: inherit; padding: 0 .4mm; border-radius: .6mm; }
"""

def wave(n=34, seed=3):
    heights, x = [], seed
    for _ in range(n):
        x = (x * 73 + 41) % 97
        heights.append(1.5 + (x % 10))
    return '<div class="wave">' + "".join(f'<i style="height:{h}mm"></i>' for h in heights) + "</div>"

def phone(inner, cls="", island=""):
    return f'<div class="phone {cls}"><div class="island {"wide" if island else ""}">{island}</div>{inner}</div>'

SB = '<div class="sb"><span>9:41</span><span>􀙇 􀛨</span></div>'.replace("􀙇 􀛨", "●●● ▮")

def shot(screen, title, text):
    return f'<div class="shot">{screen}<div class="cap"><b>{title}</b>{text}</div></div>'

def page(direction, number, body):
    return (f'<div class="page">{body}<div class="foot"><span>Quasi iPhone app · design direction {direction["letter"]}: {direction["name"]}</span>'
            f'<span>{number} / 4</span></div></div>')

# =====================================================================================  A  Logbook
A = {
    "letter": "A", "name": "Logbook", "file": "A-logbook",
    "vars": """--paper:#FBF8F2; --text:#1E1B16; --soft:#7A7265; --rule:#E4DCCD; --accent:#C8551F;
      --doc-body: "New York", "Iowan Old Style", Georgia, serif; --doc-h1: 400 34pt/1.05 "New York", "Iowan Old Style", Georgia, serif;
      --doc-h2: 400 17pt/1.2 "New York", "Iowan Old Style", Georgia, serif; --sample: 400 15pt/1.3 "New York", "Iowan Old Style", Georgia, serif;
      --bg:#FBF8F2; --surface:#F1EBDF; --sheet:#FFFDF9; --ink:#1E1B16; --mute:#8A8173; --line:#DDD3C1; --chip:#EDE5D6; --on-accent:#fff; --mark:#F6D9B8;
      --ui: -apple-system, "SF Pro Text", Helvetica, sans-serif; --title: 400 15pt/1.1 "New York", "Iowan Old Style", Georgia, serif;
      --lock1:#3B2A1E; --lock2:#15100C; --la:rgba(251,248,242,.94); --la-ink:#1E1B16;""",
    "idea": "The app is a quiet book of what you said and what was done about it. You open it rarely, and when you do, it reads like a page, not a dashboard.",
    "bets": "That the only question you ever bring to the screen is “did that land, and what did it do with it?” Everything that is not an answer to that question moves off the home view.",
    "facts": [
        ("Structure", "One screen: a newest-first log, grouped by day. Live capture rises over it as a sheet. Settings behind one button."),
        ("Autonomy", "Acts on its own, then shows a receipt. Every receipt has Undo and “Not a task”; every plain note has “Make this a task”."),
        ("Type", "New York (Apple's serif) for everything you said; SF Pro for everything the app says. The two voices never mix."),
        ("Colour", "Warm paper, dark ink, one burnt-orange accent that only ever means “the app did something”."),
        ("Sound and touch", "The full sequence stays: question, wood, answer. Follows the silent switch; the tap pattern carries the same message."),
        ("Lock Screen", "A Live Activity per recording that ends as a receipt for 15 minutes. Between recordings: nothing, or a small “last note” widget."),
    ],
}
A["screens1"] = [
    shot(phone(SB + f"""<div class="pad">
      <div class="row"><span class="muted">Recorder nearby · 82%</span><span class="muted">⚙︎</span></div>
      <div class="title">Today</div>
      <div class="muted">14:03</div>
      <div style="font:var(--title);font-size:8.4pt;line-height:1.35;margin:.6mm 0 1mm">“I should probably just test that on the train on Thursday. Oh, yes, add that as a task.”</div>
      <div class="accent" style="font-weight:600">✓ Added · Test recorder after airplane mode</div>
      <div class="muted">Thursday · Work</div>
      <div class="rule"></div>
      <div class="muted">11:20</div>
      <div style="font:var(--title);font-size:8.4pt;line-height:1.35;margin:.6mm 0 1mm">“The light was really nice around five. I want to remember that.”</div>
      <div class="muted">Kept as a note</div>
      <div class="rule"></div>
      <div class="muted">08:47</div>
      <div style="font:var(--title);font-size:8.4pt;line-height:1.35;margin:.6mm 0 1mm">“New task, call the school office tomorrow at three.”</div>
      <div class="accent" style="font-weight:600">✓ Added · Call the school office</div>
      <div class="muted">Tomorrow 15:00</div>
      <div class="title" style="margin-top:4mm;font-size:11pt" >Yesterday</div>
      <div class="muted">18:32</div>
      <div style="font:var(--title);font-size:8.4pt;line-height:1.35;margin:.6mm 0 1mm">“Remind me to order a new water filter for the kitchen, we're almost out.”</div>
    </div>"""), "Home: the log", "Each entry is your own sentence, then one line saying what the app did with it. No buttons, no waveform, no settings."),
    shot(phone(SB + f"""<div class="pad"><div class="title">Today</div><div class="muted">14:03</div>
      <div style="font:var(--title);font-size:8.4pt;line-height:1.35">“…add that as a task.”</div></div><div class="dim"></div>
      <div class="sheet" style="height:62mm"><div class="grab"></div>
      <div class="row"><span><span class="dot red"></span> <b>Recording</b></span><span class="muted" style="font-variant-numeric:tabular-nums">0:42</span></div>
      {wave()}
      <div style="font:var(--title);font-size:8.6pt;line-height:1.4;margin-top:1.5mm">So I was at the bank this morning and they need a form from me, the one for the joint account<span class="muted"> and they said it has to</span></div>
      </div>""", island='<span style="color:#ff5a4d">●</span><span>0:42</span>'),
      "Live: a sheet over the log", "If you unlock while recording, the capture view is already up. Swipe it down and the log is underneath. It leaves when the note is done."),
    shot(phone(SB + f"""<div class="pad">
      <div class="row"><span class="accent">‹ Today</span><span class="muted">•••</span></div>
      <div class="muted" style="margin-top:2mm">Monday 14:03 · 38 seconds</div>
      <div style="font:var(--title);font-size:8.6pt;line-height:1.45;margin:1.5mm 0 3mm">I've been thinking about the battery thing on the recorder. So the phone holds the link all day and it costs maybe eight percent a day, which is fine. What I really don't know is how it behaves when I'm traveling and the phone is in airplane mode and then comes back. <mark>I should probably just test that on the train on Thursday. Oh, yes, add that as a task.</mark></div>
      <div class="card"><div class="accent" style="font-weight:600;margin-bottom:1mm">✓ Added to Todoist</div>
        <div style="font-weight:600;font-size:7.4pt">Test recorder after airplane mode</div>
        <div class="rule"></div>
        <div class="row"><span class="muted">Due</span><span>Thu 8 Oct</span></div>
        <div class="row"><span class="muted">Project</span><span>Work</span></div>
        <div class="row"><span class="muted">Priority</span><span>None said</span></div>
      </div>
      <div><span class="btn">Undo</span><span class="btn">Edit</span><span class="btn">Not a task</span></div>
    </div>"""), "A note: heard, decided, done", "The sentence that triggered the task is marked in the transcript, so the reason is visible. Every field can be changed; the task can be undone."),
]
A["screens2"] = [
    shot(phone(f"""<div class="clock">9:41</div><div class="date" style="margin-top:2mm">Monday 5 October</div>
      <div class="la" style="top:44mm"><div class="row"><span><span class="dot red"></span> <b>Recording</b></span><b style="font-variant-numeric:tabular-nums">0:42</b></div></div>
      <div class="la" style="top:62mm"><div class="muted" style="font-size:5.4pt">A MOMENT LATER · STAYS 15 MIN</div>
        <div style="font-weight:600;margin-top:.6mm">✓ Added to Todoist</div><div>Test recorder after airplane mode · Thursday</div></div>
      <div class="la" style="top:86mm"><div class="muted" style="font-size:5.4pt">WITH “HIDE TEXT ON LOCK SCREEN”</div>
        <div style="font-weight:600;margin-top:.6mm">✓ One task added</div></div>
      """, cls="lock", island='<span style="color:#ff5a4d">●</span><span>0:42</span>'),
      "Lock Screen: a receipt, then gone", "One fact per glance. The activity belongs to a recording, not to the connection, and its last state is the receipt."),
    shot(phone(SB + """<div class="pad"><div class="row"><b style="font-size:8pt">Settings</b><span class="accent"><b>Done</b></span></div>
      <div class="sec">Recorder</div><div class="set"><div class="row"><span>Comulytic Note Pro</span><span class="muted">Nearby · 82%</span></div><div class="row"><span>Fetch stored recordings</span><span class="muted">›</span></div></div>
      <div class="sec">Understanding</div><div class="set"><div class="row"><span>Language</span><span class="muted">English ›</span></div><div class="row"><span>Claude</span><span class="muted">Connected ›</span></div></div>
      <div class="sec">Tasks</div><div class="set"><div class="row"><span>Todoist</span><span class="muted">Connected ›</span></div><div class="row"><span>When unsure</span><span class="muted">Keep as a note ›</span></div></div>
      <div class="sec">Feedback</div><div class="set"><div class="row"><span>Sounds</span><span class="muted">Every step ›</span></div><div class="row"><span>Taps</span><div class="toggle on"></div></div><div class="row"><span>Play when silenced</span><div class="toggle"></div></div><div class="row"><span>Hide text on Lock Screen</span><div class="toggle"></div></div></div>
      </div>"""), "Settings: one sheet", "Four groups, opened from the gear. Keys are entered once and then just read “Connected”. The recorder is found without being asked for."),
    shot(phone(SB + """<div class="pad"><div class="title">Today</div>
      <div class="muted">16:10</div>
      <div style="font:var(--title);font-size:8.4pt;line-height:1.35;margin:.6mm 0 1mm">“Add a task, send the contract to the lawyer by Friday.”</div>
      <div style="font-weight:600">Not added yet · Todoist didn't answer</div>
      <div class="muted" style="margin-bottom:1.4mm">Your note is safe. Trying again in a minute.</div>
      <span class="btn">Try now</span>
      <div class="rule"></div>
      <div class="muted">15:52</div>
      <div class="muted" style="font:var(--title);font-size:8.4pt;line-height:1.35;margin:.6mm 0 1mm;font-style:italic">A recording was made, but its audio did not reach the phone.</div>
      <div class="muted" style="margin-bottom:1.4mm">It is still on the recorder.</div>
      <span class="btn">Fetch it</span>
      <div class="rule"></div>
      <div class="muted">14:03</div>
      <div style="font:var(--title);font-size:8.4pt;line-height:1.35;margin:.6mm 0 1mm">“…add that as a task.”</div>
      <div class="accent" style="font-weight:600">✓ Added · Test recorder after airplane mode</div>
    </div>"""), "When something fails", "A failure is an entry in the same log, in plain words, with the one thing to do. The first sentence is always that the note is safe."),
]
A["why"] = [
    "The research's main finding is that the app should be where you check what happened, with the moment itself carried by sound, touch and the Lock Screen. This direction takes that literally: the home view is the audit log, and nothing else.",
    "Voice Memos, Apple Notes and Things all use a single list with capture rising from the same screen. Published guidance on AI agents asks for a chronological record of actions, each with its reason and an undo. Your transcript list is already most of that.",
    "Two typefaces separate the two voices: what you said (serif) and what the app did (sans, accent). Apple ships New York for long-form reading, so this costs nothing and keeps Dynamic Type.",
]
A["risks"] = [
    "It is the least “app-like” of the three. There is no dashboard to admire, and no at-a-glance device panel.",
    "The live view is one step removed. That is deliberate, but if you often watch the waveform, B serves you better.",
    "It acts without asking. A wrong task is one tap to undo, but it will exist in Todoist for a moment.",
]
A["first"] = ["The log with the heard / done line per note", "The note view with marked source sentence, Undo and “Not a task”", "Settings as one sheet", "Live Activity per recording, ending as a receipt"]

# =====================================================================================  B  Instrument
B = {
    "letter": "B", "name": "Instrument", "file": "B-instrument",
    "vars": """--paper:#0F1013; --text:#E9E5DB; --soft:#8C8A84; --rule:#2A2C32; --accent:#F0A23A;
      --doc-body: -apple-system, "SF Pro Text", Helvetica, sans-serif; --doc-h1: 700 32pt/1.05 -apple-system, "SF Pro Display", Helvetica, sans-serif;
      --doc-h2: 600 16pt/1.2 -apple-system, "SF Pro Display", Helvetica, sans-serif; --sample: 500 14pt/1.3 "SF Mono", ui-monospace, Menlo, monospace;
      --bg:#101114; --surface:#1B1D22; --sheet:#1F2127; --ink:#ECE8DF; --mute:#85837D; --line:#30333A; --chip:#272A31; --on-accent:#1a1205; --mark:#4A3712;
      --ui: -apple-system, "SF Pro Text", Helvetica, sans-serif; --title: 700 11pt/1.1 -apple-system, "SF Pro Display", Helvetica, sans-serif;
      --lock1:#1c1d22; --lock2:#050506; --la:rgba(24,25,29,.96); --la-ink:#ECE8DF;""",
    "idea": "The app is the faceplate of a small machine. It shows the signal path from your voice to your to-do list, and which stage a note is at, the same path the sounds already trace.",
    "bets": "That trust comes from seeing the chain. If you can see recorder, capture, transcript, agent and Todoist as five lamps, you always know where a note is and where one stopped.",
    "facts": [
        ("Structure", "A “now” screen with the signal path and one large readout. The log lives in a sheet you pull up from the bottom."),
        ("Autonomy", "Acts on its own. Each note keeps a trace: every stage with its time and result, like a flight recorder."),
        ("Type", "SF Pro for labels, SF Mono for anything measured: times, durations, battery, counts."),
        ("Colour", "Near-black, warm off-white, one amber for “signal present”. Red appears only for a broken chain."),
        ("Sound and touch", "The full machinery, including the working ticks. Each sound has a lamp: what you hear is what lights up."),
        ("Lock Screen", "A Live Activity per recording showing the five lamps filling in. A Lock Screen widget shows chain health between recordings."),
    ],
}
def chain(lit, bad=None, labels=True):
    names = ["Recorder", "Captured", "Transcript", "Agent", "Todoist"]
    cells = []
    for i, name in enumerate(names):
        cls = "dot red" if bad == i else ("dot" if i < lit else "dot off")
        label = f'<div class="muted" style="font-size:4.6pt;margin-top:.8mm">{name}</div>' if labels else ""
        cells.append(f'<div style="text-align:center;flex:1"><span class="{cls}" style="width:2.2mm;height:2.2mm"></span>{label}</div>')
    return '<div style="display:flex;align-items:flex-start;margin:2mm 0">' + "".join(cells) + "</div>"
MONO = 'font-family:\'SF Mono\',ui-monospace,Menlo,monospace'
B["screens1"] = [
    shot(phone(SB + f"""<div class="pad">
      <div class="row"><span class="muted" style="letter-spacing:.1em;font-size:5.2pt">QUASI</span><span class="muted">⚙︎</span></div>
      {chain(1)}
      <div style="text-align:center;margin:7mm 0 1mm;font:700 20pt -apple-system,sans-serif;letter-spacing:.04em">READY</div>
      <div class="muted" style="text-align:center;{MONO}">last heard 14:03 · 6 today</div>
      <div class="card" style="margin-top:8mm"><div class="row"><span class="muted">RECORDER</span><span style="{MONO}">82%</span></div>
        <div style="height:1.2mm;border-radius:1mm;background:var(--line);margin:1.4mm 0"><div style="width:82%;height:100%;border-radius:1mm;background:var(--accent)"></div></div>
        <div class="row"><span class="muted">LINK</span><span style="{MONO}">held 3 h 12 m</span></div></div>
      </div>
      <div class="sheet" style="height:27mm"><div class="grab"></div>
        <div class="row"><b>Log</b><span class="muted" style="{MONO}">6 today</span></div>
        <div class="rule"></div>
        <div class="row"><span style="{MONO}" class="muted">14:03</span><span style="flex:1">Test recorder after airplane mode</span><span class="accent">✓</span></div>
        <div class="row" style="margin-top:1mm"><span style="{MONO}" class="muted">11:20</span><span style="flex:1" class="muted">The light was really nice…</span><span class="muted">–</span></div>
      </div>"""), "Now: idle", "Five lamps for the chain, one word for the state. The newest entries of the log peek up from the bottom."),
    shot(phone(SB + f"""<div class="pad">
      <div class="row"><span class="muted" style="letter-spacing:.1em;font-size:5.2pt">QUASI</span><span class="muted">⚙︎</span></div>
      {chain(2)}
      <div style="text-align:center;margin:4mm 0 0;font:700 20pt 'SF Mono',ui-monospace,Menlo,monospace;color:var(--accent)">00:42</div>
      <div class="muted" style="text-align:center;letter-spacing:.14em;font-size:5.2pt"><span class="dot red"></span> RECORDING</div>
      <div style="margin:4mm 0 2mm">{wave(40, 5)}</div>
      <div class="card" style="{MONO};font-size:6pt;line-height:1.5">so i was at the bank this morning and they need a form from me the one for the joint account<span class="accent">▍</span></div>
      </div>""", island='<span style="color:#F0A23A">●</span><span>00:42</span>'),
      "Now: recording", "The readout becomes the timer and the second lamp lights, at the moment you hear the opening notes."),
    shot(phone(SB + f"""<div class="pad"><div class="row"><span class="muted" style="letter-spacing:.1em;font-size:5.2pt">QUASI</span><span class="muted">⚙︎</span></div>{chain(1, labels=False)}</div>
      <div class="sheet" style="height:98mm"><div class="grab"></div>
        <div class="row"><b style="font-size:8pt">Log</b><span class="muted">Today ▾</span></div>
        <div class="rule"></div>
        {"".join(f'''<div class="row" style="margin-bottom:.4mm"><span style="{MONO}" class="muted">{t}</span><span style="flex:1;{'color:var(--mute)' if g == '–' else ''}">{title}</span><span class="{c}">{g}</span></div><div style="margin:0 0 1.6mm 9mm">{chain(l, bad, labels=False).replace('margin:2mm 0','margin:0;width:22mm')}</div>'''
           for t, title, g, c, l, bad in [
             ("16:10", "Send the contract to the lawyer", "!", "", 4, 4),
             ("15:52", "No audio arrived", "!", "", 1, 1),
             ("14:03", "Test recorder after airplane mode", "✓", "accent", 5, None),
             ("11:20", "The light was really nice…", "–", "muted", 4, None),
             ("08:47", "Call the school office", "✓", "accent", 5, None),
             ("08:15", "Order a new water filter", "✓", "accent", 5, None)])}
      </div>"""), "The log, pulled up", "Every row carries its own five lamps, so you can see at a glance how far each note got and where one stopped."),
]
B["p3"] = "A note's trace, the Lock Screen, and settings"
B["screens2"] = [
    shot(phone(SB + f"""<div class="pad"><div class="row"><span class="accent">‹ Log</span><span class="muted">•••</span></div>
      <div style="font:var(--title);margin:2mm 0 .5mm">Test recorder after airplane mode</div>
      <div class="muted" style="{MONO}">Mon 5 Oct 14:03</div>
      <div class="card" style="margin-top:2.4mm;{MONO};font-size:5.9pt;line-height:1.7">
        <div class="row"><span><span class="dot"></span> Captured</span><span class="muted">38.2 s audio</span></div>
        <div class="row"><span><span class="dot"></span> Transcript</span><span class="muted">1.1 s · 71 words</span></div>
        <div class="row"><span><span class="dot"></span> Agent</span><span class="muted">2.0 s · task</span></div>
        <div class="row"><span><span class="dot"></span> Todoist</span><span class="muted">0.4 s · added</span></div></div>
      <div class="card"><div class="row"><span class="muted">DUE</span><span style="{MONO}">Thu 08 Oct</span></div><div class="row"><span class="muted">PROJECT</span><span>Work</span></div><div class="row"><span class="muted">PRIORITY</span><span class="muted">—</span></div></div>
      <div class="muted" style="font-size:6pt;line-height:1.45;margin-bottom:2mm">…how it behaves when the phone is in airplane mode and then comes back. <mark style="color:var(--ink)">I should probably just test that on the train on Thursday. Oh, yes, add that as a task.</mark></div>
      <span class="btn primary">Undo</span><span class="btn">Edit</span><span class="btn">Run again</span>
      </div>"""), "A note: its trace", "What happened at each stage and how long it took. “Run again” re-reads the note after you change a setting or a key."),
    shot(phone(f"""<div class="clock">9:41</div><div class="date" style="margin-top:2mm">Monday 5 October</div>
      <div class="la" style="top:44mm"><div class="row"><span style="letter-spacing:.12em;font-size:5.2pt"><span class="dot red"></span> RECORDING</span><b style="{MONO};color:var(--accent)">00:42</b></div>{chain(2, labels=False)}</div>
      <div class="la" style="top:66mm"><div class="row"><span style="letter-spacing:.12em;font-size:5.2pt" class="muted">DONE 14:03</span><span class="accent">✓</span></div>{chain(5, labels=False)}<div>Test recorder after airplane mode</div></div>
      <div class="la" style="top:93mm;padding:2mm 3mm"><div class="row"><span class="muted" style="font-size:5.2pt;letter-spacing:.1em">WIDGET · CHAIN OK</span><span style="{MONO}">82%</span></div></div>
      """, cls="lock", island='<span style="color:#F0A23A">●</span><span>00:42</span>'),
      "Lock Screen: the lamps", "The same five lamps fill in as the sounds play. A small widget shows that the chain is healthy when nothing is recording."),
    shot(phone(SB + f"""<div class="pad"><div class="row"><b style="font-size:8pt">Panel</b><span class="accent"><b>Done</b></span></div>
      <div class="sec">Sounds, per stage</div><div class="set">
        <div class="row"><span>Start (the question)</span><div class="toggle on"></div></div><div class="row"><span>Captured</span><div class="toggle on"></div></div>
        <div class="row"><span>Transcribed</span><div class="toggle on"></div></div><div class="row"><span>Working ticks</span><div class="toggle on"></div></div>
        <div class="row"><span>Answer</span><div class="toggle on"></div></div><div class="row"><span>Play when silenced</span><div class="toggle"></div></div></div>
      <div class="sec">Chain</div><div class="set"><div class="row"><span>Recorder</span><span class="muted" style="{MONO}">TN12 · 2.3.5</span></div><div class="row"><span>Transcript</span><span class="muted">English ›</span></div>
        <div class="row"><span>Agent</span><span class="muted">Claude · key set ›</span></div><div class="row"><span>Todoist</span><span class="muted">Token set ›</span></div></div>
      <div class="sec">Link</div><div class="set"><div class="row"><span>Hold while locked</span><div class="toggle on"></div></div></div>
      </div>"""), "Settings: the panel", "Settings follow the chain too: one row per stage, and a switch for each sound so you can thin out the middle once you trust it."),
]
B["why"] = [
    "You already built a language in sound: a start, two mechanical steps, working ticks and an answer. This direction gives each sound a matching light, so the screen, the Lock Screen and the sounds all describe the same five-stage path.",
    "The agent guidance in the research asks that a system's state be readable at a glance and that every action leave an audit trail. A per-note trace is the most literal form of that, and it is also the best debugging tool while the project is still changing weekly.",
    "The research found almost nothing on how comparable apps show device state. This direction answers that gap directly instead of hiding it: the recorder and the link are the first lamp.",
]
B["risks"] = [
    "The research did not find sourced examples of this dark, hardware-like style; it rests on judgement, not precedent.",
    "Most of the day nothing is recording, so the large readout says “READY” most of the time. The research names this as the main risk of a live-first screen.",
    "It is the furthest from stock iOS, so it is the most custom drawing to build and keep up to date.",
    "A widget for chain health works around Apple's rule that a Live Activity is for a session, not a status.",
]
B["first"] = ["The five-lamp chain as one reusable view (app, Lock Screen, log rows)", "The now screen with the readout and the log sheet", "The per-note trace with timings", "Per-stage sound switches"]

# =====================================================================================  C  Inbox
C = {
    "letter": "C", "name": "Inbox", "file": "C-inbox",
    "vars": """--paper:#FFFFFF; --text:#16181D; --soft:#6E7480; --rule:#E3E5EA; --accent:#4F46D8;
      --doc-body: -apple-system, "SF Pro Text", Helvetica, sans-serif; --doc-h1: 700 32pt/1.05 -apple-system, "SF Pro Display", Helvetica, sans-serif;
      --doc-h2: 600 16pt/1.2 -apple-system, "SF Pro Display", Helvetica, sans-serif; --sample: 600 15pt/1.3 -apple-system, "SF Pro Display", Helvetica, sans-serif;
      --bg:#F2F2F7; --surface:#FFFFFF; --sheet:#FFFFFF; --ink:#16181D; --mute:#8A8F9A; --line:#E1E3E8; --chip:#ECEBFB; --on-accent:#fff; --mark:#E2E0FB;
      --ui: -apple-system, "SF Pro Text", Helvetica, sans-serif; --title: 700 15pt/1.1 -apple-system, "SF Pro Display", Helvetica, sans-serif;
      --lock1:#3a3f73; --lock2:#101225; --la:rgba(255,255,255,.92); --la-ink:#16181D;""",
    "idea": "The app is an inbox for what the agent did and what it was not sure about. It looks and behaves like a stock iOS 26 app, and it asks you only when it has a real question.",
    "bets": "That as the agent learns to do more than add one task, the thing you need is a place to review its work, with the doubtful cases sorted to the top.",
    "facts": [
        ("Structure", "Two tabs, Notes and Tasks, in the iOS 26 floating tab bar. A live strip rides above the tab bar while recording."),
        ("Autonomy", "Acts when it is sure. When it is not, the note waits under “Needs a look” with a one-tap yes or no."),
        ("Type", "SF Pro throughout, system text styles, Dynamic Type for free."),
        ("Colour", "System greys and white. One indigo that marks anything the agent produced."),
        ("Sound and touch", "The start and the answer are heard. The middle steps become taps only, to keep daily use quiet."),
        ("Lock Screen", "A Live Activity per recording. It ends as a receipt, or as a question if the note needs a look."),
    ],
}
def crow(title, sub, right="›", ai=False):
    return f'<div class="row"><div><div style="font-weight:600">{title}</div><div class="{"accent" if ai else "muted"}">{sub}</div></div><span class="muted">{right}</span></div>'
TAB = lambda active: f'<div class="tabbar"><span class="{"accent" if active == 0 else "muted"}">▤ Notes</span><span class="{"accent" if active == 1 else "muted"}">☑ Tasks <span class="chip" style="background:var(--accent);color:#fff;margin:0">1</span></span><span class="muted">⌕</span></div>'
C["screens1"] = [
    shot(phone(SB + f"""<div class="pad"><div class="row"><span class="muted">&nbsp;</span><span class="muted">⚙︎</span></div><div class="title">Notes</div>
      <div class="sec">Today</div><div class="set">
        {crow("Test recorder after airplane mode", "✓ Task added · Thu", "14:03", True)}
        {crow("The light was really nice around five", "Note", "11:20")}
        {crow("Call the school office", "✓ Task added · Tomorrow 15:00", "08:47", True)}</div>
      <div class="sec">Yesterday</div><div class="set">
        {crow("I should water the plants more often", "? Needs a look", "18:40", True)}
        {crow("Order a new water filter", "✓ Task added", "18:32", True)}</div>
      </div>
      <div class="acc"><span><span class="dot red"></span> Recording</span><span class="muted" style="font-variant-numeric:tabular-nums">0:42 ▂▅▃▆▂</span></div>{TAB(0)}"""),
      "Notes, with the live strip", "A standard grouped list. While recording, a strip sits above the tab bar the way the player does in Music; tap it for the full live view."),
    shot(phone(SB + f"""<div class="pad"><div class="row"><span class="muted">&nbsp;</span><span class="muted">⚙︎</span></div><div class="title">Tasks</div>
      <div class="sec">Needs a look</div>
      <div class="card"><div class="muted">Yesterday 18:40 · you said</div><div style="font-weight:600;margin:.8mm 0 1.6mm">“I should really water the plants more often.”</div>
        <div class="accent" style="margin-bottom:1.6mm">Did you want a task for this?</div><span class="btn primary">Add task</span><span class="btn">No</span></div>
      <div class="sec">Added today</div><div class="set">
        <div class="row"><span>◯ &nbsp;<b>Test recorder after airplane mode</b><br><span class="chip">Thu</span><span class="chip">Work</span></span><span class="muted">Undo</span></div>
        <div class="row"><span>◯ &nbsp;<b>Call the school office</b><br><span class="chip">Tomorrow 15:00</span><span class="chip">p2</span><span class="chip">calls</span></span><span class="muted">Undo</span></div></div>
      <div class="sec">Earlier</div><div class="set"><div class="row"><span>◯ &nbsp;<b>Order a new water filter</b></span><span class="muted">›</span></div></div>
      </div>{TAB(1)}"""),
      "Tasks: what the agent did", "Doubtful notes come first, each with one question. Below, everything it added, with the fields as chips and Undo on the row."),
    shot(phone(SB + f"""<div class="pad"><div class="row"><span class="accent">‹ Notes</span><span class="muted">•••</span></div>
      <div style="font:var(--title);font-size:10pt;margin:2mm 0 .6mm">Monday 14:03</div><div class="muted" style="margin-bottom:2mm">38 seconds · English</div>
      <div class="card" style="line-height:1.5">I've been thinking about the battery thing on the recorder. What I don't know is how it behaves in airplane mode. <mark>I should probably just test that on the train on Thursday. Oh, yes, add that as a task.</mark></div>
      <div class="sec">Task</div><div class="set">
        <div class="row"><span>Title</span><span class="muted">Test recorder after… ›</span></div><div class="row"><span>Due</span><span class="muted">Thu 8 Oct ›</span></div>
        <div class="row"><span>Project</span><span class="muted">Work ›</span></div><div class="row"><span>Priority</span><span class="muted">None ›</span></div><div class="row"><span>Labels</span><span class="muted">None ›</span></div></div>
      <div class="set"><div class="row"><span style="color:#d33">Remove task from Todoist</span></div></div>
      </div>"""), "A note and its task", "The transcript on top with the source sentence marked, then the task as an ordinary editable form. Changes go straight to Todoist."),
]
C["screens2"] = [
    shot(phone(f"""<div class="clock">9:41</div><div class="date" style="margin-top:2mm">Monday 5 October</div>
      <div class="la" style="top:44mm"><div class="row"><span><span class="dot red"></span> <b>Recording</b></span><b style="font-variant-numeric:tabular-nums">0:42</b></div></div>
      <div class="la" style="top:62mm"><div class="accent" style="font-weight:600">✓ Task added</div><div>Test recorder after airplane mode · Thu</div></div>
      <div class="la" style="top:82mm"><div class="accent" style="font-weight:600">? Did you want a task?</div><div>“I should really water the plants…”</div><div style="margin-top:1.4mm"><span class="btn primary">Add</span><span class="btn">No</span></div></div>
      """, cls="lock", island='<span style="color:#ff5a4d">●</span><span>0:42</span>'),
      "Lock Screen: receipt or question", "The activity ends one of two ways: a receipt, or the single question, answerable without unlocking."),
    shot(phone(SB + """<div class="pad"><div class="row"><b style="font-size:8pt">Settings</b><span class="accent"><b>Done</b></span></div>
      <div class="sec">Recorder</div><div class="set"><div class="row"><span>Comulytic Note Pro</span><span class="muted">Connected · 82%</span></div><div class="row"><span>Download stored recordings</span><span class="muted">›</span></div></div>
      <div class="sec">Agent</div><div class="set"><div class="row"><span>How sure before acting</span><span class="muted">Fairly sure ›</span></div><div class="row"><span>Claude API key</span><span class="muted">Stored ›</span></div><div class="row"><span>Todoist</span><span class="muted">Connected ›</span></div><div class="row"><span>Default project</span><span class="muted">Inbox ›</span></div></div>
      <div class="sec">Transcription</div><div class="set"><div class="row"><span>Language</span><span class="muted">English ›</span></div></div>
      <div class="sec">Feedback</div><div class="set"><div class="row"><span>Sounds</span><span class="muted">Start and answer ›</span></div><div class="row"><span>Haptics</span><div class="toggle on"></div></div><div class="row"><span>Lock Screen previews</span><span class="muted">When unlocked ›</span></div></div>
      </div>"""), "Settings: stock grouped list", "The one setting that is new here is how sure the agent must be before it acts by itself."),
    shot(phone(SB + f"""<div class="pad"><div class="row"><span class="muted">&nbsp;</span><span class="muted">⚙︎</span></div><div class="title">Tasks</div>
      <div class="sec">Needs a look</div>
      <div class="card"><div class="muted">Today 16:10</div><div style="font-weight:600;margin:.8mm 0 1mm">Send the contract to the lawyer</div>
        <div style="color:#c2410c;margin-bottom:1.6mm">Not in Todoist yet: the token was rejected.</div><span class="btn primary">Open settings</span><span class="btn">Try again</span></div>
      <div class="card"><div class="muted">Today 15:52</div><div style="font-weight:600;margin:.8mm 0 1mm">A recording did not reach the phone</div>
        <div class="muted" style="margin-bottom:1.6mm">It is still on the recorder.</div><span class="btn primary">Download it</span></div>
      <div class="sec">Added today</div><div class="set"><div class="row"><span>◯ &nbsp;<b>Test recorder after airplane mode</b></span><span class="muted">Undo</span></div></div>
      </div>{TAB(1)}"""), "When something fails", "Failures join the same “Needs a look” queue as doubtful notes, so there is one place to check and one badge to clear."),
]
C["why"] = [
    "It follows the iOS 26 rules most closely: glass only on the tab bar and the live strip, content on plain opaque surfaces, one tinted action per screen. Apple documents the strip above the tab bar for exactly this kind of ongoing activity.",
    "Todoist's own voice feature, Ramble, works from the principle “easy correction beats perfect first-time accuracy”. The research adds that people want no confirmation when things went right and an explicit question once something is in doubt. The “Needs a look” queue is that idea.",
    "It scales. When the agent can do more than one task per note, or more than tasks, each new kind of action is another row type in the same Tasks tab.",
]
C["risks"] = [
    "With one task per note and a reliable extractor, the Tasks tab mostly repeats the Notes tab. Two tabs may be more structure than today's feature set needs.",
    "A review queue is a second inbox to keep empty. If it fills with trivial questions, it becomes the thing you avoid.",
    "It needs a notion of “not sure” from the extractor, which does not exist yet: today it answers task or no task.",
    "It is the least distinctive of the three; it will look like many other iOS 26 apps.",
]
C["first"] = ["A confidence answer from the extractor (sure / unsure), with eval cases for it", "The Notes list and note form", "The Tasks tab with “Needs a look”", "The live strip above the tab bar"]

# ===================================================================================== pages
def build(d):
    facts = "".join(f"<tr><th>{k}</th><td>{v}</td></tr>" for k, v in d["facts"])
    p1 = page(d, 1, f"""<div class="kicker">Quasi iPhone app · design direction {d["letter"]} of three</div>
      <h1>{d["name"]}</h1><p class="lead">{d["idea"]}</p>
      <h3>What it bets on</h3><p style="max-width:150mm">{d["bets"]}</p>
      <h3>At a glance</h3><table>{facts}</table>
      <div class="cols" style="margin-top:6mm"><div><h3>Colour</h3><div class="swatches">
        <div class="sw" style="background:var(--bg)"></div><div class="sw" style="background:var(--surface)"></div><div class="sw" style="background:var(--ink)"></div><div class="sw" style="background:var(--accent)"></div></div></div>
        <div><h3>Type</h3><div class="type">Call the dentist, tomorrow at three</div></div></div>""")
    p2 = page(d, 2, f"""<div class="kicker">Direction {d["letter"]} · {d["name"]}</div><h2 style="margin-top:4mm">The three screens you would see most</h2>
      <div class="phones">{"".join(d["screens1"])}</div>""")
    p3 = page(d, 3, f"""<div class="kicker">Direction {d["letter"]} · {d["name"]}</div><h2 style="margin-top:4mm">{d.get("p3", "Off the screen, in settings, and when something goes wrong")}</h2>
      <div class="phones">{"".join(d["screens2"])}</div>""")
    p4 = page(d, 4, f"""<div class="kicker">Direction {d["letter"]} · {d["name"]}</div><h2 style="margin-top:4mm">Why this direction, and what it costs</h2>
      <div class="cols" style="margin-top:4mm"><div><h3 style="margin-top:0">Grounding in the research</h3>{"".join(f"<p>{t}</p>" for t in d["why"])}</div>
      <div><h3 style="margin-top:0">Risks and costs</h3><ul>{"".join(f"<li>{t}</li>" for t in d["risks"])}</ul>
      <h3>What would be built first</h3><ul>{"".join(f"<li>{t}</li>" for t in d["first"])}</ul></div></div>
      <h3>True of all three directions</h3>
      <ul style="columns:2;column-gap:9mm;font-size:9.5pt">
        <li>The recorder is found automatically; keys are entered once and kept in the keychain.</li>
        <li>“Your note is safe” is said first in every failure, because the recorder keeps the full copy.</li>
        <li>The Live Activity belongs to a recording and ends as a receipt. Today's permanent “connected” banner goes away.</li>
        <li>Lock Screen text can be hidden.</li>
        <li>Every state is available by sound, by touch and by sight; each can be switched off.</li>
        <li>Sounds follow the silent switch unless you choose otherwise.</li>
      </ul>
      <h3>Not settled yet</h3>
      <p style="font-size:9.5pt">The mock-ups are drawn by hand in HTML to show structure and character; they are not final visual design and no screenshots of other apps were consulted.
      One technical question affects all three: whether iOS lets the app start a Live Activity when a recording begins while the phone is locked. Apple's guidance assumes it is started from the app or by a push. This needs a small test before the Lock Screen design is relied on.</p>""")
    html = f'<!doctype html><html><head><meta charset="utf-8"><title>Quasi design direction {d["letter"]}: {d["name"]}</title><style>:root{{{d["vars"]}}}{BASE_CSS}</style></head><body>{p1}{p2}{p3}{p4}</body></html>'
    path = os.path.join(HERE, d["file"] + ".html")
    open(path, "w").write(html)
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer", f"--print-to-pdf={os.path.join(HERE, d['file'] + '.pdf')}", "file://" + path],
                   check=True, capture_output=True)
    print("wrote", d["file"] + ".pdf")

for direction in (A, B, C):
    build(direction)

# ===================================================================================== A: the Lock Screen between recordings
def lock(inline, widgets, caption_title, caption):
    return shot(phone(f"""<div class="date" style="margin-top:11mm">{inline}</div><div class="clock" style="margin-top:1mm">9:41</div>
      <div style="display:flex;gap:2mm;margin:4mm 4mm 0">{widgets}</div>""", cls="lock"), caption_title, caption)

def rect(lines):
    return ('<div style="flex:1;background:rgba(255,255,255,.14);border-radius:3.2mm;padding:1.8mm 2.2mm;font-size:5.8pt;line-height:1.4">'
            + "".join(lines) + "</div>")

def ring(percent, glyph, dashed=False):
    border = "dashed" if dashed else "solid"
    fill = f"conic-gradient(#fff {percent}%, rgba(255,255,255,.25) 0)" if not dashed else "none"
    return (f'<div style="width:11mm;height:11mm;border-radius:50%;background:{fill};display:flex;align-items:center;justify-content:center;flex:none;'
            f'{"border:.5mm dashed rgba(255,255,255,.55);" if dashed else ""}">'
            f'<div style="width:8.6mm;height:8.6mm;border-radius:50%;background:#2a1e16;display:flex;align-items:center;justify-content:center;font-size:6pt">{glyph}</div></div>')

def lock_states():
    d = A
    b = lambda text: f'<div style="font-weight:600">{text}</div>'
    m = lambda text: f'<div style="opacity:.7">{text}</div>'
    screens = [
        lock("Recorder nearby", rect([b("✓ Call the school office"), m("Last note 14:03 · task added")]) + ring(82, "82"),
             "Idle and connected", "Quiet. The widget shows your last note and what became of it, which is also the proof that things work. The ring is the recorder's battery."),
        lock("Recorder out of reach", rect([b("Recorder out of reach"), m("since 15:40 · notes stay on it")]) + ring(0, "–", dashed=True),
             "Recorder out of reach", "Visible if you look, never announced. Nothing is lost: the recorder keeps recording and the notes are fetched when it is back."),
        lock("Quasi is not running", rect([b("No contact since 12:05"), m("Open Quasi to reconnect")]) + ring(0, "!", dashed=True),
             "The app has stopped", "If the widget has not been refreshed for a while, it changes by itself to say so. This is the one state that also sends a notification."),
    ]
    body = f"""<div class="kicker">Direction A · Logbook · addendum</div><h2 style="margin-top:4mm">The Lock Screen between recordings</h2>
      <p style="max-width:160mm">During a recording the Lock Screen shows the Live Activity from page 3. Between recordings it shows two small widgets under the clock and one line above it. They replace today's permanent “Recorder connected” banner.</p>
      <div class="phones">{"".join(screens)}</div>
      <div class="cols" style="margin-top:7mm"><div><h3 style="margin-top:0">Why widgets and not the banner</h3>
        <ul><li>A widget stays for good. The banner is a Live Activity, which iOS ends after eight hours and only lets the app restart when it is opened.</li>
        <li>It leaves the banner free to mean one thing: a recording is happening or has just finished.</li>
        <li>It is your choice to place them; the app works the same without.</li></ul></div>
      <div><h3 style="margin-top:0">What it costs</h3>
        <ul><li>Widgets update on a budget iOS controls, so “out of reach” can appear a few minutes late. The banner updates at once.</li>
        <li>Lock Screen widgets are one colour and very small: one fact each.</li>
        <li>They are a new piece to build: a widget needs its own shared storage with the app.</li></ul></div></div>
      <h3>If you would rather keep the banner</h3>
      <p style="font-size:9.5pt;max-width:165mm">It can stay as an option: “Show the link on the Lock Screen”. It would look like today's, in the Logbook style, and turn into the recording banner when a note starts. The eight-hour limit remains, so after a night it is gone until the app is opened once.</p>"""
    html = (f'<!doctype html><html><head><meta charset="utf-8"><title>Quasi direction A: Lock Screen between recordings</title>'
            f'<style>:root{{{d["vars"]}}}{BASE_CSS}</style></head><body><div class="page">{body}'
            f'<div class="foot"><span>Quasi iPhone app · design direction A: Logbook · Lock Screen states</span><span>addendum</span></div></div></body></html>')
    path = os.path.join(HERE, "A-logbook-lock-screen.html")
    open(path, "w").write(html)
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
                    f"--print-to-pdf={os.path.join(HERE, 'A-logbook-lock-screen.pdf')}", "file://" + path], check=True, capture_output=True)
    print("wrote A-logbook-lock-screen.pdf")

lock_states()
