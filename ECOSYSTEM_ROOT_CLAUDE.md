# 108 Ecosystem — machine layout

<!-- verified: 2026-09-02 (tree walk, `gh repo view`, `docker inspect`, `git worktree list`); machine-neutral since 2026-10-22. Re-verify anything older than two weeks. -->

This is `~/108-ecosystem/CLAUDE.md`, a symlink to `108-ting-ecosystem-docs/ECOSYSTEM_ROOT_CLAUDE.md`
(edit it there, by PR). **Claude Code** loads it as an ancestor of any
working directory below here. **Codex / ChatGPT** reads the same bytes through
`AGENTS.md` (a symlink beside this file) and the global `~/.codex/AGENTS.md`
(symlink here too — Codex does not walk above a repo root). `CLAUDE.md` is the
canonical name because the ecosystem's control-doc standard names it
(`108-ting-ecosystem-docs/CONTROL_DOC_COVERAGE.md`); `AGENTS.md` is only the door. Keep it under ~10 KB: Codex caps project docs
at 32 KB and this loads alongside each repo's own, so the real constraint is
whether a reader still finds the fact they came for.

## What lives where — the three tiers

| tier | lives in | who edits |
|---|---|---|
| **repo facts** — gates, quirks, "this fails silently because…" | each repo's `CLAUDE.md` (`AGENTS.md` → symlink), plus `.ai_context/` where present | anyone, by PR |
| **ecosystem design & decisions** — architecture, deployment allocation, ADRs, **`DO_NOT_TOUCH.md`** (read it first), `ACTIVE_WORK.md` (in-flight state / handoff) | `108-ting-ecosystem-docs/` (clone of `108-Plaza/108-ting-ecosystem-docs`) | owner, by PR |
| **machine layout** — layout, conventions, what runs locally | this file, shared by every team machine | anyone, by PR to `108-ting-ecosystem-docs` |
| **handoff / in-flight state** | `108-ting-ecosystem-docs/ACTIVE_WORK.md` — **stale since 2026-07-24**; refresh by PR before trusting it. The owner's 2026-09-01 instruction moving active work to `jh/` is the "explicit approval" `DO_NOT_TOUCH.md` requires for leaving POS108. | both tools |
| agent-private lessons ("prove RED first") | each tool's own memory | that tool |

Every fact in the first three tiers carries a `verified: <date>` and, where it
matters, the command that verified it. Facts rot within days here — three
private memories were wrong within a week of being written. Facts true on one
machine only go in your tool's own memory, not here.

## AI workflow

Before any feature or fix: read `108-ting-ecosystem-docs/AI_DEVELOPMENT_WORKFLOW.md` and invoke
the `karpathy-guidelines` skill. New machine, or `~/.claude/agents/engineering-code-reviewer.md`
missing: run `108-ting-ecosystem-docs/scripts/ai-bootstrap.sh` first.

## Layout (since 2026-09-02)

Directory name **is** the GitHub repo name. Check with `gh repo view <slug>`,
never the on-disk remote URL — renamed repos redirect silently and the URL keeps
lying. Org repos are `108-Plaza/<name>`; personal mirrors are
`yuthstyle88/<name>-dev`; a bridge merges them as `_bsync` commits.

**Work on the `-dev` mirror. Every 108jobs and 108heros repo, no exceptions**
(owner, 2026-09-10). Branch there, open the issue there, open and merge the PR
there; the org copy syncs automatically and is never a push or PR target. The
`-dev` suffix is the whole rule — no `gh repo view`, no PR-number archaeology, no
per-repo lookup table. Verified 2026-09-10: all five mirrors are unarchived and
writable, and all merge their own PRs.

