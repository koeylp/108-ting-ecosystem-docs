# AI Review Protocol

How the gates in [AI_DEVELOPMENT_WORKFLOW.md](AI_DEVELOPMENT_WORKFLOW.md) are reviewed.
It extends Rule 7 of [ENGINEERING_STANDARD_AI_AUTHORED.md](ENGINEERING_STANDARD_AI_AUTHORED.md):
the supervisor is not the reviewer, a gate is.

## Roles

- **Orchestrator** — the main Claude session. It is also the **implementation worker**: the only
  writer of code, records, commits, pushes and PRs.
- **Reviewers** — the seven agents pinned in [AI_AGENT_ROLES.lock](AI_AGENT_ROLES.lock), installed in
  `~/.claude/agents/`. Each has only `Read` and `mcp__memory-search__memory_search` (the second is
  exposed only once that MCP server is registered). None can edit, run commands, spawn agents,
  drive a browser or change external state.
- **Rapid Prototyper** returns prototype HTML in its reply; the orchestrator writes the file.

## Routing

| Gate | Reviewer | When |
|---|---|---|
| Plan (state 4) | `engineering-minimal-change-engineer` | every feature or fix |
| Plan (state 4) | `engineering-multi-agent-systems-architect` | several repos change; a shared interface, ownership or deployment topology changes; memory-search architecture changes; this workflow changes |
| Prototype (state 5) | `engineering-rapid-prototyper` | UI, layout, navigation, styling, interaction or user-visible states change |
| Code (state 7) | `engineering-code-reviewer` | every feature or fix |
| UI (state 10) | `design-ui-finish-gate-reviewer` | UI work, running locally |
| UI/integration evidence (state 10) | `testing-evidence-collector` | UI or integration behaviour needs screenshots, journeys or runtime proof |
| Final (state 11) | `testing-reality-checker` | every feature or fix |

## Running a reviewer

Each reviewer runs as its own headless Claude Code session in agent mode: a separate context
window, with its tools limited by the agent definition. The orchestrator relays everything;
the user never copies messages.

```
cd <worktree>
claude -p "Read <packet-dir>/<gate>-<n>.md and review it." \
  --agent <slug> --session-id <uuid> --add-dir ~/108-ecosystem \
  --output-format stream-json --verbose > <packet-dir>/<gate>-<n>.jsonl
# next round, same reviewer, same context:
claude -p "Read <packet-dir>/<gate>-<n+1>.md …" --agent <slug> --resume <uuid> … > …jsonl
```

`--add-dir` widens what `Read` may open (packets sit outside the worktree); it adds no tools.
Before accepting any reply, the orchestrator checks the `system/init` record of that run:
its `tools` list must contain `Read` and nothing outside the slug's `tools` in the lock (a declared
MCP tool whose server is not registered is simply absent). If it does not, the reply is void
and the gate stops ([enforcement check](#enforcement-check)). Session IDs per gate are kept in
`<packet-dir>/agents.json`. If a session cannot be resumed, a new session of the same slug gets
the earlier packets and findings.

## Review packet

`~/108-ecosystem/.ai/reviews/<work-item>/<gate>-<n>.md`. This sits outside every git root and outside
`.wt/`, so it is never committed or indexed. The packet holds the minimum the reviewer needs,
never the conversation transcript:

- work-item id; repo and worktree path; the user request; the approved plan; acceptance criteria
- memory-search results used; context-record paths
- base and head SHA; the **full diff text**; a `git ls-files` manifest; full contents of changed files;
  `rg` results for symbols the diff touches
- every command run, with exit code and output tail; test and build results; smoke evidence
- prototype and screenshots (UI); known limitations; explicit open questions

Runtime evidence (re-runs, screenshots, page text, console and network dumps) is produced by the
orchestrator in a **verification worktree** at the packet SHA:
`git worktree add --detach ~/108-ecosystem/.wt/<repo>/<branch>--verify <sha>`, removed with
`git worktree remove` after the gate. Rust builds there use
`CARGO_TARGET_DIR=~/108-ecosystem/.wt/<repo>/.verify-target`. Web setup is
`pnpm install --frozen-lockfile` (108heros-web: `pnpm bootstrap`). Flutter setup is
`flutter pub get` + `build_runner`, plus the documented gitignored config. A setup failure is
recorded as an environment limitation. A re-run that changes tracked files is a finding.
Playwright capture specs live in `<packet-dir>/capture/` with a wrapper config that imports the
repo's `playwright.config.ts` and overrides `testDir` and `outputDir`. "No tests found" is a
capture failure.

**Freeze rule.** While a review is open the orchestrator does not write to the implementation
worktree. On each reply it checks that worktree `HEAD == packet SHA` and that its status is clean;
otherwise the token is void.

## Reply grammar

First line, exactly: `DECISION: <TOKEN> @ <head-sha>`

| Gate | Tokens |
|---|---|
| plan | `PLAN_APPROVED` · `CHANGES_REQUIRED` |
| code | `CODE_APPROVED` · `CHANGES_REQUIRED` |
| UI | `UI_PASS` · `UI_HOLD` |
| final | `READY` · `NEEDS_WORK` |

- A positive token is followed by `EVIDENCE:`, listing what was reviewed and verified.
- A negative token is followed by numbered findings, each with `SEVERITY` (blocker/major/minor),
  `FINDING` (reproducible, with file:line), `REQUIREMENT` (requirement or invariant affected),
  `CORRECTION` and `CLOSURE` (the verification that closes it).
- A reviewer that needs more evidence adds a `REQUESTS:` block. The orchestrator runs the requests
  and appends the outputs. At most two request rounds per gate; after that the reviewer must decide.
- Ratings, encouragement and "looks good" are not decisions. A reply without a valid token for the
  current SHA is re-requested at most twice, then escalated to the user.

The role prompts' own verdict formats (emoji severities, letter grades, "NEEDS WORK", "HOLD") are
overridden by this grammar. Body instructions that need tools the reviewers do not have (shell
capture scripts, scaffolding, deploys) do not apply.

The token, SHA and reviewer slug of every gate go into the PR body; the context record's Evidence
links to the PR. (A commit cannot carry the token for its own SHA, so the record never does.)

## Enforcement check

[AI_AGENT_ROLES.lock](AI_AGENT_ROLES.lock) records the Claude Code version on which read-only
enforcement was proven. At state 1 of every work item, compare it with `claude --version`. If
the versions differ, re-run the negative test before spawning any reviewer. Count only the
platform's `system/init` tool list and actual call attempts as evidence, never the agent's
description of itself.

Negative test: run each slug with `--agent` and ask it to attempt Write, Edit, Bash, Agent,
ToolSearch, SendMessage, EnterWorktree and one tool each from context-mode, `ccd_*`, terminal,
scheduled-tasks and browser. Then resume the same session with `--resume` and attempt
Write/Edit/Bash again. Pass when both init records list only the allowlist and no file appears.
On a pass, update the lock. On a fail, stop: a fail-closed PreToolUse guard becomes a required
amendment, plan-reviewed before use.
