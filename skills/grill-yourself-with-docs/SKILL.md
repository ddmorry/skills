---
name: grill-yourself-with-docs
description: Self-grilling variant of grill-with-docs. The main agent spawns a Fable 5 sub-agent (the bundled grilling-agent, which embeds the full grill-with-docs methodology) that interviews the main agent instead of the human; the main agent answers from context the user provided upfront, CONTEXT.md and ADRs are produced during the session, and decisions are then reported to the user in three reversibility tiers — irreversible (tier-1) decisions are always confirmed via AskUserQuestion. Use when the user wants grill-with-docs outcomes without sitting through the interview — says "grill yourself", "self-grill", "セルフgrill", "自分でgrillして", or wants grills to run unattended / in parallel sessions.
---

# grill-yourself-with-docs

Keeps the outcomes of grill-with-docs (terminology accumulated in CONTEXT.md, decisions recorded as ADRs) while replacing the human interviewee with the session's main agent, eliminating the user's time commitment. The griller is a Fable 5 sub-agent defined in the bundled [agents/grilling-agent.md](./agents/grilling-agent.md); that definition embeds the full grill-with-docs methodology (interview techniques, CONTEXT.md/ADR formats), so this skill does not depend on the grill-with-docs skill being installed. The main agent plays three roles: answerer, keeper of the decision ledger, and reporter to the user.

## Pre-flight checks

1. **Confirm the plan and context**: verify the conversation contains the plan to grill (design, requirements, PRD, …) and the user context needed to ground answers. If missing, ask the user for it before starting — this is the only point where asking the user is allowed.
2. **Check grilling-agent availability**: verify `grilling-agent` is among the available agent types. If not, copy `agents/grilling-agent.md` from this skill's base directory to `~/.claude/agents/grilling-agent.md` (file watching auto-reloads it). Only if it still isn't usable, fall back to `subagent_type: "general-purpose"` + `model: "fable"` and paste the full body of the agent definition at the top of the launch prompt.
3. If the SendMessage tool is deferred, load it via ToolSearch.

## Phase 1: Launch the grilling agent

Launch with the Agent tool. The interview protocol lives in the agent definition, so the launch prompt carries only the dynamic payload:

- `subagent_type: "grilling-agent"` (no `model` needed — the frontmatter's `model: fable` applies)
- `run_in_background: false` (wait for the first question)
- prompt: fill this template:

```
Repository root: {{REPO_ROOT}}

## The plan to grill
{{PLAN}}

## Context provided by the human user
{{USER_CONTEXT}}
```

`{{PLAN}}` is the full plan text; `{{USER_CONTEXT}}` is every requirement, constraint, and preference the user gave, verbatim where possible. The sub-agent cannot see the parent conversation at all — embed everything it needs here.

The grilling agent runs the embedded grill-with-docs methodology: it explores the codebase itself, writes CONTEXT.md and ADRs (`status: proposed`) directly into the target repository, asks exactly one question per turn, and ends with `GRILL COMPLETE`.

## Phase 2: Answer loop

Reply to each of the grilling agent's final messages (= its question) via SendMessage. Repeat until `GRILL COMPLETE`. Ground every answer in this priority order:

1. **User context** — requirements, constraints, and preferences the user gave in conversation
2. **Codebase and existing docs** — explore yourself to verify when needed
3. **Adopt the recommendation (= assumption)** — only when 1 and 2 don't settle it, adopt the grilling agent's recommended answer after sanity-checking it, and mark the reply with `(assumption — pending human review)`

Rules during the loop:

- **Never ask the user.** Record uncertainties in the ledger and resolve them all at once in Phase 3. This is the skill's reason to exist.
- **Keep a decision ledger.** Per decision: what was decided / the adopted answer / basis (user-context | codebase | assumption) / estimated reversibility / the corresponding ADR, if any.
- If the session looks like exceeding 40 rounds, tell the grilling agent to converge on the highest-value remaining branches.

## Phase 3: Classify by reversibility and get the user's agreement

Classify the decision ledger into three tiers:

1. **Irreversible / costly to reverse** — public APIs and external contracts, DB schemas and data migrations, technology choices with lock-in, the architectural core
2. **Moderately costly to reverse** — module boundaries, internal interfaces, core terminology: things worth deciding precisely to avoid rework
3. **Easily reversible** — internal naming, implementation details, things cheap to change later

**Tier 1 always requires the user's answer/agreement via AskUserQuestion** (max 4 questions per call; put the adopted answer first labeled `(Recommended)`, with the reasoning and rejected alternatives in the description). Any decision whose basis is assumption is escalated to tier-1 confirmation even if its content is tier-2 grade. If there are zero tier-1 decisions, report that and skip AskUserQuestion.

## Phase 4: Apply and final report

- If the user overturns a decision: send it back to the grilling agent via SendMessage to fix CONTEXT.md / the ADRs (edit them directly as the main agent if the agent is gone).
- Flip approved tier-1 ADRs from `status: proposed` to `accepted`.
- The final message reports: all decisions organized in the three tiers (tier 1 including agreement outcomes), the list of CONTEXT.md / ADR files changed (with paths), and remaining assumptions/risks.

## Installation

This skill installs to two locations:

- Skill body → `~/.claude/skills/grill-yourself-with-docs/` (copy or symlink)
- Agent definition → copy `agents/grilling-agent.md` to `~/.claude/agents/grilling-agent.md` (auto-repaired by pre-flight check 2)

Workspaces that set `CLAUDE_CONFIG_DIR` do not read `~/.claude/` — install under `$CLAUDE_CONFIG_DIR/skills/` and `$CLAUDE_CONFIG_DIR/agents/` instead (a symlink per skill works; if `agents` is itself a symlink to `~/.claude/agents`, the agent definition needs no extra install).
