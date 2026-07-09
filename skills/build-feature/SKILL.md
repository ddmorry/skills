---
name: build-feature
description: Delegate one Issue to the Coding Agent (shared subagent bundled with afk-build-feature) to implement it TDD-style, get the gates green, and open a PR; the main session then runs an acceptance review (PR diff vs Issue / Design Doc) and stops at "ready to merge" — a human does the merge. This is the default feature-development skill, for Claude Tag (Claude in Slack) and review-required repos where direct pushes to main are forbidden; the human-merge counterpart of afk-build-feature (which runs Issue sets unattended all the way to merge). The main session never implements — it delegates one Issue and sticks to delegate / adjudicate questions / accept. Use by default when the user wants one Issue turned into a PR — e.g. "この Issue を実装して", "機能を実装して", "Issue #N をやって", "実装して PR を出して", "PR まで作って", "implement this issue", "open a PR for this". Use afk-build-feature only for unattended merge, running multiple Issues in sequence, or when "AFK" is stated explicitly.
argument-hint: "Issue number or URL to implement (e.g. #250)"
---

# Build Feature — delegate one Issue to the Coding Agent, stop at an open PR (human merges)

Delegate a single Issue to `coding-agent` (the shared implementation subagent bundled with [afk-build-feature](../afk-build-feature/agents/coding-agent.md)) and drive it up to an **open PR**. **The main session never writes code.** Its three jobs: **delegate**, **adjudicate questions**, **accept**. The endpoint is not a merge but an **open PR + acceptance notes handed off to a human**, who merges.

Vocabulary (delegation, rework, gate, acceptance, HITL, smoke) is defined in CONTEXT.md; the rationale is in docs/adr/0001–0002.

## build-feature vs afk-build-feature (which one)

- **build-feature (default)**: one Issue, stop at an open PR, **human merges**. For Claude Tag and review-required repos (direct push to main forbidden). No worktree isolation, no parallelism, no auto-merge.
- **afk-build-feature (only when explicitly asked)**: run a set of Issues unattended (AFK) all the way **to merge**. Higher risk, restricted use. Only when the user explicitly says "AFK", "run the Epic", "merge them in sequence", etc.

## Default policy (overridable at invocation)

