#!/usr/bin/env python3
"""Grades the runner's answers against cases.jsonl and writes results.jsonl for the report.

A note can ask for none, one or several tasks. The tasks in an answer are paired with the expected
ones by their titles (whichever shares the most expected words), and every field of each pair is
checked. Four numbers per case:
  exact   1 if the note was read correctly as a whole: the right number of tasks, and every
          graded field of every task right. This is the headline.
  detect  1 if "is there a task at all" was answered correctly.
  count   1 if the number of tasks is right.
  fields  the share of graded fields that were right, a missing task counting as all wrong
          (for a note without a task: same as detect).

usage: grade.py <cases.jsonl> <variant folder>          grade outputs.jsonl in that folder
       grade.py <cases.jsonl> --selftest                check the grader on known-good and known-bad answers
"""
import collections, json, math, os, sys

FIELDS = ["title", "due_date", "due_time", "recurrence", "deadline_date", "priority", "duration_minutes", "project", "section", "labels"]
KEYS = {"due_date": "dueDate", "due_time": "dueTime", "deadline_date": "deadlineDate", "duration_minutes": "durationMinutes"}

def norm(text): return " ".join(str(text).lower().split())

def check_task(expected, draft):
    """Returns ({field: right?}, [what was wrong]) for one expected task and the draft paired with it."""
    checks, wrong = {}, []
    for field in FIELDS:
        if field in expected["skip"]:
            continue
        got = draft.get(KEYS.get(field, field))
        if field == "title":
            title = norm(got)
            missing = [w for w in expected["title_has"] if norm(w) not in title]
            unwanted = [w for w in expected["title_lacks"] if norm(w) in title]
            good = not missing and not unwanted
            detail = f"title {got!r}" + (f" lacks {missing}" if missing else "") + (f" contains {unwanted}" if unwanted else "")
        elif field == "recurrence":
            wanted = [norm(w) for w in expected["recurrence"]]
            good = norm(got) in wanted if wanted else norm(got) == ""
            detail = f"recurrence {got!r}, expected {' or '.join(wanted) or 'none'}"
        elif field == "labels":
            good = sorted(got or []) == sorted(expected["labels"])
            detail = f"labels {got}, expected {expected['labels']}"
        else:
            good = got == expected[field]
            detail = f"{field} {got!r}, expected {expected[field]!r}"
        checks[field] = good
        if not good:
            wrong.append(detail)
    return checks, wrong

def pair(expected, drafts):
    """Pairs each expected task with the draft whose title shares the most of its words; leftovers stay unpaired."""
    scores = []
    for i, task in enumerate(expected):
        for j, draft in enumerate(drafts):
            title = norm(draft.get("title", ""))
            shared = sum(norm(w) in title for w in task["title_has"]) / max(1, len(task["title_has"]))
            scores.append((shared, -abs(i - j), i, j))
    pairs, used_i, used_j = {}, set(), set()
    for shared, _, i, j in sorted(scores, reverse=True):
        if i not in used_i and j not in used_j:
            pairs[i] = j
            used_i.add(i); used_j.add(j)
    return pairs

def grade_case(case, drafts):
    """Returns (grade dict, list of what was wrong, list of per-field results for each paired task)."""
    expected = case["expected"]["tasks"]
    drafts = drafts or []
    detect = int(bool(drafts) == bool(expected))
    count = int(len(drafts) == len(expected))
    if not expected:
        wrong = [] if not drafts else ["invented: " + "; ".join(repr(d.get("title")) for d in drafts)]
        return {"exact": detect, "detect": detect, "count": count, "fields": float(detect)}, wrong, []
    if not drafts:
        return {"exact": 0, "detect": 0, "count": 0, "fields": 0.0}, ["missed: no task found"], []
    wrong, all_checks, right, total = [], [], 0, 0
    if not count:
        wrong.append(f"{len(drafts)} tasks instead of {len(expected)}: " + "; ".join(repr(d.get("title")) for d in drafts))
    pairs = pair(expected, drafts)
    for i, task in enumerate(expected):
        graded = [f for f in FIELDS if f not in task["skip"]]
        total += len(graded)
        if i not in pairs:
            continue
        checks, task_wrong = check_task(task, drafts[pairs[i]])
        all_checks.append(checks)
        right += sum(checks.values())
        label = f"task {i + 1}: " if len(expected) > 1 else ""
        wrong += [label + w for w in task_wrong]
    return {"exact": int(not wrong), "detect": detect, "count": count, "fields": right / total}, wrong, all_checks

def wilson(successes, n):
    if n == 0: return (0.0, 0.0)
    z, p = 1.96, successes / n
    centre, half = p + z * z / (2 * n), z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))
    return ((centre - half) / (1 + z * z / n), (centre + half) / (1 + z * z / n))

def perfect(case):
    return [{"title": " ".join(e["title_has"]), "dueDate": e["due_date"], "dueTime": e["due_time"],
             "recurrence": e["recurrence"][0] if e["recurrence"] else "", "deadlineDate": e["deadline_date"], "priority": e["priority"],
             "durationMinutes": e["duration_minutes"], "project": e["project"], "section": e["section"], "labels": e["labels"]}
            for e in case["expected"]["tasks"]]

