#!/usr/bin/env python3
"""Writes the eval cases for task extraction: cases.jsonl (for the runner) and cases.md (for reading).

Every case is a transcript as speech recognition would produce it, plus the tasks the extractor
should return: none, one or several. Unless a case says otherwise, the note was recorded on
Monday 2026-10-05 at 10:00, so the week runs Tue 6, Wed 7, Thu 8, Fri 9, Sat 10, Sun 11, Mon 12.

A field that is not listed for a task is expected to come back empty (or 0): inventing a due date
or a project is as wrong as missing one. `skip` names fields that are not graded for that task.

Where the cases come from: all were written for this eval. A few are modelled on the shape of
real recordings (short tests of the recorder; a list of things named as tasks), in other words. Edit this file and re-run it; do not edit cases.jsonl by hand.
"""
import datetime, json, os

MONDAY = datetime.date(2026, 10, 5)
def day(offset): return (MONDAY + datetime.timedelta(days=offset)).isoformat()

CATALOG = {
    "projects": [
        {"name": "Inbox", "sections": []},
        {"name": "Work", "sections": ["Admin", "Clients", "Product"]},
        {"name": "Home", "sections": ["Repairs", "Garden"]},
        {"name": "Mosey", "sections": ["Launch", "Video"]},
        {"name": "Family", "sections": []},
        {"name": "Reading list", "sections": []},
    ],
    "labels": ["errands", "waiting", "calls", "computer", "quick", "someday"],
}

CASES = []
def N(id, tags, text, recorded_at="2026-10-05T10:00"):
    CASES.append({"id": id, "tags": ["no task"] + tags, "recorded_at": recorded_at, "transcript": " ".join(text.split()),
                  "expected": {"tasks": []}})

def T(title_has, title_lacks=(), skip=(), **fields):
    """One expected task: words its title must (and must not) contain, and the fields the speaker set."""
    task = {"title_has": list(title_has), "title_lacks": list(title_lacks), "skip": list(skip),
            "due_date": "", "due_time": "", "recurrence": [], "deadline_date": "", "priority": 0,
            "duration_minutes": 0, "project": "", "section": "", "labels": []}
    task.update(fields)
    return task

def P(id, tags, text, title_has, title_lacks=(), skip=(), recorded_at="2026-10-05T10:00", **fields):
    """A note that asks for exactly one task."""
    M(id, tags, text, [T(title_has, title_lacks, skip, **fields)], recorded_at)

def M(id, tags, text, tasks, recorded_at="2026-10-05T10:00"):
    """A note that asks for the given tasks, in this order."""
    CASES.append({"id": id, "tags": tags, "recorded_at": recorded_at, "transcript": " ".join(text.split()),
                  "expected": {"tasks": tasks}})

# ---------------------------------------------------------------- no task: trying out the recorder
N("test-1", ["recorder test"], "Okay, this is just a test. One, two, three, hello.")
N("test-2", ["recorder test"], "Right, this is the test with the phone locked. I'm recording now and I'll look at it once I've unlocked the phone.")
N("test-3", ["recorder test"], "Hi, um, this is the long wait test. The phone's been locked and lying there for about half an hour now, the recorder too. Let's see whether the transcript shows up when I unlock it.")
N("test-4", ["recorder test"], "Test, test, another voice note. Does it buzz? That's what I want to know.")
N("test-5", ["recorder test"], "One more note, I don't know whether it buzzes this time, trying it out.")
N("test-6", ["recorder test"], "Morning. Is the app still running, is it still picking this up?")

# ---------------------------------------------------------------- no task: written
N("neg-thinking-1", ["thinking aloud"], """Okay so just thinking out loud here. Um, I had this conversation with Tobi yesterday about the
  recorder and he said he might want to try it. I think the whole task of making something like this useful is really about
  trust, like, do I trust that it captured what I said. Uh, yeah. It's a nice day. I don't really have a point here, I'm just, you know, talking.""")
N("neg-thinking-2", ["thinking aloud"], """Walking to the station. It's colder than I thought. Um, the thing with the video is that the
  third part drags, and I don't know yet what to do about it. Maybe cut the slide, maybe not. I'll see how I feel after lunch.""")
N("neg-list-long", ["talks about tasks"], """The task list in Todoist is getting really long, I noticed that this morning. Like there are
  forty things in there and half of them I added months ago. I don't know. It was a hard task to even read through it.""")
N("neg-past-task", ["talks about tasks"], """Yesterday I finally finished that task with the tax papers, that was a relief. Um, and Anna added
  a task for me on the shared list which I thought was funny. Anyway.""")
N("neg-question", ["talks about tasks"], """I wonder if I should be adding tasks by voice at all, or if that just makes the list longer. Hmm.
  Not sure. Let me think about it.""")
N("neg-intention-1", ["intention only"], "I need to call the dentist tomorrow, I keep forgetting. And the car needs to go in for the inspection at some point.")
N("neg-intention-2", ["intention only"], "Uh, so today the plan is, finish the slides, then go to the gym, then pick up Lina at four. Busy day.")
N("neg-intention-3", ["intention only"], "I should really water the plants more often. They look sad.")
N("neg-other-person", ["talks about tasks"], "Marcus said he would add a task for the invoice on his side, so I don't have to do anything there. Good.")
N("neg-hypothetical", ["talks about tasks"], """If I were to add a task for every idea I have on a walk, the list would explode. That's the
  problem with these capture tools, you capture too much.""")
N("neg-quote", ["talks about tasks"], """So in the meeting Sarah goes, add that as a task for the design team, and everybody just nodded.
  I'm not sure anyone actually wrote it down. Not my problem though.""")
