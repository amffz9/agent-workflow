# Large plans and parallel work

For contracts with more than three parts or more than one implementer.
Smaller plans stay in one file with the same sections.


## Split the plan into files

Each reader loads only what it needs, instead of many agents re-reading one huge file.

```
plans/<name>/
  00-overview.md       tier and why, decisions and assumptions, scope, glossary, parts,
                       the tree, flow, end-to-end check, execution plan, and an index:
                       "to work on part X, read these files"
  contracts/<part>.md  one contract block per part
  examples/<part>.md   the Given/When/Then table for that part
  examples/flow.md     end-to-end and cross-part failure examples
  packets/<id>.md      one per work packet, written after the gates pass
  findings.md          the findings log
```

- The glossary and part list live only in `00-overview.md`, so a rename happens in one place.
- Each file opens with two lines: what it covers, and what else to read with it.
- Contract files never contain file paths, languages or build details. Those go in packets.
- An agent given a packet reads the packet, the glossary, the contracts it names, the code it owns and the code that calls it. Nothing else unless blocked.


## The tree

- For each part, list the parts it calls. Entry points at the top, leaves at the bottom.
- A branch with its own flow or its own implementer becomes a module, with its own small contract. Its parent sees only its entry operations.
- Parts called from many places are leaves. A cycle means the part boundaries are wrong.
- Boundary parts are leaves. That keeps all the platform checking in one place.
- Everyone building a part assumes its children keep their contracts. That is what lets every part be built at the same time.


## Packets

One packet per leaf, or per small branch when its nodes are tiny.
Don't make a packet, or tests, for something a branch's tests already cover.

```
PACKET <id>: <title>
Implements:  contracts/<part>.md (which operations), and which children it calls
Tests:       the example rows to turn into tests (some rows are held back and not named here)
Owns:        files or folders this packet may change (closed list)
Reads only:  other files it may read but not change
Others now:  packets running at the same time, and what each owns
Depends on:  contracts only, never another packet's code
Git:         none; the coordinator commits
Commands:    light checks of your own files only; heavy commands go through <queue agent>,
             or return "blocked: needs <command>"
Done when:   code and tests are written to the contract, static checks on owned files pass
             (a failure in someone else's file is reported, not fixed), no new TODOs remain.
             Run the tests only if every child is done; a leaf runs them straight away.
Return:      files changed, checks run with their output, anything blocked
```

- Send closed, well-specified packets to a cheaper model, and integration or judgment-heavy ones to a stronger model.
- A cheaper implementer may need a more explicit contract. Add detail when it names a specific missing obligation.


## Phases

1. Contract. The tree, contracts and examples, with boundary facts checked first-hand. Give each shared registration point (dependency manifest, route table, wiring, migration numbering) one owner packet. If the language needs signatures before static checks can pass, add signature-only stubs now. No fakes.
2. Build, all at once. Every packet runs in parallel, in any order, against the contracts. Nothing waits for a child.
3. Verify, bottom-up. One agent runs the tests from the leaves up; a node's tests run once its children pass. A failure goes back to the owner of the lowest failing node. At the top, the coordinator runs the held-back rows and `examples/flow.md`.

Before phase 2, check:

- No two packets own the same file. Shared hot files (a global stylesheet, a central registry) get one owner; others ask it for changes.
- No packet needs another packet's behaviour (not just its interface) to be written. If one does, the boundaries are wrong.

The cost of this approach: bugs only show up in phase 3. Keep the examples sharp and the tree shallow.


## Execution plan

In `00-overview.md`, write one line per piece of work: how it will run, and why.

- Do it yourself: small, serial, and the context is already loaded.
- Fresh agent with a packet: a closed task that needs only part of the context. The usual choice.
- Fork: several short jobs that each need most of one large context. Fork right after your last read, while the cache is warm, and have forks write long results to a file. A fork runs on your model and shares your mistakes, so never fork for a review.
- Reviewer on another model: reviews and second opinions.
- Serial chain: only when each step needs the previous step's real output.

Agents cost several times the tokens of doing the work yourself, so delegate only when a shape clearly fits.
Without agent support, do the work yourself and say independent review wasn't available.