def selftest(cases):
    def rate(answer):
        grades = [grade_case(c, answer(c))[0] for c in cases]
        return sum(g["exact"] for g in grades) / len(grades)
    negatives = sum(not c["expected"]["tasks"] for c in cases) / len(cases)
    bare = {"title": "do the thing", "dueDate": "", "dueTime": "", "recurrence": "", "deadlineDate": "", "priority": 0,
            "durationMinutes": 0, "project": "", "section": "", "labels": []}
    results = {"perfect answers": (rate(perfect), 1.0), "always 'no task'": (rate(lambda c: []), negatives),
               "always one bare task": (rate(lambda c: [bare]), 0.0),
               "perfect answers, last task dropped": (rate(lambda c: perfect(c)[:-1]), negatives),
               "perfect answers, one task too many": (rate(lambda c: perfect(c) + [bare]), 0.0)}
    failed = False
    for name, (got, want) in results.items():
        ok = abs(got - want) < 1e-9
        failed |= not ok
        print(f"{'ok  ' if ok else 'FAIL'} {name}: exact {got:.1%}, expected {want:.1%}")
    sys.exit(1 if failed else 0)

def main():
    cases = [json.loads(line) for line in open(sys.argv[1])]
    if sys.argv[2] == "--selftest":
        selftest(cases)
    folder = sys.argv[2]
    by_id = {c["id"]: c for c in cases}
    outputs = [json.loads(line) for line in open(os.path.join(folder, "outputs.jsonl"))]
    errors_path = os.path.join(folder, "errors.jsonl")
    errors = [json.loads(line) for line in open(errors_path)] if os.path.exists(errors_path) else []
    answered = {(o["id"], o["rep"]) for o in outputs}
    errors = [e for e in errors if (e["id"], e["rep"]) not in answered]

    field_right, field_total = collections.Counter(), collections.Counter()
    groups = collections.defaultdict(list)
    tp = fp = tn = fn = 0
    several = several_count = 0
    rows = []
    for output in sorted(outputs, key=lambda o: (o["id"], o["rep"])):
        case = by_id.get(output["id"])
        if case is None:
            continue
        grade, wrong, all_checks = grade_case(case, output["drafts"])
        expected = case["expected"]["tasks"]
        positive = bool(expected)
        tp += positive and grade["detect"]; fn += positive and not grade["detect"]
        tn += (not positive) and grade["detect"]; fp += (not positive) and not grade["detect"]
        if len(expected) > 1:
            several += 1
            several_count += grade["count"]
        for checks in all_checks:
            for field, good in checks.items():
                field_total[field] += 1
                field_right[field] += good
        groups[case["tags"][0]].append(grade["exact"])
        rows.append({"prompt_id": case["id"], "rep": output["rep"], "prompt": case["transcript"], "tags": case["tags"],
                     "status": "ok", "stop_reason": "end_turn", "grade": grade,
                     "explanation": {"exact": "; ".join(wrong) or "all correct"},
                     "model": output["model"], "latency_s": output["latency_s"], "usage": output["usage"],
                     "meta": {"answer": output["drafts"], "attempts": output["attempts"]}})
    with open(os.path.join(folder, "results.jsonl"), "w") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")

    n = len(rows)
    exact = sum(r["grade"]["exact"] for r in rows)
    counted = sum(r["grade"]["count"] for r in rows)
    low, high = wilson(exact, n)
    latencies = sorted(r["latency_s"] for r in rows)
    tokens_in, tokens_out = sum(r["usage"]["input_tokens"] for r in rows), sum(r["usage"]["output_tokens"] for r in rows)
    lines = [f"Read correctly as a whole: {exact} of {n} ({exact / n:.1%}, 95% interval {low:.0%} to {high:.0%})", "",
             "Is there a task?",
             f"  asked for one and found:      {tp} of {tp + fn}" + (f" ({tp / (tp + fn):.1%} recall)" if tp + fn else ""),
             f"  did not ask and none made:    {tn} of {tn + fp}" + (f" ({tn / (tn + fp):.1%} specificity)" if tn + fp else ""),
             f"  tasks invented:               {fp}" + (f" (precision {tp / (tp + fp):.1%})" if tp + fp else ""), "",
             "How many tasks?",
             f"  right number of tasks:        {counted} of {n} ({counted / n:.1%})",
             f"  ... in notes asking for several: {several_count} of {several}" if several else "", "",
             "Fields, over the tasks that were found and paired:"]
    lines += [f"  {field:<17}{field_right[field]:>4} of {field_total[field]:<4} {field_right[field] / field_total[field]:.1%}" for field in FIELDS if field_total[field]]
    lines += ["", "By kind of case (read correctly as a whole):"]
    lines += [f"  {group:<17}{sum(v):>4} of {len(v)}" for group, v in groups.items()]
    cost = tokens_in / 1e6 * 2.0 + tokens_out / 1e6 * 10.0      # claude-sonnet-5-5: $2 in, $10 out per million tokens
    lines += ["", f"Latency: median {latencies[n // 2]:.1f} s, slowest {latencies[-1]:.1f} s",
              f"Tokens: {tokens_in:,} in, {tokens_out:,} out, about ${cost:.2f} for this run (${cost / n:.4f} per note)",
              f"Errors (not scored): {len(errors)}"]
    failures = [r for r in rows if not r["grade"]["exact"]]
    if failures:
        lines += ["", "Not read correctly:"] + [f"  {r['prompt_id']}: {r['explanation']['exact']}" for r in failures]
    summary = "\n".join(lines)
    open(os.path.join(folder, "summary.txt"), "w").write(summary + "\n")
    print(summary)

main()