N("neg-negated", ["negated"], "The thing with the heating, um, I already called the landlord, so no need to add a task for that. Just noting it.")
N("neg-cancelled", ["negated"], "Add a task, buy more coffee filters. Uh, actually no, forget it, we still have a full box. Never mind.")
N("neg-meta-1", ["about the app"], """So the way this works is, when I say add a new task, the phone picks it up and sends it to Todoist.
  I'm explaining this to Tobi right now, he's standing next to me. Pretty neat, right?""")
N("neg-meta-2", ["about the app"], "Test, test. Let's see if the sounds play. I'm not asking for a task this time, I just want to hear the wooden blocks.")
N("neg-short-1", ["short"], "Hello.")
N("neg-short-2", ["short"], "Um. Okay. No. Never mind.")
N("neg-diary", ["thinking aloud"], """Today was good. We went to the lake with the kids, Lina swam for the first time without the floats.
  I want to remember that. The light was really nice around five.""")
N("neg-idea", ["thinking aloud"], """Idea for the app. What if the lock screen showed the last thing it understood, like one line.
  That would help with trust. Just an idea, not sure it's worth building.""")
N("neg-reading", ["thinking aloud"], """Reading from the manual here. Press and hold the button for two seconds to start recording.
  The light turns red. To add a bookmark, press once briefly. Okay, that's what it says.""")
N("neg-shopping-talk", ["intention only"], "We're out of milk and I think also eggs. I'll probably pass by the shop on the way home anyway.")
N("neg-de-thinking", ["german", "thinking aloud"], """Ja, also ich bin gerade auf dem Weg nach Hause und denke über das Video nach.
  Der dritte Teil ist irgendwie zu langsam. Mal sehen. Das Wetter ist schön heute.""")
N("neg-de-tasks", ["german", "talks about tasks"], "Meine Aufgabenliste ist viel zu lang geworden, ich müsste da mal aufräumen. Aber nicht heute.")
N("neg-de-intention", ["german", "intention only"], "Ich muss morgen unbedingt beim Zahnarzt anrufen. Und das Auto muss zum TÜV.")
N("neg-song", ["thinking aloud"], "La la la, testing the microphone, one two three, the quick brown fox jumps over the lazy dog.")
N("neg-message-draft", ["thinking aloud"], """Draft for the email to Marcus. Hi Marcus, thanks for the workshop, it went really well.
  I'll send the invoice this week. Best, Alexis. Something like that.""")
N("neg-someone-reminded", ["talks about tasks"], "Anna reminded me to pay the school trip thing this morning, which I did right away on the phone. Done.")
N("neg-question-recorder", ["about the app"], "Does this thing also record when the phone is in airplane mode? I have no idea. Curious.")
N("neg-wish", ["talks about tasks"], "It would be nice if tasks could have photos attached. I don't think Todoist does that from here though.")

# ---------------------------------------------------------------- basic requests, nothing extra
P("basic-1", ["basic"], "Okay, add a new task which is, uh, call the dentist to move my appointment to next week.", ["dentist"])
P("basic-2", ["basic"], "New task. Buy a birthday card for Anna.", ["card", "anna"])
P("basic-3", ["basic"], "Uh, please create a task, renew my passport.", ["passport"])
P("basic-4", ["basic"], "Remind me to order a new water filter for the kitchen.", ["water filter"])
P("basic-5", ["basic"], "Put this on my to-do list, um, return the library books.", ["library book"])
P("basic-6", ["basic"], "Task. Book a table at the Italian place for our anniversary.", ["table"])
P("basic-7", ["basic"], "Add to my to-dos, ask Tobi for the charger back.", ["tobi", "charger"])
P("basic-8", ["basic"], "Can you add a task for me, check the tire pressure on the bike.", ["tire pressure"])
P("basic-date-in-task", ["basic"], "New task, book flights to Lisbon for the fourteenth of December.", ["flight", "lisbon"])

# ---------------------------------------------------------------- the request points back
P("backref-1", ["points back"], """I've been thinking about the battery thing on the recorder. So the phone holds the link all day and
  it costs maybe eight percent a day, which is fine. Um, but what I really don't know is how it behaves when I'm traveling and the
  phone is in airplane mode and then comes back. I should probably just test that on the train on Thursday. Oh, yes, add that as a task.""",
  ["airplane mode"], due_date=day(3))
P("backref-2", ["points back"], """So I'm just walking back from the bakery and thinking about the Mosey launch. Uh, the video is kind of
  done, I think the third part still feels a bit slow, but whatever. Oh, this reminds me, we need to add a new task here as follows.
  Um, re-render the slide for the third part with the new headline. Yeah. And then, I don't know, maybe I'll get a coffee later.""",
  ["re-render", "slide"])
P("backref-3", ["points back"], """The gutter on the back of the house is leaking again, I saw it this morning when it rained.
  Somebody has to get up there and clean it out. Make this a task.""", ["gutter"])
P("backref-4", ["points back"], """Lina's school wants the consent form back, the one for the swimming lessons. It's on the fridge.
  I need to sign it and put it in her bag. Oh, make that a task please.""", ["consent form"])
P("backref-5", ["points back"], """Um, I just realized the domain for the old site expires soon, I got an email about it. If that lapses
  somebody will grab it. Yeah, put that on my list, renewing it I mean.""", ["renew", "domain"])
P("backref-6", ["points back"], """Talking to myself here. The printer is out of cyan again, which is why everything looks pink.
  Add this as a task, the cyan cartridge.""", ["cyan"])
P("backref-7", ["points back"], """We said at dinner that we'd finally invite the neighbours over, the ones from the second floor.
  It's been a year. Oh, that should be a task, add it.""", ["invite", "neighbour"])
P("backref-8", ["points back"], """I keep meaning to back up the photos from the old phone before it dies completely. It only turns on
  when it's plugged in now. Okay, make it a task so I don't forget.""", ["back up", "photo"])

