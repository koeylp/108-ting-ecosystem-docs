# AI Context Compaction

Weekly maintenance of the records described in [AI_CONTEXT_CONVENTION.md](AI_CONTEXT_CONVENTION.md).

**Status:**
- **Where the job lives:** `memory-search-dev`, which already owns the nightly memory pipeline and
  its protections. It's in [yuthstyle88/memory-search-dev#4](https://github.com/yuthstyle88/memory-search-dev/pull/4),
  stacked on #2.
- **How to install it:** `scripts/install.sh --ecosystem-root ~/108-ecosystem --weekly-compaction`,
  from that repo's primary checkout.
- **Where it runs today:** on the owner's machine (2026-10-22). It runs once #2 and #4 merge and
  that checkout is updated.
- **Until it runs where you work:** do this procedure by hand when a repo's index grows stale.

## Schedule and lock

- Thursday 05:00 local time (owner's choice, 2026-10-22). A machine in repository-context mode
  never runs the nightly memory pipeline, so there is no 03:00 run to follow.
- `scripts/weekly-compact.sh` sits next to `scripts/nightly.sh` and takes the same lock,
  `<checkout>/.nightly.lock`: mkdir, pid file, take over from a dead holder, exit 0 while a live
  pid holds it.
- Both launchd plists are written by `install.sh` from the same primary checkout. The weekly job
  refuses to run if the nightly plist points at a different checkout.

## Per repository

1. Review records changed in the last 7 days.
2. Detect duplicates. Merge only records that describe the **same invariant**; keep every source
   link and every rationale.
3. Mark replaced records `superseded`, linked to their successor.
4. Move inactive history to `docs/context-archive/YYYY-QN/` with `status: archived`.
5. Update `docs/AI_CONTEXT_INDEX.md`, so that only active records are routed.
6. Rebuild the semantic index, then run representative queries, a repository-isolation check, and
   Thai and English queries where the repo has both.
7. Open a documentation PR only if something changed. Never auto-merge it.

Never replace precise records with a vague weekly summary.

## Safety

- **Isolation.** The run is headless, in a worktree `.wt/<repo>/chore-context-compact-<YYYY-Www>/`,
  with the nightly pipeline's flags: `--setting-sources project --permission-mode dontAsk`. Any
  permission denial fails the run.
- **Staging.** The model only writes staging output: full proposed files plus a move manifest.
- **Validation and apply.** The script, not the model, validates, then applies and commits:
  - only `docs/` paths change;
  - frontmatter is valid;
  - every superseded record names an existing successor;
  - archive paths match `YYYY-QN`;
  - the secret scan passes;
  - the commit is path-scoped.
  It then pushes to the repo's PR target.
- **Cleanup.** The worktree is removed by the next run, once its PR is merged or closed and CI has
  passed.
