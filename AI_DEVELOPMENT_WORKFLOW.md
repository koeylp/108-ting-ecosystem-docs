# AI Development Workflow

The lifecycle every AI-assisted feature or fix follows in the 108 ecosystem. Read it when
you start a feature or fix; you do not need it for questions or read-only investigation.

Companion docs: [AI_REVIEW_PROTOCOL.md](AI_REVIEW_PROTOCOL.md) (how gates are reviewed),
[AI_CONTEXT_CONVENTION.md](AI_CONTEXT_CONVENTION.md) (durable context records),
[AI_AGENT_ROLES.lock](AI_AGENT_ROLES.lock) (pinned agents and skills),
[AI_CONTEXT_COMPACTION.md](AI_CONTEXT_COMPACTION.md) (weekly maintenance).
Machine facts (paths, Docker stack, cleanup commands) live in `~/108-ecosystem/CLAUDE.md`;
repository commands and hazards live in each repo's `CLAUDE.md`. This file does not copy them.

## Setting up a machine

Every team member runs `scripts/ai-bootstrap.sh` once, and again whenever `AI_AGENT_ROLES.lock`
changes. Run it from this repo's primary checkout at `~/108-ecosystem/108-ting-ecosystem-docs` or
any worktree of it; it finds the primary and the ecosystem root itself.
- **What it installs:** the pinned reviewer agents and the Karpathy skill.
- **context-mode:** it installs the plugin if it's missing, and fails unless the installed version
  is the one the lock pins.
- **The root `CLAUDE.md`:** it links `~/108-ecosystem/CLAUDE.md` and `AGENTS.md` to
  [ECOSYSTEM_ROOT_CLAUDE.md](ECOSYSTEM_ROOT_CLAUDE.md). It never replaces an existing root
  `CLAUDE.md`; it says how it differs.
- **The read-only test:** it runs it last, as 7 short Haiku calls. `--check` changes nothing and
  `--skip-verify` installs only; neither runs the test.
- **Backups:** a file that differs from its pin is backed up under
  `~/.claude/.ai-bootstrap-backups/` before it's replaced.
- **Platforms:** macOS, or Linux with `sha256sum`.

## Authority order

1. Explicit user instructions
2. Safety, permissions, destructive-action restrictions ([DO_NOT_TOUCH.md](DO_NOT_TOUCH.md))
3. Repository `CLAUDE.md` / `AGENTS.md`
4. This workflow and the ecosystem decisions in this repo
5. The approved plan and approved UI prototype
6. Retrieved context records
7. Agency Agent role prompts (`~/.claude/agents/`)
8. General defaults, including installed skills

Role prompts and skills never override a repository rule, an approved requirement or a
decision recorded here. Where the `karpathy-guidelines` skill says "present interpretations
and ask", the decision rule below governs.

## Golden rules

- **Context-mode.** Commands that read many files, search recursively, run tests or builds, read
  logs, inspect git history, query GitHub, Docker or APIs, or may print more than a small
  predictable amount go through the context-mode tools; only derived findings enter the
  conversation. Plain tools are for exact edits, small fixed outputs and git writes. If
  context-mode is unhealthy: run `ctx_doctor`, then `ctx_upgrade`, then report — never fall
  back silently to large raw reads.
- **Karpathy guidelines.** Invoke the `karpathy-guidelines` skill before planning or editing code.
  Smallest change that fully satisfies the requirement; state consequential assumptions; fix
  root causes; every changed line traces to the request; define observable success first;
  reproduce a bug before fixing it; verify, never claim.
- **Decision rule.** Decide when the evidence supports one clearly better path, and record why.
  Ask the user only when two or more valid choices remain and the choice changes product
  behaviour, UX, visual direction, a public interface, architecture or ownership, security or
  privacy, operating cost, data migration or compatibility, or irreversible external state.
- **PR targets.** 108jobs/108heros repos and `memory-search-dev`: the `yuthstyle88/<name>-dev`
  mirror, always. This docs repo has no mirror: PRs go to `108-Plaza/108-ting-ecosystem-docs`
  from a fork, and the owner merges.
- **Never:** `git reset --hard`, broad `git clean`, `docker compose down -v`, volume pruning,
  recursive deletion of a broad or unresolved path, deleting or overwriting unknown work.

## The lifecycle

States run in order. A later state never starts before the earlier one's exit criterion
holds. A fix that invalidates an earlier state sends the work back to that state.

**Docs-only changes** (no runtime behaviour changes) mark states 5, 8 and 10 `N/A` with the
reason in the context record; every other state still applies.