# ---------------------------------------------------------------- when to do it: a day
P("due-today", ["due day"], "Add a task for today, pick up the parcel from the post office.", ["parcel"], due_date=day(0))
P("due-tomorrow", ["due day"], "New task, call the insurance about the claim, tomorrow.", ["insurance"], due_date=day(1))
P("due-day-after", ["due day"], "Remind me the day after tomorrow to cancel the gym trial.", ["cancel", "gym"], due_date=day(2))
P("due-thursday", ["due day"], "Add a task for Thursday, bring the cake to the office.", ["cake"], due_date=day(3))
P("due-by-friday", ["due day"], "Um, new task. I need to send the invoice to Marcus for the September workshop, and that has to go out by Friday at the latest.",
  ["invoice", "marcus"], due_date=day(4))
P("due-end-of-week", ["due day"], "Create a task, finish the expense report, by the end of the week.", ["expense report"], due_date=day(4))
P("due-weekend", ["due day"], "Add a task for this weekend, mow the lawn.", ["mow", "lawn"], due_date=day(5))
P("due-next-week", ["due day"], "Task for next week, schedule the car inspection.", ["car inspection"], due_date=day(7))
P("due-tuesday-next-week", ["due day"], "Add a task, Tuesday next week, prepare the slides for the board meeting.", ["slides"], due_date=day(8))
P("due-in-two-weeks", ["due day"], "Remind me in two weeks to check whether the refund arrived.", ["refund"], due_date=day(14))
P("due-in-three-days", ["due day"], "New task, in three days, follow up with the plumber.", ["plumber"], due_date=day(3))
P("due-the-20th", ["due day"], "Add a task for the twentieth, pay the kindergarten fee.", ["kindergarten fee"], due_date="2026-10-20")
P("due-nov-3", ["due day"], "Create a task for November third, renew the parking permit.", ["parking permit"], due_date="2026-11-03")
P("due-end-of-month", ["due day"], "Task, submit the VAT return, end of the month.", ["vat return"], due_date="2026-10-31")
P("due-few-days-before", ["due day"], """So today I need to, um, well I already bought the groceries, that's done. And I talked to Anna
  about the weekend, we might go hiking. Uh, what else. Right, the thing I actually wanted to record. Please create a task, buy a
  birthday present for Jonas, his birthday is on the twentieth of October, so I want to have that done a few days before.""",
  ["present", "jonas"], due_date="2026-10-17")
P("due-morning-no-time", ["due day"], "Add a task, tomorrow morning, take the bins out.", ["bins"], due_date=day(1))
P("due-recorded-friday", ["due day"], "New task for Monday, send the contract to the lawyer.", ["contract", "lawyer"],
  recorded_at="2026-10-09T16:20", due_date="2026-10-12")
P("due-tonight", ["due day"], "Remind me tonight to charge the recorder.", ["charge", "recorder"], due_date=day(0))

# ---------------------------------------------------------------- when to do it: a clock time
P("time-tomorrow-3", ["due time"], "Add a task, call the school office tomorrow at three.", ["school office"], due_date=day(1), due_time="15:00")
P("time-half-past-nine", ["due time"], "New task, tomorrow morning at half past nine, dial in to the supplier call.", ["supplier call"], due_date=day(1), due_time="09:30")
P("time-3pm-today", ["due time"], "Remind me at 3 p.m. to pick up Lina.", ["pick up", "lina"], due_date=day(0), due_time="15:00")
P("time-passed-today", ["due time"], "Remind me at nine to take my pills.", ["pills"], recorded_at="2026-10-05T20:30", skip=["due_date", "due_time"])
P("time-thursday-noon", ["due time"], "Task for Thursday at noon, lunch with Katrin, book the table before that. Actually just add, book the table for lunch with Katrin, Thursday at noon.",
  ["table", "katrin"], due_date=day(3), due_time="12:00")
P("time-quarter-to-five", ["due time"], "Add a task, on Friday at quarter to five, leave for the airport.", ["airport"], due_date=day(4), due_time="16:45")
P("time-tonight-8", ["due time"], "New task, tonight at eight, call mum.", ["call", "mum"], due_date=day(0), due_time="20:00")
P("time-24h", ["due time"], "Add a task for Wednesday at fourteen thirty, pick up the glasses from the optician.", ["glasses"], due_date=day(2), due_time="14:30")
P("time-7am", ["due time"], "Remind me tomorrow at 7 a.m. to put the bread in the oven.", ["bread"], due_date=day(1), due_time="07:00")

# ---------------------------------------------------------------- repeats
P("rec-every-day", ["repeats"], "Add a task, water the seedlings, every day.", ["seedlings"], skip=["due_date"], recurrence=["every day"])
P("rec-weekdays-9", ["repeats"], "New recurring task, every weekday at nine, check the support inbox.", ["support inbox"], skip=["due_date"],
  recurrence=["every weekday"], due_time="09:00")
P("rec-mondays", ["repeats"], "Create a task that repeats every Monday, take out the recycling.", ["recycling"], skip=["due_date"], recurrence=["every monday"])
P("rec-two-weeks", ["repeats"], "Add a task, every two weeks, change the bed sheets.", ["bed sheets"], skip=["due_date"], recurrence=["every 2 weeks"])
P("rec-monthly-15", ["repeats"], "Remind me every month on the fifteenth to transfer the rent.", ["rent"], skip=["due_date"],
  recurrence=["every month on the 15th", "every 15th"])
P("rec-yearly", ["repeats"], "Add a yearly task, on October twentieth, wish Jonas a happy birthday.", ["jonas", "birthday"], skip=["due_date"],
  recurrence=["every year on october 20", "every october 20"])
P("rec-two-days", ["repeats"], "New task, every Monday and Thursday, go for a run.", ["run"], skip=["due_date"],
  recurrence=["every monday and thursday", "every monday, thursday"])
P("rec-evening-10", ["repeats"], "Remind me every evening at ten to plug in the recorder.", ["plug in", "recorder"], skip=["due_date"],
  recurrence=["every day"], due_time="22:00")