This replaces a per-repo table that said `108heros-web` was org-trunk because
`108heros-web-dev#14` was closed and moved to `108-Plaza/108heros-web#80` on
2026-09-09 (*"repo นี้เป็นกระจกอ่านอย่างเดียว"*). That was one **issue** being
moved: PRs were merging on that same mirror throughout (#13, 2026-09-06). Do not
reinstate the table from a moved issue.

Clone only what you work on; whatever you clone goes where this tree puts it.

```
~/108-ecosystem/
  AGENTS.md  CLAUDE.md            symlinks to this file (scripts/ai-bootstrap.sh makes them)
  108-ting-ecosystem-docs/       ecosystem design + decisions (tier 2)
  jh/                            the jobs + heros family (was 108jobs/)
    108jobs-flutter-dev  108jobs-web-dev        jobs side
    108heros-flutter-dev 108heros-web-dev       rider side ("heros")
    jh-api-dev                                  ONE API serving both sides
    Recognize-Platform-dev                      Thai ID/licence reader (rider onboarding)
    local-media-stack/                          MAD media service compose + data (not a repo)
  108plaza-pos/   pos108-core-dev  pos108-admin-dev  pos108-orders-dev  pos108-pos-dev
  108bipbyte/     tix-tox-clone-dev  tixtox-web-dev  tixtox-clone-frontend-dev  imageprocessing-dev
  Identity-Platform-dev  Media-Platform-dev  Notification-Platform-dev
  Payment-Platform-dev   Livechat-Platform-dev (was message-platform-dev)
  memory-search-dev              memory_search MCP + nightly memory pipeline
  docker/                        July 2026 ecosystem compose — a relic, never adopted
  .wt/                           worktrees go here (see below)
  .ai/archive/                   retired notes, kept for triage
```

On a machine set up before 2026-09-02, `~/108-ecosystem/108jobs` may be a
**transitional symlink → jh/**, left so sessions and containers started before
the rename keep resolving. Remove it once
`lsof -a -d cwd` shows nothing under it and no key in `~/.codex/config.toml` /
`~/.claude.json` names the old path.

**Vocabulary in the ride code:** *rider* means the **driver**; the customer is
the **passenger**. Misreading this inverts most of `jh-api-dev/crates/logistics`.

## Working rules

- **Primary checkouts stay on the default branch and clean.** All work in a
  worktree: `~/108-ecosystem/.wt/<repo>/<branch>/`. Never `/private/tmp` (macOS
  purges it; one held a live database on 2026-09-01), never `.claude/worktrees`
  auto-dirs. `git worktree prune` when done.
- A fresh worktree is missing gitignored essentials: `config/*.json` /
  `config/*.hjson`, `.env`, and `packages/card_scan/ios/RecogFFI.xcframework`
  (167 MB, built from `Recognize-Platform-dev`, copy from another checkout). A
  device build without it dies with an opaque linker error (flutter #199).
- In `108heros-flutter-dev`, run `tool/ios_sim.sh --off` before committing
  `pubspec.lock` or `ios/Podfile.lock`, or the simulator stub ships to trunk
  (flutter #198 — it happened).
- Several agents and a human maintainer (yongyutjantaboot) work these repos
  concurrently and merge within minutes. Fetch before every merge; verify the
  tree you tested is the tree that merges (`git merge-base --is-ancestor`).
- `jh-api-dev` CI runs on every PR (`ci.yml`: `pull_request`, and pushes to
  `main`/`dev`; verified 2026-09-11 — it once ran only on `_bsync` commits).
  Match a run to the PR's head sha, and merge with `gh pr merge
  --match-head-commit <sha>`. Still run the four gates locally before pushing
  (its `AGENTS.md`/`CLAUDE.md` lists them) and say so in the PR.

## What runs locally — all of it in Docker

**Everything for 108jobs + 108heros runs as one Compose project, `jh`**, since
2026-09-02. Nothing is started by hand any more.

```bash
cd ~/108-ecosystem/jh/jh-api-dev/docker/local-stack
docker compose up -d api          # + postgres, redis, backbone-redis
docker compose up -d jobs-web     # http://localhost:3000
docker compose up -d heros-web    # http://localhost:3001
docker compose up -d              # all of it
```

`jh-postgres` :5432 · `jh-redis` :6379 · `jh-backbone-redis` :6380 ·
`jh-api` :8536 · `jh-jobs-web` :3000 · `jh-heros-web` :3001. Docker Desktop
shows them as one group. It lives in the repo (jh-api-dev #344, merged
2026-09-02); full detail — volumes, config, the private-dependency problem,
build times, four traps — is in its `README.md` beside `compose.yaml`.

Two neighbours keep their own repos and Compose projects and are reached over
`host.docker.internal`: **Identity-Platform** (:8090) and **MAD media**
(:8082 / :8091, from `jh/local-media-stack`).

**The Flutter apps cannot be containerised** — they build to iOS/Android and
need a simulator or a device. Run them from Xcode / Android Studio / `flutter
run`, pointed at `http://localhost:8536`.

Data lives in the `app108jobs_*` volumes (+ `jh_cargo_home`), declared `external`
so the rename did not orphan them: `app_108jobs` and `rider_flow_scratch`, which
the API config uses. **A fresh machine has none**, so `up` stops until they exist
(compose `README.md` → *Volumes*). `down` is safe; `down -v` destroys them.

pictrs is gone (removed 2026-09-01; MAD replaced it). The old `app108jobs`
Compose project — launched from a worktree that no longer exists and therefore
unmanageable — was retired in the same move.

**After every finished feature or fix: clean, then rebuild** (owner, 2026-09-14).
Build output piles up unseen — that day an orphaned Rust `target` volume from the
retired `app108jobs` project held 151 GB of a 441 GB macOS "System Data".

```bash
cd ~/108-ecosystem/jh/jh-api-dev/docker/local-stack
docker volume ls -f dangling=true   # while the stack is UP; rm orphans by name
docker compose down                 # never -v
docker builder prune -af && docker image prune -f
docker compose build --pull && docker compose up -d
```

List orphans **before** `down`: once it is down, the database volumes
(`app108jobs_*`, `jh_cargo_home`) look dangling too, and `down -v` or `docker
volume prune -a` destroys them. Restart Docker Desktop to return the space to
macOS. Xcode grows too: trash `~/Library/Developer/Xcode/DerivedData/*`, then
`xcrun simctl delete unavailable`.

## Decisions that shape everything (pointers, not copies)

- **Identity-Platform is the single auth authority** (owner, 2026-06-15,
  `Identity-Platform-dev/docs/IDENTITY_DECISION_RECORD.md`, D2/D6/D7). pos108 is
  the one permanent exception: offline `pos-auth`, never live JWKS. Built, not
  yet adopted by any consumer.
- **jobs and heros split on 2026-09-02** at the product level; the API is still
  shared. Ride fares: a quote is proposed as a *ceiling* (jh-api-dev #298, open),
  and whether "no deposit" bars coin payment at completion is an open owner
  question (#340). Neither is a ruling yet.

## Memory

Claude keys memory by working directory, with `/` turned into `-`:
`~/.claude/projects/-Users-<you>-108-ecosystem-<group>/memory/` — `jh` (also
under `108jobs` where that symlink exists), `108plaza-pos`, `108bipbyte`, and one
per platform repo. Start sessions from the group or repo dir you mean.
Codex has its own store (`~/.codex/memories`) and an optional
hosted MCP server (mnemoverse) enabled only on the Codex side — a recall
convenience, **never the source of truth**.

`.ai/archive/`, where a machine has one, holds notes copied out of an agent's
memory and never synced since. Treat them as unverified; fold anything still
true into a repo `CLAUDE.md`.

## Pending (owner)

Removing the `108jobs` symlink;
whether `jh/` gets `108jobs/` + `108heros/` subfolders.
