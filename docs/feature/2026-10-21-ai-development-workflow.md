---
type: feature
status: active
updated: 2026-10-21
areas:
  - ai-workflow
triggers:
  - ai development workflow
  - review gate
  - review worker
  - context record
  - agency agents
  - ขั้นตอนการทำงานของ AI
canonical_code:
  - AI_DEVELOPMENT_WORKFLOW.md
  - AI_REVIEW_PROTOCOL.md
  - AI_CONTEXT_CONVENTION.md
  - AI_AGENT_ROLES.lock
  - AI_CONTEXT_COMPACTION.md
supersedes: []
---

# One AI workflow for the whole ecosystem, with read-only reviewers that run as gates

## Why this exists
Agents and a human maintainer work these repos concurrently. Without one lifecycle, review
was ad hoc, durable reasons lived only in chat or in private agent memory, and reviewer
"approval" could come from an agent that could also edit the code. This record explains why the
canonical workflow is shaped as it is, so later changes keep its guarantees.

## Decision or root cause
The user approved a 15-state lifecycle, durable per-repo context records, normalized review tokens,
and a phased rollout (2026-10-21; rollout plan reviewed through five rounds).

- **Reviewer tools.** Reviewers get `Read` and memory_search only. A Bash allowlist cannot be made
  read-only: every candidate program has write or exec flags, and `git status` takes index locks.
- **Headless reviewers.** Reviewers run as headless `--agent` sessions. Each run's `system/init`
  record proves its tool list. A resumed session keeps its own context, and agent types installed
  mid-session are usable without a restart.
- **Docs repo PR route.** The docs repo PR goes to `108-Plaza` from the koeylp fork. No `-dev` mirror
  exists, and koeylp has no push access to the org repo.

## Must preserve
- No installed agent has a writer tool. The orchestrator is the only writer.
- A token counts only for the SHA it names. The tool list comes from the platform, not from the
  agent.
- Pins change only by PR, never by silently tracking upstream `main`.
- Root and per-repo `CLAUDE.md` additions stay pointers. The workflow is not copied into repos.

## What changed
Added the five `AI_*` documents at the repo root, this repo's `docs/` context skeleton, a pointer in
[CLAUDE.md](../../CLAUDE.md), and index rows in [README.md](../../README.md).

## Evidence
- **Plan review:** `PLAN_APPROVED` from engineering-minimal-change-engineer and
  engineering-multi-agent-systems-architect (round 5, 2026-10-21).
- **Pinned blobs:** the seven agency-agents files and the Karpathy SKILL.md were hashed against
  their pinned blobs ([AI_AGENT_ROLES.lock](../../AI_AGENT_ROLES.lock)).
- **Enforcement test:** on Claude Code 2.1.126, `system/init` tools were `["Read"]` before and after
  `--resume`, every forbidden tool was absent, and no file was written.
- **Code and final review:** tokens are in the PR body.

## Open follow-ups
- The retrieval section of AI_CONTEXT_CONVENTION.md is updated once repo-scoped memory-search ships.
- The compaction job is not yet installed.
- ACTIVE_WORK.md and CONTROL_DOC_COVERAGE.md are stale (2026-07-24/25); they need an owner refresh.
