# AI Context Convention

Durable context: the short record of *why* a feature or fix is the way it is, kept in the repo
that owns the code. Markdown in git is the source of truth. Embeddings and retrieval caches are
derived data, kept outside git.

## Layout (every participating repo)

```
docs/AI_CONTEXT_INDEX.md      routing table — not a source of truth
docs/feature/YYYY-MM-DD-<short-slug>.md
docs/fix/YYYY-MM-DD-<short-slug>.md
docs/feature/assets/<record-slug>/   UI prototype + screenshots (UI work only)
docs/context-archive/YYYY-QN/        inactive records, kept for provenance
```

Every feature or fix creates or updates **exactly one** record in each affected repo. When the same
decision or invariant changes, update the existing record rather than adding one. A small change
gets a short record, but it still states the durable reason, the invariant and the evidence.

## Record template

```markdown
---
type: feature            # or: fix
status: active           # active | superseded | archived
updated: YYYY-MM-DD
areas:
  - <owned area>
triggers:
  - <phrase a future agent may search, English or Thai>
canonical_code:
  - <repo-relative path>
supersedes: []           # repo-relative paths of records this one replaces
---

# <Outcome-oriented title>

## Why this exists
Why a future agent needs this record.

## Decision or root cause
Feature: the approved behaviour and why. Fix: the symptom, the reproduced failure, the root cause,
and why the fix addresses that cause.

## Must preserve
Invariants future work must keep.

## What changed
Concise, with links to source.

## Evidence
Issue, PR (it carries the review tokens), tests, commands, screenshots, source locations,
or the user's explicit decision.

## Open follow-ups
Known unresolved items, or "None".
```

Normally under 400 words. Link to code, tests, ADRs, issues and PRs instead of copying them.

**Never store:** chat transcripts; routine command output; raw production logs; secrets, tokens or
personal data; large copies of source code; material that duplicates a README or ADR; speculation
presented as fact; narration with no future consequence.

## Index template

```markdown
# AI Context Index

Read this file only to locate context relevant to the current task.
Read a linked record only when its trigger matches the task.

## Active

| Trigger | Record | Use when |
|---|---|---|
| <search terms> | [Title](feature/example.md) | <task condition> |

## Superseded

| Former record | Replaced by |
|---|---|
| <old> | <new> |
```

A record is retrievable only when its frontmatter says `status: active` **and** the index lists it
under Active. Superseded and archived records stay in git but are excluded from normal retrieval.
When a record is replaced:

- set the old record's `status: superseded`;
- list the old record in the new one's `supersedes:`;
- move the row to the Superseded table.

Archiving moves a record to `docs/context-archive/YYYY-QN/` with `status: archived`.

## Relation to existing conventions

| Convention | Holds | Relation |
|---|---|---|
| `docs/feature`, `docs/fix` | durable why, invariants, evidence for a change | this convention |
| `.ai_context/` | handoff and in-flight task state | unchanged; not migrated; records may link to it |
| `docs/superpowers/{specs,plans}` | plan artefacts | linked from a record's Evidence |
| `docs/design/`, `docs/adr/`, ADRs here | design and decisions | canonical; records link, never copy |
| [CONTROL_DOC_COVERAGE.md](CONTROL_DOC_COVERAGE.md) six-doc standard | per-repo control docs | unchanged |

## Retrieval

**Today:** read `docs/AI_CONTEXT_INDEX.md` in the repo you are working in, and open only the records
whose trigger matches the task. Read another repo's records only when the task touches that repo.

**Once repo-scoped memory-search is installed.** That's
[yuthstyle88/memory-search-dev#2](https://github.com/yuthstyle88/memory-search-dev/pull/2), installed with
`scripts/install.sh --ecosystem-root ~/108-ecosystem` from that repo's primary checkout (macOS):

- call `memory_search(query, worktree_root=<current worktree>, limit=3)`;
- a worktree sees its own uncommitted record edits;
- ecosystem-wide search needs an explicit `scope="ecosystem"`;
- the UserPromptSubmit hook injects at most three active records from the current repo, and nothing
  below its calibrated threshold.