- **selfFixBudget = 3**: gate-failure self-fix limit inside the Coding Agent (passed in the delegation prompt).
- **reworkBudget = 2**: at most 2 acceptance bounce-backs per Issue; on the 3rd, stop and hand to a human.
- **redelegateBudget = 1**: if the Coding Agent dies or goes off the rails, re-delegate once.
- **Acceptance = design reconciliation**: no style-level re-review (left to the agent's own code-review). Add real tests only for tricky spots.
- **Endpoint is an open PR + acceptance review — never a merge** (ADR-0002; Claude Tag requires review / forbids direct main push → a human merges).
- **No worktree**: one Issue, and the sandbox (Claude Tag) already isolates → do not pass `isolation` when delegating. No production / irreversible ops.

## On start (once)

1. **Read the Issue**: `gh issue view <N> --comments` — read the body (What to build / Acceptance criteria / Blocked by) and comments. **If it is a HITL Issue** (needs human implementation/judgment), do not start — hand it back to the human with the reason and stop.
2. **Design Doc preflight**: if the Issue references `## Design doc`, run `git fetch origin` and confirm the target exists on origin/main. If missing, **stop before starting** and prompt to ship it first (afk-ship).
3. **Resolve gate commands**: find test / lint / build via the target repo's CLAUDE.md → `docs/agents/` → package.json scripts, in that order. Default to `npm test` / `npm run lint` / `npm run build` if none found. Pass the resolved commands explicitly in the delegation prompt (do not let the agent guess).
4. **Confirm coding-agent availability**: if `coding-agent` is not in the agent list, symlink `afk-build-feature/agents/coding-agent.md` to `~/.claude/agents/coding-agent.md` (local only — under Claude Tag it is supplied from the same plugin's `agents/`). Only if it is still unusable, fall back to `subagent_type: "general-purpose"` + `model: "claude-opus-4-8"` and paste the agent definition body at the top of the delegation prompt (note: this fallback cannot guarantee `effort: xhigh`). If SendMessage is deferred, load it via ToolSearch.
5. Present the resolved Issue, gates, and policy **in one message, then start**.

## Delegate (once)

- Launch via the Agent tool: `subagent_type: "coding-agent"` (do not set model / effort — the frontmatter's `model: claude-opus-4-8` / `effort: xhigh` apply; passing `model` overrides them), `run_in_background: true`, and **do not pass `isolation`** (no worktree).
- Fill this delegation-prompt template (the agent cannot see the conversation — include every material):

```
Issue: #{{N}} (read the body and comments with gh)
Design Doc: {{path + section in docs/design/….md | none}}
Gates: {{resolved command list}}
selfFixBudget: {{3}}
Repo conventions: {{key points from the target repo's CLAUDE.md — test style, commit language, etc.}}
Notes: {{area-specific cautions, relevant ADR/CONTEXT.md locations. Omit if none}}
```

- Record the agent ID (all QUESTION answers, rework, and rebase instructions go to the same agent via SendMessage).

## Progress (on each notification)

**When a QUESTION arrives from the Coding Agent** (tiered by reversibility — same idea as grill-yourself-with-docs / afk-build-feature; under Claude Tag the human is in the Slack thread):

- **Reversible** (detailing, filling in the Design Doc, clarifying Issue interpretation): the main session decides on the spot within the bounds of existing ADR/PRD intent and answers via SendMessage. Record the ruling by (a) editing the Issue body (`gh issue edit`) and (b) noting it in the PR body / thread.
- **Irreversible / ADR change / PRD intent change**: confirm with the human in the Slack thread (proactive notification) before answering and recording.

**When a REPORT (PR opened) arrives, move to acceptance.**

## Acceptance (one PR)

- [ ] Read the full PR with `gh pr diff`.
- [ ] Reconcile each Acceptance criterion one by one.
- [ ] Check it does not contradict the relevant Design Doc section / related ADRs / CONTEXT.md vocabulary.
- [ ] Check tests were added as the Issue requires. Look in the diff for **tests that merely mirror the implementation, or test changes made just to pass**.
- [ ] If the reported gate results look off, for tricky spots / core functionality, or when you want to verify yourself, re-run the gates on the PR branch.
- [ ] Record any UI change as a **smoke item** (auto-gates cannot verify it → human QA).

**Pass** → **do not merge**. Append the acceptance notes (criteria checklist, smoke items, adjudicated questions) to the PR body and **stop with a proactive "ready to merge" summary**. A human reviews and merges on GitHub.

**Fail** → bounce back via SendMessage with **specific fix instructions** (up to reworkBudget).

## Stop and hand off to a human when

Stop and **notify proactively** with the reason and options when:

- reworkBudget / redelegateBudget is exceeded.
- A QUESTION is irreversible / ADR-level and needs human judgment.
- A design-conflict-level conflict that a rebase instruction cannot resolve.
- Production / irreversible ops (deploy, migration, secrets, data deletion) are requested.
- The input Issue turned out to be HITL (needs human implementation/judgment).

## Reporting

- Short progress at the delegate and acceptance milestones. **Proactive notification** on stop and on completion (ready-to-merge handoff).
- Closing summary: PR URL / acceptance notes / adjudicated questions / **smoke items** / remaining concerns. State explicitly that the merge is left to a human.

## Notes

- Output language (commits / PR / comments) follows the target repo's convention (Japanese for these repos). Commit / PR footers follow the harness instructions (also stated in the agent definition).
- **Never merge, never push directly to main, never `gh pr merge --admin`** (human merge only).
- `coding-agent` is the **shared agent bundled with afk-build-feature** (this skill keeps no copy — avoiding a second vendored source). Company distribution assumes both skills ship together.
