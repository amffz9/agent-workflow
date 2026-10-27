# agent-workflow

Claude Code skills, in two plugins.

agent-workflow
- planning: decide how much planning a change needs, then write it as a contract implementation can follow.
- delegating-to-subagents: when and how to hand work to other agents, and how to brief them.
- codex: reviews and second opinions from the codex CLI.
- prompting-*: how to write prompts for specific Claude and GPT models.

android
- android-*: Android and Kotlin Multiplatform development, from architecture to testing.

## Install

    /plugin marketplace add amffz9/agent-workflow
    /plugin install agent-workflow@agent-workflow
    /plugin install android@agent-workflow

## Update

Edit the skills under plugins/<plugin>/skills/, commit and push.
On each machine: /plugin marketplace update agent-workflow

## Conventions

- Paths in skills are relative to the project they run in. No drive letters or machine paths.
- Temporary output goes to <scratchpad>/, the agent's session scratch folder.