P("rec-quarterly", ["repeats"], "Add a task every three months, descale the coffee machine.", ["descale", "coffee machine"], skip=["due_date"],
  recurrence=["every 3 months"])

# ---------------------------------------------------------------- deadline
P("deadline-both", ["deadline"], "Add a task, write the grant application. I want to do it on Thursday, the deadline is the twentieth.",
  ["grant application"], due_date=day(3), deadline_date="2026-10-20")
P("deadline-only", ["deadline"], "New task, hand in the tax documents. The deadline is Friday.", ["tax document"], deadline_date=day(4))
P("deadline-far", ["deadline"], "Create a task, register for the conference, deadline November fifteenth.", ["register", "conference"], deadline_date="2026-11-15")
P("deadline-with-time", ["deadline"], "Add a task for tomorrow at ten, review the contract draft, the deadline for it is Wednesday.",
  ["contract draft"], due_date=day(1), due_time="10:00", deadline_date=day(2))
P("deadline-not-said", ["deadline"], "Add a task, upload the photos for the school yearbook by Wednesday.", ["photos", "yearbook"], due_date=day(2))

# ---------------------------------------------------------------- priority
P("prio-urgent", ["priority"], "Add an urgent task, call the bank about the blocked card.", ["bank", "card"], title_lacks=["urgent"], priority=1)
P("prio-top", ["priority"], "New task, top priority, fix the broken signup form.", ["signup form"], title_lacks=["priority"], priority=1)
P("prio-p1", ["priority"], "Add a task, priority one, send the signed offer back.", ["offer"], title_lacks=["priority"], priority=1)
P("prio-high", ["priority"], "Create a task with high priority, prepare the pitch for Thursday's meeting.", ["pitch"], title_lacks=["priority"], priority=2, skip=["due_date"])
P("prio-important", ["priority"], "Add a task, it's important, book the vaccination appointment for Lina.", ["vaccination"], title_lacks=["important"], priority=2)
P("prio-p2", ["priority"], "New task, p two, update the pricing page.", ["pricing page"], priority=2)
P("prio-medium", ["priority"], "Add a task, medium priority, tidy up the shared drive.", ["shared drive"], title_lacks=["priority"], priority=3)
P("prio-low", ["priority"], "Add a low priority task, sort the old cables in the drawer.", ["cables"], title_lacks=["priority"], priority=4)
P("prio-no-rush", ["priority"], "Put this on my list, no rush, look into a better backpack.", ["backpack"], title_lacks=["rush"], priority=4)
P("prio-none-said", ["priority"], "Add a task, it would be great to finally repaint the hallway.", ["repaint", "hallway"])

# ---------------------------------------------------------------- how long it takes
P("dur-half-hour", ["duration"], "Add a task, go through the mail pile, takes about half an hour.", ["mail"], duration_minutes=30)
P("dur-block-two-hours", ["duration"], "New task, tomorrow at ten, block two hours for the quarterly numbers.", ["quarterly numbers"],
  due_date=day(1), due_time="10:00", duration_minutes=120)
P("dur-15", ["duration"], "Add a quick fifteen minute task, update the phone's software.", ["update", "software"], duration_minutes=15, skip=["labels"])
P("dur-90", ["duration"], "Create a task for Wednesday at two, ninety minutes, workshop prep with Katrin.", ["workshop prep"],
  due_date=day(2), due_time="14:00", duration_minutes=90)
P("dur-not-said", ["duration"], "Add a task, write the long overdue newsletter.", ["newsletter"])

# ---------------------------------------------------------------- where it goes: project and section
P("proj-work", ["project"], "Add a task in my Work project, review the Q4 roadmap.", ["roadmap"], title_lacks=["work project"], project="Work")
P("proj-work-admin", ["project"], "New task under Admin in Work, file the travel receipts.", ["travel receipts"], project="Work", section="Admin")
P("proj-home", ["project"], "Put it in Home, replace the bathroom light bulb.", ["light bulb"], project="Home")
P("proj-mosey-launch", ["project"], "Add a task to the Mosey project, under Launch, write the press note.", ["press note"], project="Mosey", section="Launch")
P("proj-garbled", ["project"], "Add a task in the mosy project, export the final video.", ["export", "video"], project="Mosey", skip=["section"])
P("proj-reading-list", ["project"], "Add to my reading list, the book about calm technology by Amber Case.", ["calm technology"], project="Reading list")
P("proj-section-only", ["project"], "New task under Repairs, fix the squeaky door.", ["squeaky door"], project="Home", section="Repairs")
P("proj-unknown", ["project"], "Add a task to my Finance project, compare the two savings accounts.", ["savings account"])
P("proj-topic-only", ["project"], "Add a task, send the client the revised proposal.", ["proposal"])
P("proj-family", ["project"], "Create a task in Family, plan grandma's eightieth birthday.", ["grandma"], project="Family")
P("proj-clients", ["project"], "Task for the Clients section, call back the people from the bakery chain.", ["bakery chain"], project="Work", section="Clients")

# ---------------------------------------------------------------- labels
P("label-errands", ["labels"], "Add a task, pick up the dry cleaning, label it errands.", ["dry cleaning"], title_lacks=["errands"], labels=["errands"])
P("label-waiting", ["labels"], "New task, hear back from the landlord about the lease, tag that as waiting.", ["landlord", "lease"], labels=["waiting"])
P("label-two", ["labels"], "Add a task, phone the pediatrician, labels calls and quick.", ["pediatrician"], labels=["calls", "quick"])
P("label-unknown", ["labels"], "Add a task, get new running shoes, label it shopping.", ["running shoes"])
P("label-garbled", ["labels"], "Create a task, drop off the keys at Tobi's, with the errand label.", ["keys", "tobi"], labels=["errands"])
P("label-someday", ["labels"], "Add a task, learn to bake sourdough, tag it someday.", ["sourdough"], labels=["someday"])
P("label-none-said", ["labels"], "Add a task, call the pharmacy about the prescription.", ["pharmacy", "prescription"])