| # | State | Do | Exit criterion |
|---|---|---|---|
| 1 | Intake and recall | Identify affected repos; read their `CLAUDE.md`; query context (see [convention](AI_CONTEXT_CONVENTION.md#retrieval)) per repo; read related issues, ADRs, tests, code; check the Claude Code version against the lock ([protocol](AI_REVIEW_PROTOCOL.md#enforcement-check)). Define observable success criteria. Name the context record to create or update. | Scope, success criteria, context sources and open user decisions are explicit. |
| 2 | Clean baseline and isolation | `git fetch`; confirm the primary checkout is on its default branch and note whether it is clean (preserve, never clean, unknown changes — stop and report them); check `git worktree list` and open PRs for concurrent work; create the worktree `~/108-ecosystem/.wt/<repo>/<branch>/` from the fetched base; copy only documented gitignored prerequisites; run the repo's baseline gates. Bugs: issue first (see this repo's `CLAUDE.md`). | Work happens in an isolated worktree on verified remote state; baseline results recorded. |
| 3 | Plan | Write: outcome, scope, non-goals, repos, retrieved context, decisions, interfaces and invariants, files, test-first strategy, local runtime and smoke strategy, prototype strategy (UI), docs changes, rollback, risks, acceptance criteria, stop condition. No implementation. | Another engineer could implement and verify it without guessing product behaviour. |
| 4 | Plan review | Minimal Change Engineer; plus Multi-Agent Systems Architect when triggered ([routing](AI_REVIEW_PROTOCOL.md#routing)). Revise and resubmit to the same reviewer until approved. | Every required reviewer returns `PLAN_APPROVED`. |
| 5 | UI prototype and approval (UI work) | Rapid Prototyper drafts one self-contained HTML prototype showing loading, empty, error, success, disabled/permission-limited, narrow (375 px) and desktop states, with one clear primary action; it goes through plan review; show it to the user (private Artifact); wait for explicit approval. Save it as `docs/feature/assets/<record-slug>/prototype.html` with screenshots (PNG/WebP, ≤ 300 KB each, ≤ 10 per feature). | User approval of the prototype and its states is quoted, with its date, in the record. |
| 6 | Implementation | Implement only the approved plan; test first; for a bug, a failing reproduction before any production change; minimal diff; update the record as decisions or discoveries happen. No push, no PR. | Focused tests pass; the plan is satisfied locally. |
| 7 | Code review | Code Reviewer, with a review packet. Fix required findings within scope; scope-expanding suggestions go to follow-up issues; resubmit to the same reviewer. | `CODE_APPROVED` against the current head SHA. |
| 8 | Clean rebuild and local run | Record the reviewed SHA; run the repo's documented cleanup; rebuild from clean; start the full affected system; confirm the running build is the reviewed SHA. jh repos: the cleanup sequence in `~/108-ecosystem/CLAUDE.md`, in its exact order (list dangling volumes while up, `down` without `-v`, prune builders and images, `build --pull`, `up -d`). Preserve databases, volumes, credentials and user data. | The reviewed revision runs locally through the documented runtime path. |
| 9 | Smoke and integration | Focused tests; every repo-required gate; the changed user journey; affected integrations; error and recovery paths; concrete evidence; untested scope written down honestly. Multi-repo: test the exact revision combination intended for the PRs. | Every acceptance criterion has observed local evidence. |
| 10 | UI finish gate (UI work) | Capture desktop and narrow screenshots of every prototype state from the running build; UI Finish-Gate Reviewer compares them with the prototype; Evidence Collector checks journey coverage. On `UI_HOLD`: fix, rebuild, recapture, resubmit. | `UI_PASS` with evidence from the current SHA. |
| 11 | Final reality check | Reality Checker compares request, plan, prototype, diff, record, tests, smoke, integration and UI evidence, and known limits. On `NEEDS_WORK`: fix, then return to the earliest invalidated state. | `READY` for the current SHA. |
| 12 | Docs and evidence | Finalize the record; update `docs/AI_CONTEXT_INDEX.md`; mark superseded records; update ecosystem docs for cross-repo changes and repo docs where commands or behaviour changed; record exact tests, builds, smoke steps, screenshots, limits; check links. | Docs describe the observed, reviewed implementation. |
| 13 | Push and PR | Fetch again; `git merge-base --is-ancestor origin/<base> HEAD`; no unintended changes; push to the correct target; open the PR there with: outcome, scope, plan summary, record links, review decisions (token, SHA, reviewer), test/build/smoke evidence, screenshots (UI), risks, rollback, follow-ups, `Fixes #N`. Do not merge unless the user asks separately. | PR exists in the correct repo and references the pushed head SHA. |
| 14 | CI | Match CI to the exact head SHA; wait for required checks; investigate failures with context-mode; fix in the worktree; repeat the affected review and verification states; push; re-check. Where a repo has no runnable CI (see its `CLAUDE.md`), record that and the local gates in the PR. | All required checks pass for the head SHA, or CI absence is recorded. |
| 15 | Worktree cleanup | Only when everything is committed and pushed, the PR exists, CI passed, and no untracked, ignored or unknown file is still needed: `git worktree remove <path>`, `git worktree prune`, confirm the primary is clean and on its default branch, report the removed path and the branch/PR to recover from. | Worktree removed; work recoverable from the remote branch and PR. |

## Where things go

| What | Where |
|---|---|
| Why a feature/fix is the way it is, its invariants, evidence | that repo's `docs/feature/` or `docs/fix/` record ([convention](AI_CONTEXT_CONVENTION.md)) |
| Cross-repo architecture, workflow, ownership decisions | this repo |
| Machine layout, running stack, cleanup sequence | `~/108-ecosystem/CLAUDE.md` |
| Repo build/test/smoke/clean commands, hazards | that repo's `CLAUDE.md` |
| Review packets (transient) | `~/108-ecosystem/.ai/reviews/<work-item>/`, removed at state 15 |
