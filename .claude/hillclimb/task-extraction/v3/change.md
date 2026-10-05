A note can ask for several tasks: the answer is a list, one entry per request, empty if there is none.

Before, the extractor returned at most one task and was told to take the most explicit request. The prompt now says what
makes something its own task (asked for separately, or one item of a dictated list), that one request stays one task
however much it contains, and that what is said about several tasks at once applies to each. The eval grew from 160 to
198 cases: 38 new ones for two to four tasks in a note, lists, shared context, tasks taken back, and requests that
must not be split. It also grades the number of tasks.