# ---------------------------------------------------------------- several things at once
P("combo-1", ["combined"], "Add an urgent task in Work, under Clients, send the corrected quote to the bakery chain, tomorrow at nine.",
  ["quote", "bakery chain"], due_date=day(1), due_time="09:00", priority=1, project="Work", section="Clients")
P("combo-2", ["combined"], "New task in Home, mow the lawn, this weekend, label it quick, low priority.", ["mow", "lawn"],
  due_date=day(5), priority=4, project="Home", labels=["quick"], skip=["section"])
P("combo-3", ["combined"], "Remind me every Friday at four to send the weekly update, put it in Work, high priority.", ["weekly update"],
  recurrence=["every friday"], due_time="16:00", priority=2, project="Work", skip=["due_date"])
P("combo-4", ["combined"], "Add a task to Mosey under Video, record the voiceover, Thursday at ten, takes an hour, label computer.",
  ["voiceover"], due_date=day(3), due_time="10:00", duration_minutes=60, project="Mosey", section="Video", labels=["computer"])
P("combo-5", ["combined"], "Create a task, important, submit the visa application, I'll do it Wednesday, the deadline is the twentieth, in Family.",
  ["visa application"], due_date=day(2), deadline_date="2026-10-20", priority=2, project="Family")
P("combo-6", ["combined"], """Okay so I was at the bank this morning and they need a form from me, the one for the joint account,
  and they said it has to be there by Friday. That's kind of urgent actually. Add that as a task, in Home, label errands.""",
  ["form"], due_date=day(4), priority=1, project="Home", labels=["errands"])
P("combo-7", ["combined"], "New task, call the tax adviser, tomorrow at eleven, label calls, takes fifteen minutes, in Work under Admin.",
  ["tax adviser"], due_date=day(1), due_time="11:00", duration_minutes=15, project="Work", section="Admin", labels=["calls"])
P("combo-8", ["combined"], "Add a task every month on the first, pay the cleaner, in Home, priority two.", ["cleaner"],
  recurrence=["every month on the 1st", "every 1st"], priority=2, project="Home", skip=["due_date"])

# ---------------------------------------------------------------- the speaker corrects themselves
P("fix-verb", ["self-correction"], "Add a task, email the landlord about the heating. Uh, no wait, not email, call. Call the landlord about the heating, tomorrow morning.",
  ["call", "landlord"], title_lacks=["email"], due_date=day(1))
P("fix-day", ["self-correction"], "New task, pick up the suit from the tailor on Wednesday. No, sorry, Thursday. Thursday.", ["suit"], due_date=day(3))
P("fix-priority", ["self-correction"], "Add an urgent task, order printer paper. Well, it's not urgent, make it low priority.", ["printer paper"], priority=4)
P("fix-project", ["self-correction"], "Add a task in Work, buy a new desk lamp. Hm, no, that's a Home thing, put it in Home.", ["desk lamp"], project="Home")
P("fix-time", ["self-correction"], "Remind me tomorrow at two, no, make that three, to call the garage.", ["garage"], due_date=day(1), due_time="15:00")
P("fix-object", ["self-correction"], "Add a task, buy tomatoes for the, no, not tomatoes, peppers. Buy peppers for the stew.", ["peppers"], title_lacks=["tomato"])
P("fix-cancel-then-other", ["self-correction"], "Add a task, book the hotel in Hamburg. Ah no, Anna did that already, forget it. But do add a task to book the train tickets to Hamburg.",
  ["train ticket"], title_lacks=["hotel"])

# ---------------------------------------------------------------- an intention next to a request
P("mixed-1", ["one of several"], """I have to go to the hardware store later and I should also call my brother at some point.
  Um, but the thing to write down, add a task, measure the window for the new blinds.""", ["measure", "window"])
P("mixed-2", ["one of several"], """The week is packed. Gym on Tuesday, parents' evening on Wednesday, and somewhere in there I want to
  finish the book. Okay. New task for Thursday, send the signed lease back.""", ["lease"], due_date=day(3))
P("mixed-3", ["one of several"], """I was thinking I might repaint the bike, and maybe sell the old stroller, we don't use it anymore.
  Remind me to put the stroller on the classifieds site.""", ["stroller"])

# ---------------------------------------------------------------- German
P("de-basic", ["german"], "Okay, neue Aufgabe. Ähm, ich muss morgen Nachmittag die Steuerunterlagen an den Steuerberater schicken, also die vom dritten Quartal.",
  ["steuerunterlagen"], due_date=day(1))
P("de-uebermorgen", ["german"], "Neue Aufgabe, übermorgen den Kinderarzt anrufen.", ["kinderarzt"], due_date=day(2))
P("de-freitag-15", ["german"], "Erinnere mich am Freitag um 15 Uhr daran, das Paket abzuholen.", ["paket"], due_date=day(4), due_time="15:00")
P("de-dringend", ["german"], "Füg bitte eine dringende Aufgabe hinzu, die Bank wegen der gesperrten Karte anrufen.", ["bank", "karte"], title_lacks=["dringend"], priority=1)
P("de-backref", ["german", "points back"], """Die Spülmaschine macht wieder dieses komische Geräusch, ich glaube das Sieb ist verstopft.
  Das müsste man mal sauber machen. Ach ja, mach daraus eine Aufgabe.""", ["sieb"])
P("de-frist", ["german"], "Neue Aufgabe, die Steuererklärung abgeben, die Frist ist der einunddreißigste Oktober.", ["steuererklärung"], deadline_date="2026-10-31")
P("de-jeden-freitag", ["german", "repeats"], "Neue Aufgabe, jeden Freitag den Müll rausbringen.", ["müll"], recurrence=["every friday"], skip=["due_date"])
P("de-project", ["german", "project"], "Neue Aufgabe im Projekt Home, die Dachrinne sauber machen, am Wochenende.", ["dachrinne"], due_date=day(5), project="Home", skip=["section"])

