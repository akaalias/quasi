#!/usr/bin/env python3
"""Grades outputs.jsonl from the task-extraction runner against cases.jsonl. usage: grade.py cases.jsonl outputs.jsonl"""
import json, sys
cases = {c["id"]: c for c in map(json.loads, open(sys.argv[1]))}
right = 0
for out in map(json.loads, open(sys.argv[2])):
    e, wrong = cases[out["id"]]["expected"], []
    drafts = out.get("drafts", [])
    if len(drafts) != len(e["tasks"]): wrong.append(f"tasks {[d['title'] for d in drafts]}")
    else:
        for want, got in zip(e["tasks"], drafts):
            if not all(w.lower() in got["title"].lower() for w in want["title_has"]): wrong.append(f"title {got['title']!r}")
            if got.get("reminder", False) != want["reminder"]: wrong.append(f"reminder {got.get('reminder')} for {got['title']!r}")
    people = [m["recipient"] for m in out.get("messages", [])]
    if people != e["messages"]: wrong.append(f"messages to {people}")
    seconds = [t["seconds"] for t in out.get("timers", [])]
    if seconds != e["timers"]: wrong.append(f"timers {seconds}")
    if bool(out.get("cancelled")) != e["cancelled"]: wrong.append(f"cancelled {out.get('cancelled')}")
    right += not wrong
    print("ok  " if not wrong else "FAIL", out["id"], "; ".join(wrong))
print(f"{right}/{len(cases)} right")
