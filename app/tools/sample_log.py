#!/usr/bin/env python3
"""Prints a sample log.json for screenshots: the notes shown in the Logbook design."""
import datetime, json

today = datetime.datetime.now().replace(second=0, microsecond=0)
def at(days_ago, hour, minute):
    moment = (today - datetime.timedelta(days=days_ago)).replace(hour=hour, minute=minute)
    return moment.astimezone().astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def task(title, source, **fields):
    draft = {"title": title, "notes": "", "source": source, "due": "", "dueDate": "", "dueTime": "", "recurrence": "",
             "deadlineDate": "", "priority": 0, "durationMinutes": 0, "project": "", "section": "", "labels": []}
    draft.update(fields)
    return draft

def added(title, source, **fields):
    """A task as the log keeps it: the draft, and the id it was given in Todoist."""
    return {"draft": task(title, source, **fields), "todoistID": "demo"}

AIRPLANE = ("I've been thinking about the battery thing on the recorder. So the phone holds the link all day and it costs maybe "
            "eight percent a day, which is fine. What I really don't know is how it behaves when I'm traveling and the phone is in "
            "airplane mode and then comes back. I should probably just test that on the train on Thursday. Oh, yes, add that as a task.")
notes = [
    {"id": "a", "date": at(0, 14, 3), "seconds": 38, "transcript": AIRPLANE, "outcome": "taskAdded",
     "tasks": [added("Test recorder after airplane mode", "I should probably just test that on the train on Thursday. Oh, yes, add that as a task.",
                     due="Thursday", dueDate="2026-10-08", project="Work")]},
    {"id": "b", "date": at(0, 11, 20), "transcript": "The light was really nice around five. I want to remember that.", "outcome": "note"},
    {"id": "c", "date": at(0, 8, 47), "transcript": "New task, call the school office tomorrow at three.", "outcome": "taskAdded",
     "tasks": [added("Call the school office", "New task, call the school office tomorrow at three.", due="Tomorrow 15:00", dueDate="2026-10-06", dueTime="15:00")]},
    {"id": "d", "date": at(1, 18, 32), "transcript": "Remind me to order a new water filter for the kitchen, we're almost out.", "outcome": "taskAdded",
     "tasks": [added("Order a new water filter", "Remind me to order a new water filter for the kitchen, we're almost out.")]},
    {"id": "e", "date": at(1, 9, 5), "transcript": "Walking to the station. It's colder than I thought.", "outcome": "note"},
]
# `sample_log.py site`: for the web page's screenshots, one note carries three tasks.
import sys
if sys.argv[1:] == ["site"]:
    said = "Three tasks, all for tomorrow: call the school, return the parcel, book the car wash."
    notes[2] = {"id": "c", "date": at(0, 8, 47), "seconds": 9, "transcript": said, "outcome": "taskAdded",
                "tasks": [added(title, said, due="tomorrow", dueDate="2026-10-06") for title in ("Call the school", "Return the parcel", "Book the car wash")]}
print(json.dumps(notes, indent=1))