# ---------------------------------------------------------------- speech recognition noise
P("noisy-at-a-task", ["noisy"], "okay at a new task call the dentist to move my appointment", ["dentist"])
P("noisy-ad-task", ["noisy"], "um ad a task for tomorrow by oat milk and bananas", ["oat milk"], due_date=day(1))
P("noisy-run-on", ["noisy"], "so yeah add a task uh renew the the the passport for lina um before the holidays i think that's it", ["passport"], skip=["due_date"])
P("noisy-todo-list", ["noisy"], "put that on my two do list pay the plumber", ["plumber"])
P("noisy-remind-me", ["noisy"], "remind me too cancel the magazine subscription on friday", ["cancel", "subscription"], due_date=day(4))

# ---------------------------------------------------------------- long rambles
P("long-1", ["long"], """So I was at the meeting with the school today and it went okay, they want us to bring the forms next time,
  and the teacher said that Lina is doing really well in reading which is great. Um, they also talked about the trip in November, I
  think it's the fourteenth, and it costs thirty euros. Hmm. There was a long discussion about whether the kids can bring phones,
  which, I don't know, I don't have a strong opinion. Some parents were really upset. Anyway, the teacher handled it well. Okay put
  that on my to-do list, pay the thirty euros for the school trip before the fourteenth of November. And then, yeah, I walked home
  and it started raining, and I remembered I left the umbrella at the office again. Typical.""",
  ["school trip"], skip=["due_date"])
P("long-2", ["long"], """Morning walk. Thinking about the recorder project again. The sounds are getting good, I like the wooden blocks
  and the chime. What I'm less sure about is the screen, it's one long list right now and you can't find anything. We talked about
  three design directions and I'm waiting for those. In the meantime the Mac app hasn't been touched in days, I don't even know if
  it still builds. Probably it does. There's also the thing with the name, Quasi is not a name, it's a placeholder. I had a few
  ideas on the weekend but nothing stuck. Oh, and before I forget, add a task, in Work, ask Tobi whether he still wants to test the
  app with his own recorder, this week if possible. Okay. The weather's turning, I should have brought a jacket.""",
  ["tobi"], project="Work", skip=["due_date"])
P("long-3", ["long"], """Okay, brain dump. The kitchen tap is dripping, has been for a week. The landlord knows. The car makes a noise
  when I brake, not sure that's related to the tires. Mum's birthday is coming up and I haven't got anything. Work is fine, the
  client presentation moved to next month so there's breathing room. I've been sleeping badly, probably too much coffee. What else.
  The bike needs a new chain. And the tax thing, I got a letter, it says I have to respond within two weeks. That one I can't let
  slide. Add a task for that, respond to the tax office letter, high priority.""",
  ["tax office"], priority=2, skip=["due_date", "deadline_date"])


# ---------------------------------------------------------------- several tasks in one note
S = "several tasks"
M("multi-two-1", [S, "two requests"], "Add a task, call the plumber. And add another task, buy light bulbs.",
  [T(["plumber"]), T(["light bulb"])])
M("multi-two-2", [S, "two requests"], "New task, renew the car insurance. New task, book the dentist for Lina.",
  [T(["car insurance"]), T(["dentist", "lina"])])
M("multi-two-dates", [S, "two requests"], "Add a task for tomorrow, send the slides to Katrin. And another one for Friday, pay the electrician.",
  [T(["slides", "katrin"], due_date=day(1)), T(["electrician"], due_date=day(4))])
M("multi-two-remind", [S, "two requests"], "Remind me to water the plants tonight, and remind me to take the bins out tomorrow morning.",
  [T(["water", "plants"], due_date=day(0)), T(["bins"], due_date=day(1))])
M("multi-two-times", [S, "two requests"], "Tomorrow at nine remind me to take the car to the garage, and at five remind me to pick it up again.",
  [T(["take", "garage"], due_date=day(1), due_time="09:00"), T(["pick"], due_date=day(1), due_time="17:00")])
M("multi-three-list", [S, "dictated list"], "Three tasks. One, buy stamps. Two, post the letter to the tax office. Three, pick up the passport photos.",
  [T(["stamps"]), T(["letter", "tax office"]), T(["passport photos"])])
M("multi-three-few", [S, "dictated list"], "I've got a few tasks for you. Order printer ink, cancel the old phone contract, and email the landlord about the parking spot.",
  [T(["printer ink"]), T(["cancel", "phone contract"]), T(["landlord", "parking"])])
M("multi-three-colon", [S, "dictated list"], "Add these to my to-do list, descale the kettle, clean the oven, and wash the windows.",
  [T(["kettle"]), T(["oven"]), T(["windows"])])
M("multi-four", [S, "dictated list"], "Okay, four quick ones for the list. Charge the camera, print the tickets, find the umbrella, check in online.",
  [T(["camera"]), T(["tickets"]), T(["umbrella"]), T(["check in"])])
M("multi-all-tomorrow", [S, "shared context"], "Three tasks, all for tomorrow. Call the school, return the parcel, and book the car wash.",
  [T(["school"], due_date=day(1)), T(["parcel"], due_date=day(1)), T(["car wash"], due_date=day(1))])
M("multi-both-work", [S, "shared context"], "Two tasks, both in Work. Update the roadmap, and reply to the bakery chain.",
  [T(["roadmap"], project="Work"), T(["bakery chain"], project="Work")])
M("multi-home-errands", [S, "shared context"], "Add two tasks in Home, both labelled errands. Buy paint for the hallway, and get the keys copied.",
  [T(["paint"], project="Home", labels=["errands"]), T(["keys"], project="Home", labels=["errands"])])
