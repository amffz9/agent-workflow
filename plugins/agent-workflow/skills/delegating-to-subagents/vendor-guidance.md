# Vendor guidance behind this skill

Paraphrased. Follow the link before relying on a detail; both vendors move docs
without notice.

## Anthropic

| Claim | Source |
|---|---|
| Do it yourself for back-and-forth work, shared heavy context, quick targeted changes or latency-sensitive steps. Delegate verbose output, work needing tool limits, and self-contained work that returns a summary. | [CC] |
| Fork when a named agent would need too much background, or to try several approaches from one start. | [CC] |
| Opus over-delegates. Delegate only large, truly independent parallel work; not what a few tool calls finish; never to verify your own work. | [O5] |
| Verification lines ("double-check", "use a subagent to verify") make Opus over-verify. | [O5] |
| Agents ≈4x chat tokens, multi-agent ≈15x. Poor fit for tightly interdependent work. | [MARS] |
| Every delegation needs objective, output format, tool guidance and boundaries; vague briefs cause duplicated work. | [MARS] |
| A non-fork subagent sees only its prompt; only its final message returns. Return ~1–2k-token summaries; write large output to files. | [SDK], [CTX] |
| Model resolution: per-call `model` → frontmatter → `CLAUDE_CODE_SUBAGENT_MODEL` → parent. Only a definition's `effort` sets effort. | [CC] |
| Worktree isolation branches from the default branch, not the parent's HEAD. | [CC] |
| Say the why; say what to do rather than what to avoid; no ALL-CAPS. | [BP] |
| Sonnet 5 is literal and won't generalize an instruction; state full scope. | [S5] |
| "Only report high-severity" hides findings. Ask for everything with severity and confidence. | [O5], [S5] |
| `opus` resolves to Opus 5.5 in Claude Code 2.1.280+; default effort `medium`. | [CCM], [EFF] |
| Opus 5.5 can end a long task with a report while work remains; send open items back, two or three times at most. | [O55] |
| `sonnet` resolves to Sonnet 5.5 in Claude Code 2.1.284+; Claude Code default effort `medium`. | [CCM] |
| Sonnet 5.5 at `low`/`medium` may check in before finishing and at `low` may skip verification; at `xhigh`/`max` it starts its own review rounds, sometimes with reviewer subagents. | [S55] |

- [CC] https://code.claude.com/docs/en/sub-agents
- [CCM] https://code.claude.com/docs/en/model-config
- [SDK] https://code.claude.com/docs/en/agent-sdk/subagents
- [BP] https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- [O5] https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5
- [O55] https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5
- [S5] https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5
- [S55] https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5
- [EFF] https://platform.claude.com/docs/en/build-with-claude/effort
- [MARS] https://www.anthropic.com/engineering/multi-agent-research-system
- [CTX] https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents

## OpenAI

| Claim | Source |
|---|---|
| Start with one agent; split only for capability isolation, prompt clarity or trace legibility. | [GUIDE], [ORCH] |
| Codex subagents fit bounded, read-heavy lanes; parallel writers conflict. | [CXSUB] |
| Task prompt = goal, context, constraints, done-when. Durable rules belong in AGENTS.md. | [CXBP] |
| Contradictory instructions burn reasoning; state precedence explicitly. | [G6] |
| GPT-6 models ask and stop early; give a full definition of done and granted loops. | [G6], [ASTRA] |
| Reviews: findings first by severity with file:line, then open questions, summary last. | [CXPG] |
| Upfront plan requests can make Codex models stop early. | [CXPG] |
| `codex exec`: read-only by default; `-o` writes the final message only; `.git` stays read-only in workspace-write. | [CXEXEC], [CXSEC] |
| Codex starting efforts: Sol `medium`, Luna `high`, Astra `low`. | [MODELS] |
| GPT-6.1 Sol is the recommended Codex model for complex work; near-Astra at a fifth of the price. No `none`/`minimal` effort; tool calls need Responses. | [G6], [MODELS] |

- [GUIDE] https://cdn.openai.com/business-guides-and-resources/a-practical-guide-to-building-agents.pdf
- [ORCH] https://developers.openai.com/api/docs/guides/agents/orchestration
- [CXSUB] https://learn.chatgpt.com/docs/agent-configuration/subagents
- [CXBP] https://learn.chatgpt.com/guides/best-practices
- [CXPG] https://developers.openai.com/cookbook/examples/gpt-5/codex_prompting_guide.md
- [CXEXEC] https://learn.chatgpt.com/docs/non-interactive-mode.md
- [CXSEC] https://learn.chatgpt.com/docs/agent-approvals-security
- [MODELS] https://learn.chatgpt.com/docs/models
- [G6] https://developers.openai.com/api/docs/guides/latest-model?model=gpt-6-astra
- [ASTRA] https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra
