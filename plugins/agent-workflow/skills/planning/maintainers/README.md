# Maintaining the planning skill

This folder is for people editing the skill. Agents never load it.


## Files

- SKILL.md: always loaded when the skill runs. Tiers, the steps, and pointers to the rest.
- references/contract.md: loaded for Tier 2. Template, rules, examples and tests, gates.
- references/review.md: loaded when reviewing a plan. Findings rules and the findings log.
- references/parallel.md: loaded for plans with more than three parts or implementers.
- references/shared-checkout.md: loaded when several agents share one checkout.
- maintainers/evidence.md: where each rule came from, and how sure we are.
- maintainers/research/: the raw research reports behind evidence.md.


## Conventions

- One rule per bullet, one idea per sentence. Give a reason only when the rule would look arbitrary without it.
- Say each thing in exactly one file. Other files point to it.
- Use plain lists, not tables, in agent-facing files; they read and edit better as raw text.
- Templates go in code blocks.
- Sources, numbers and history go in evidence.md, never in the agent-facing files.
- Keep SKILL.md to what every planning task needs. Anything only some tasks need goes in a reference file, with a line in SKILL.md saying when to read it.


## Changing a rule

1. Edit the one file that holds the rule.
2. If the rule's basis changed, update its row in evidence.md (sourced, inferred, measured).
3. Search the other files for the old wording to make sure nothing still repeats it.