M("multi-both-urgent", [S, "shared context"], "Two urgent tasks. First, call the bank about the fraud alert. Second, change the password for the online banking.",
  [T(["bank", "fraud"], title_lacks=["urgent"], priority=1), T(["password"], title_lacks=["urgent"], priority=1)])
M("multi-both-friday", [S, "shared context"], "Add two tasks for Friday, both low priority. Sort the receipts, and clean out the car.",
  [T(["receipts"], due_date=day(4), priority=4), T(["car"], due_date=day(4), priority=4)])
M("multi-ramble-1", [S, "through a ramble"], """Walking home. The stairwell light is out again, somebody should tell the caretaker. Actually,
  add that as a task, tell the caretaker about the stairwell light. Um, what else. I saw the posters for the school fair, that's in
  two weeks, and we said we'd bake something. I don't know what yet. Oh, and add a task to sign up for the cake stall, that has to
  happen by Wednesday.""",
  [T(["caretaker"]), T(["cake stall"], due_date=day(2))])
M("multi-ramble-2", [S, "through a ramble"], """The gutter on the back of the house is leaking again, I saw it this morning. Somebody has to get
  up there and clean it out. Make that a task. It rained all night, the garden is a swamp. The kids loved it. Oh, and remind me to
  call mum on Sunday, it's her name day.""",
  [T(["gutter"]), T(["call", "mum"], due_date=day(6))])
M("multi-ramble-3", [S, "through a ramble"], """Okay, brain dump after the meeting. The client wants the numbers earlier than we said, so, new
  task, send the client the draft numbers by Thursday. Then Katrin asked about the offsite, nobody has booked anything. Add a task,
  book a room for the offsite. And the projector in the small room is broken, which is annoying but not my job. Last thing, remind
  me to bring the adapter tomorrow.""",
  [T(["draft numbers"], due_date=day(3)), T(["room", "offsite"]), T(["adapter"], due_date=day(1))])
M("multi-backref-two", [S, "through a ramble"], "The bike has a flat tire, and the bell is broken too. Make those two tasks.",
  [T(["tire"]), T(["bell"])])
M("multi-de-1", [S, "german"], "Zwei Aufgaben. Erstens, den Kinderarzt anrufen. Zweitens, die Winterreifen bestellen.",
  [T(["kinderarzt"]), T(["winterreifen"])])
M("multi-de-2", [S, "german"], "Neue Aufgabe, morgen das Paket zur Post bringen. Und noch eine Aufgabe, am Freitag die Miete überweisen.",
  [T(["paket"], due_date=day(1)), T(["miete"], due_date=day(4))])
M("multi-mixed-1", [S, "different fields"], """Add an urgent task in Work, send the contract to the client today. And a low priority one in Home,
  sort the bookshelf.""",
  [T(["contract"], title_lacks=["urgent"], due_date=day(0), priority=1, project="Work"), T(["bookshelf"], priority=4, project="Home")])
M("multi-mixed-2", [S, "different fields"], """Two things. Remind me every Monday to submit the timesheet. And add a task for tomorrow at ten,
  call the tax adviser, label it calls.""",
  [T(["timesheet"], skip=["due_date"], recurrence=["every monday"]), T(["tax adviser"], due_date=day(1), due_time="10:00", labels=["calls"])])
M("multi-mixed-3", [S, "different fields"], """New task under Admin in Work, file the expense claims, by Friday. Another task, in Family, order
  the photo book, the deadline is the twentieth.""",
  [T(["expense claims"], due_date=day(4), project="Work", section="Admin"), T(["photo book"], deadline_date="2026-10-20", project="Family")])
M("multi-mixed-4", [S, "different fields"], """Add a task in Mosey under Video, export the trailer, takes about an hour, tomorrow at two. And
  remind me on Thursday to post it, high priority.""",
  [T(["export", "trailer"], due_date=day(1), due_time="14:00", duration_minutes=60, project="Mosey", section="Video"),
   T(["post"], due_date=day(3), priority=2, skip=["project", "section"])])
M("multi-corrected-1", [S, "taken back"], "Three tasks. Buy coffee, call the garage, and book the hotel. Ah no, scratch the second one, I already called.",
  [T(["coffee"]), T(["hotel"])])
M("multi-corrected-2", [S, "taken back"], "Add a task, pay the gym. And add a task, cancel the newspaper. Actually no, forget the gym one, it's on direct debit.",
  [T(["newspaper"], title_lacks=["gym"])])
M("multi-noisy", [S, "two requests"], "at a task by stamps and at a task call the bank", [T(["stamps"]), T(["bank"])])
# One request, however much it holds, is one task.
M("nosplit-dentist", [S, "stays one"], "Add a task, call the dentist and ask whether they have anything earlier, and also ask about the bill.",
  [T(["dentist"])])
M("nosplit-hardware", [S, "stays one"], "New task, go to the hardware store and get screws, wall plugs and a spirit level.", [T(["hardware store"])])
M("nosplit-cc", [S, "stays one"], "Remind me to email Marcus the invoice and copy in the accountant.", [T(["marcus", "invoice"])])
M("nosplit-party", [S, "stays one"], "Add a task, plan Lina's birthday party, so invite the class, order the cake, book the room.", [T(["birthday party"])])
M("nosplit-pack", [S, "stays one"], "New task for Thursday, pack for the trip, passport, chargers and the rain jacket.", [T(["pack"], due_date=day(3))])
M("nosplit-landlord", [S, "stays one"], "Add a task, write to the landlord about the heating and mention the broken intercom as well.", [T(["landlord"])])
M("nosplit-shopping", [S, "stays one"], "Put this on my list, buy milk, eggs and bread.", [T(["milk"])])
M("nosplit-meeting", [S, "stays one"], "Add a task for Wednesday, prepare the board meeting, that means the agenda, the numbers and the room.",
  [T(["board meeting"], due_date=day(2))])
