#!/usr/bin/env bash
# ai-bootstrap.sh — set up (or check) one machine for the 108 AI development workflow.
#
#   scripts/ai-bootstrap.sh            install what is missing, then run the read-only test
#   scripts/ai-bootstrap.sh --check    change nothing; report what is missing or drifted
#   scripts/ai-bootstrap.sh --skip-verify   install, but skip the read-only test
#                                           (7 short Haiku calls, one per reviewer agent)
#
# Run it from any checkout or worktree of this repo: it finds the primary checkout,
# and ~/108-ecosystem as that checkout's parent. macOS, or Linux with git, curl,
# python3 and shasum or sha256sum.
# Every pin comes from AI_AGENT_ROLES.lock beside this repo's root; nothing here is a second copy.
# Safe to re-run. Never overwrites a file that differs from the pin without saying so first.
set -euo pipefail

MODE=install; VERIFY=1
for a in "$@"; do
  case $a in
    --check) MODE=check ;;
    --skip-verify) VERIFY=0 ;;
    -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

DOCS=$(cd "$(dirname "$0")/.." && pwd)
# The root CLAUDE.md belongs beside the PRIMARY checkout, not beside a worktree under .wt/.
PRIMARY=$(dirname "$(git -C "$DOCS" rev-parse --path-format=absolute --git-common-dir)")
ECO=$(dirname "$PRIMARY")                  # ~/108-ecosystem
case "$ECO/" in
  */.wt/*) echo "the primary checkout of this repo is under .wt/ ($PRIMARY); clone it to ~/108-ecosystem/$(basename "$PRIMARY")" >&2; exit 1 ;;
esac
# Every doc assumes ~/108-ecosystem; a root CLAUDE.md anywhere else is loaded by nothing that matters.
[ "$(basename "$ECO")" = 108-ecosystem ] || { echo "this repo's primary checkout is $PRIMARY; the workflow expects it at ~/108-ecosystem/$(basename "$PRIMARY")" >&2; exit 1; }
LOCK=$DOCS/AI_AGENT_ROLES.lock
CLAUDE_DIR=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
FAIL=0
ok()   { printf '  ok    %s\n' "$*"; }
bad()  { printf '  MISS  %s\n' "$*"; FAIL=$((FAIL+1)); }
note() { printf '  note  %s\n' "$*"; }

for t in git curl python3 claude; do
  command -v $t >/dev/null || { echo "required tool not found: $t (install it, then re-run)" >&2; exit 1; }
done

# lock value: section key  ->  value (text after '=', comment stripped)
lockval() { awk -v s="[$1]" -v k="$2" '$0==s{f=1;next} /^\[/{f=0} f && $1==k {sub(/^[^=]*=[ ]*/,""); sub(/[ ]+#.*/,""); print; exit}' "$LOCK"; }
if command -v shasum >/dev/null; then sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
elif command -v sha256sum >/dev/null; then sha() { sha256sum "$1" | cut -d' ' -f1; }
else echo "required tool not found: shasum or sha256sum" >&2; exit 1; fi
raw() { curl -fsSL "https://raw.githubusercontent.com/$1/$2/$3"; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
STAMP=$(date +%Y%m%d%H%M%S)

# install <dest> <expected-sha256> <staged-file>
place() {
  local dest=$1 want=$2 staged=$3
  if [ "$(sha "$staged")" != "$want" ]; then bad "$dest: built file does not match the lock ($(sha "$staged"))"; return; fi
  if [ -f "$dest" ] && [ "$(sha "$dest")" = "$want" ]; then ok "$dest"; return; fi
  if [ "$MODE" = check ]; then bad "$dest ($([ -f "$dest" ] && echo differs || echo absent))"; return; fi
  if [ -f "$dest" ]; then  # backups go outside agents/ and skills/, where Claude Code looks
    local bak="$CLAUDE_DIR/.ai-bootstrap-backups/$STAMP/${dest#"$CLAUDE_DIR"/}"
    mkdir -p "$(dirname "$bak")"; cp "$dest" "$bak"; note "$dest differed; previous copy kept at $bak"
  fi
  mkdir -p "$(dirname "$dest")"; cp "$staged" "$dest"; ok "$dest (installed)"
}

echo "== agency-agents (reviewer roles)"
REPO=$(lockval agency-agents source | sed 's#https://github.com/##')
REV=$(lockval agency-agents revision)
TOOLS=$(lockval agency-agents tools)
while read -r path blob want; do
  slug=$(basename "$path" .md)
  raw "$REPO" "$REV" "$path" > "$TMP/$slug.up" || { bad "$slug: download failed"; continue; }
  [ "$(git hash-object "$TMP/$slug.up")" = "$blob" ] || { bad "$slug: upstream blob mismatch"; continue; }
  desc=$(awk 'NR>1 && /^---$/{exit} /^description: /{print; exit}' "$TMP/$slug.up")
  { printf -- '---\nname: %s\n%s\ntools: %s\n---\n' "$slug" "$desc" "$TOOLS"
    awk 'c>=2{print} /^---$/{c++}' "$TMP/$slug.up"; } > "$TMP/$slug.md"
  place "$CLAUDE_DIR/agents/$slug.md" "$want" "$TMP/$slug.md"
done < <(awk '/^\[agency-agents\]/{f=1;next} /^\[/{f=0} f && $1 ~ /\.md$/ {print $1, $2, $3}' "$LOCK")

echo "== karpathy-guidelines (skill)"
KREPO=$(lockval karpathy-guidelines source | sed 's#https://github.com/##')
raw "$KREPO" "$(lockval karpathy-guidelines revision)" "$(lockval karpathy-guidelines path)" > "$TMP/SKILL.md"
if [ "$(git hash-object "$TMP/SKILL.md")" = "$(lockval karpathy-guidelines upstream_blob)" ]; then
  place "$CLAUDE_DIR/skills/karpathy-guidelines/SKILL.md" "$(lockval karpathy-guidelines installed_sha256)" "$TMP/SKILL.md"
else bad "karpathy-guidelines: upstream blob mismatch"; fi

echo "== context-mode (plugin)"
# The CLI installs a plugin only at the marketplace's current version, so the pin is enforced after
# the fact: a version other than the lock's is a failure until a lock PR records it.
CM_WANT=$(lockval context-mode version)
cm_version() { claude plugin list --json 2>/dev/null </dev/null | python3 -c 'import json, sys
print(next((p.get("version", "") for p in json.load(sys.stdin) if p.get("id") == "context-mode@context-mode"), ""))' 2>/dev/null || true; }
CM_HAVE=$(cm_version)
if [ -z "$CM_HAVE" ] && [ "$MODE" = install ]; then
  claude plugin marketplace add mksglu/context-mode </dev/null >/dev/null 2>&1
  claude plugin install context-mode@context-mode </dev/null >/dev/null 2>&1 \
    || bad "context-mode install failed; run it once by hand: claude plugin install context-mode@context-mode"
  CM_HAVE=$(cm_version); [ -n "$CM_HAVE" ] && note "context-mode installed; restart Claude Code to load it"
fi
if [ -z "$CM_HAVE" ]; then bad "context-mode plugin not installed"
elif [ "$CM_HAVE" = "$CM_WANT" ]; then ok "context-mode $CM_HAVE"
else bad "context-mode $CM_HAVE installed, but the lock pins $CM_WANT: review the new version, then record it in AI_AGENT_ROLES.lock by PR"
fi
command -v rtk >/dev/null && ok "rtk $(rtk --version 2>/dev/null | awk '{print $2}')" || note "rtk not installed (optional token saver: brew install rtk)"

echo "== ecosystem root CLAUDE.md"
SRC=$PRIMARY/ECOSYSTEM_ROOT_CLAUDE.md
[ -f "$SRC" ] || bad "$SRC is missing: update the primary checkout ($PRIMARY) to a branch that has it"
for f in CLAUDE.md AGENTS.md; do
  [ -f "$SRC" ] || break
  dest=$ECO/$f
  if [ -L "$dest" ] && [ "$(cd "$ECO" && realpath "$f")" = "$(realpath "$SRC")" ]; then ok "$dest -> docs copy"
  elif [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    [ "$MODE" = check ] && bad "$dest absent" || { ln -s "$(basename "$PRIMARY")/ECOSYSTEM_ROOT_CLAUDE.md" "$dest"; ok "$dest (linked)"; }
  elif [ -L "$dest" ] && [ "$f" = AGENTS.md ] && [ "$(readlink "$dest")" = CLAUDE.md ]; then ok "$dest -> CLAUDE.md"
  elif cmp -s "$dest" "$SRC"; then note "$dest is a copy identical to the docs version; replace it with a symlink to stay in sync"
  else note "$dest differs from $SRC — left untouched. Shared facts go to ECOSYSTEM_ROOT_CLAUDE.md by PR; machine-only facts to your tool's memory. Then replace it with the symlink."; fi
done

echo "== memory-search"
if command -v memq >/dev/null; then ok "memq $(memq --version 2>/dev/null || true)"
else note "not installed — repo-scoped memory-search is not released yet; read docs/AI_CONTEXT_INDEX.md by hand"; fi

if [ "$MODE" = install ] && [ "$VERIFY" = 1 ] && [ "$FAIL" = 0 ]; then
  echo "== read-only test (AI_REVIEW_PROTOCOL.md#enforcement-check)"
  allowed=",${TOOLS// /},"
  while read -r path _; do
    slug=$(basename "$path" .md); probe="$TMP/probe-$slug"
    (cd "$TMP" && claude -p "Tool test, no other work: try once each to Write the file $probe, and to run the shell command 'touch $probe'. Then reply DONE." \
       --agent "$slug" --model haiku --output-format stream-json --verbose </dev/null 2>"$TMP/$slug.err") > "$TMP/$slug.jsonl" || true
    tools=$(grep -m1 '"subtype":"init"' "$TMP/$slug.jsonl" | sed -E 's/.*"tools":\[([^]]*)\].*/\1/' | tr -d '" ')
    extra=""; IFS=, read -ra arr <<< "$tools"; for t in "${arr[@]}"; do [[ $allowed == *",$t,"* ]] || extra+="$t "; done
    if [ -z "$tools" ]; then bad "$slug: no init record (is Claude Code logged in?): $(tail -c 300 "$TMP/$slug.err" | tr '\n' ' ')"
    elif [ -n "$extra" ] || [ -e "$probe" ]; then bad "$slug: NOT read-only (extra tools: ${extra:-none}; probe written: $([ -e "$probe" ] && echo yes || echo no))"
    else ok "$slug tools=[$tools]"; fi
  done < <(awk '/^\[agency-agents\]/{f=1;next} /^\[/{f=0} f && $1 ~ /\.md$/ {print $1}' "$LOCK")
  have=$(claude --version | awk '{print $1}'); want=$(lockval enforcement claude_code_version)
  [ "$have" = "$want" ] || note "Claude Code $have differs from lock $want: if the test passed, update [enforcement] in the lock by PR"
fi

echo
if [ "$FAIL" = 0 ]; then echo "ready — read AI_DEVELOPMENT_WORKFLOW.md before your next feature or fix"; else echo "$FAIL problem(s) above"; exit 1; fi
