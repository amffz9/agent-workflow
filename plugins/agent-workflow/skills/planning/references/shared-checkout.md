# Several agents in one checkout

Use when two or more agents are active at the same time and any of them changes the checkout or runs heavy commands (test suites, builds, emulators, containers).
Not needed for one agent, a serial chain, or agents that only read.

Agents behave as if they are alone. In a shared checkout they stage each other's files, switch branches under each other, and run heavy commands at once until the machine thrashes.


## Name an owner for each shared resource

- the working tree, index, branch and HEAD
- test runners and anything heavy on CPU or memory
- fixed ports, database files, caches, lock files, output folders
- physical devices, shared hosts, emulators (one driver per device)
- registration points no packet owns: dependency manifests and lockfiles, route tables, wiring, migration numbering, snapshot files


## Pick a pattern

- Coordinator owns all git and heavy commands. Workers return file lists and ask. Best for a few agents with short tasks. The usual choice.
- Command-queue agent: a long-lived agent on a cheaper model that runs git and heavy commands for everyone. For many parallel writers or many heavy commands.
- Full clone per writer: only when a writer needs its own branch state, build cache or ports. The coordinator pulls the results.
- Lock file around heavy commands: when only the machine's limits matter.

Use a full clone, not a git worktree. A worktree still shares branches, stashes, hooks and lock files, and leaves out ignored and uncommitted files. Even a clone doesn't separate ports, databases or CPU.


## Rules for every agent

Put these in every brief, along with the other agents' names, what each owns, and the queue agent's name.

- You share this checkout. Edit only the files you own.
- Need a change in a file you don't own? Message its owner, or return `blocked: needs <change> in <file>`.
- A file changing that you didn't touch, or a failure in code you don't own, means another agent is working there. Report it; don't fix or revert it.
- Never undo work with git (`checkout`, `restore`, `reset`, `stash`, `clean`). In a shared tree that wipes everyone's uncommitted work. Undo by editing your own files back.
- Make no state-changing git calls.
- Run only light checks on your own files. Send heavy commands to the queue agent and wait. If you can't reach it, return `blocked: needs <command>`.

Whether agents can message each other depends on the harness. Test it with one small message before relying on it.


## What the command-queue agent does

- Takes requests in a fixed shape: who is asking, the command, the folder, the files it reads and writes, and anything it needs exclusively (a port, a device, lots of CPU).
- Does all state-changing git, one operation at a time. Commits only the returned packet's owned files, by path, never `-A`. Runs checkouts, resets, rebases and merges only when no other agent is working in the checkout.
- Answers read-only git (status, diff, log) freely.
- Limits how many heavy commands run at once. Measure the limit once, record it in the repository's agent instructions, and start at one if unknown.
- Runs whole-tree checks against a stable snapshot, or with writers paused. Otherwise a pass proves nothing.
- Spots collisions early: overlapping files, a checkout while others work, two requests for one port or device, a rerun of something already running.
- Reuses a result only if every input (tree, environment, dependencies, external state) is unchanged. Never reuses checks that touch a device.
- Returns a short result and a path to the full log.
- Says "wait" or "blocked" with a reason rather than running something risky.

Keep it on a cheap model and reset it between phases; its context is paid for on every call.