# A request next to things the speaker only means to do.
M("multi-intent-1", [S, "request and intentions"], "I need to call my brother at some point and the car needs washing. Anyway, add a task, book the vet for the cat.",
  [T(["vet"])])
M("multi-intent-2", [S, "request and intentions"], "Add a task, send the birthday card to grandma. I should also really start running again, but that's another story.",
  [T(["card", "grandma"])])
M("multi-intent-3", [S, "request and intentions"], """Tomorrow I've got the dentist at nine and then lunch with Katrin, so the morning is gone. Two tasks though.
  Send the offer to the bakery chain, and renew the domain.""",
  [T(["offer", "bakery chain"]), T(["renew", "domain"])])

# ---------------------------------------------------------------- things named as tasks or to-dos, without "add"
# The first has the shape of a note the extractor once answered with no task: nothing in it says "add".
M("named-tasks-ramble", [S, "named as tasks"], """Okay so, um, thinking out loud, there are a few things, uh, a few tasks for tomorrow,
  a few to-dos, which is, I need to wash the car. I need to buy stamps and go to that first rehearsal.""",
  [T(["car"], due_date=day(1)), T(["stamps"], due_date=day(1)), T(["rehearsal"], due_date=day(1))], recorded_at="2026-10-05T15:39")
M("named-todos-today", [S, "named as tasks"], "Okay, my to-dos for today. Um, pick up the parcel, and call the insurance about the claim.",
  [T(["parcel"], due_date=day(0)), T(["insurance"], due_date=day(0))])
M("named-tasks-thursday", [S, "named as tasks"], "So, tasks for Thursday. Uh, send the contract to the lawyer, book the car inspection, and, um, order printer paper.",
  [T(["contract", "lawyer"], due_date=day(3)), T(["car inspection"], due_date=day(3)), T(["printer paper"], due_date=day(3))])
M("named-couple-of-tasks", [S, "named as tasks"], "Um, a couple of tasks while I think of it. I need to renew my passport, and I need to cancel the gym trial.",
  [T(["passport"]), T(["cancel", "gym"])])
P("named-one-todo", ["named as tasks"], "Uh, one to-do for tomorrow, which is, I have to return the library books.", ["library book"], due_date=day(1))
M("named-de-aufgaben", [S, "named as tasks", "german"], "Also, ein paar Aufgaben für morgen. Ich muss die Wäsche machen und einkaufen gehen.",
  [T(["wäsche"], due_date=day(1)), T(["einkaufen"], due_date=day(1))])
N("neg-things-no-list", ["intention only"], "Uh, a few things on my mind today. I need to sleep more, and I should probably eat better. Anyway.")
N("neg-busy-tomorrow", ["intention only"], "Tomorrow is going to be busy. I have to drive to Hamburg, then there's the meeting, and in the evening the parents' thing at school.")

ids = [c["id"] for c in CASES]
assert len(ids) == len(set(ids)), "duplicate case id"
here = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(here, "cases.jsonl"), "w") as f:
    for case in CASES:
        f.write(json.dumps({**case, "catalog": CATALOG}, ensure_ascii=False) + "\n")

def describe(expected):
    if not expected["tasks"]:
        return "no task"
    if len(expected["tasks"]) == 1:
        return describe_task(expected["tasks"][0])
    return f"{len(expected['tasks'])} tasks" + "".join(f"\n\n{i}. {describe_task(t)}" for i, t in enumerate(expected["tasks"], 1))

def describe_task(expected):
    skip = expected["skip"]
    parts = ["title has " + " + ".join(f"“{w}”" for w in expected["title_has"])]
    if expected["title_lacks"]: parts.append("title lacks " + ", ".join(f"“{w}”" for w in expected["title_lacks"]))
    for key, label in (("due_date", "due"), ("due_time", "at"), ("deadline_date", "deadline"), ("project", "project"), ("section", "section")):
        if expected[key]: parts.append(f"{label} {expected[key]}")
    if expected["recurrence"]: parts.append("repeats " + " / ".join(expected["recurrence"]))
    if expected["priority"]: parts.append(f"p{expected['priority']}")
    if expected["duration_minutes"]: parts.append(f"{expected['duration_minutes']} min")
    if expected["labels"]: parts.append("labels " + ", ".join(expected["labels"]))
    if skip: parts.append("(not graded: " + ", ".join(skip) + ")")
    return "; ".join(parts)

positives = sum(bool(c["expected"]["tasks"]) for c in CASES)
several = sum(len(c["expected"]["tasks"]) > 1 for c in CASES)
with open(os.path.join(here, "cases.md"), "w") as f:
    f.write(f"# Task extraction eval cases\n\n{len(CASES)} cases: {positives} that ask for a task ({several} of them for more than one), {len(CASES) - positives} that do not. "
            "Generated by `make_cases.py`; edit that file, not this one.\n\n"
            "Unless noted, recorded Monday 2026-10-05 at 10:00. Any field not listed for a task is expected to be empty.\n\n"
            "Projects: " + "; ".join(p["name"] + (" (" + ", ".join(p["sections"]) + ")" if p["sections"] else "") for p in CATALOG["projects"]) + "\n\n"
            "Labels: " + ", ".join(CATALOG["labels"]) + "\n")
    group = None
    for case in CASES:
        if case["tags"][0] != group:
            group = case["tags"][0]
            f.write(f"\n## {group}\n\n")
        when = "" if case["recorded_at"] == "2026-10-05T10:00" else f" (recorded {case['recorded_at'].replace('T', ' ')})"
        f.write(f"**{case['id']}**{when}\n\n> {case['transcript']}\n\nExpected: {describe(case['expected'])}\n\n")
print(f"{len(CASES)} cases: {positives} with a task ({several} with several), {len(CASES) - positives} without")
