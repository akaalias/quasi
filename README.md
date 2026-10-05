# Quasi

**Say it, hear it done.** [The project's page](https://alexisrondeau.me/quasi/) has the sounds to
listen to. Quasi is a small experiment in computing without a screen. You speak
into a pocket recorder. Your phone stays in your bag, dark and locked. A few notes of wood and
chime tell you that you were heard, understood, and that the thing you asked for is done. If you
ever want to check, there is a logbook. Most days you won't open it.

In practice: an iPhone app and a Mac menu bar app that talk directly to a
[Comulytic Note Pro](https://www.comulytic.com) voice recorder over Bluetooth. No vendor app, no
account: audio goes from the recorder to your own device and is transcribed there, and tasks you
ask for are added to Todoist. The phone has to be switched on and within Bluetooth range; it does
not have to be looked at.

This is a personal project for one recorder and one owner, not a product. It is not affiliated
with Comulytic.

## What it does

Press record on the recorder, and within a second or two:

- **Live view.** A waveform of what the recorder hears, with a running timer.
- **Transcript.** When you stop, the audio is transcribed on the device and shown. Audio is
  saved as `.m4a`, the transcript as `.txt`, named by the recording's start time.
- **Stored recordings.** "Download Stored Recordings" fetches the complete copies from the
  recorder's own storage. Nothing is ever deleted from the recorder.
- **Tasks.** If you store an Anthropic API key in the app, each transcript is sent to Claude,
  which finds the tasks you asked for ("add a new task…", "oh, add that as a task", "three
  tasks: …"): none, one or several per note. For each it works out what you said about it: title,
  due day and time, repeats, deadline, priority, how long it takes, and the project, section and
  labels to file it under. With a Todoist token stored as well, the tasks are added to Todoist
  with the transcript in their description. These two
  services are the only places where text leaves your device, and only if you store their keys.

On the Mac this is a menu bar item with a small floating window that appears when a recording
starts. Files go to `~/Recordings/Comulytic`.

On the iPhone the home screen is a log: every recording, newest first, as your own words and one
line saying what became of them. A note opens to its transcript with the words that asked for the
task marked, the task as it was understood, and Undo. The live view rises as a sheet while you
record, with the waveform and your words appearing as you speak; settings are behind the gear. Plus:

- It keeps working with the phone locked and in your pocket.
- A banner on the Lock Screen and in the Dynamic Island shows whether the recorder is connected,
  its battery level, and a timer while recording.
- Lock Screen widgets you can add under the clock: your last note and what became of it, whether
  the recorder is nearby, and its battery.
- Sound and touch for every step, so you know without looking: two rising chime notes when a
  recording starts, a wooden note when it has arrived and another when it is transcribed, then a
  chime that says what happened (nothing to do, a task added, or a failure, which falls and rings).
  An even, quiet tick-tock in between when a step takes more than a moment.
- Files are visible in the Files app under On My iPhone → Quasi.

Only one device can hold the recorder at a time. The Mac app and the iPhone app compete for
it; run one.

## Try it with your own phone and Xcode

This puts the iPhone app on your own phone, talking to your own recorder. It takes about ten
minutes. It has only ever been run against one recorder, so expect rough edges.

**You need**

- A Mac with Xcode 26 and an iPhone on iOS 26 or later.
- An Apple account signed in to Xcode (Xcode → Settings → Accounts). A free one works; the app
  then stops opening after 7 days until you run it from Xcode again.
- A Comulytic Note Pro that has been set up once with Comulytic's own app.

**Steps**

1. Clone this repository and open `app/Quasi.xcodeproj` in Xcode.
2. Make the signing yours. In the project editor, do this for both the **QuasiPhone** and the
   **QuasiWidgets** target, under Signing & Capabilities:
   - choose your own Team;
   - change the bundle identifier to something of your own, for example `com.yourname.Quasi`
     for QuasiPhone and `com.yourname.Quasi.Widgets` for QuasiWidgets. The second must
     start with the first.
3. On the iPhone, turn on Developer Mode (Settings → Privacy & Security → Developer Mode) and
   connect it to the Mac with a cable.
4. Free the recorder: close Comulytic's app completely on every phone it is set up on (swipe it
   away in the app switcher). A recorder that is connected to another app is invisible to this one.
5. In Xcode's toolbar choose the **QuasiPhone** scheme and your iPhone, then press Run.
6. On the phone, allow Bluetooth when asked. With a free Apple account you also have to trust
   yourself as a developer once: Settings → General → VPN & Device Management.
7. The app should show "Connected" within a few seconds. Press record on the recorder.

**If it does not connect**

- "Looking for the recorder…" that never ends usually means another app still holds the recorder,
  or the recorder is off or out of range.
- It connects to the first Note Pro it sees. With more than one nearby, it may pick the wrong one.
- A different hardware model or firmware may speak a different protocol. This was built against
  hardware "TN12" on firmware 2.3.5.

The app never deletes, formats or changes settings on the recorder, and Comulytic's app keeps
working afterwards; just do not run both at the same time.

## What has been tested

Tested by hand with one recorder (firmware 2.3.5), a Mac on macOS 26 and an iPhone 15 on iOS 26.2,
between 2026-10-01 and 2026-10-05.

### iPhone

| Test | Result |
|---|---|
| App in front: record, live view, stop, transcript | Works |
| Phone locked for 3 minutes, off the cable, then record | Captured and transcribed |
| Phone locked and untouched for 50 minutes, then record | Captured and transcribed |
| Used through an evening, a night and a morning, phone mostly locked | Every recording arrived live |
| Phone taken out of range | Banner shows the recorder as out of reach |
| Phone brought back, still locked | Reconnects by itself, banner returns to "Recorder connected" |
| Lock Screen / Dynamic Island banner | Shows "Recorder connected" |
| Double vibration at the end of a recording while locked | Works |
| Recorder battery with the phone holding the link all the time | 96 % to 90 % in about 16 to 18 hours, test recordings included: roughly 8 % a day |

### Mac

| Test | Result |
|---|---|
| Recorder battery with the link dropped while away from the Mac | 100 % to 96 % in 24 hours |
| Mac woken from sleep by Bluetooth | 11 to 18 times a day, down from 3,198 on the day before the fix |
| Battery level shown | Follows the recorder (99, 97, 96 %); it used to read 100 % always |

### Task extraction

There is an eval in `evals/task-extraction`: 206 transcripts (169 that ask for a task, 32 of
those for more than one, and 37 that ask for none), all written for it, with the expected tasks
and the expected value of every field. On 2026-10-05, Claude Sonnet 5.5 read every one of them
entirely correctly: the right number of tasks each time, none missed, none invented, no request
split in two. Median 2 seconds and about two thirds of a cent per note. The cases were written by
the same hand as the prompt, so treat this as an optimistic score. On the iPhone, notes recorded
in daily use have produced single and several tasks; the newer fields (time, repeats, priority,
project and so on) have mostly been exercised by the eval.

Adding to Todoist was tested from a script with one task (created with the right title, due day
and description, then deleted). It has not been used from the apps yet.

### Not tested yet

- **iPhone, after iOS removes the app from memory.** The code to come back from this exists
  (see below) but has never been seen to trigger.
- **iPhone, downloading stored recordings.** Same code as on the Mac, not exercised on the phone.
- **Mac, the current build.** The measurements above were made with the build of 2026-10-03.
  The code has since been split into shared and Mac-only parts; that build compiles but has
  not been run.
- **Lock, display-sleep and sleep handling on the Mac** was verified by its effect (the numbers
  above), not by watching each transition.

## How it works

### The recorder

The recorder speaks Bluetooth LE. The apps implement the small part of its protocol that they
need: connecting, keeping the connection alive, receiving the recording in progress as a live
stream, and listing and downloading stored recordings. They never send anything that changes,
unbinds or deletes what is on the recorder.

Three facts about the recorder shape everything else:

1. **It only streams to a connected client.** Its advertisement does not change when it starts
   recording, so there is no way to notice a recording from the outside. A live view within
   seconds requires holding the connection.
2. **Holding the connection costs its battery.** Connected and kept awake by the heartbeat, it
   uses far more than when left alone.
3. **The live stream can have small gaps;** the copy stored on the recorder is complete. That is
   what "Download Stored Recordings" is for.

### Shared by both apps

About three quarters of the Swift code is in `app/Shared` and compiled into both apps:

- `RecorderProtocol`, `RecorderClient`: the wire format and the Bluetooth session described above.
- `LiveMP3Decoder`: decodes the MP3 stream as it arrives and resynchronises after gaps.
- `AudioFiles`: keeps the right channel (the microphone; the left mostly carries handling noise)
  and writes mono AAC.
- `Transcriber`: Apple's on-device `SpeechAnalyzer`. The language model is downloaded by the
  system on first use; no audio leaves the device.
- `AppModel`: ties these together, and decides when the link may be dropped.
- `LiveView`: the waveform and transcript.

Each app adds a thin layer for what differs. The difference that matters is when to hold the link.

### macOS: hold the link only while you are there

A Mac app keeps running in the background without restrictions, so holding the link is easy.
The problem was the opposite: it was held too much.

The first version connected whenever the recorder was in range and reconnected at once after
every drop. With the lid closed that became a loop: the Mac sleeps, the heartbeat stops, the
recorder drops the link and advertises, the Mac's pending connection wakes it, the app runs the
handshake, the Mac sleeps again. This repeated about every 14 seconds all night. The recorder
drained in a day or two, and the Mac lost battery as well.

The live window is only useful when someone can see it, so now:

- `MacServices` watches for screen lock, display sleep and system sleep.
- While any of those holds, the app disconnects and cancels its pending connection, so the
  recorder idles and the Mac sleeps undisturbed.
- A recording or download already in progress is allowed to finish first. System sleep drops the
  link immediately.
- On unlock or wake it reconnects.

Idle time is not used: sitting in front of the Mac without touching it still counts as being there.

### iOS: hold the link especially while locked

On the phone the goal is reversed. The recorder and the phone travel together, and the point is
that a recording made with the phone in a pocket arrives anyway.

iOS works against this by default: an app in the background is suspended within seconds, and a
suspended app's timers do not fire, so the heartbeat would stop and the recorder would drop the
link. Four pieces keep it alive:

- **Bluetooth background mode** (`bluetooth-central`). iOS keeps the connection open at system
  level and wakes the app briefly for every packet from the recorder.
- **`BackgroundLink`.** Each packet renews a short background task. The recorder answers every
  heartbeat, so the answer keeps the app awake long enough to send the next one: a chain that
  holds for as long as the recorder is in range.
- **Pending connection.** When the recorder goes out of range the chain ends and the app is
  suspended, but iOS keeps the connection request and wakes the app when the recorder is seen
  again. The recorder advertises no service identifiers, so background scanning cannot find it;
  the phone has to have connected once with the app in front.
- **State restoration.** If iOS removes the app from memory, it relaunches it in the background
  when the recorder connects or disconnects. (Untested, see above.)

The Lock Screen banner is a Live Activity drawn by a small widget extension. While connected the
app refreshes it every two minutes and marks it valid for five. If the app stops running, the
refreshes stop and the banner turns to "Lost contact" by itself, so the banner is also the check
that the app is alive.

What iOS does not allow:

- Swiping the app away in the app switcher stops it until it is opened again. So does restarting
  the phone.
- A Live Activity ends after eight hours and can only be started with the app in front. Opening
  the app starts a new one.

## Building

Requires Xcode 26. Both apps need macOS 26 / iOS 26 for the transcription.

```sh
app/tools/release.sh   # Mac: build, install to /Applications, launch
app/tools/phone.sh     # iPhone: build, install and launch on the connected phone
```

The first connection is made with whichever app you open first; the recorder needs to have been
set up once with the vendor's app, which gives it the bind code these apps read back.

## Repository layout

| Path | Contents |
|---|---|
| `app/Shared` | Code compiled into both apps |
| `app/Quasi` | Mac only: menu, floating window, presence, launch at login |
| `app/QuasiPhone` | iPhone only: the logbook screens, background link, sounds, Live Activity controller |
| `app/PhoneShared`, `app/QuasiWidgets` | The Live Activity, the Lock Screen widgets and what they share with the app |
| `evals/task-extraction` | The eval for turning transcripts into tasks |
| `design/directions` | The three design directions the iPhone app was chosen from |
| `site` | The project's web page (published from `docs/` in the public repository) |

Quasi is free software under the GNU General Public License, version 3 (see `LICENSE`). It is an
independent project and is not affiliated with or endorsed by Comulytic. The research
notes on the recorder itself are not part of this repository.
