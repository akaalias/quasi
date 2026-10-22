#!/usr/bin/env python3
"""Writes cases.jsonl: notes that call things off, ask for reminders, or start timers.

Each case expects: tasks (words the title must have, and whether it is a reminder), the people
messages go to, the timers' lengths in seconds, and whether something was called off.
"""
import json, os

CATALOG = {"projects": [{"name": "Inbox", "sections": []}, {"name": "Work", "sections": ["Admin"]}, {"name": "Home", "sections": []}],
           "labels": ["errands", "calls"]}

def t(*words, reminder=False): return {"title_has": list(words), "reminder": reminder}

CASES = [
    # Calling off
    ("cancel-message", "Send Franziska a message that I love her. Oh, actually never mind, cancel that, don't send it.", [], [], [], True),
    ("cancel-message-keep-task", "Add a task to buy milk. And text Jonas that I'm running late. Actually, don't send the message to Jonas, I'll call him.", [t("milk")], [], [], True),
    ("cancel-task", "Create a task to call the dentist. Hmm, no, never mind, forget it, don't create the task.", [], [], [], True),
    ("cancel-everything", "Add a task to book the flights to Zurich and send Toby a message that I land at six. Oh, actually, never mind, cancel that, do not send the message, do not create the tasks.", [], [], [], True),
    ("cancel-timer", "Set a timer for ten minutes. Never mind, cancel the timer.", [], [], [], True),
    ("cancel-then-new", "Add a task, buy flowers. Cancel that. Add a task to buy wine instead.", [t("wine")], [], [], True),
    ("correction-not-cancel", "Text Alex I'm on my way. No wait, make it: I'll be ten minutes late.", [], ["Alex"], [], False),
    ("cancel-reminder-german", "Erinnere mich morgen um neun, die Bank anzurufen. Ach nee, vergiss es, mach das doch nicht.", [], [], [], True),
    ("cancel-message-german", "Schreib Jonas, dass ich später komme. Nein, doch nicht, nicht schicken.", [], [], [], True),
    ("cancel-one-of-list", "Add three tasks: buy stamps, post the letter, pick up the photos. Scratch the second one.", [t("stamps"), t("photos")], [], [], True),
    ("cancelled-meeting-not-cancel", "The meeting with Felix got cancelled, so add a task to reschedule it.", [t("reschedule")], [], [], False),
    ("never-mind-not-cancel", "Never mind the weather, add a task to fix the bike.", [t("bike")], [], [], False),
    # Reminders
    ("reminder-time", "Remind me at five to call Mum.", [t("call", reminder=True)], [], [], False),
    ("task-not-reminder", "Add a task to renew the passport.", [t("passport")], [], [], False),
    ("reminder-set", "Set a reminder for tomorrow morning to bring the documents.", [t("documents", reminder=True)], [], [], False),
    ("reminder-german", "Erinnere mich morgen um acht, die Steuererklärung abzugeben.", [t("steuer", reminder=True)], [], [], False),
    ("todo-not-reminder", "Put on my to-do list: clean the garage.", [t("garage")], [], [], False),
    ("reminder-no-time", "Remind me to water the plants.", [t("plants", reminder=True)], [], [], False),
    # Timers
    ("timer", "Set a timer for ten minutes.", [], [], [600], False),
    ("timer-label", "Timer, 25 minutes, pasta.", [], [], [1500], False),
    ("timer-german", "Stell einen Timer auf fünf Minuten für den Tee.", [], [], [300], False),
    ("timer-long", "Start a countdown of an hour and a half.", [], [], [5400], False),
    ("reminder-in-an-hour", "Remind me in an hour to take out the laundry.", [t("laundry", reminder=True)], [], [], False),
    ("timer-mentioned", "I set a timer earlier and the pasta was overcooked anyway.", [], [], [], False),
    ("task-named-past", "I had a task to flesh out the idea of an article about autonomous research versus automatic research, which is also, it feels like, automation versus augmentation. And I would like to maybe just write something and share on Twitter that calls out that easy misunderstanding.", [t("article")], [], [], False),
    ("intent-not-task", "I need to think more about the article on autonomous research at some point, it's a fun topic.", [], [], [], False),
    # Pointing back at the note before
    ("previous-into-task", "Can you make my previous note into a task?", [t("article")], [], [], False,
     "I had a task to flesh out the idea of an article about autonomous research versus automatic research."),
    ("previous-send", "Send what I just said to Jonas.", [], ["Jonas"], [], False, "The workshop moves to Thursday at ten, same room."),
    ("previous-ignored", "Okay, and now something else entirely: the weather is lovely today.", [], [], [], False,
     "Add a task to buy milk."),
    ("previous-not-used-alone", "Add a task to call the plumber.", [t("plumber")], [], [], False, "I should also think about the garden at some point."),
    ("timer-and-message", "Set a timer for 90 seconds and text Felix I'm almost there.", [], ["Felix"], [90], False),
]

with open(os.path.join(os.path.dirname(__file__), "cases.jsonl"), "w") as f:
    for id, transcript, tasks, messages, timers, cancelled, *previous in CASES:
        f.write(json.dumps({"id": id, "recorded_at": "2026-10-22T09:00", "transcript": transcript, "catalog": CATALOG,
                            "previous": previous[0] if previous else None,
                            "expected": {"tasks": tasks, "messages": messages, "timers": timers, "cancelled": cancelled}},
                           ensure_ascii=False) + "\n")
print(len(CASES), "cases")
