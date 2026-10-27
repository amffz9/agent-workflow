# Planning guidance for coding agents (researched 2026-10-05)

Official docs pages show no date; all were fetched 2026-10-05 and are current as of that fetch. arXiv dates come from IDs and search snippets.

## 1. Anthropic: plan mode, when to plan, effort

Source: https://code.claude.com/docs/en/best-practices (fetched 2026-10-05)
- [quoted] "Plan mode is useful, but also adds overhead."
- [quoted] "Planning is most useful when you're uncertain about the approach, when the change modifies multiple files, or when you're unfamiliar with the code being modified. If you could describe the diff in one sentence, skip the plan."
- [quoted] For larger features, "have Claude interview you first ... write a complete spec to SPEC.md", then "start a fresh session to execute it." Good specs "name the files and interfaces involved, state what is out of scope, and end with an end-to-end verification step."
- [quoted] "Instead of carefully planning every move, you can tell Claude to try something risky. If it doesn't work, rewind." Same page: checkpoints miss Bash side effects and are "not a replacement for git."
- [quoted] "A reviewer prompted to find gaps will usually report some, even when the work is sound ... Chasing every finding leads to over-engineering." Tell reviewers to flag only gaps "that affect correctness or the stated requirements."
- [quoted] "Claude stops when the work looks done"; a runnable check is the first-listed practice.
- No recommended plan length is given anywhere on the page. No source found for plan length.

Source: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5 (fetched 2026-10-05)
- [quoted] Effort is "the main control for how much Claude Opus 5.5 thinks"; "Start at medium ... test several levels against your own evals."
- [quoted] "Reserve xhigh and max for work where you've measured a quality gain."
- [quoted] "To get less thinking, lower the effort level first."
- [quoted] Unattended runs: keep parts "in a checklist"; "stop after two or three automatic continuations on the same task."
- [inferred] This is per-turn thinking effort, not plan-document depth. It prescribes no plan size by task class.

## 2. OpenAI: Codex and GPT

Source: https://developers.openai.com/cookbook/examples/gpt-5/codex_prompting_guide (fetched 2026-10-05)
- [quoted] "Skip using the planning tool for straightforward tasks (roughly the easiest 25%)." "Do not make single-step plans."
- [quoted] "When you made a plan, update it after having performed one of the sub-tasks"; before finishing every item is "Done, Blocked ... or Cancelled."
- [quoted] "remove all prompting for the model to communicate an upfront plan, preambles ... as this can cause the model to stop abruptly" (older models; for 5.3-Codex, preambles are tuned to "1-2 sentence plan").
- [quoted] "Persist until the task is fully handled end-to-end"; "Bias to action: default to implementing with reasonable assumptions."

Source: https://learn.chatgpt.com/guides/best-practices (redirect from developers.openai.com/codex/learn/best-practices; fetched 2026-10-05)
- [quoted] "If the task is complex, ambiguous, or hard to describe well, ask Codex to plan before it starts coding." PLANS.md or execution plans are for "longer-running or multi-step work."
- Not found: a stopping rule for the planning phase, or a plan-length limit. The stopping rules found concern not stopping early during implementation.

Agreement: both vendors say skip planning for easy work and plan when ambiguous or multi-step. Difference [inferred]: Anthropic frames the plan as a human review gate and spec handoff to a fresh session; OpenAI frames it as a live checklist the agent updates while coding.

## 3. Practitioner and research evidence

- Empirical Study of Harness Design for Coding Agents, arXiv 2609.20804 (Sept 2026), https://arxiv.org/html/2609.20804v1. [quoted] "Planning changes from an accuracy scaffold to an efficiency aid as model capability increases." Nemotron-3 30B: +11.6 points on SWE-Bench Verified with planning, at higher cost. 120B: no consistent gain. 550B: -2.0 points, about 30% lower cost. Mistral-Medium-3.5: -0.4 points, about 32% lower cost. [inferred] Caveats: it ablates an in-loop plan tool, not a separate spec/review stage; open models, not Claude or GPT-6; no rework measure. I read the first 100k of 163k characters.
- From Plan to Action, arXiv 2604.12147 (ASE 2026), https://arxiv.org/html/2604.12147v1. Search snippet only: 16,991 SWE-agent trajectories; "providing the standard plan improves issue resolution, and periodic plan reminders can mitigate plan violations." [inferred] Supports re-reading the plan during execution, not writing longer plans.
- Addy Osmani, https://addyosmani.com/blog/good-spec/ (undated). [quoted] "adjust spec detail to task complexity. Don't under-spec a hard problem...but don't over-spec a trivial one." Cites the "curse of instructions." Practitioner opinion, no measurements seen.
- Augment Code guide (vendor content, weak): spec-driven development is usually not worth it for a one-off script or a feature smaller than its spec.
- No source found with measured plan depth versus rework for Claude Code or Codex workflows. Plan-mode tutorial blogs repeat the official triggers without data; not relied on.

Disagreement: spec-driven vendors argue more up-front spec reduces drift; the harness study and Anthropic's "try it, then rewind" advice say planning cost often exceeds benefit for capable models and reversible work.

## 4. Written-down heuristics for depth

- Anthropic: one-sentence-diff test; triggers are uncertain approach, multi-file, unfamiliar code. [quoted above]
- OpenAI: skip roughly the easiest 25%; plan when "complex, ambiguous, or hard to describe." [quoted above]
- Reversibility and blast radius: one-way versus two-way doors. Snippets only (https://www.sagarmandal.com/2026/03/15/agentic-engineering-part-8-decision-classification-how-one-way-and-two-way-doors-tell-your-agent-when-to-be-careful/ ; https://fs.blog/reversible-irreversible-decisions/): "One-way door decisions demand broader review and contingency planning." General decision theory, not agent measurements.
- Novelty and size appear only as Anthropic's "unfamiliar" and "multi-file" triggers. No numeric thresholds found.
- Not opened: the Sagar Mandal and fs.blog pages (snippets only). Nothing failed to load; the OpenAI best-practices URL redirected and I followed it.

## What I would put in a planning skill

1. Classify first in one line (one-sentence diff? files touched? novelty? reversible?); the class sets the depth. [sourced: Anthropic best-practices; door posts]
2. Tier 0, diff fits one sentence and is reversible: no plan, implement and run the check. [sourced]
3. Tier 1, multi-file, known pattern, git-revertable: a short checklist in the agent's task list, no separate spec, no review round. [inferred from OpenAI "no single-step plans" and live checklist]
4. Tier 2, unfamiliar, ambiguous, or one-way (schema migration, data deletion, deploy, public API): explore, then a spec naming files, out-of-scope items and an end-to-end verification; at most one review round. [sourced: Anthropic spec guidance; round cap inferred]
5. Fix the stop condition per tier: planning is done when files, out-of-scope and a runnable check are written; non-blocking questions become recorded assumptions, not another round. [contents sourced; the rule inferred from OpenAI "bias to action"]
6. Tell reviewers to flag only correctness or stated-requirement gaps; cap rounds (0 for Tier 1, 1 for Tier 2). [sourced: Anthropic reviewer warning; numbers inferred]
7. When undo is free (branch, checkpoint), prefer a cheap attempt over deeper planning; note that Bash side effects and the NAS are not covered by checkpoints. [sourced: Anthropic checkpoints; NAS note inferred]
8. Plan once, re-read it during implementation, tick items off; changes go in as edits, not a new planning phase; lower effort rather than prompt text to cut thinking. [sourced: arXiv 2604.12147 snippet, OpenAI plan updates, Opus 5.5 effort guidance]
